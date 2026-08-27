<script setup>
import { ref, onMounted, onUnmounted, computed, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { usePlatform } from '../composables/usePlatform'
import CarrierProfile from '../components/CarrierProfile.vue'
import { supabase, fmtTZS } from '../lib/supabase'
import { humanError } from '../lib/humanError'
import Icon from '../components/Icon.vue'
import EmptyState from '../components/EmptyState.vue'
import BrandMark from '../components/BrandMark.vue'
import CarrierMark from '../components/CarrierMark.vue'
import Spinner from '../components/Spinner.vue'

const router = useRouter()
const toast = inject('toast')
const { profile, isPlatformAdmin, setHat, signOut } = useAuth()
const plat = usePlatform()

const carriers = ref([])
const stats = ref({ carriers: 0, consignments: 0, onRoad: 0, settledToday: 0 })
const loading = ref(true)
const ptab = ref('carriers')   // carriers | money | problems | analytics | people

// aggregated platform data
const money = ref({ owed: 0, held: 0, settled: 0, byCarrier: [] })
const problems = ref([])        // failed parcels + cash gaps across all carriers
const analytics = ref({ byStage: [], byCarrier: [], topCorridors: [] })
const people = ref([])          // all staff + drivers across carriers
const pendingProps = ref([])
const propsLoading = ref(false)
const fairCheck = ref({})
async function loadPendingProps() {
  propsLoading.value = true
  try {
    const { data } = await plat.pendingProperties()
    pendingProps.value = data?.listings || []
  } catch (e) { pendingProps.value = [] }
  propsLoading.value = false
}
async function reviewProp(id, decision) {
  try {
    const { data } = await plat.reviewProperty(id, decision, !!fairCheck.value[id])
    if (data?.ok) { toast(decision==='verified' ? 'Published' : 'Rejected', 'ok'); await loadPendingProps() }
    else toast(data?.error || 'Could not review', 'warn')
  } catch (e) { toast('Could not review', 'warn') }
}
const independent = ref([])
const indepLoading = ref(false)

// #2 dispute resolution
const disputes = ref([])
const REASONS = { not_delivered:'Never delivered', damaged:'Arrived damaged', wrong_item:'Wrong item', not_as_described:'Not as described', other:'Other issue' }

// #10 shop verification
const shopApps = ref([])
async function loadShopVerifications() {
  try { const { data } = await supabase.rpc('admin_shop_verifications'); shopApps.value = data?.shops || [] } catch (e) {}
}
async function reviewShop(id, decision) {
  try {
    const { data } = await supabase.rpc('admin_review_shop', { p_id: id, p_decision: decision })
    if (data?.ok) { toast(decision==='verified' ? 'Shop verified' : 'Application rejected', 'ok'); await loadShopVerifications() }
    else toast(data?.error || 'Could not review', 'warn')
  } catch (e) { toast('Could not review', 'warn') }
}

// enforced category taxonomy management
const cats = ref([])
async function loadCategories() {
  try { const { data } = await supabase.rpc('admin_list_categories'); cats.value = data?.categories || [] } catch (e) {}
}
function newCategory() { cats.value.unshift({ id: null, name: 'New category', sort: 100, active: true, product_count: 0 }) }
async function saveCat(cat) {
  try {
    const { data } = await supabase.rpc('admin_save_category', { p_id: cat.id, p_name: cat.name, p_sort: cat.sort || 100, p_active: cat.active })
    if (data?.ok) { if (!cat.id) await loadCategories() } else toast(data?.error || 'Could not save', 'warn')
  } catch (e) { toast('Could not save', 'warn') }
}
function reasonLabel(r) { return REASONS[r] || r }
async function loadDisputes() {
  try { const { data } = await supabase.rpc('admin_disputes'); disputes.value = data?.disputes || [] } catch (e) { disputes.value = [] }
}
async function doResolve(d, resolution) {
  try {
    const { data } = await supabase.rpc('resolve_dispute', { p_id: d.id, p_resolution: resolution })
    if (data?.ok) {
      if (resolution === 'resolved_buyer') { try { await supabase.rpc('refund_escrow', { p_consignment_id: d.consignment_id }) } catch (e) {} }
      toast('Dispute resolved', 'ok'); await loadDisputes()
    } else toast(data?.error || 'Could not resolve', 'warn')
  } catch (e) { toast('Could not resolve', 'warn') }
}
const unassigned = ref([])
const assignDrv = ref(null)
async function loadIndependent() {
  indepLoading.value = true
  try {
    const { data } = await plat.independentDrivers()
    independent.value = data?.drivers || []
  } catch (e) {}
  indepLoading.value = false
}
async function openAssign(d) {
  assignDrv.value = d
  try { const { data } = await plat.unassignedParcels(); unassigned.value = data?.parcels || [] } catch (e) { unassigned.value = [] }
}
async function doAssign(code) {
  try {
    const { data } = await plat.assignIndependent(code, assignDrv.value.id)
    if (data?.ok) { toast(`${code} assigned to ${assignDrv.value.name}`, 'ok'); assignDrv.value = null; await loadIndependent() }
    else toast(data?.error || 'Could not assign', 'warn')
  } catch (e) { toast('Could not assign', 'warn') }
}
const applications = ref([])    // pending carrier applications
const revenue = ref({ mrr: 0, paying_carriers: 0, overdue_carriers: 0, free_carriers: 0 })

// onboarding form
const showForm = ref(false)
const f = ref({ name: '', slug: '', mark: '', accent: '#0B6E5D', region: '', adminEmail: '', reg_number:'', about:'', contact_person:'', phone:'', address:'', fleet_size:'', vehicle_types:'', corridors:'', listed_in_marketplace:true })
const busy = ref(false)

// The platform console is Enkiama Cargos' OWN surface — always brand teal,
// never the accent of whatever carrier is signed in (white-label is for carrier surfaces only).
const BRAND = '#0B6E5D'
onMounted(() => {
  document.documentElement.style.setProperty('--accent', BRAND)
  load()
})
onUnmounted(() => {
  // let App.vue's white-label watcher re-apply the carrier accent when leaving
  document.documentElement.style.removeProperty('--accent')
})
let platPoll = null
onMounted(() => { platPoll = setInterval(() => { if (document.visibilityState === 'visible') load() }, 10000) })
onUnmounted(() => { if (platPoll) clearInterval(platPoll) })
async function load() {
  loading.value = true
  const { data: cs } = await plat.listCarriers()
  carriers.value = cs || []
  const { data: cons } = await plat.listConsignmentsLite()
  const all = cons || []
  // platform cash: pull payments for money view
  const { data: pays } = await plat.listPaymentsLite()
  const payByCons = {}; (pays||[]).forEach(p => { payByCons[p.consignment_id] = p })
  const consById = {}; all.forEach(c => consById[c.id] = c)

  const onRoadStages = ['collected','linehaul','with_driver']
  stats.value = {
    carriers: carriers.value.length,
    consignments: all.length,
    onRoad: all.filter(c => onRoadStages.includes(c.stage)).length,
    delivered: all.filter(c => ['delivered','confirmed'].includes(c.stage)).length,
    needsAction: all.filter(c => ['booked','failed'].includes(c.stage)).length,
  }
  // per-carrier health
  const byCarrier = {}
  all.forEach(c => {
    const b = byCarrier[c.carrier_id] || (byCarrier[c.carrier_id] = { total:0, onRoad:0, done:0, issues:0 })
    b.total++
    if (onRoadStages.includes(c.stage)) b.onRoad++
    if (['delivered','confirmed'].includes(c.stage)) b.done++
    if (c.stage === 'failed') b.issues++
  })
  carriers.value.forEach(c => {
    const b = byCarrier[c.id] || { total:0, onRoad:0, done:0, issues:0 }
    c._count = b.total; c._onRoad = b.onRoad; c._done = b.done; c._issues = b.issues
    c._pct = b.total ? Math.round(b.done / b.total * 100) : 0
    c._status = b.total === 0 ? 'idle' : (b.issues > 0 ? 'attention' : (b.onRoad > 0 ? 'active' : 'steady'))
  })

  // ── richer data for money / problems / analytics / people ──
  const { data: fullCons } = await plat.listConsignmentsFull()
  const cons2 = fullCons || []
  const carrierName = {}; carriers.value.forEach(c => carrierName[c.id] = c)

  // MONEY: owed / held / settled across all carriers
  let owed=0, held=0, settled=0
  const mByCarrier = {}
  ;(pays||[]).forEach(p => {
    const con = cons2.find(c => c.id === p.consignment_id)
    if (!con) return
    const cid = con.carrier_id
    const m = mByCarrier[cid] || (mByCarrier[cid] = { owed:0, held:0, settled:0 })
    if (p.mode === 'cash') {
      if (p.state === 'owed') { owed += p.cod_amount||0; m.owed += p.cod_amount||0 }
      else if (p.state === 'collected') { held += p.cod_amount||0; m.held += p.cod_amount||0 }
      else if (['remitted','settled'].includes(p.state)) { settled += p.cod_amount||0; m.settled += p.cod_amount||0 }
    }
  })
  money.value = {
    owed, held, settled,
    byCarrier: carriers.value.map(c => ({ ...c, ...(mByCarrier[c.id]||{owed:0,held:0,settled:0}) }))
      .filter(c => c.owed||c.held||c.settled).sort((a,b)=>(b.owed+b.held)-(a.owed+a.held)),
  }

  // PROBLEMS: failed parcels + cash held-not-remitted, across all carriers
  const probs = []
  cons2.filter(c => c.stage === 'failed').forEach(c => {
    probs.push({ type:'failed', id:c.id, code:c.code, carrier:carrierName[c.carrier_id], receiver:c.receiver_name, addr:c.dest_address, detail:'Delivery failed' })
  })
  ;(pays||[]).filter(p => p.mode==='cash' && p.state==='collected').forEach(p => {
    const con = cons2.find(c => c.id === p.consignment_id); if (!con) return
    probs.push({ type:'cash', id:con.id, code:con.code, carrier:carrierName[con.carrier_id], receiver:con.receiver_name, detail:`TZS ${(p.cod_amount||0).toLocaleString()} collected, not remitted` })
  })
  problems.value = probs

  // ANALYTICS: stage distribution + per-carrier volume + top corridors
  const stageCount = {}
  cons2.forEach(c => stageCount[c.stage] = (stageCount[c.stage]||0)+1)
  const corridors = {}
  cons2.forEach(c => { const k = (c.dest_address||'—').split(',')[0].trim(); corridors[k]=(corridors[k]||0)+1 })
  analytics.value = {
    byStage: Object.entries(stageCount).map(([stage,n])=>({stage,n})).sort((a,b)=>b.n-a.n),
    byCarrier: carriers.value.map(c=>({name:c.name, slug:c.slug, accent:c.accent, n:c._count})).sort((a,b)=>b.n-a.n),
    topCorridors: Object.entries(corridors).map(([place,n])=>({place,n})).sort((a,b)=>b.n-a.n).slice(0,6),
  }

  // PEOPLE: all drivers + staff across carriers
  const { data: drivers } = await plat.listDrivers()
  const { data: profiles } = await plat.listProfiles()
  const ppl = []
  ;(profiles||[]).forEach(p => ppl.push({ kind:'staff', name:p.name||'—', role:p.role, carrier:carrierName[p.carrier_id] }))
  ;(drivers||[]).forEach(d => ppl.push({ kind:'driver', name:d.name, role:d.active?'driver (active)':'driver (off)', carrier:carrierName[d.carrier_id], vehicle:d.vehicle }))
  people.value = ppl

  // carrier applications (pending first)
  const { data: apps } = await plat.listApplications()
  applications.value = apps || []

  const { data: rev } = await plat.revenue()
  if (rev && rev[0]) revenue.value = rev[0]

  loading.value = false
}

function autoSlug() {
  if (!f.value.slug) f.value.slug = f.value.name.toLowerCase().replace(/[^a-z0-9]+/g,'').slice(0,12)
  if (!f.value.mark) f.value.mark = f.value.name.slice(0,2).toUpperCase()
}

async function onboard() {
  const v = f.value
  if (!v.name || !v.slug || !v.adminEmail) { toast('Name, slug and admin email are required', 'warn'); return }
  busy.value = true
  const { error } = await plat.createCarrier({
    p_slug: v.slug, p_name: v.name, p_mark: v.mark || v.name.slice(0,2).toUpperCase(),
    p_accent: v.accent, p_region: v.region, p_admin_email: v.adminEmail,
    p_reg_number: v.reg_number || null, p_about: v.about || null, p_contact_person: v.contact_person || null,
    p_phone: v.phone || null, p_address: v.address || null,
    p_fleet_size: v.fleet_size ? Number(v.fleet_size) : null, p_vehicle_types: v.vehicle_types || null,
    p_corridors: v.corridors || null, p_listed: v.listed_in_marketplace,
  })
  busy.value = false
  if (error) { toast(error.message || 'Could not onboard carrier', 'warn'); return }
  toast(`${v.name} onboarded — invite sent to ${v.adminEmail}`, 'ok')
  showForm.value = false
  f.value = { name: '', slug: '', mark: '', accent: '#0B6E5D', region: '', adminEmail: '', reg_number:'', about:'', contact_person:'', phone:'', address:'', fleet_size:'', vehicle_types:'', corridors:'', listed_in_marketplace:true }
  load()
}

function runAsEnkiama() {
  // switch hat to carrier console (platform admin also runs Enkiama)
  setHat('carrier'); router.push('/dispatch')
}
async function logout() { await signOut(); router.push('/login') }

// ── PHASE 1.1: platform admin ACTS on problems (with clear confirmation) ──
const actingOn = ref(null)  // id currently being acted on (for button feedback)
async function flagProblem(p) {
  if (!p.id) return
  actingOn.value = p.id
  try {
    const note = p.type === 'cash' ? 'Cash gap — follow up on remittance' : 'Failed delivery — needs follow-up'
    const { error } = await plat.flagConsignment(p.id, note)
    if (error) throw error
    toast(`${p.code} flagged for follow-up — ${p.carrier?.name || 'carrier'} will see it`, 'ok')
    p._flagged = true
  } catch (e) { toast(e.message || 'Could not flag', 'warn') }
  actingOn.value = null
}
function nudgeCarrier(p) {
  // opens a pre-filled message the admin can send the carrier (clear, no silent action)
  const msg = p.type === 'cash'
    ? `Hi ${p.carrier?.name}, parcel ${p.code} has cash collected but not yet remitted. Please reconcile.`
    : `Hi ${p.carrier?.name}, parcel ${p.code} (to ${p.receiver}) failed delivery. Please arrange a retry.`
  navigator.clipboard?.writeText(msg).then(() => {
    toast(`Nudge message for ${p.carrier?.name} copied — paste it to them`, 'ok')
  }).catch(() => toast('Could not copy message', 'warn'))
}

// ── PHASE 3: approve / reject carrier applications ──
const reviewApp = ref(null)
const appSlug = ref(''); const appAccent = ref('#3E5BD6'); const appBusy = ref(false)
function openApprove(app) {
  reviewApp.value = app
  appSlug.value = app.company_name.toLowerCase().replace(/[^a-z0-9]+/g,'').slice(0,16)
  appAccent.value = '#3E5BD6'
}
async function confirmApprove() {
  if (!appSlug.value.trim()) { toast('Pick a slug (short handle)', 'warn'); return }
  appBusy.value = true
  try {
    const { error } = await plat.approveApplication({
      p_app: reviewApp.value.id, p_slug: appSlug.value.trim(), p_accent: appAccent.value })
    if (error) throw error
    toast(`${reviewApp.value.company_name} approved — now a live carrier`, 'ok')
    reviewApp.value = null
    await load()
  } catch (e) { toast(e.message || 'Could not approve', 'warn') }
  appBusy.value = false
}
async function rejectApp(app) {
  const reason = prompt(`Reject ${app.company_name}? Optional reason:`, '')
  if (reason === null) return
  try {
    const { error } = await plat.rejectApplication(app.id, reason)
    if (error) throw error
    toast(`${app.company_name} declined`, 'ok')
    await load()
  } catch (e) { toast(e.message || 'Could not reject', 'warn') }
}
const pendingApps = computed(() => applications.value.filter(a => a.status === 'pending'))

// ── billing (dormant/free now, but the machinery is ready) ──
const billingFor = ref(null)   // carrier open in billing editor
const billPlan = ref('free'); const billFee = ref(0)
function openBilling(c) { billingFor.value = c; billPlan.value = c.billing_plan || 'free'; billFee.value = c.monthly_fee || 0 }
async function saveBilling() {
  try {
    const { error } = await plat.setBilling(billingFor.value.id, billPlan.value, Number(billFee.value)||0)
    if (error) throw error
    toast(`${billingFor.value.name} set to ${billPlan.value}${billPlan.value==='monthly'?' · '+fmtTZS(Number(billFee.value)||0)+'/mo':''}`, 'ok')
    billingFor.value = null; await load()
  } catch (e) { toast(e.message || 'Could not update billing', 'warn') }
}
async function recordPayment(c) {
  try {
    const { error } = await plat.recordPayment(c.id)
    if (error) throw error
    toast(`Payment recorded for ${c.name}`, 'ok'); await load()
  } catch (e) { toast(e.message || 'Could not record', 'warn') }
}
function fmtDate(d) { return d ? new Date(d).toLocaleDateString() : '—' }

// ── admin: find & intervene on any parcel ──
const findCode = ref(''); const foundParcel = ref(null); const findTried = ref(false); const interveneNote = ref('')
async function findParcel() {
  if (!findCode.value.trim()) return
  findTried.value = true
  try {
    const { data } = await plat.findParcel(findCode.value.trim())
    foundParcel.value = (data && data[0]) || null
  } catch (e) { foundParcel.value = null }
}
async function doIntervene() {
  if (!interveneNote.value.trim()) { toast('Add a note first', 'warn'); return }
  try {
    const { error } = await plat.intervene(foundParcel.value.code, interveneNote.value.trim())
    if (error) throw error
    toast(`Intervention recorded on ${foundParcel.value.code}`, 'ok')
    interveneNote.value = ''; await findParcel()
  } catch (e) { toast(e.message || 'Could not intervene', 'warn') }
}

// ── CARRIER DRILL-DOWN (platform admin sees a carrier's full operation) ──
const drill = ref(null)          // the carrier being inspected
const drillData = ref({ parcels: [], drivers: [], loading: false })
async function openDrill(c) {
  drill.value = c
  drillData.value = { parcels: [], drivers: [], loading: true }
  try {
    const [{ data: parcels }, { data: drivers }, { data: pays }] = await plat.carrierDrill(c.id)
    const payBy = {}; (pays||[]).forEach(p => payBy[p.consignment_id] = p)
    const list = (parcels||[]).map(p => ({ ...p, _pay: payBy[p.id] || {} }))
    drillData.value = {
      parcels: list,
      drivers: drivers || [],
      loading: false,
      cashOwed: list.filter(p => p._pay.mode==='cash' && p._pay.state==='owed').reduce((a,p)=>a+(p._pay.cod_amount||0),0),
      cashHeld: list.filter(p => p._pay.mode==='cash' && p._pay.state==='collected').reduce((a,p)=>a+(p._pay.cod_amount||0),0),
      failed: list.filter(p => p.stage==='failed').length,
    }
  } catch (e) { drillData.value = { parcels: [], drivers: [], loading: false } }
}
const drillStageCap = { booked:'Booked', collected:'Collected', linehaul:'On road', with_driver:'With driver', delivered:'Delivered', confirmed:'Confirmed', failed:'Failed', cancelled:'Cancelled' }

// ── manage a carrier (edit / suspend) ──
const manageModal = ref(null)   // the carrier being managed
const m = ref({ name:'', mark:'', accent:'', region:'' })
const profileCarrierId = ref(null)
function openProfile(c) { profileCarrierId.value = c.id }
function openManage(c) {
  manageModal.value = c
  m.value = { name:c.name, mark:c.mark, accent:c.accent, region:c.region }
}
async function saveCarrier() {
  const c = manageModal.value
  const { error } = await plat.updateCarrier({
    p_carrier: c.id, p_name: m.value.name, p_mark: m.value.mark,
    p_accent: m.value.accent, p_region: m.value.region,
  })
  if (error) { toast(humanError(error), 'warn'); return }
  toast('Carrier updated', 'ok'); manageModal.value = null; load()
}
async function toggleStatus(c) {
  const next = c.status === 'active' ? 'suspended' : 'active'
  const { error } = await plat.setCarrierStatus(c.id, next)
  if (error) { toast(humanError(error), 'warn'); return }
  toast(`${c.name} ${next}`, 'ok'); manageModal.value = null; load()
}

function initials(n){ return (n||'?').split(' ').map(w=>w[0]).slice(0,2).join('').toUpperCase() }
</script>

<template>
  <div class="topbar"><div class="inner">
    <BrandMark variant="mark" :height="34" style="margin-right:2px" />
    <div class="tb-idblock"><div class="tb-name">Enkiama Cargos</div><div class="tb-role">Platform console · {{ profile?.name || 'Admin' }}</div></div>
    <div class="tb-spacer"></div>
    <button class="btn btn-accent" @click="runAsEnkiama"><Icon name="swap" :size="15" /> Run Enkiama as carrier</button>
    <button class="btn btn-ghost" style="margin-left:8px" @click="logout">Sign out</button>
  </div></div>

  <div class="wrap">
    <!-- rich stat strip -->
    <div class="pstat-grid">
      <div class="pstat accent">
        <div class="pstat-ic"><Icon name="building" :size="20" /></div>
        <div><div class="pstat-v">{{ stats.carriers }}</div><div class="pstat-l">Carriers on platform</div></div>
      </div>
      <div class="pstat">
        <div class="pstat-ic"><Icon name="package" :size="20" /></div>
        <div><div class="pstat-v">{{ stats.consignments }}</div><div class="pstat-l">Total consignments</div></div>
      </div>
      <div class="pstat go">
        <div class="pstat-ic"><Icon name="truck" :size="20" /></div>
        <div><div class="pstat-v">{{ stats.onRoad }}</div><div class="pstat-l">On the road now</div></div>
      </div>
      <div class="pstat" :class="stats.needsAction ? 'owed' : ''">
        <div class="pstat-ic"><Icon name="alert" :size="20" /></div>
        <div><div class="pstat-v">{{ stats.needsAction }}</div><div class="pstat-l">Need attention</div></div>
      </div>
    </div>

    <!-- PLATFORM TABS -->
    <div class="ptabs">
      <button class="ptab" :class="{on:ptab==='carriers'}" @click="ptab='carriers'"><Icon name="building" :size="15" /> Carriers <span class="ptab-n">{{ carriers.length }}</span></button>
      <button class="ptab" :class="{on:ptab==='money'}" @click="ptab='money'"><Icon name="cash" :size="15" /> Money</button>
      <button class="ptab" :class="{on:ptab==='problems'}" @click="ptab='problems'"><Icon name="alert" :size="15" /> Problems <span v-if="problems.length" class="ptab-n owed">{{ problems.length }}</span></button>
      <button class="ptab" :class="{on:ptab==='analytics'}" @click="ptab='analytics'"><Icon name="chart" :size="15" /> Analytics</button>
      <button class="ptab" :class="{on:ptab==='people'}" @click="ptab='people'"><Icon name="users" :size="15" /> People <span class="ptab-n">{{ people.length }}</span></button>
      <button class="ptab" :class="{on:ptab==='property'}" @click="ptab='property'; loadPendingProps()"><Icon name="pin" :size="15" /> Property <span v-if="pendingProps.length" class="tb-count owed">{{ pendingProps.length }}</span></button>
      <button class="ptab" :class="{on:ptab==='disputes'}" @click="ptab='disputes'; loadDisputes()"><Icon name="shield" :size="15" /> Disputes <span v-if="disputes.length" class="tb-count owed">{{ disputes.length }}</span></button>
      <button class="ptab" :class="{on:ptab==='categories'}" @click="ptab='categories'; loadCategories()"><Icon name="menu" :size="15" /> Categories</button>
      <button class="ptab" :class="{on:ptab==='shops'}" @click="ptab='shops'; loadShopVerifications()"><Icon name="building" :size="15" /> Shops <span v-if="shopApps.length" class="ptab-n owed">{{ shopApps.length }}</span></button>
      <button class="ptab" :class="{on:ptab==='applications'}" @click="ptab='applications'"><Icon name="inbox" :size="15" /> Applications <span v-if="pendingApps.length" class="ptab-n owed">{{ pendingApps.length }}</span></button>
      <button class="ptab" :class="{on:ptab==='revenue'}" @click="ptab='revenue'"><Icon name="cash" :size="15" /> Revenue</button>
    </div>

    <!-- ══ CARRIERS TAB ══ -->
    <template v-if="ptab==='carriers'">
    <div class="psec-head">
      <div><h2 class="psec-title">Carriers</h2><span class="psec-sub">Every company operating on your platform</span></div>
      <button class="btn btn-accent btn-lg" @click="showForm=true"><Icon name="plus" :size="16" /> Onboard a carrier</button>
    </div>

    <div v-if="loading" class="pcarrier-grid">
      <div v-for="i in 4" :key="i" class="pcarrier sk"></div>
    </div>
    <EmptyState v-else-if="!carriers.length" icon="truck" title="No carriers yet" hint="Onboard your first delivery company to get started." />

    <div v-else class="pcarrier-grid">
      <div v-for="c in carriers" :key="c.id" class="pcarrier" :class="{ mine: c.slug==='enkiama', suspended: c.status==='suspended' }">
        <div class="pcarrier-top">
          <CarrierMark :slug="c.slug" :mark="c.mark" :name="c.name" :accent="c.accent" :size="44" />
          <div class="pcarrier-id">
            <div class="pcarrier-name">{{ c.name }}
              <span v-if="c.slug==='enkiama'" class="tag tag-you">You</span>
              <span v-if="c.status==='suspended'" class="tag tag-susp">Suspended</span>
            </div>
            <div class="pcarrier-meta">{{ c.region || '—' }} · <span class="mono">{{ c.slug }}</span></div>
          </div>
          <span class="pcarrier-status" :class="'st-'+c._status">
            <span class="st-dot"></span>{{ c._status==='attention'?'Needs action':c._status==='active'?'Active':c._status==='idle'?'Idle':'Steady' }}
          </span>
        </div>

        <div class="pcarrier-stats">
          <div class="pcs"><span class="pcs-v mono">{{ c._count }}</span><span class="pcs-l">Parcels</span></div>
          <div class="pcs"><span class="pcs-v mono">{{ c._onRoad }}</span><span class="pcs-l">On road</span></div>
          <div class="pcs"><span class="pcs-v mono">{{ c._done }}</span><span class="pcs-l">Delivered</span></div>
          <div class="pcs"><span class="pcs-v mono" :class="{owed:c._issues}">{{ c._issues || 0 }}</span><span class="pcs-l">Failed</span></div>
        </div>

        <div class="pcarrier-bar"><div class="pcarrier-fill" :style="{ width: c._pct+'%' }"></div></div>

        <div class="pcarrier-foot">
          <span class="pcarrier-pct"><b>{{ c._pct }}%</b> delivered</span>
          <div class="pcarrier-actions">
            <button class="pc-act primary" @click="openProfile(c)"><Icon name="chart" :size="14" /> Open profile</button>
          </div>
        </div>
      </div>
    </div>
    </template>

    <!-- ══ MONEY TAB ══ -->
    <template v-if="ptab==='money'">
      <div class="psec-head"><div><h2 class="psec-title">Money across the platform</h2><span class="psec-sub">Cash owed, held by drivers, and settled — every carrier</span></div></div>
      <div class="pstat-grid" style="margin-bottom:24px">
        <div class="pstat owed"><div class="pstat-ic"><Icon name="clock" :size="20" /></div><div><div class="pstat-v">{{ fmtTZS(money.owed) }}</div><div class="pstat-l">Owed (to collect)</div></div></div>
        <div class="pstat" style="grid-column:span 1"><div class="pstat-ic"><Icon name="cash" :size="20" /></div><div><div class="pstat-v">{{ fmtTZS(money.held) }}</div><div class="pstat-l">Held by drivers</div></div></div>
        <div class="pstat go"><div class="pstat-ic"><Icon name="check" :size="20" /></div><div><div class="pstat-v">{{ fmtTZS(money.settled) }}</div><div class="pstat-l">Settled</div></div></div>
        <div class="pstat"><div class="pstat-ic"><Icon name="building" :size="20" /></div><div><div class="pstat-v">{{ money.byCarrier.length }}</div><div class="pstat-l">Carriers with cash</div></div></div>
      </div>
      <EmptyState v-if="!money.byCarrier.length" icon="cash" title="No cash movement yet" hint="Cash-on-delivery parcels will show here as they move." />
      <div v-else class="ptable">
        <div class="ptable-head"><div>Carrier</div><div class="num">Owed</div><div class="num">Held</div><div class="num">Settled</div></div>
        <div v-for="c in money.byCarrier" :key="c.id" class="ptable-row">
          <div class="ptable-carrier"><CarrierMark :slug="c.slug" :mark="c.mark" :name="c.name" :accent="c.accent" :size="30" /> {{ c.name }}</div>
          <div class="num owed">{{ c.owed ? fmtTZS(c.owed) : '—' }}</div>
          <div class="num">{{ c.held ? fmtTZS(c.held) : '—' }}</div>
          <div class="num go">{{ c.settled ? fmtTZS(c.settled) : '—' }}</div>
        </div>
      </div>
    </template>

    <!-- ══ PROBLEMS TAB ══ -->
    <template v-if="ptab==='problems'">
      <div class="psec-head"><div><h2 class="psec-title">Problems everywhere</h2><span class="psec-sub">Failed deliveries and cash gaps across all carriers</span></div></div>

      <!-- admin: find & act on ANY parcel (e.g. a receiver complained to the platform) -->
      <div class="intervene-tool">
        <div class="intervene-head"><Icon name="search" :size="14" /> Look up any parcel</div>
        <div class="intervene-row">
          <input v-model="findCode" placeholder="Enter a tracking code (e.g. ENK-2918)" @keyup.enter="findParcel" />
          <button class="btn btn-accent" @click="findParcel">Find</button>
        </div>
        <div v-if="foundParcel" class="intervene-result">
          <div class="ir-top"><span class="mono">{{ foundParcel.code }}</span> · <b>{{ foundParcel.carrier_name }}</b> · {{ foundParcel.stage }}</div>
          <div class="ir-detail">{{ foundParcel.item }} → {{ foundParcel.receiver_name }} ({{ foundParcel.receiver_phone }}) · {{ foundParcel.dest_address }}</div>
          <div v-if="foundParcel.admin_note" class="ir-note"><Icon name="alert" :size="12" /> {{ foundParcel.admin_note }}</div>
          <div class="intervene-row" style="margin-top:10px">
            <input v-model="interveneNote" placeholder="Add an intervention note…" @keyup.enter="doIntervene" />
            <button class="btn btn-ghost" @click="doIntervene">Flag & note</button>
          </div>
        </div>
        <div v-else-if="findTried" class="intervene-empty">No parcel found with that code.</div>
      </div>

      <EmptyState v-if="!problems.length" icon="check" title="Nothing needs attention" hint="Failed deliveries and unremitted cash across the platform will surface here." />
      <div v-else class="prob-list">
        <div v-for="(p,i) in problems" :key="i" class="prob-row" :class="p.type">
          <div class="prob-ic"><Icon :name="p.type==='failed'?'alert':'cash'" :size="16" /></div>
          <div style="flex:1;min-width:0">
            <div class="prob-title"><span class="mono">{{ p.code }}</span> · {{ p.detail }}
              <span v-if="p._flagged" class="tag tag-you" style="margin-left:6px">✓ Flagged</span>
            </div>
            <div class="prob-meta">{{ p.carrier?.name || '—' }} → {{ p.receiver }}<span v-if="p.addr"> · {{ p.addr }}</span></div>
          </div>
          <div class="prob-actions">
            <button class="btn btn-ghost prob-btn" @click="nudgeCarrier(p)"><Icon name="send" :size="13" /> Nudge</button>
            <button class="btn btn-ghost prob-btn" :disabled="actingOn===p.id || p._flagged" @click="flagProblem(p)">
              <Spinner v-if="actingOn===p.id" :size="13" /><template v-else><Icon name="alert" :size="13" /> {{ p._flagged ? 'Flagged' : 'Flag' }}</template>
            </button>
          </div>
        </div>
      </div>
    </template>

    <!-- ══ ANALYTICS TAB ══ -->
    <template v-if="ptab==='analytics'">
      <div class="psec-head"><div><h2 class="psec-title">Platform analytics</h2><span class="psec-sub">Volume, stages, and busy corridors across the network</span></div></div>
      <div class="an-grid">
        <div class="an-card">
          <div class="an-h">Parcels by stage</div>
          <div v-for="s in analytics.byStage" :key="s.stage" class="an-bar-row">
            <span class="an-lab">{{ s.stage }}</span>
            <div class="an-track"><div class="an-fill" :style="{ width: (s.n / (analytics.byStage[0]?.n||1) * 100)+'%' }"></div></div>
            <span class="an-n">{{ s.n }}</span>
          </div>
        </div>
        <div class="an-card">
          <div class="an-h">Volume by carrier</div>
          <div v-for="c in analytics.byCarrier" :key="c.slug" class="an-bar-row">
            <span class="an-lab">{{ c.name }}</span>
            <div class="an-track"><div class="an-fill" :style="{ width: (c.n / (analytics.byCarrier[0]?.n||1) * 100)+'%', background:c.accent||'var(--accent)' }"></div></div>
            <span class="an-n">{{ c.n }}</span>
          </div>
        </div>
        <div class="an-card">
          <div class="an-h">Busiest corridors</div>
          <EmptyState v-if="!analytics.topCorridors.length" icon="pin" title="No data yet" />
          <div v-for="c in analytics.topCorridors" :key="c.place" class="an-bar-row">
            <span class="an-lab"><Icon name="pin" :size="12" /> {{ c.place }}</span>
            <div class="an-track"><div class="an-fill" :style="{ width: (c.n / (analytics.topCorridors[0]?.n||1) * 100)+'%' }"></div></div>
            <span class="an-n">{{ c.n }}</span>
          </div>
        </div>
      </div>
    </template>

    <!-- ══ PEOPLE TAB ══ -->
    <template v-if="ptab==='people'">
      <div class="psec-head"><div><h2 class="psec-title">People across the platform</h2><span class="psec-sub">Every staff member and driver, on every carrier</span></div></div>
      <EmptyState v-if="!people.length" icon="users" title="No people yet" hint="Staff and drivers will appear here as carriers add them." />
      <div v-else class="ptable">
        <div class="ptable-head"><div>Name</div><div>Role</div><div>Carrier</div></div>
        <div v-for="(p,i) in people" :key="i" class="ptable-row">
          <div class="ptable-carrier"><span class="ppl-ic" :class="p.kind"><Icon :name="p.kind==='driver'?'bike':'user'" :size="14" /></span> {{ p.name }}</div>
          <div class="p-sub">{{ p.role }}<span v-if="p.vehicle"> · {{ p.vehicle }}</span></div>
          <div class="p-sub">{{ p.carrier?.name || '—' }}</div>
        </div>
      </div>
    </template>

    <!-- ══ SHOP VERIFICATIONS TAB ══ -->
    <template v-if="ptab==='shops'">
      <div class="psec-head"><div><h2 class="psec-title">Shop verification</h2><span class="psec-sub">Shops applying for the Verified badge. Check their business details and track record.</span></div></div>
      <EmptyState v-if="!shopApps.length" icon="check" title="No pending shop applications" hint="Shops applying for verification appear here." />
      <div v-else class="pshop-list">
        <div v-for="sh in shopApps" :key="sh.id" class="pshop-card">
          <div class="pshop-top">
            <div><b>{{ sh.name }}</b><span class="pshop-slug mono">/shop/{{ sh.slug }}</span></div>
            <div class="pshop-nums">{{ sh.products }} products · {{ sh.delivered }} delivered</div>
          </div>
          <div class="pshop-details">
            <div class="pshop-field"><span>Business name</span><b>{{ sh.business_name || '—' }}</b></div>
            <div class="pshop-field"><span>Reg. number</span><b>{{ sh.business_reg || '—' }}</b></div>
            <div class="pshop-field"><span>Owner phone</span><b>{{ sh.owner_phone || '—' }}</b></div>
          </div>
          <div class="pshop-actions">
            <button class="btn btn-accent" @click="reviewShop(sh.id, 'verified')"><Icon name="shield" :size="14" /> Grant verified badge</button>
            <button class="btn btn-ghost" @click="reviewShop(sh.id, 'rejected')">Reject</button>
          </div>
        </div>
      </div>
    </template>

    <!-- ══ CATEGORIES TAB — the enforced marketplace taxonomy ══ -->
    <template v-if="ptab==='categories'">
      <div class="psec-head">
        <div><h2 class="psec-title">Marketplace categories</h2><span class="psec-sub">The fixed taxonomy every shop must choose from. Shops organize their own storefront into free sections — but products are categorized here.</span></div>
        <button class="btn btn-accent" @click="newCategory"><Icon name="plus" :size="15" /> Add category</button>
      </div>
      <div class="pcat-list">
        <div v-for="cat in cats" :key="cat.id" class="pcat-row" :class="{off:!cat.active}">
          <input v-model="cat.name" class="pcat-name" @blur="saveCat(cat)" />
          <input v-model.number="cat.sort" type="number" class="pcat-sort" @blur="saveCat(cat)" title="Sort order" />
          <span class="pcat-count">{{ cat.product_count }} product{{ cat.product_count===1?'':'s' }}</span>
          <label class="pcat-active"><input type="checkbox" v-model="cat.active" @change="saveCat(cat)" /> Active</label>
        </div>
      </div>
    </template>

    <!-- ══ DISPUTES TAB — the ledger is the evidence ══ -->
    <template v-if="ptab==='disputes'">
      <div class="psec-head"><div><h2 class="psec-title">Dispute resolution</h2><span class="psec-sub">Every parcel's custody record is the evidence. Review the trail, then resolve fairly.</span></div></div>
      <EmptyState v-if="!disputes.length" icon="check" title="No open disputes" hint="When a buyer reports a problem, it appears here with the full custody ledger." />
      <div v-else class="pdisp-list">
        <div v-for="d in disputes" :key="d.id" class="pdisp-card">
          <div class="pdisp-top">
            <div><span class="pdisp-code mono">{{ d.code }}</span> <span class="pdisp-reason">{{ reasonLabel(d.reason) }}</span></div>
            <span class="pdisp-cod" v-if="d.cod">TZS {{ Number(d.cod).toLocaleString() }}</span>
          </div>
          <div class="pdisp-by">Raised by <b>{{ d.raised_by }}</b> ({{ d.raised_role }}) · {{ d.phone }}</div>
          <p v-if="d.detail" class="pdisp-detail">"{{ d.detail }}"</p>
          <div class="pdisp-evidence">
            <div class="pdisp-ev-lab"><Icon name="link" :size="12" /> Custody ledger — the evidence</div>
            <div v-for="(e,i) in d.ledger" :key="i" class="pdisp-ev-row">
              <span class="pdisp-ev-stage">{{ e.stage }}</span>
              <span class="pdisp-ev-who">{{ e.actor }}<span v-if="e.role"> · {{ e.role }}</span></span>
              <span class="pdisp-ev-at">{{ e.at ? new Date(e.at).toLocaleString() : '' }}</span>
            </div>
            <div v-if="d.pod_photo" class="pdisp-pod"><Icon name="camera" :size="12" /> Proof of delivery photo on file<a :href="d.pod_photo" target="_blank" class="pdisp-pod-link">View</a></div>
            <div v-else class="pdisp-nopod">No proof-of-delivery photo recorded</div>
          </div>
          <div class="pdisp-actions">
            <button class="btn btn-ghost" @click="doResolve(d, 'resolved_seller')">Side with seller</button>
            <button class="btn btn-accent" @click="doResolve(d, 'resolved_buyer')"><Icon name="shield" :size="14" /> Refund buyer</button>
            <button class="btn btn-ghost" @click="doResolve(d, 'closed')">Close (no action)</button>
          </div>
        </div>
      </div>
    </template>

    <!-- ══ PROPERTY REVIEW TAB ══ -->
    <template v-if="ptab==='property'">
      <div class="psec-head"><div><h2 class="psec-title">Property verification</h2><span class="psec-sub">Review listings before they go live. Approve fair, accurate ones; reject the rest.</span></div></div>
      <div v-if="propsLoading" class="ptable"><div class="skel skel-line"></div></div>
      <template v-else>
        <EmptyState v-if="!pendingProps.length" icon="check" title="Nothing to review" hint="New property submissions will appear here for verification." />
        <div v-else class="pprop-list">
          <div v-for="p in pendingProps" :key="p.id" class="pprop-card">
            <div class="pprop-imgs">
              <div v-for="(im,i) in (p.images||[]).slice(0,3)" :key="i" class="pprop-img" :style="{backgroundImage:`url(${im})`}"></div>
              <div v-if="!p.images || !p.images.length" class="pprop-img pprop-noimg"><Icon name="pin" :size="20" /></div>
            </div>
            <div class="pprop-body">
              <div class="pprop-top">
                <div><b>{{ p.title }}</b><span class="pprop-loc">{{ p.location }}, {{ p.region }} · {{ p.kind }}</span></div>
                <div class="pprop-price">{{ p.price_tzs ? 'TZS '+Number(p.price_tzs).toLocaleString() : 'Price on request' }}</div>
              </div>
              <div class="pprop-detail">
                <span v-if="p.size_value">{{ p.size_value }} {{ p.size_unit }}</span>
                <span v-if="p.has_electricity">Power</span>
                <span v-if="p.has_water">Water{{ p.water_potable ? ' (potable)' : '' }}</span>
              </div>
              <div class="pprop-owner">
                <template v-if="p.lister_role==='representative'">
                  <Icon name="alert" :size="12" /> Listed on behalf — owner: <b>{{ p.owner_name }}</b> ({{ p.owner_relation }}), {{ p.owner_contact }}
                </template>
                <template v-else><Icon name="check" :size="12" /> Listed by owner directly</template>
              </div>
              <p v-if="p.neighbours" class="pprop-note"><b>Neighbours:</b> {{ p.neighbours }}</p>
              <p v-if="p.services_5km" class="pprop-note"><b>Services 5km:</b> {{ p.services_5km }}</p>
              <label class="pprop-fair"><input type="checkbox" v-model="fairCheck[p.id]" /> Pricing is fair for the area</label>
              <div class="pprop-actions">
                <button class="btn btn-accent" @click="reviewProp(p.id, 'verified')"><Icon name="check" :size="14" /> Verify &amp; publish</button>
                <button class="btn btn-ghost" @click="reviewProp(p.id, 'rejected')">Reject</button>
              </div>
            </div>
          </div>
        </div>
      </template>
    </template>

    <!-- ══ APPLICATIONS TAB ══ -->
    <template v-if="ptab==='applications'">
      <div class="psec-head"><div><h2 class="psec-title">Carrier applications</h2><span class="psec-sub">Fleet operators applying to join the platform</span></div></div>
      <EmptyState v-if="!applications.length" icon="inbox" title="No applications yet" hint="When a fleet operator applies from the landing page, it appears here to review." />
      <div v-else class="app-list">
        <div v-for="a in applications" :key="a.id" class="app-card" :class="a.status">
          <div class="app-top">
            <div class="app-ic"><Icon name="truck" :size="18" /></div>
            <div style="flex:1;min-width:0">
              <div class="app-name">{{ a.company_name }}
                <span class="app-status" :class="a.status">{{ a.status }}</span>
              </div>
              <div class="app-meta">{{ a.contact_name }} · {{ a.contact_phone }}<span v-if="a.contact_email"> · {{ a.contact_email }}</span></div>
            </div>
          </div>
          <div class="app-body">
            <div v-if="a.region" class="app-line"><Icon name="pin" :size="13" /> {{ a.region }}</div>
            <div v-if="a.fleet_note" class="app-line"><Icon name="truck" :size="13" /> {{ a.fleet_note }}</div>
            <div v-if="a.admin_note && a.status!=='pending'" class="app-line note"><Icon name="pen" :size="13" /> {{ a.admin_note }}</div>
          </div>
          <div v-if="a.status==='pending'" class="app-actions">
            <button class="btn btn-ghost" @click="rejectApp(a)"><Icon name="plus" :size="14" style="transform:rotate(45deg)" /> Decline</button>
            <button class="btn btn-accent" @click="openApprove(a)"><Icon name="check" :size="14" /> Approve & onboard</button>
          </div>
        </div>
      </div>
    </template>

    <!-- ══ REVENUE TAB ══ -->
    <template v-if="ptab==='revenue'">
      <div class="psec-head"><div><h2 class="psec-title">Platform revenue</h2><span class="psec-sub">Carriers use it free for now — billing is ready to switch on anytime.</span></div></div>
      <div class="statrow" style="margin-bottom:24px">
        <div class="statcard"><div class="statcard-ic go"><Icon name="cash" :size="18" /></div><div class="statcard-body"><div class="statcard-v go-ink mono">{{ fmtTZS(revenue.mrr) }}</div><div class="statcard-l">Monthly recurring</div></div></div>
        <div class="statcard"><div class="statcard-ic accent"><Icon name="building" :size="18" /></div><div class="statcard-body"><div class="statcard-v">{{ revenue.paying_carriers }}</div><div class="statcard-l">Paying carriers</div></div></div>
        <div class="statcard" :class="{alert:revenue.overdue_carriers}"><div class="statcard-ic" :class="revenue.overdue_carriers?'owed':'muted'"><Icon name="alert" :size="18" /></div><div class="statcard-body"><div class="statcard-v">{{ revenue.overdue_carriers }}</div><div class="statcard-l">Overdue</div></div></div>
        <div class="statcard"><div class="statcard-ic muted"><Icon name="users" :size="18" /></div><div class="statcard-body"><div class="statcard-v">{{ revenue.free_carriers }}</div><div class="statcard-l">On free plan</div></div></div>
      </div>
      <div class="rev-list">
        <div v-for="c in carriers" :key="c.id" class="rev-row">
          <CarrierMark :slug="c.slug" :mark="c.mark" :name="c.name" :accent="c.accent" :size="34" />
          <div class="rev-info">
            <div class="rev-name">{{ c.name }}</div>
            <div class="rev-plan">
              <span class="rev-badge" :class="c.billing_plan">{{ c.billing_plan==='monthly' ? fmtTZS(c.monthly_fee)+'/mo' : 'Free' }}</span>
              <span v-if="c.billing_plan==='monthly'" class="rev-through">paid through {{ fmtDate(c.paid_through) }}</span>
            </div>
          </div>
          <div class="rev-actions">
            <button v-if="c.billing_plan==='monthly'" class="btn btn-ghost" @click="recordPayment(c)">Record payment</button>
            <button class="btn btn-ghost" @click="openBilling(c)">Plan</button>
          </div>
        </div>
      </div>
    </template>
  </div>

  <!-- BILLING MODAL -->
  <div v-if="billingFor" class="overlay" v-escape="() => { billingFor=null }" @click.self="billingFor=null">
    <div class="modal" style="max-width:420px">
      <h3>Billing · {{ billingFor.name }}</h3>
      <p>Set how this carrier is billed. Free means no charge — the machinery stays ready to switch on later.</p>
      <div class="fg"><label>Plan</label>
        <select v-model="billPlan">
          <option value="free">Free (no charge)</option>
          <option value="monthly">Monthly subscription</option>
        </select>
      </div>
      <div v-if="billPlan==='monthly'" class="fg"><label>Monthly fee (TZS)</label>
        <input v-model="billFee" type="number" inputmode="numeric" placeholder="30000" />
      </div>
      <div class="confirm-actions">
        <button class="btn btn-ghost" @click="billingFor=null">Cancel</button>
        <button class="btn btn-accent" @click="saveBilling">Save plan</button>
      </div>
    </div>
  </div>

  <!-- APPROVE APPLICATION MODAL -->
  <div v-if="reviewApp" class="overlay" v-escape="() => { reviewApp=null }" @click.self="reviewApp=null">
    <div class="modal" style="max-width:440px">
      <h3>Approve {{ reviewApp.company_name }}</h3>
      <p>This creates a live carrier on the platform. They'll be able to operate immediately.</p>
      <div class="fg"><label>Carrier handle (slug) <span class="req">*</span></label>
        <input v-model="appSlug" placeholder="e.g. mwanzamovers" />
        <div class="field-hint">Lowercase, no spaces — used in tracking codes and URLs.</div>
      </div>
      <div class="fg"><label>Brand colour</label>
        <input v-model="appAccent" type="color" style="height:44px;padding:4px;cursor:pointer" />
      </div>
      <div class="confirm-actions">
        <button class="btn btn-ghost" @click="reviewApp=null">Cancel</button>
        <button class="btn btn-accent" :disabled="appBusy" @click="confirmApprove"><Spinner v-if="appBusy" :size="15" /><span v-else>Approve & create carrier</span></button>
      </div>
    </div>
  </div>
  <div v-if="drill" class="drill-scrim" v-escape="() => { drill=null }" @click.self="drill=null">
    <div class="drill-panel">
      <div class="drill-head">
        <CarrierMark :slug="drill.slug" :mark="drill.mark" :name="drill.name" :accent="drill.accent" :size="42" />
        <div style="flex:1;min-width:0">
          <div class="drill-name">{{ drill.name }}</div>
          <div class="drill-meta">{{ drill.region || '—' }} · <span class="mono">{{ drill.slug }}</span></div>
        </div>
        <button aria-label="Close" class="btn btn-ghost" @click="drill=null"><Icon name="plus" :size="16" style="transform:rotate(45deg)" /></button>
      </div>

      <div v-if="drillData.loading" class="empty"><p>Loading {{ drill.name }}…</p></div>
      <template v-else>
        <div class="drill-stats">
          <div class="ds"><div class="ds-v">{{ drillData.parcels.length }}</div><div class="ds-l">Parcels</div></div>
          <div class="ds"><div class="ds-v">{{ drillData.drivers.length }}</div><div class="ds-l">Drivers</div></div>
          <div class="ds"><div class="ds-v owed">{{ fmtTZS(drillData.cashOwed) }}</div><div class="ds-l">Cash owed</div></div>
          <div class="ds"><div class="ds-v" :class="drillData.failed?'owed':''">{{ drillData.failed }}</div><div class="ds-l">Failed</div></div>
        </div>

        <div class="drill-sec">Drivers</div>
        <div v-if="!drillData.drivers.length" class="p-sub" style="padding:4px 2px 12px">No drivers registered.</div>
        <div v-else class="drill-drivers">
          <div v-for="d in drillData.drivers" :key="d.id" class="drill-driver">
            <Icon name="bike" :size="15" /> <span>{{ d.name }}</span>
            <span class="p-sub mono" style="margin-left:auto">{{ d.vehicle || '—' }}</span>
            <span class="tag" :class="d.active?'tag-you':'tag-susp'">{{ d.active?'Active':'Off' }}</span>
          </div>
        </div>

        <div class="drill-sec">Parcels <span class="p-sub">({{ drillData.parcels.length }})</span></div>
        <div v-if="!drillData.parcels.length" class="p-sub" style="padding:4px 2px">No parcels yet.</div>
        <div v-else class="drill-parcels">
          <div v-for="p in drillData.parcels" :key="p.id" class="drill-parcel">
            <span class="mono drill-code">{{ p.code }}</span>
            <div style="flex:1;min-width:0">
              <div class="drill-p-to">{{ p.receiver_name }}</div>
              <div class="p-sub">{{ p.dest_address }}</div>
            </div>
            <span class="pchip" :class="p.stage==='failed'?'st-attention':['delivered','confirmed'].includes(p.stage)?'st-active':'st-steady'">{{ drillStageCap[p.stage] || p.stage }}</span>
          </div>
        </div>
      </template>
    </div>
  </div>

  <!-- MANAGE CARRIER MODAL -->
  <div v-if="manageModal" class="overlay" v-escape="() => { manageModal=null }" @click.self="manageModal=null">
    <div class="modal">
      <h3>Manage {{ manageModal.name }}</h3>
      <p>Edit the carrier's brand, or suspend them from operating.</p>
      <div class="fg"><label>Name</label><input v-model="m.name" /></div>
      <div class="row2">
        <div class="fg"><label>Badge</label><input v-model="m.mark" maxlength="2" /></div>
        <div class="fg"><label>Colour</label><input v-model="m.accent" type="color" style="height:44px;padding:4px" /></div>
      </div>
      <div class="fg"><label>Region</label><input v-model="m.region" /></div>
      <div style="display:flex;gap:10px;margin-top:4px">
        <button class="btn" :class="manageModal.status==='active' ? 'btn-owed' : 'btn-go'" @click="toggleStatus(manageModal)">
          {{ manageModal.status==='active' ? 'Suspend carrier' : 'Reactivate' }}
        </button>
        <button class="btn btn-accent" style="flex:1" @click="saveCarrier">Save changes</button>
      </div>
      <button class="btn btn-ghost btn-block" style="margin-top:8px" @click="manageModal=null">Close</button>
    </div>
  </div>

  <!-- ONBOARD MODAL -->
  <div v-if="showForm" class="overlay" v-escape="() => { showForm=false }" @click.self="showForm=false">
    <div class="modal modal-wide">
      <h3>Onboard a carrier</h3>
      <p>Create the company profile and invite its admin. They set their own password by signing up with this email.</p>

      <div class="cf-section">Company</div>
      <div class="fg"><label>Company name</label><input v-model="f.name" placeholder="USIRI Cargo" @blur="autoSlug" /></div>
      <div class="row2">
        <div class="fg"><label>Slug (url id)</label><input v-model="f.slug" placeholder="usiri" /></div>
        <div class="fg"><label>Badge (2 letters)</label><input v-model="f.mark" maxlength="2" placeholder="US" /></div>
      </div>
      <div class="row2">
        <div class="fg"><label>Brand colour</label><input v-model="f.accent" type="color" style="height:44px;padding:4px" /></div>
        <div class="fg"><label>Reg / licence no. <span class="fld-opt">optional</span></label><input v-model="f.reg_number" placeholder="TZ-TRANS-00123" /></div>
      </div>
      <div class="fg"><label>About <span class="fld-opt">shown in the marketplace</span></label><textarea v-model="f.about" rows="2" placeholder="Reliable road freight across the southern corridor since 2019."></textarea></div>

      <div class="cf-section">Contact</div>
      <div class="row2">
        <div class="fg"><label>Contact person</label><input v-model="f.contact_person" placeholder="Full name" /></div>
        <div class="fg"><label>Phone</label><input v-model="f.phone" placeholder="+255…" /></div>
      </div>
      <div class="fg"><label>Physical address</label><input v-model="f.address" placeholder="Street, city" /></div>
      <div class="fg"><label>Admin email (they'll be invited)</label><input v-model="f.adminEmail" type="email" placeholder="admin@usiri.co.tz" /></div>

      <div class="cf-section">Operations</div>
      <div class="row2">
        <div class="fg"><label>Home region</label><input v-model="f.region" placeholder="Dar es Salaam" /></div>
        <div class="fg"><label>Fleet size <span class="fld-opt">optional</span></label><input v-model="f.fleet_size" type="number" placeholder="12" /></div>
      </div>
      <div class="row2">
        <div class="fg"><label>Vehicle types</label><input v-model="f.vehicle_types" placeholder="trucks, bajaji, bodaboda" /></div>
        <div class="fg"><label>Corridors served</label><input v-model="f.corridors" placeholder="Dar–Mbeya, Dar–Arusha" /></div>
      </div>
      <label class="cf-check"><input type="checkbox" v-model="f.listed_in_marketplace" /> List this carrier in the marketplace (Delivery &amp; Carriage)</label>

      <div style="display:flex;gap:10px;margin-top:14px">
        <button class="btn btn-ghost" @click="showForm=false">Cancel</button>
        <button class="btn btn-accent" style="flex:1" :disabled="busy" @click="onboard">Onboard carrier</button>
      </div>
    </div>

    <CarrierProfile v-if="profileCarrierId" :carrier-id="profileCarrierId" @close="profileCarrierId=null" @changed="load" />
  </div>
</template>

<style scoped>
/* rich stat cards */
.pstat-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:30px}
@media(max-width:820px){.pstat-grid{grid-template-columns:repeat(2,1fr)}}
.pstat{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:16px;display:flex;align-items:center;gap:14px;box-shadow:var(--shadow-sm);transition:.18s}
.pstat:hover{box-shadow:var(--shadow-md);transform:translateY(-2px)}
.pstat-ic{width:44px;height:44px;border-radius:12px;background:var(--surface-2);color:var(--ink-faint);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.pstat.accent .pstat-ic{background:var(--accent-soft);color:var(--accent-ink)}
.pstat.go .pstat-ic{background:var(--go-soft);color:var(--go-ink)}
.pstat.owed{border-color:var(--owed-soft)}
.pstat.owed .pstat-ic{background:var(--owed-soft);color:var(--owed-ink)}
.pstat-v{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:28px;line-height:1;letter-spacing:-.02em;color:var(--ink)}
.pstat.owed .pstat-v{color:var(--owed-ink)}
.pstat-l{font-size:12.5px;color:var(--ink-faint);margin-top:4px;font-weight:500}

/* section head */
.psec-head{display:flex;align-items:flex-end;justify-content:space-between;gap:16px;margin-bottom:18px;flex-wrap:wrap}
.psec-title{font-size:18px;font-weight:700;margin:0}
.psec-sub{font-size:13px;color:var(--ink-faint)}

/* carrier cards — a responsive grid, not full-width rows */
.pcarrier-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:16px}
.pcarrier{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:16px;box-shadow:var(--shadow-sm);transition:.18s;position:relative;overflow:hidden}
.pcarrier:hover{box-shadow:var(--shadow-md);transform:translateY(-2px);border-color:var(--hairline-2)}
.pcarrier.mine{border-color:var(--accent-soft)}
.pcarrier.mine::before{content:"";position:absolute;left:0;top:0;bottom:0;width:3px;background:var(--accent)}
.pcarrier.suspended{opacity:.6}
.pcarrier.sk{height:210px;background:linear-gradient(90deg,var(--surface-2) 25%,var(--hairline) 37%,var(--surface-2) 63%);background-size:400% 100%;animation:pshim 1.4s infinite}
@keyframes pshim{0%{background-position:100% 0}100%{background-position:-100% 0}}
.pcarrier-top{display:flex;align-items:center;gap:12px;margin-bottom:16px}
.pcarrier-mark{width:44px;height:44px;border-radius:12px;color:#fff;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:15px;display:flex;align-items:center;justify-content:center;flex-shrink:0;box-shadow:var(--shadow-sm)}
.pcarrier-id{min-width:0;flex:1}
.pcarrier-name{font-weight:650;font-size:15px;color:var(--ink);display:flex;align-items:center;gap:6px;flex-wrap:wrap}
.pcarrier-meta{font-size:12.5px;color:var(--ink-faint);margin-top:2px}
.tag{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;padding:2px 7px;border-radius:8px}
.tag-you{background:var(--accent-soft);color:var(--accent-ink)}
.tag-susp{background:var(--owed-soft);color:var(--owed-ink)}
.pcarrier-status{display:inline-flex;align-items:center;gap:5px;font-size:11px;font-weight:600;padding:4px 9px;border-radius:18px;flex-shrink:0}
.st-dot{width:6px;height:6px;border-radius:50%}
.st-active{background:var(--go-soft);color:var(--go-ink)} .st-active .st-dot{background:var(--go)}
.st-attention{background:var(--owed-soft);color:var(--owed-ink)} .st-attention .st-dot{background:var(--owed)}
.st-steady{background:var(--accent-soft);color:var(--accent-ink)} .st-steady .st-dot{background:var(--accent)}
.st-idle{background:var(--surface-2);color:var(--ink-faint)} .st-idle .st-dot{background:var(--ink-ghost)}
.pcarrier-stats{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-bottom:14px;padding:12px;background:var(--surface-2);border-radius:12px}
.pcs{display:flex;flex-direction:column;align-items:flex-start}
.pcs-v{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:20px;line-height:1;color:var(--ink);font-variant-numeric:tabular-nums}
.pcs-v.owed{color:var(--owed-ink)}
.pcs-l{font-size:10px;color:var(--ink-faint);margin-top:4px;text-transform:uppercase;letter-spacing:.03em;font-weight:600}
.pcarrier-bar{height:5px;background:var(--surface-3);border-radius:8px;overflow:hidden;margin-bottom:14px}
.pcarrier-fill{height:100%;background:var(--accent);border-radius:8px;transition:width .5s var(--ease-out)}
.pcarrier-foot{display:flex;align-items:center;justify-content:space-between}
.pcarrier-pct{font-size:12.5px;color:var(--ink-soft);font-weight:500}
.pcarrier-pct b{color:var(--ink);font-weight:700}
.pcarrier-actions{display:flex;gap:6px}
.pc-act{display:inline-flex;align-items:center;gap:5px;padding:7px 12px;border:1px solid var(--hairline-2);background:var(--surface);border-radius:10px;font-family:inherit;font-size:12.5px;font-weight:600;color:var(--ink-soft);cursor:pointer;transition:all var(--dur-fast) var(--ease)}
.pc-act:hover{border-color:var(--ink-faint);color:var(--ink)}
.pc-act.primary{background:var(--accent);border-color:var(--accent);color:#fff}
.pc-act.primary:hover{background:var(--accent-ink);border-color:var(--accent-ink);color:#fff}

/* platform tabs */
.ptabs{display:flex;gap:6px;margin-bottom:26px;flex-wrap:wrap}
.ptab{display:inline-flex;align-items:center;gap:7px;padding:9px 15px;border:none;background:none;font-family:inherit;font-size:14px;font-weight:600;color:var(--ink-faint);cursor:pointer;border-radius:10px;white-space:nowrap;transition:color var(--dur-fast) var(--ease),background var(--dur-fast) var(--ease)}
.ptab:hover{color:var(--ink);background:var(--surface-2)}
.ptab.on{color:var(--accent-ink);background:var(--accent-soft);font-weight:700}
.ptab-n{background:var(--surface-3);color:var(--ink-faint);font-size:11px;font-weight:700;min-width:18px;height:18px;padding:0 6px;border-radius:999px;display:inline-flex;align-items:center;justify-content:center;font-variant-numeric:tabular-nums}
.ptab.on .ptab-n{background:var(--accent);color:#fff}

/* platform tables (money, people) */
.ptable{background:var(--surface);border:1px solid var(--hairline);border-radius:12px;overflow:hidden}
.ptable-head{display:grid;grid-template-columns:2fr 1fr 1fr 1fr;gap:10px;padding:13px 18px;background:var(--surface-2);font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;color:var(--ink-faint)}
.ptable-row{display:grid;grid-template-columns:2fr 1fr 1fr 1fr;gap:10px;padding:14px 18px;border-top:1px solid var(--hairline);align-items:center;font-size:14px}
.ptable-carrier{display:flex;align-items:center;gap:10px;font-weight:600;color:var(--ink);min-width:0}
.num{text-align:right;font-variant-numeric:tabular-nums;font-family:'Space Grotesk',sans-serif;font-weight:600}
.num.owed{color:var(--owed-ink)} .num.go{color:var(--go-ink)}
.ppl-ic{width:28px;height:28px;border-radius:8px;display:inline-flex;align-items:center;justify-content:center;background:var(--surface-2);color:var(--ink-faint);flex-shrink:0}
.ppl-ic.driver{background:var(--accent-soft);color:var(--accent-ink)}
@media(max-width:640px){
  .ptable-head{grid-template-columns:2fr 1fr 1fr;font-size:10px}
  .ptable-head div:nth-child(4),.ptable-row div:nth-child(4){display:none}
  .ptable-row{grid-template-columns:2fr 1fr 1fr;font-size:13px}
}

/* problems list */
.prob-list{display:flex;flex-direction:column;gap:10px}
.prob-row{display:flex;align-items:center;gap:13px;background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:14px 16px}
.prob-row.failed{border-left:3px solid var(--owed)}
.prob-row.cash{border-left:3px solid var(--warn)}
.prob-ic{width:38px;height:38px;border-radius:12px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.prob-row.failed .prob-ic{background:var(--owed-soft);color:var(--owed-ink)}
.prob-row.cash .prob-ic{background:#FBF0DD;color:#B5791E}
.prob-title{font-size:14px;font-weight:600;color:var(--ink)}
.prob-meta{font-size:12.5px;color:var(--ink-faint);margin-top:2px}

/* analytics */
.an-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}
.an-card{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:16px}
.an-h{font-size:13px;font-weight:700;color:var(--ink);margin-bottom:16px}
.an-bar-row{display:flex;align-items:center;gap:12px;margin-bottom:11px}
.an-lab{font-size:12.5px;color:var(--ink-soft);width:92px;flex-shrink:0;display:flex;align-items:center;gap:5px;text-transform:capitalize}
.an-track{flex:1;height:8px;background:var(--surface-2);border-radius:8px;overflow:hidden}
.an-fill{height:100%;background:var(--accent);border-radius:8px;transition:width .5s cubic-bezier(.16,1,.3,1)}
.an-n{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:13px;color:var(--ink);width:28px;text-align:right}

/* carrier drill-down slide-over */
.drill-scrim{position:fixed;inset:0;z-index:1600;background:rgba(26,29,33,.32);backdrop-filter:blur(3px);display:flex;justify-content:flex-end}
.drill-panel{width:min(560px,100%);height:100%;background:var(--paper);overflow-y:auto;padding:24px;box-shadow:var(--shadow-lg);animation:drillIn .34s cubic-bezier(.16,1,.3,1)}
@keyframes drillIn{from{transform:translateX(30px);opacity:0}to{transform:none;opacity:1}}
.drill-head{display:flex;align-items:center;gap:13px;margin-bottom:22px;padding-bottom:18px;border-bottom:1px solid var(--hairline)}
.drill-name{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:18px;color:var(--ink)}
.drill-meta{font-size:12.5px;color:var(--ink-faint);margin-top:2px}
.drill-stats{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:24px}
@media(max-width:520px){.drill-stats{grid-template-columns:repeat(2,1fr)}}
.ds{background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:12px}
.ds-v{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:18px;color:var(--ink)}
.ds-v.owed{color:var(--owed-ink);font-size:15px}
.ds-l{font-size:11px;color:var(--ink-faint);margin-top:3px;text-transform:uppercase;letter-spacing:.03em}
.drill-sec{font-size:12.5px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;color:var(--ink-faint);margin:20px 0 12px}
.drill-drivers{display:flex;flex-direction:column;gap:8px}
.drill-driver{display:flex;align-items:center;gap:9px;background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:11px 13px;font-size:13px;font-weight:550}
.drill-parcels{display:flex;flex-direction:column;gap:8px}
.drill-parcel{display:flex;align-items:center;gap:12px;background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:11px 13px}
.drill-code{font-size:12.5px;font-weight:700;color:var(--accent-ink);flex-shrink:0;width:74px}
.drill-p-to{font-size:13px;font-weight:600;color:var(--ink)}
.pchip{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.03em;padding:4px 9px;border-radius:8px;flex-shrink:0}
.pchip.st-active{background:var(--go-soft);color:var(--go-ink)}
.pchip.st-attention{background:var(--owed-soft);color:var(--owed-ink)}
.pchip.st-steady{background:var(--accent-soft);color:var(--accent-ink)}

.prob-actions{display:flex;gap:6px;flex-shrink:0}
.prob-btn{padding:7px 11px !important;font-size:12.5px}
@media(max-width:560px){.prob-actions{flex-direction:column}}

.app-list{display:flex;flex-direction:column;gap:14px}
.app-card{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:16px;box-shadow:var(--shadow-sm)}
.app-card.pending{border-left:3px solid var(--accent)}
.app-card.approved{border-left:3px solid var(--go);opacity:.85}
.app-card.rejected{opacity:.6}
.app-top{display:flex;align-items:center;gap:13px;margin-bottom:12px}
.app-ic{width:40px;height:40px;border-radius:12px;background:var(--accent-soft);color:var(--accent-ink);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.app-name{font-weight:650;font-size:16px;color:var(--ink);display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.app-status{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;padding:2px 8px;border-radius:8px}
.app-status.pending{background:var(--accent-soft);color:var(--accent-ink)}
.app-status.approved{background:var(--go-soft);color:var(--go-ink)}
.app-status.rejected{background:var(--owed-soft);color:var(--owed-ink)}
.app-meta{font-size:12.5px;color:var(--ink-faint);margin-top:2px}
.app-body{display:flex;flex-direction:column;gap:6px;margin-bottom:14px}
.app-line{display:flex;align-items:center;gap:7px;font-size:13px;color:var(--ink-soft)}
.app-line.note{color:var(--ink-faint);font-style:italic}
.app-actions{display:flex;gap:10px;justify-content:flex-end}

.modal-wide{max-width:560px;max-height:88vh;overflow-y:auto}
.cf-section{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:var(--accent-ink);margin:20px 0 10px;padding-bottom:6px;border-bottom:1px solid var(--hairline)}
.cf-section:first-of-type{margin-top:12px}
.cf-check{display:flex;align-items:center;gap:9px;font-size:13px;color:var(--ink-soft);margin-top:14px;cursor:pointer}
.cf-check input{width:16px;height:16px;accent-color:var(--accent)}
</style>

