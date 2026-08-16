<script setup>
import { ref, onMounted, computed, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { supabase, fmtTZS } from '../lib/supabase'
import Icon from '../components/Icon.vue'
import EmptyState from '../components/EmptyState.vue'
import BrandMark from '../components/BrandMark.vue'
import CarrierMark from '../components/CarrierMark.vue'
import Spinner from '../components/Spinner.vue'

const router = useRouter()
const toast = inject('toast')
const { profile, isPlatformAdmin, setHat, signOut } = useAuth()

const carriers = ref([])
const stats = ref({ carriers: 0, consignments: 0, onRoad: 0, settledToday: 0 })
const loading = ref(true)
const ptab = ref('carriers')   // carriers | money | problems | analytics | people

// aggregated platform data
const money = ref({ owed: 0, held: 0, settled: 0, byCarrier: [] })
const problems = ref([])        // failed parcels + cash gaps across all carriers
const analytics = ref({ byStage: [], byCarrier: [], topCorridors: [] })
const people = ref([])          // all staff + drivers across carriers
const applications = ref([])    // pending carrier applications

// onboarding form
const showForm = ref(false)
const f = ref({ name: '', slug: '', mark: '', accent: '#3E5BD6', region: '', adminEmail: '' })
const busy = ref(false)

onMounted(load)
async function load() {
  loading.value = true
  const { data: cs } = await supabase.from('carrier').select('*').order('created_at', { ascending: true })
  carriers.value = cs || []
  const { data: cons } = await supabase.from('consignment').select('id,stage,carrier_id')
  const all = cons || []
  // platform cash: pull payments for money view
  const { data: pays } = await supabase.from('payment').select('consignment_id,mode,state,cod_amount')
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
  const { data: fullCons } = await supabase.from('consignment')
    .select('id,code,stage,carrier_id,receiver_name,dest_address,created_at')
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
  const { data: drivers } = await supabase.from('driver').select('id,name,vehicle,active,carrier_id')
  const { data: profiles } = await supabase.from('profile').select('user_id,name,role,carrier_id')
  const ppl = []
  ;(profiles||[]).forEach(p => ppl.push({ kind:'staff', name:p.name||'—', role:p.role, carrier:carrierName[p.carrier_id] }))
  ;(drivers||[]).forEach(d => ppl.push({ kind:'driver', name:d.name, role:d.active?'driver (active)':'driver (off)', carrier:carrierName[d.carrier_id], vehicle:d.vehicle }))
  people.value = ppl

  // carrier applications (pending first)
  const { data: apps } = await supabase.from('carrier_application')
    .select('*').order('created_at', { ascending: false })
  applications.value = apps || []

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
  const { error } = await supabase.rpc('create_carrier_with_admin', {
    p_slug: v.slug, p_name: v.name, p_mark: v.mark || v.name.slice(0,2).toUpperCase(),
    p_accent: v.accent, p_region: v.region, p_admin_email: v.adminEmail,
  })
  busy.value = false
  if (error) { toast(error.message || 'Could not onboard carrier', 'warn'); return }
  toast(`${v.name} onboarded — invite sent to ${v.adminEmail}`, 'ok')
  showForm.value = false
  f.value = { name: '', slug: '', mark: '', accent: '#3E5BD6', region: '', adminEmail: '' }
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
    const { error } = await supabase.rpc('admin_flag_consignment', { p_consignment: p.id, p_note: note, p_flag: true })
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
    const { error } = await supabase.rpc('approve_carrier_application', {
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
    const { error } = await supabase.rpc('reject_carrier_application', { p_app: app.id, p_reason: reason || null })
    if (error) throw error
    toast(`${app.company_name} declined`, 'ok')
    await load()
  } catch (e) { toast(e.message || 'Could not reject', 'warn') }
}
const pendingApps = computed(() => applications.value.filter(a => a.status === 'pending'))

// ── CARRIER DRILL-DOWN (platform admin sees a carrier's full operation) ──
const drill = ref(null)          // the carrier being inspected
const drillData = ref({ parcels: [], drivers: [], loading: false })
async function openDrill(c) {
  drill.value = c
  drillData.value = { parcels: [], drivers: [], loading: true }
  try {
    const [{ data: parcels }, { data: drivers }, { data: pays }] = await Promise.all([
      supabase.from('consignment').select('*').eq('carrier_id', c.id).order('created_at', { ascending: false }),
      supabase.from('driver').select('*').eq('carrier_id', c.id),
      supabase.from('payment').select('consignment_id,mode,state,cod_amount'),
    ])
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
function openManage(c) {
  manageModal.value = c
  m.value = { name:c.name, mark:c.mark, accent:c.accent, region:c.region }
}
async function saveCarrier() {
  const c = manageModal.value
  const { error } = await supabase.rpc('update_carrier', {
    p_carrier: c.id, p_name: m.value.name, p_mark: m.value.mark,
    p_accent: m.value.accent, p_region: m.value.region,
  })
  if (error) { toast(error.message, 'warn'); return }
  toast('Carrier updated', 'ok'); manageModal.value = null; load()
}
async function toggleStatus(c) {
  const next = c.status === 'active' ? 'suspended' : 'active'
  const { error } = await supabase.rpc('set_carrier_status', { p_carrier: c.id, p_status: next })
  if (error) { toast(error.message, 'warn'); return }
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
      <button class="ptab" :class="{on:ptab==='applications'}" @click="ptab='applications'"><Icon name="inbox" :size="15" /> Applications <span v-if="pendingApps.length" class="ptab-n owed">{{ pendingApps.length }}</span></button>
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
          <div class="pcs"><span class="pcs-v">{{ c._count }}</span><span class="pcs-l">parcels</span></div>
          <div class="pcs"><span class="pcs-v" :class="{go:c._onRoad}">{{ c._onRoad }}</span><span class="pcs-l">on road</span></div>
          <div class="pcs"><span class="pcs-v">{{ c._done }}</span><span class="pcs-l">delivered</span></div>
          <div class="pcs" v-if="c._issues"><span class="pcs-v owed">{{ c._issues }}</span><span class="pcs-l">failed</span></div>
        </div>

        <div class="pcarrier-bar"><div class="pcarrier-fill" :style="{ width: c._pct+'%', background: c.accent || 'var(--accent)' }"></div></div>

        <div class="pcarrier-foot">
          <span class="pcarrier-pct">{{ c._pct }}% delivered</span>
          <div style="display:flex;gap:8px">
            <button class="btn btn-ghost" @click="openDrill(c)"><Icon name="chart" :size="14" /> View</button>
            <button class="btn btn-ghost" @click="openManage(c)"><Icon name="pen" :size="14" /> Manage</button>
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
  </div>

  <!-- APPROVE APPLICATION MODAL -->
  <div v-if="reviewApp" class="overlay" @click.self="reviewApp=null">
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
  <div v-if="drill" class="drill-scrim" @click.self="drill=null">
    <div class="drill-panel">
      <div class="drill-head">
        <CarrierMark :slug="drill.slug" :mark="drill.mark" :name="drill.name" :accent="drill.accent" :size="42" />
        <div style="flex:1;min-width:0">
          <div class="drill-name">{{ drill.name }}</div>
          <div class="drill-meta">{{ drill.region || '—' }} · <span class="mono">{{ drill.slug }}</span></div>
        </div>
        <button class="btn btn-ghost" @click="drill=null"><Icon name="plus" :size="16" style="transform:rotate(45deg)" /></button>
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
  <div v-if="manageModal" class="overlay" @click.self="manageModal=null">
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
  <div v-if="showForm" class="overlay" @click.self="showForm=false">
    <div class="modal">
      <h3>Onboard a carrier</h3>
      <p>Create the company and invite its admin. They set their own password by signing up with this email.</p>
      <div class="fg"><label>Company name</label><input v-model="f.name" placeholder="USIRI Cargo" @blur="autoSlug" /></div>
      <div class="row2">
        <div class="fg"><label>Slug (url id)</label><input v-model="f.slug" placeholder="usiri" /></div>
        <div class="fg"><label>Badge (2 letters)</label><input v-model="f.mark" maxlength="2" placeholder="US" /></div>
      </div>
      <div class="row2">
        <div class="fg"><label>Brand colour</label><input v-model="f.accent" type="color" style="height:44px;padding:4px" /></div>
        <div class="fg"><label>Region</label><input v-model="f.region" placeholder="Dar es Salaam" /></div>
      </div>
      <div class="fg"><label>Admin email (they'll be invited)</label><input v-model="f.adminEmail" type="email" placeholder="admin@usiri.co.tz" /></div>
      <div style="display:flex;gap:10px;margin-top:6px">
        <button class="btn btn-ghost" @click="showForm=false">Cancel</button>
        <button class="btn btn-accent" style="flex:1" :disabled="busy" @click="onboard">Onboard carrier</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* rich stat cards */
.pstat-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:30px}
@media(max-width:820px){.pstat-grid{grid-template-columns:repeat(2,1fr)}}
.pstat{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:18px;display:flex;align-items:center;gap:14px;box-shadow:var(--shadow-sm);transition:.18s}
.pstat:hover{box-shadow:var(--shadow-md);transform:translateY(-2px)}
.pstat-ic{width:44px;height:44px;border-radius:12px;background:var(--surface-2);color:var(--ink-faint);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.pstat.accent .pstat-ic{background:var(--accent-soft);color:var(--accent-ink)}
.pstat.go .pstat-ic{background:var(--go-soft);color:var(--go-ink)}
.pstat.owed{border-color:var(--owed-soft)}
.pstat.owed .pstat-ic{background:var(--owed-soft);color:var(--owed-ink)}
.pstat-v{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:28px;line-height:1;letter-spacing:-.02em;color:var(--ink)}
.pstat.owed .pstat-v{color:var(--owed-ink)}
.pstat-l{font-size:12px;color:var(--ink-faint);margin-top:4px;font-weight:500}

/* section head */
.psec-head{display:flex;align-items:flex-end;justify-content:space-between;gap:16px;margin-bottom:18px;flex-wrap:wrap}
.psec-title{font-size:19px;font-weight:700;margin:0}
.psec-sub{font-size:13px;color:var(--ink-faint)}

/* carrier cards — a responsive grid, not full-width rows */
.pcarrier-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:16px}
.pcarrier{background:var(--surface);border:1px solid var(--hairline);border-radius:18px;padding:18px;box-shadow:var(--shadow-sm);transition:.18s;position:relative;overflow:hidden}
.pcarrier:hover{box-shadow:var(--shadow-md);transform:translateY(-2px);border-color:var(--hairline-2)}
.pcarrier.mine{border-color:var(--accent-soft)}
.pcarrier.mine::before{content:"";position:absolute;left:0;top:0;bottom:0;width:3px;background:var(--accent)}
.pcarrier.suspended{opacity:.6}
.pcarrier.sk{height:210px;background:linear-gradient(90deg,var(--surface-2) 25%,var(--hairline) 37%,var(--surface-2) 63%);background-size:400% 100%;animation:pshim 1.4s infinite}
@keyframes pshim{0%{background-position:100% 0}100%{background-position:-100% 0}}
.pcarrier-top{display:flex;align-items:center;gap:12px;margin-bottom:16px}
.pcarrier-mark{width:44px;height:44px;border-radius:12px;color:#fff;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:15px;display:flex;align-items:center;justify-content:center;flex-shrink:0;box-shadow:var(--shadow-sm)}
.pcarrier-id{min-width:0;flex:1}
.pcarrier-name{font-weight:650;font-size:15.5px;color:var(--ink);display:flex;align-items:center;gap:6px;flex-wrap:wrap}
.pcarrier-meta{font-size:12px;color:var(--ink-faint);margin-top:2px}
.tag{font-size:9.5px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;padding:2px 7px;border-radius:6px}
.tag-you{background:var(--accent-soft);color:var(--accent-ink)}
.tag-susp{background:var(--owed-soft);color:var(--owed-ink)}
.pcarrier-status{display:inline-flex;align-items:center;gap:5px;font-size:10.5px;font-weight:600;padding:4px 9px;border-radius:20px;flex-shrink:0}
.st-dot{width:6px;height:6px;border-radius:50%}
.st-active{background:var(--go-soft);color:var(--go-ink)} .st-active .st-dot{background:var(--go)}
.st-attention{background:var(--owed-soft);color:var(--owed-ink)} .st-attention .st-dot{background:var(--owed)}
.st-steady{background:var(--accent-soft);color:var(--accent-ink)} .st-steady .st-dot{background:var(--accent)}
.st-idle{background:var(--surface-2);color:var(--ink-faint)} .st-idle .st-dot{background:var(--ink-ghost)}
.pcarrier-stats{display:flex;gap:18px;margin-bottom:14px}
.pcs{display:flex;flex-direction:column}
.pcs-v{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:20px;line-height:1;color:var(--ink)}
.pcs-v.go{color:var(--go-ink)} .pcs-v.owed{color:var(--owed-ink)}
.pcs-l{font-size:10.5px;color:var(--ink-faint);margin-top:3px;text-transform:uppercase;letter-spacing:.03em}
.pcarrier-bar{height:6px;background:var(--surface-2);border-radius:6px;overflow:hidden;margin-bottom:14px}
.pcarrier-fill{height:100%;border-radius:6px;transition:width .5s cubic-bezier(.16,1,.3,1)}
.pcarrier-foot{display:flex;align-items:center;justify-content:space-between}
.pcarrier-pct{font-size:12px;color:var(--ink-soft);font-weight:600}

/* platform tabs */
.ptabs{display:flex;gap:4px;margin-bottom:26px;border-bottom:1px solid var(--hairline);overflow-x:auto;-webkit-overflow-scrolling:touch}
.ptab{display:inline-flex;align-items:center;gap:7px;padding:12px 16px;border:none;background:none;font-family:inherit;font-size:14px;font-weight:600;color:var(--ink-faint);cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-1px;white-space:nowrap;transition:.15s}
.ptab:hover{color:var(--ink-soft)}
.ptab.on{color:var(--accent-ink);border-bottom-color:var(--accent)}
.ptab-n{background:var(--surface-2);color:var(--ink-faint);font-size:11px;font-weight:700;padding:1px 7px;border-radius:20px}
.ptab-n.owed{background:var(--owed-soft);color:var(--owed-ink)}

/* platform tables (money, people) */
.ptable{background:var(--surface);border:1px solid var(--hairline);border-radius:14px;overflow:hidden}
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
.prob-row{display:flex;align-items:center;gap:13px;background:var(--surface);border:1px solid var(--hairline);border-radius:13px;padding:14px 16px}
.prob-row.failed{border-left:3px solid var(--owed)}
.prob-row.cash{border-left:3px solid #E8A33D}
.prob-ic{width:38px;height:38px;border-radius:10px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.prob-row.failed .prob-ic{background:var(--owed-soft);color:var(--owed-ink)}
.prob-row.cash .prob-ic{background:#FBF0DD;color:#B5791E}
.prob-title{font-size:14px;font-weight:600;color:var(--ink)}
.prob-meta{font-size:12px;color:var(--ink-faint);margin-top:2px}

/* analytics */
.an-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}
.an-card{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:18px}
.an-h{font-size:13px;font-weight:700;color:var(--ink);margin-bottom:16px}
.an-bar-row{display:flex;align-items:center;gap:12px;margin-bottom:11px}
.an-lab{font-size:12.5px;color:var(--ink-soft);width:92px;flex-shrink:0;display:flex;align-items:center;gap:5px;text-transform:capitalize}
.an-track{flex:1;height:8px;background:var(--surface-2);border-radius:8px;overflow:hidden}
.an-fill{height:100%;background:var(--accent);border-radius:8px;transition:width .5s cubic-bezier(.16,1,.3,1)}
.an-n{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:13px;color:var(--ink);width:28px;text-align:right}

/* carrier drill-down slide-over */
.drill-scrim{position:fixed;inset:0;z-index:1600;background:rgba(26,29,33,.32);backdrop-filter:blur(3px);display:flex;justify-content:flex-end}
.drill-panel{width:min(560px,100%);height:100%;background:var(--paper);overflow-y:auto;padding:22px;box-shadow:var(--shadow-lg);animation:drillIn .34s cubic-bezier(.16,1,.3,1)}
@keyframes drillIn{from{transform:translateX(30px);opacity:0}to{transform:none;opacity:1}}
.drill-head{display:flex;align-items:center;gap:13px;margin-bottom:22px;padding-bottom:18px;border-bottom:1px solid var(--hairline)}
.drill-name{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:19px;color:var(--ink)}
.drill-meta{font-size:12.5px;color:var(--ink-faint);margin-top:2px}
.drill-stats{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:24px}
@media(max-width:520px){.drill-stats{grid-template-columns:repeat(2,1fr)}}
.ds{background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:13px}
.ds-v{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:19px;color:var(--ink)}
.ds-v.owed{color:var(--owed-ink);font-size:15px}
.ds-l{font-size:10.5px;color:var(--ink-faint);margin-top:3px;text-transform:uppercase;letter-spacing:.03em}
.drill-sec{font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;color:var(--ink-faint);margin:20px 0 12px}
.drill-drivers{display:flex;flex-direction:column;gap:8px}
.drill-driver{display:flex;align-items:center;gap:9px;background:var(--surface);border:1px solid var(--hairline);border-radius:11px;padding:11px 13px;font-size:13.5px;font-weight:550}
.drill-parcels{display:flex;flex-direction:column;gap:8px}
.drill-parcel{display:flex;align-items:center;gap:12px;background:var(--surface);border:1px solid var(--hairline);border-radius:11px;padding:11px 13px}
.drill-code{font-size:12px;font-weight:700;color:var(--accent-ink);flex-shrink:0;width:74px}
.drill-p-to{font-size:13.5px;font-weight:600;color:var(--ink)}
.pchip{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.03em;padding:4px 9px;border-radius:6px;flex-shrink:0}
.pchip.st-active{background:var(--go-soft);color:var(--go-ink)}
.pchip.st-attention{background:var(--owed-soft);color:var(--owed-ink)}
.pchip.st-steady{background:var(--accent-soft);color:var(--accent-ink)}

.prob-actions{display:flex;gap:6px;flex-shrink:0}
.prob-btn{padding:7px 11px !important;font-size:12.5px}
@media(max-width:560px){.prob-actions{flex-direction:column}}

.app-list{display:flex;flex-direction:column;gap:14px}
.app-card{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:18px;box-shadow:var(--shadow-sm)}
.app-card.pending{border-left:3px solid var(--accent)}
.app-card.approved{border-left:3px solid var(--go);opacity:.85}
.app-card.rejected{opacity:.6}
.app-top{display:flex;align-items:center;gap:13px;margin-bottom:12px}
.app-ic{width:40px;height:40px;border-radius:11px;background:var(--accent-soft);color:var(--accent-ink);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.app-name{font-weight:650;font-size:16px;color:var(--ink);display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.app-status{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;padding:2px 8px;border-radius:6px}
.app-status.pending{background:var(--accent-soft);color:var(--accent-ink)}
.app-status.approved{background:var(--go-soft);color:var(--go-ink)}
.app-status.rejected{background:var(--owed-soft);color:var(--owed-ink)}
.app-meta{font-size:12.5px;color:var(--ink-faint);margin-top:2px}
.app-body{display:flex;flex-direction:column;gap:6px;margin-bottom:14px}
.app-line{display:flex;align-items:center;gap:7px;font-size:13px;color:var(--ink-soft)}
.app-line.note{color:var(--ink-faint);font-style:italic}
.app-actions{display:flex;gap:10px;justify-content:flex-end}
</style>

