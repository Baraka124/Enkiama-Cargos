<script setup>
import { ref, computed, onMounted, onUnmounted, inject, watch } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { useConsignments } from '../composables/useConsignments'
import { useDispatch } from '../composables/useDispatch'
import { useI18n } from '../composables/useI18n'
import { fmtTZS } from '../lib/supabase'
import ConsignmentCard from '../components/ConsignmentCard.vue'
import EmptyState from '../components/EmptyState.vue'
import Skeleton from '../components/Skeleton.vue'
import Spinner from '../components/Spinner.vue'
import Icon from '../components/Icon.vue'
import CarrierMark from '../components/CarrierMark.vue'
import CarrierOnboard from '../components/CarrierOnboard.vue'

const router = useRouter()
const toast = inject('toast')
const theme = inject('theme', ref('light'))
const toggleTheme = inject('toggleTheme', () => {})
const menuOpen = ref(false)
const { carrier, profile, signOut, isPlatformAdmin, setHat } = useAuth()
const { setLang, isSwahili } = useI18n()
const { consignments, loading, STAGE_CAP, STAGE_ORDER, fetchAll, subscribe, unsubscribe, advance, assignDriver, markDelivered, remitCash, confirmMomo, book } = useConsignments()
const disp = useDispatch()

const tab = ref('action')
const drivers = ref([])
const ledger = ref([])
const assignModal = ref(null)   // parcel being assigned
const isAdmin = computed(() => profile.value?.role === 'carrier_admin')
const search = ref('')

// search filter across code / receiver / phone / sender
function matchesSearch(p) {
  const q = search.value.trim().toLowerCase()
  if (!q) return true
  return [p.code, p.receiver, p.receiverPhone, p.sender, p.senderPhone, p.addr]
    .filter(Boolean).some(v => String(v).toLowerCase().includes(q))
}

// dashboard numbers for the carrier admin
const dash = computed(() => {
  const cs = consignments.value
  const delivered = cs.filter(p => ['delivered','confirmed'].includes(p.stage)).length
  const failed = cs.filter(p => p.stage === 'failed').length
  const codCollected = cs.filter(p => p.payMode==='cash' && ['collected','remitted','settled'].includes(p.payState)).reduce((a,p)=>a+p.cod,0)
  const feeEarned = cs.filter(p => ['delivered','confirmed'].includes(p.stage)).reduce((a,p)=>a+p.fee,0)
  return { total: cs.length, delivered, failed, codCollected, feeEarned,
    successRate: cs.length ? Math.round(delivered / cs.length * 100) : 0 }
})

// #3 pipeline distribution for the dashboard bar
const pipeline = computed(() => {
  const cs = consignments.value
  const count = (s) => cs.filter(p => (Array.isArray(s) ? s.includes(p.stage) : p.stage === s)).length
  return [
    { stage: 'booked', label: 'Booked', color: '#9AA0A8', count: count('booked') },
    { stage: 'collected', label: 'Collected', color: '#3E5BD6', count: count('collected') },
    { stage: 'linehaul', label: 'On road', color: '#5B7BE8', count: count('linehaul') },
    { stage: 'with_driver', label: 'With driver', color: '#3049B0', count: count('with_driver') },
    { stage: 'done', label: 'Delivered', color: '#1E9E63', count: count(['delivered','confirmed']) },
    { stage: 'failed', label: 'Failed', color: '#C0392B', count: count('failed') },
  ]
})

// new-consignment (walk-in booking by dispatch)
const showOnboard = ref(false)
const bookModal = ref(false)
const bk = ref({ receiver:'', receiverPhone:'', addr:'', item:'', weight:1, mode:'prepaid', cod:0, fee:0, senderName:'', senderPhone:'' })
const booking = ref(false)
const bkErr = ref({})
const bookedCode = ref('')
const copied = ref(false)

// live formatters
function fmtNum(v) { const n = Number(v); return n ? n.toLocaleString('en-US') : '' }
function unNum(s) { return Number(String(s).replace(/[^\d]/g, '')) || 0 }

const trackUrl = computed(() => bookedCode.value ? `${location.origin}/#/track/${bookedCode.value}` : '')

function validateBk(field) {
  const v = bk.value; const e = { ...bkErr.value }
  const check = {
    receiver: () => !v.receiver.trim() ? 'Receiver name is required' : '',
    receiverPhone: () => {
      if (!v.receiverPhone.trim()) return 'Phone is required'
      const digits = v.receiverPhone.replace(/[^\d]/g, '')
      return digits.length < 9 ? "That phone doesn't look complete" : ''
    },
    addr: () => !v.addr.trim() ? 'Delivery address is required' : '',
    item: () => !v.item.trim() ? 'Tell us what the parcel contains' : '',
    cod: () => (v.mode === 'cod' && (!v.cod || v.cod <= 0)) ? 'Enter the cash amount to collect' : '',
  }
  if (field) { const r = check[field]?.(); if (r) e[field] = r; else delete e[field] }
  else { Object.keys(check).forEach(k => { const r = check[k](); if (r) e[k] = r; else delete e[k] }) }
  bkErr.value = e
  return Object.keys(e).length === 0
}

function closeBooking() {
  const hasData = bk.value.receiver || bk.value.receiverPhone || bk.value.addr || bk.value.item
  if (!bookedCode.value && hasData && !confirm('Discard this booking? Your entries will be lost.')) return
  bookModal.value = false; bookedCode.value = ''; bkErr.value = {}
  bk.value = { receiver:'', receiverPhone:'', addr:'', item:'', weight:1, mode:'prepaid', cod:0, fee:0, senderName:'', senderPhone:'' }
}
function startAnother() {
  bookedCode.value = ''; bkErr.value = {}
  bk.value = { receiver:'', receiverPhone:'', addr:'', item:'', weight:1, mode:'prepaid', cod:0, fee:0, senderName:'', senderPhone:'' }
}
async function copyTrackLink() {
  try { await navigator.clipboard.writeText(trackUrl.value); copied.value = true; setTimeout(()=>copied.value=false, 2000) } catch (e) {}
}

async function submitBooking() {
  if (!validateBk()) { toast('Please fix the highlighted fields', 'warn'); return }
  booking.value = true
  try {
    const code = await book({
      carrierId: profile.value.carrier_id,
      receiver: bk.value.receiver, receiverPhone: bk.value.receiverPhone,
      addr: bk.value.addr, item: bk.value.item, weight: Number(bk.value.weight)||1,
      mode: bk.value.mode, cod: Number(bk.value.cod)||0, fee: Number(bk.value.fee)||0,
      senderName: bk.value.senderName || 'Walk-in', senderPhone: bk.value.senderPhone || '',
    })
    bookedCode.value = code   // show success state
  } catch (e) { toast(e.message || 'Booking failed','warn') }
  booking.value = false
}

// team management (carrier admin only)
const newDriver = ref({ name: '', phone: '', vehicle: 'bajaji' })
const newStaff = ref({ email: '' })
const savingTeam = ref(false)

async function loadDrivers() {
  try {
    const cid = profile.value?.carrier_id
    const { data } = await disp.listDrivers(cid)
    drivers.value = data || []
    const { data: led } = await disp.cashLedger()
    ledger.value = led || []
  } catch (e) { ledger.value = [] }
}
async function addDriver() {
  if (!newDriver.value.name || !newDriver.value.phone) { toast('Name and phone required', 'warn'); return }
  savingTeam.value = true
  const { error } = await disp.addDriver({
    carrier_id: profile.value.carrier_id, name: newDriver.value.name,
    phone: newDriver.value.phone, vehicle: newDriver.value.vehicle,
  })
  savingTeam.value = false
  if (error) { toast(error.message, 'warn'); return }
  toast('Driver added', 'ok'); newDriver.value = { name: '', phone: '', vehicle: 'bajaji' }; loadDrivers()
}
async function toggleDriver(d) {
  const { error } = await disp.setDriverActive(d.id, !d.active)
  if (error) { toast(error.message, 'warn'); return }
  toast(d.active ? 'Driver deactivated' : 'Driver reactivated', 'ok'); loadDrivers()
}
async function sendStaffInvite() {
  if (!newStaff.value.email) { toast('Staff email required', 'warn'); return }
  const { error } = await disp.inviteStaff(newStaff.value.email)
  if (error) { toast(error.message, 'warn'); return }
  toast(`Invite created for ${newStaff.value.email} — they join by signing up with it`, 'ok')
  newStaff.value = { email: '' }
}
function switchToPlatform() { setHat('platform'); router.push('/platform') }

// ── carrier notifications (seller selected you / new order) ──
const notifs = ref([])
const notifsOpen = ref(false)
const unreadNotifs = computed(() => notifs.value.filter(n => !n.read).length)
async function loadNotifs() {
  try { const { data } = await disp.notifications(); notifs.value = data || [] } catch (e) {}
}
async function openNotifs() {
  notifsOpen.value = true
  await disp.markNotificationsRead().catch(()=>{})
  await loadNotifs()
}

onMounted(async () => {
  try { await fetchAll() } catch (e) {}
  try { subscribe() } catch (e) {}
  try { await loadDrivers() } catch (e) {}
  try { await loadCash() } catch (e) {}
  try { await loadCustomers() } catch (e) {}
  try { await loadNotifs() } catch (e) {}
  window.addEventListener('keydown', onKey)
  maybeOnboard()
})
function maybeOnboard() {
  const cid = profile.value?.carrier_id || ''
  const dismissed = localStorage.getItem('ob-done-' + cid)
  const noDrivers = !drivers.value || drivers.value.length === 0
  const noParcels = !consignments.value || consignments.value.length === 0
  if (!dismissed && cid && noDrivers && noParcels) showOnboard.value = true
}
// re-check when carrier/profile finish loading (auth is async)
watch(() => profile.value?.carrier_id, (cid) => { if (cid) maybeOnboard() }, { immediate: true })
function finishOnboard() {
  showOnboard.value = false
  localStorage.setItem('ob-done-' + (profile.value?.carrier_id || ''), '1')
}
onUnmounted(() => { unsubscribe(); window.removeEventListener('keydown', onKey) })

// #12 keyboard shortcuts for power dispatchers
function onKey(e) {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT' || e.target.tagName === 'TEXTAREA') return
  if (e.key === 'n') { bookModal.value = true; e.preventDefault() }
  else if (e.key === '/') { tab.value = 'ledger'; e.preventDefault(); setTimeout(()=>document.querySelector('input[placeholder*="Search"]')?.focus(), 50) }
  else if (e.key === '1') tab.value = 'action'
  else if (e.key === '2') tab.value = 'dash'
  else if (e.key === '3') tab.value = 'ledger'
  else if (e.key === '4') tab.value = 'customers'
  else if (e.key === '5') tab.value = 'cash'
  else if (e.key === '6') tab.value = 'team'
  else if (e.key === 'Escape') { bookModal.value = false; assignModal.value = null; detail.value = null; confirmDialog.value = null }
}

const owedTotal = computed(() => consignments.value.filter(p => (p.payMode==='cash') && !['collected','remitted','settled'].includes(p.payState)).reduce((a,p)=>a+p.cod,0))
const heldTotal = computed(() => consignments.value.filter(p => p.payMode==='cash' && p.payState==='collected').reduce((a,p)=>a+p.cod,0))
const active = computed(() => consignments.value.filter(p => !['confirmed','cancelled'].includes(p.stage)))
const filteredLedger = computed(() => consignments.value.filter(matchesSearch))
const actionList = computed(() => consignments.value.filter(p =>
  ['booked','collected','linehaul','failed'].includes(p.stage) || (p.payMode==='cash' && p.payState==='collected')))
const actionSearch = ref('')
const filteredAction = computed(() => {
  const q = actionSearch.value.trim().toLowerCase()
  if (!q) return actionList.value
  return actionList.value.filter(p => [p.code, p.receiver, p.receiverPhone, p.addr, p.sender]
    .filter(Boolean).some(v => String(v).toLowerCase().includes(q)))
})

const customers = ref([])
async function loadCustomers() {
  const { data } = await disp.customers()
  customers.value = data || []
}

function whyLine(p) {
  if (p.stage==='failed') return `Failed: ${p.lastReason||'attempt failed'} — needs retry`
  if (p.stage==='booked') return 'Awaiting pickup by carrier'
  if (p.stage==='linehaul' && !p.driver) return 'No local driver assigned'
  if (p.payMode==='cash' && p.payState==='collected') return 'Cash held by driver — awaiting remit'
  return ''
}
async function doAssign(driverId) {
  try {
    await assignDriver(assignModal.value, driverId)
    toast(`${assignModal.value.code} assigned`, 'ok')
    assignModal.value = null
  } catch (e) {
    toast(e.message || 'Could not assign — driver may belong to another carrier', 'warn')
  }
}
async function retry(p) { await advance(p, 'with_driver', 'Retry scheduled'); toast(`${p.code} back on driver's run`, 'ok') }
function initials(n){ return (n||'?').split(' ').map(w=>w[0]).slice(0,2).join('').toUpperCase() }
async function logout(){ await signOut(); router.push('/login') }

// cash ledger — who's holding what (v7 view)
const cashLedger = ref([])
async function loadCash() {
  try {
    const { data } = await disp.cashLedger()
    cashLedger.value = data || []
  } catch (e) { cashLedger.value = [] }
}
const totalHolding = computed(() => cashLedger.value.reduce((a,r)=>a + (r.cash_holding||0), 0))
const totalRemitted = computed(() => cashLedger.value.reduce((a,r)=>a + (r.cash_remitted||0), 0))
const settling = ref(null)
function askSettle(r) {
  askConfirm(
    `Settle up with ${r.driver_name}?`,
    `Confirm you've received ${fmtTZS(r.cash_holding)} in cash from ${r.driver_name} for ${r.parcels_holding} parcel(s). This marks it all as remitted to the office.`,
    async () => {
      settling.value = r.driver_id
      try {
        const { data, error } = await disp.settleDriverCash(r.driver_id)
        if (error) throw error
        const res = Array.isArray(data) ? data[0] : data
        toast(`Settled ${fmtTZS(res?.total_settled || r.cash_holding)} from ${r.driver_name} (${res?.parcels_settled || r.parcels_holding} parcels)`, 'ok')
        await loadCash()
      } catch (e) { toast(e.message || 'Could not settle', 'warn') }
      settling.value = null
    })
}
// #6 confirm dialog for irreversible money actions
const confirmDialog = ref(null)  // { title, body, onYes }
function askConfirm(title, body, onYes) { confirmDialog.value = { title, body, onYes } }
async function runConfirm() {
  const fn = confirmDialog.value?.onYes
  confirmDialog.value = null
  if (fn) await fn()
}

async function doRemit(p) {
  askConfirm('Confirm cash remitted?',
    `Mark ${fmtTZS(p.cod)} for ${p.code} as handed in by the driver. This updates the cash ledger.`,
    async () => {
      try { await remitCash(p); await loadDrivers(); toast(`${fmtTZS(p.cod)} remitted for ${p.code}`, 'ok') }
      catch (e) { toast(e.message || 'Remit failed', 'warn') }
    })
}
async function doMomo(p) {
  askConfirm('Mark paid by mobile money?',
    `Confirm ${p.code} was paid via M-Pesa. This settles the parcel's payment.`,
    async () => {
      try { await confirmMomo(p, 'M-Pesa'); toast(`${p.code} marked paid by mobile money`, 'ok') }
      catch (e) { toast(e.message || 'Could not confirm', 'warn') }
    })
}

// ── bulk operations (#5) ──
const bulkMode = ref(false)
const selected = ref(new Set())
function toggleSelect(id) {
  const s = new Set(selected.value)
  s.has(id) ? s.delete(id) : s.add(id)
  selected.value = s
}
function clearBulk() { bulkMode.value = false; selected.value = new Set() }
const bulkAssignModal = ref(false)
async function bulkAssign(driverId) {
  const ids = [...selected.value]
  let ok = 0
  for (const id of ids) {
    const p = consignments.value.find(c => c.id === id)
    if (!p) continue
    try { await assignDriver(p, driverId); ok++ } catch (e) { /* skip */ }
  }
  toast(`Assigned ${ok} of ${ids.length} to driver`, ok ? 'ok' : 'warn')
  bulkAssignModal.value = false; clearBulk(); await fetchAll()
}

// ── consignment detail (full story) ──
const detail = ref(null)          // the parcel
const detailEvents = ref([])
const detailLoading = ref(false)
async function openDetail(p) {
  detail.value = p; detailEvents.value = []; detailLoading.value = true
  try {
    const { data } = await disp.custodyEvents(p.id)
    detailEvents.value = data || []
  } catch (e) { /* non-fatal */ }
  detailLoading.value = false
}
// drive the parcel from the detail modal, then refresh its timeline
async function detailAdvance(p, stage, note) {
  try { await advance(p, stage, note); toast(`${p.code} → ${STAGE_CAP[stage] || stage}`, 'ok'); await refreshDetail(p) }
  catch (e) { toast(e.message || 'Could not update', 'warn') }
}
async function detailFail(p) {
  try { await advance(p, 'failed', 'Delivery attempt failed'); toast(`${p.code} marked failed`, 'warn'); await refreshDetail(p) }
  catch (e) { toast(e.message || 'Could not update', 'warn') }
}
async function detailRemit(p) {
  try { await remitCash(p); toast(`Remitted ${fmtTZS(p.cod)} for ${p.code}`, 'ok'); await refreshDetail(p) }
  catch (e) { toast(e.message || 'Could not remit', 'warn') }
}
async function refreshDetail(p) {
  await fetchAll()
  const fresh = consignments.value.find(c => c.id === p.id)
  if (fresh) { detail.value = fresh; const { data } = await disp.custodyEvents(p.id); detailEvents.value = data || [] }
  else detail.value = null
}
// ── delivery fee (dispatcher sets who pays + amount → enables delivery) ──
const feeEdit = ref(false)
const feeAmt = ref(0)
const feePayer = ref('sender_prepaid')
function openFeeEdit(p) { feeEdit.value = true; feeAmt.value = p.deliveryFee || 0; feePayer.value = p.feePayer || 'sender_prepaid' }
async function saveFee(p) {
  try {
    const { error } = await disp.setDeliveryFee(p.code, Number(feeAmt.value)||0, feePayer.value)
    if (error) throw error
    toast(`Delivery fee agreed: ${fmtTZS(Number(feeAmt.value)||0)}`, 'ok')
    feeEdit.value = false
    await refreshDetail(p)
  } catch (e) { toast(e.message || 'Could not set fee', 'warn') }
}
const FEE_PAYER_LABEL = { sender_prepaid:'Sender prepaid', receiver_on_delivery:'Receiver pays on delivery', negotiated:'Negotiated' }
function fmtWhen(ts) {
  if (!ts) return ''
  const d = new Date(ts)
  return d.toLocaleDateString() + ' · ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <CarrierOnboard v-if="showOnboard" :carrier="carrier"
    @done="finishOnboard"
    @add-driver="finishOnboard(); tab='team'"
    @book="finishOnboard(); bookModal=true" />
  <div class="topbar"><div class="inner">
    <CarrierMark :slug="carrier?.slug" :mark="carrier?.mark" :name="carrier?.name" :accent="carrier?.accent" :size="38" />
    <div class="tb-idblock"><div class="tb-name">{{ carrier?.name || 'Enkiama Cargos' }}</div><div class="tb-role">{{ isAdmin ? 'Admin' : 'Dispatch' }} · {{ profile?.name }}</div></div>
    <span class="live-badge tb-live-desktop" style="margin-left:14px"><span class="dot"></span>Live</span>
    <div class="tb-spacer"></div>
    <!-- desktop actions inline -->
    <div class="tb-actions-desktop">
      <button v-if="isPlatformAdmin" class="btn btn-ghost" style="margin-right:8px" @click="switchToPlatform">↔ Platform console</button>
      <RouterLink to="/market" class="btn btn-ghost tb-icon-btn" style="margin-right:8px" title="Marketplace"><Icon name="box" :size="18" /></RouterLink>
      <button aria-label="Notifications" class="btn btn-ghost tb-icon-btn" style="position:relative;margin-right:8px" @click="openNotifs">
        <Icon name="bell" :size="18" /><span v-if="unreadNotifs" class="notif-dot">{{ unreadNotifs }}</span>
      </button>
      <button class="btn btn-ghost lang-toggle" style="margin-right:8px" :title="isSwahili ? 'Switch to English' : 'Badilisha kwa Kiswahili'" @click="setLang(isSwahili?'en':'sw')"><Icon name="globe" :size="14" /> {{ isSwahili ? 'EN' : 'SW' }}</button>
      <button class="btn btn-ghost" style="margin-right:8px" :title="theme==='dark'?'Light mode':'Dark mode'" @click="toggleTheme"><Icon :name="theme==='dark'?'sun':'moon'" :size="15" /></button>
      <button class="btn btn-ghost" @click="logout">Sign out</button>
    </div>
    <!-- mobile: theme quick-toggle + overflow menu -->
    <div class="tb-actions-mobile">
      <button class="btn btn-ghost tb-icon-btn" @click="toggleTheme"><Icon :name="theme==='dark'?'sun':'moon'" :size="17" /></button>
      <button aria-label="Menu" class="btn btn-ghost tb-icon-btn" @click="menuOpen=!menuOpen"><Icon name="menu" :size="18" /></button>
    </div>
    <div v-if="menuOpen" class="tb-menu-scrim" @click="menuOpen=false"></div>
    <div v-if="menuOpen" class="tb-menu">
      <button v-if="isPlatformAdmin" class="tb-menu-item" @click="switchToPlatform(); menuOpen=false"><Icon name="swap" :size="16" /> Platform console</button>
      <button class="tb-menu-item" @click="showOnboard=true; menuOpen=false"><Icon name="truck" :size="16" /> Setup guide</button>
      <button class="tb-menu-item" @click="setLang(isSwahili?'en':'sw'); menuOpen=false"><Icon name="globe" :size="16" /> {{ isSwahili ? 'English' : 'Kiswahili' }}</button>
      <button class="tb-menu-item danger" @click="logout"><Icon name="signout" :size="16" /> Sign out</button>
    </div>
  </div></div>

  <div class="wrap">
    <div class="statrow">
      <button class="statcard clickable" @click="tab='ledger'">
        <div class="statcard-ic accent"><Icon name="box" :size="18" /></div>
        <div class="statcard-body"><div class="statcard-v">{{ active.length }}</div><div class="statcard-l">Active consignments</div></div>
      </button>
      <button class="statcard clickable" :class="{alert: actionList.length}" @click="tab='action'">
        <div class="statcard-ic" :class="actionList.length ? 'owed' : 'muted'"><Icon name="alert" :size="18" /></div>
        <div class="statcard-body"><div class="statcard-v">{{ actionList.length }}</div><div class="statcard-l">Needs action</div></div>
      </button>
      <button class="statcard clickable" @click="tab='action'">
        <div class="statcard-ic owed"><Icon name="cash" :size="18" /></div>
        <div class="statcard-body"><div class="statcard-v mono owed-ink">{{ fmtTZS(owedTotal) }}</div><div class="statcard-l">Cash to collect</div></div>
      </button>
      <button class="statcard clickable" @click="tab='cash'">
        <div class="statcard-ic go"><Icon name="check" :size="18" /></div>
        <div class="statcard-body"><div class="statcard-v mono go-ink">{{ fmtTZS(heldTotal) }}</div><div class="statcard-l">Collected · unremitted</div></div>
      </button>
    </div>

    <div class="dtabs" style="align-items:center">
      <button class="dtab" :class="{on:tab==='action'}" @click="tab='action'">Needs action <span class="tb-count">{{ actionList.length }}</span></button>
      <button v-if="isAdmin" class="dtab" :class="{on:tab==='dash'}" @click="tab='dash'">Dashboard</button>
      <button class="dtab" :class="{on:tab==='ledger'}" @click="tab='ledger'">Ledger <span class="tb-count">{{ consignments.length }}</span></button>
      <button class="dtab" :class="{on:tab==='customers'}" @click="tab='customers'">Customers <span class="tb-count">{{ customers.length }}</span></button>
      <button class="dtab" :class="{on:tab==='cash'}" @click="tab='cash'">Cash <span class="tb-count">{{ cashLedger.length }}</span></button>
      <button v-if="isAdmin" class="dtab" :class="{on:tab==='team'}" @click="tab='team'">Team <span class="tb-count">{{ drivers.length }}</span></button>
      <button class="btn btn-accent" style="margin-left:auto" @click="bookModal=true"><Icon name="plus" :size="15" /> New consignment</button>
    </div>

    <!-- ACTION -->
    <div v-if="tab==='action'">
      <div class="fg" style="margin-bottom:12px;position:relative">
        <input v-model="actionSearch" placeholder="Filter by code, receiver, phone…" style="padding-left:38px" />
        <Icon name="search" :size="16" style="position:absolute;left:13px;top:13px;color:var(--ink-faint)" />
      </div>
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:14px">
        <button class="btn btn-ghost" @click="bulkMode ? clearBulk() : bulkMode=true">
          <Icon :name="bulkMode ? 'check' : 'box'" :size="15" /> {{ bulkMode ? 'Cancel select' : 'Select multiple' }}
        </button>
        <div v-if="bulkMode && selected.size" style="display:flex;align-items:center;gap:10px;margin-left:auto">
          <span class="p-sub">{{ selected.size }} selected</span>
          <button class="btn btn-accent" @click="bulkAssignModal=true"><Icon name="bike" :size="15" /> Assign driver to all</button>
        </div>
      </div>
      <Skeleton v-if="loading && !consignments.length" variant="card" :count="3" />
      <EmptyState v-else-if="!filteredAction.length" icon="check" :title="actionSearch ? 'No matches' : 'All clear'" :hint="actionSearch ? 'Try a different code or name.' : 'New bookings and problems will surface here.'" />
      <div v-for="p in filteredAction" :key="p.id" :class="{selrow: bulkMode}" style="position:relative">
        <label v-if="bulkMode" class="selbox">
          <input type="checkbox" :checked="selected.has(p.id)" @change="toggleSelect(p.id)" />
        </label>
        <ConsignmentCard :p="p" :why="whyLine(p)" :urgent="p.stage==='failed'" :style="bulkMode ? 'margin-left:38px' : ''">
        <template v-if="p.stage==='failed'">
          <button class="btn btn-accent" @click="retry(p)">Schedule retry</button>
          <button class="btn btn-ghost" @click="advance(p,'returning','Returning to sender')">Return to sender</button>
        </template>
        <button v-else-if="p.stage==='booked'" class="btn btn-accent" @click="advance(p,'collected','Collected by carrier')">Mark collected</button>
        <button v-else-if="p.stage==='collected'" class="btn btn-accent" @click="advance(p,'linehaul','Sent on road')">Send on road</button>
        <button v-else-if="p.stage==='linehaul' && !p.driver" class="btn btn-accent" @click="assignModal=p">Assign local driver</button>
        <button v-else-if="p.stage==='linehaul' && p.driver" class="btn btn-ghost" @click="advance(p,'with_driver','Handed to driver')">Handed to driver</button>
        <button v-if="p.payMode==='cash' && p.payState==='collected'" class="btn btn-go" @click="doRemit(p)">Confirm cash remitted</button>
        <button v-if="p.payMode==='cash' && p.payState==='owed'" class="btn btn-ghost" @click="doMomo(p)"><Icon name="phone" :size="15" /> Mark paid by M-Pesa</button>
        </ConsignmentCard>
      </div>
    </div>

    <!-- DASHBOARD (admin) -->
    <div v-else-if="tab==='dash'">
      <div class="strip" style="margin-bottom:16px">
        <div class="cell"><div class="cl">Total consignments</div><div class="cv">{{ dash.total }}</div></div>
        <div class="cell go"><div class="cl">Delivered</div><div class="cv">{{ dash.delivered }}</div></div>
        <div class="cell owed"><div class="cl">Failed</div><div class="cv">{{ dash.failed }}</div></div>
        <div class="cell"><div class="cl">Success rate</div><div class="cv">{{ dash.successRate }}%</div></div>
      </div>
      <div class="strip">
        <div class="cell go money"><div class="cl">COD collected</div><div class="cv mono">{{ fmtTZS(dash.codCollected) }}</div></div>
        <div class="cell money"><div class="cl">Fees earned</div><div class="cv mono">{{ fmtTZS(dash.feeEarned) }}</div></div>
        <div class="cell money"><div class="cl">Active drivers</div><div class="cv">{{ drivers.filter(d=>d.active).length }}</div></div>
        <div class="cell owed money"><div class="cl">Cash outstanding</div><div class="cv mono">{{ fmtTZS(ledger.reduce((a,l)=>a+Number(l.cash_holding||0),0)) }}</div></div>
      </div>
      <div class="sub" style="margin-top:14px;text-align:center">A live snapshot of {{ carrier?.name }}'s operation today.</div>

      <!-- #3 visual pipeline distribution -->
      <div class="panel" style="margin-top:16px">
        <div class="trk-lab" style="margin-bottom:14px"><Icon name="link" :size="12" /> Pipeline right now</div>
        <div class="pipe-bar">
          <div v-for="s in pipeline" :key="s.stage" class="pipe-seg" :style="{ flexGrow: s.count || 0.001, background: s.color }" :title="`${s.label}: ${s.count}`"></div>
        </div>
        <div class="pipe-legend">
          <div v-for="s in pipeline" :key="s.stage" class="pipe-leg-item">
            <span class="pipe-dot" :style="{ background: s.color }"></span>{{ s.label }} <b>{{ s.count }}</b>
          </div>
        </div>
      </div>
    </div>

    <!-- LEDGER -->
    <div v-else-if="tab==='ledger'">
      <div class="fg" style="margin-bottom:14px;position:relative">
        <input v-model="search" placeholder="Search code, receiver, phone, address…" style="padding-left:38px" />
        <Icon name="search" :size="16" style="position:absolute;left:13px;top:13px;color:var(--ink-faint)" />
      </div>
      <Skeleton v-if="loading && !consignments.length" variant="card" :count="4" />
      <EmptyState v-else-if="!filteredLedger.length" icon="search" :title="search ? 'No matches' : 'Ledger is empty'" :hint="search ? 'Try a different code, name, or phone.' : 'Booked consignments appear here.'" />
      <ConsignmentCard v-for="p in filteredLedger" :key="p.id" :p="p" @click="openDetail(p)" style="cursor:pointer" />
    </div>

    <!-- CUSTOMERS (carrier's relationship view — the hybrid) -->
    <div v-else-if="tab==='customers'">
      <div class="strip" style="grid-template-columns:repeat(3,1fr)">
        <div class="cell"><div class="cl">Your customers</div><div class="cv">{{ customers.length }}</div></div>
        <div class="cell"><div class="cl">Businesses</div><div class="cv">{{ customers.filter(c=>c.is_business).length }}</div></div>
        <div class="cell"><div class="cl">With an account</div><div class="cv">{{ customers.filter(c=>c.has_account).length }}</div></div>
      </div>
      <div class="sub" style="margin:0 2px 16px">Your customers on {{ carrier?.name }} — the people you serve. Repeat senders and receivers, ranked by how much they ship with you.</div>
      <EmptyState v-if="!customers.length" icon="user" title="No customers yet" hint="People you send to or receive from will appear here automatically." />
      <div v-else class="cust-grid">
        <div v-for="c in customers" :key="c.id" class="cust-card">
          <div class="cust-top">
            <div class="avatar">{{ initials(c.name) }}</div>
            <div style="flex:1;min-width:0">
              <div class="cust-name">{{ c.name }}
                <span v-if="c.is_business" class="tag tag-biz">Business</span>
                <span v-if="c.has_account" class="tag tag-acct">Has account</span>
              </div>
              <div class="p-sub">{{ c.phone || 'no phone' }} · {{ c.kind }}</div>
            </div>
          </div>
          <div class="cust-stats">
            <div class="cust-stat"><span class="cst-v">{{ c.parcels }}</span><span class="cst-l">parcels</span></div>
            <div class="cust-stat"><span class="cst-v go">{{ c.delivered }}</span><span class="cst-l">delivered</span></div>
            <div class="cust-stat" v-if="c.cash_outstanding"><span class="cst-v owed">{{ fmtTZS(c.cash_outstanding) }}</span><span class="cst-l">owed</span></div>
          </div>
          <div v-if="c.default_addr" class="cust-addr"><Icon name="pin" :size="12" /> {{ c.default_addr }}</div>
        </div>
      </div>
    </div>

    <!-- CASH LEDGER (v7) -->
    <div v-else-if="tab==='cash'">
      <div class="strip" style="grid-template-columns:repeat(3,1fr)">
        <div class="cell owed money"><div class="cl">Held by drivers</div><div class="cv mono">{{ fmtTZS(totalHolding) }}</div></div>
        <div class="cell go money"><div class="cl">Settled to office</div><div class="cv mono">{{ fmtTZS(totalRemitted) }}</div></div>
        <div class="cell"><div class="cl">Drivers holding cash</div><div class="cv">{{ cashLedger.filter(r=>r.cash_holding>0).length }}</div></div>
      </div>
      <div class="sub" style="margin:0 2px 16px">Reconcile cash each driver is holding. "Settle up" remits everything a driver has collected in one action — with a receipt.</div>
      <EmptyState v-if="!cashLedger.length" icon="cash" title="No cash activity yet" hint="Cash-on-delivery collections will appear here per driver." />
      <div v-else class="recon-grid">
        <div v-for="r in cashLedger" :key="r.driver_id" class="recon-card" :class="{owing: r.cash_holding>0}">
          <div class="recon-top">
            <div class="avatar">{{ initials(r.driver_name) }}</div>
            <div style="flex:1;min-width:0">
              <div class="recon-name">{{ r.driver_name }}</div>
              <div class="p-sub">{{ r.parcels_holding }} parcel(s) to remit</div>
            </div>
            <div class="recon-hold" :class="{zero: !r.cash_holding}">
              <div class="recon-hold-v mono">{{ fmtTZS(r.cash_holding) }}</div>
              <div class="recon-hold-l">holding</div>
            </div>
          </div>
          <div class="recon-split">
            <div class="recon-stat"><span class="rs-v owed">{{ fmtTZS(r.cash_holding) }}</span><span class="rs-l">to settle</span></div>
            <div class="recon-stat"><span class="rs-v go">{{ fmtTZS(r.cash_remitted) }}</span><span class="rs-l">settled</span></div>
          </div>
          <button v-if="r.cash_holding>0" class="btn btn-accent btn-block" :disabled="settling===r.driver_id" @click="askSettle(r)">
            <Spinner v-if="settling===r.driver_id" :size="15" /><template v-else><Icon name="check" :size="15" /> Settle up {{ fmtTZS(r.cash_holding) }}</template>
          </button>
          <div v-else class="recon-clear"><Icon name="check" :size="14" /> All settled</div>
        </div>
      </div>
    </div>

    <!-- TEAM (carrier admin only) -->
    <div v-else-if="tab==='team'">
      <div class="panel">
        <h2>Add a driver</h2>
        <div class="sub">Drivers belong to {{ carrier?.name }} and can only be assigned to your consignments.</div>
        <div class="row2">
          <div class="fg"><label>Name</label><input v-model="newDriver.name" placeholder="Juma" /></div>
          <div class="fg"><label>Phone</label><input v-model="newDriver.phone" placeholder="+255712000111" /></div>
        </div>
        <div class="fg"><label>Vehicle</label>
          <select v-model="newDriver.vehicle"><option>bajaji</option><option>bodaboda</option><option>toctoc</option><option>pickup</option><option>truck</option></select>
        </div>
        <button class="btn btn-accent" :disabled="savingTeam" @click="addDriver">Add driver</button>
      </div>

      <div class="sec"><h2>Cash held by drivers</h2><span class="ln"></span></div>
      <div class="sub" style="margin:0 2px 12px">Real-time — collected cash-on-delivery each driver is holding and hasn't remitted to the carrier yet.</div>
      <div v-if="!ledger.length" class="empty" style="padding:24px"><p>No cash outstanding</p></div>
      <div v-for="l in ledger" :key="l.driver_id" class="cons" style="padding:14px 16px;display:flex;align-items:center;gap:13px">
        <div class="avatar">{{ initials(l.driver_name) }}</div>
        <div><div style="font-weight:600">{{ l.driver_name }}</div><div class="p-sub">{{ l.parcels_holding }} parcel{{ l.parcels_holding===1?'':'s' }} · {{ fmtTZS(l.cash_remitted) }} remitted</div></div>
        <div style="margin-left:auto;text-align:right">
          <div class="mono" :style="{fontWeight:700,fontSize:'18px',color: l.cash_holding>0 ? 'var(--owed-ink)' : 'var(--ink-3)'}">{{ fmtTZS(l.cash_holding) }}</div>
          <div class="p-sub">holding</div>
        </div>
      </div>

      <div class="sec"><h2>Drivers</h2><span class="ln"></span></div>
      <EmptyState v-if="!drivers.length" icon="bike" title="No drivers yet" />
      <div v-for="d in drivers" :key="d.id" class="cons" style="padding:14px 16px;display:flex;align-items:center;gap:13px">
        <div class="avatar">{{ initials(d.name) }}</div>
        <div><div style="font-weight:600">{{ d.name }}</div><div class="p-sub">{{ d.phone }} · {{ d.vehicle }}</div></div>
        <button class="btn btn-ghost" style="margin-left:auto" @click="toggleDriver(d)">{{ d.active ? 'Deactivate' : 'Reactivate' }}</button>
        <span class="paychip" :class="d.active?'pay-prepaid':'pay-settled'">{{ d.active?'Active':'Off' }}</span>
      </div>

      <div class="panel" style="margin-top:20px">
        <h2>Invite dispatch staff</h2>
        <div class="sub">They sign up with this email and join {{ carrier?.name }} as dispatch. (Invite flow uses the same claim-on-signup as carrier onboarding.)</div>
        <div class="fg"><label>Staff email</label><input v-model="newStaff.email" type="email" placeholder="staff@carrier.co.tz" /></div>
        <button class="btn btn-ghost" @click="sendStaffInvite">Send invite</button>
      </div>
    </div>
  </div>

  <!-- #6 CONFIRM DIALOG -->
  <div v-if="confirmDialog" class="overlay" v-escape="() => { confirmDialog=null }" @click.self="confirmDialog=null">
    <div class="modal" style="max-width:400px">
      <h3>{{ confirmDialog.title }}</h3>
      <p>{{ confirmDialog.body }}</p>
      <div class="confirm-actions">
        <button class="btn btn-ghost" @click="confirmDialog=null">Cancel</button>
        <button class="btn btn-accent" @click="runConfirm">Confirm</button>
      </div>
    </div>
  </div>

  <!-- NOTIFICATIONS PANEL -->
  <div v-if="notifsOpen" class="overlay" v-escape="() => { notifsOpen=false }" @click.self="notifsOpen=false">
    <div class="modal" style="max-width:440px">
      <h3>Notifications</h3>
      <EmptyState v-if="!notifs.length" icon="bell" title="Nothing yet" hint="When a seller selects you or an order comes in, it appears here." />
      <div v-else class="notif-list">
        <div v-for="n in notifs" :key="n.id" class="notif-item" :class="{unread:!n.read}">
          <div class="notif-ic" :class="n.kind"><Icon :name="n.kind==='new_order'?'box':'truck'" :size="15" /></div>
          <div style="flex:1;min-width:0">
            <div class="notif-title">{{ n.title }}</div>
            <div v-if="n.body" class="notif-body">{{ n.body }}</div>
          </div>
        </div>
      </div>
      <button class="btn btn-ghost btn-block" style="margin-top:14px" @click="notifsOpen=false">Close</button>
    </div>
  </div>

  <!-- BULK ASSIGN MODAL -->
  <div v-if="bulkAssignModal" class="overlay" v-escape="() => { bulkAssignModal=false }" @click.self="bulkAssignModal=false">
    <div class="modal">
      <h3>Assign {{ selected.size }} parcels</h3>
      <p>Pick a driver to hand all selected consignments to at once.</p>
      <button v-for="d in drivers.filter(x=>x.active)" :key="d.id" class="btn btn-ghost btn-block" style="margin-bottom:8px;justify-content:flex-start" @click="bulkAssign(d.id)">
        <Icon name="bike" :size="16" /> {{ d.name }} · {{ d.vehicle }}
      </button>
      <button class="btn btn-ghost btn-block" style="margin-top:6px" @click="bulkAssignModal=false">Cancel</button>
    </div>
  </div>

  <!-- CONSIGNMENT DETAIL MODAL -->
  <div v-if="detail" class="overlay" v-escape="() => { detail=null }" @click.self="detail=null">
    <div class="modal" style="max-width:520px">
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:4px">
        <h3 class="mono" style="margin:0">{{ detail.code }}</h3>
        <span class="paychip" :class="detail.stage==='failed'?'pay-cod':'pay-collected'" style="margin-left:auto">{{ STAGE_CAP[detail.stage] || detail.stage }}</span>
      </div>
      <p style="margin-bottom:16px">{{ detail.sender || 'Walk-in' }} → {{ detail.receiver }}</p>

      <div class="party" style="margin-bottom:16px">
        <div><div class="p-lab">To</div><div class="p-val">{{ detail.receiver }}</div><div class="p-sub">{{ detail.receiverPhone }}</div><div class="p-sub">{{ detail.addr }}</div></div>
        <div style="text-align:right"><div class="p-lab">Item</div><div class="p-val">{{ detail.item }}</div><div class="p-sub">{{ detail.weight }}kg</div></div>
      </div>

      <!-- #18 unified money summary -->
      <div class="money-bar" :class="detail.payMode==='cash' && !['collected','remitted','settled'].includes(detail.payState) ? 'owed' : 'done'" style="margin-bottom:16px">
        <Icon name="cash" :size="16" />
        <span class="m-txt">{{ detail.payMode==='cash' ? (['collected','remitted','settled'].includes(detail.payState) ? 'Cash collected' : 'Cash on delivery') : (detail.payMode==='feeonly' ? 'Fee only' : 'Prepaid') }}<span v-if="detail.payState==='remitted'||detail.payState==='settled'"> · remitted</span></span>
        <span class="m-amt mono">{{ fmtTZS(detail.cod || detail.fee || 0) }}</span>
      </div>

      <!-- proof of delivery, if present -->
      <div v-if="detail.podPhotoUrl || detail.podSignature" class="panel" style="margin-bottom:16px;padding:14px">
        <div class="trk-lab" style="margin-bottom:10px"><Icon name="camera" :size="12" /> Proof of delivery</div>
        <img v-if="detail.podPhotoUrl" :src="detail.podPhotoUrl" style="width:100%;border-radius:10px;margin-bottom:8px;max-height:180px;object-fit:cover" />
        <img v-if="detail.podSignature" :src="detail.podSignature" style="width:120px;border:1px solid var(--hairline);border-radius:8px;background:#fff" />
      </div>

      <!-- full custody timeline -->
      <div class="trk-lab" style="margin-bottom:12px"><Icon name="link" :size="12" /> Full history</div>
      <Skeleton v-if="detailLoading" variant="line" :count="4" />
      <div v-else-if="!detailEvents.length" class="p-sub">No events recorded yet.</div>
      <div v-else class="timeline">
        <div v-for="(e,i) in detailEvents" :key="e.id||i" class="tl-item">
          <div class="tl-dot" :class="{last: i===detailEvents.length-1}"></div>
          <div class="tl-body">
            <div class="tl-stage">{{ STAGE_CAP[e.stage] || e.stage }}</div>
            <div class="tl-note">{{ e.note }}</div>
            <div class="tl-when">{{ fmtWhen(e.at) }}<span v-if="e.actor_name"> · {{ e.actor_name }}</span></div>
          </div>
        </div>
      </div>

      <!-- DELIVERY FEE — who pays, how much (must be agreed before delivery) -->
      <div class="fee-block" :class="{pending: detail.feeStatus==='pending'}">
        <div class="fee-head">
          <div class="trk-lab"><Icon name="cash" :size="12" /> Delivery fee</div>
          <button class="fee-edit-btn" @click="openFeeEdit(detail)">{{ detail.feeStatus==='pending' ? 'Set fee' : 'Edit' }}</button>
        </div>
        <template v-if="!feeEdit">
          <div class="fee-row">
            <span class="fee-amt mono">{{ detail.deliveryFee ? fmtTZS(detail.deliveryFee) : 'No fee' }}</span>
            <span class="fee-payer">{{ FEE_PAYER_LABEL[detail.feePayer] }}</span>
            <span class="fee-status" :class="detail.feeStatus">{{ detail.feeStatus }}</span>
          </div>
          <div v-if="detail.feeStatus==='pending'" class="fee-warn"><Icon name="alert" :size="12" /> Agree the fee before this parcel can be delivered.</div>
        </template>
        <div v-else class="fee-edit">
          <div class="row2">
            <div class="fg"><label>Fee (TZS)</label><input v-model="feeAmt" type="number" inputmode="numeric" placeholder="0" /></div>
            <div class="fg"><label>Who pays</label>
              <select v-model="feePayer">
                <option value="sender_prepaid">Sender prepaid</option>
                <option value="receiver_on_delivery">Receiver on delivery</option>
                <option value="negotiated">Negotiated</option>
              </select>
            </div>
          </div>
          <div class="fee-edit-actions">
            <button class="btn btn-ghost" @click="feeEdit=false">Cancel</button>
            <button class="btn btn-accent" @click="saveFee(detail)">Agree fee</button>
          </div>
        </div>
      </div>

      <!-- ACTIONS — drive the parcel from here -->
      <div class="detail-actions">
        <div class="trk-lab" style="margin-bottom:10px"><Icon name="handoff" :size="12" /> Move this parcel</div>
        <div class="detail-act-row">
          <button v-if="detail.stage==='booked'" class="btn btn-accent" @click="detailAdvance(detail,'collected','Collected by carrier')">Mark collected</button>
          <button v-else-if="detail.stage==='collected'" class="btn btn-accent" @click="detailAdvance(detail,'linehaul','Sent on road')">Send on road</button>
          <template v-else-if="detail.stage==='linehaul'">
            <button v-if="!detail.driver" class="btn btn-accent" @click="assignModal=detail; detail=null">Assign a driver</button>
            <button v-else class="btn btn-accent" @click="detailAdvance(detail,'with_driver','Handed to driver')">Hand to driver</button>
          </template>
          <template v-else-if="detail.stage==='with_driver'">
            <button class="btn btn-go" @click="detailAdvance(detail,'delivered','Delivered')">Mark delivered</button>
            <button class="btn btn-ghost" @click="detailFail(detail)">Delivery failed</button>
          </template>
          <button v-else-if="detail.stage==='failed'" class="btn btn-accent" @click="detailAdvance(detail,'with_driver','Retry scheduled')">Retry delivery</button>
          <div v-else-if="detail.stage==='delivered'" class="detail-await">Waiting for receiver to confirm receipt.</div>
          <div v-else-if="detail.stage==='confirmed'" class="detail-done"><Icon name="check" :size="15" /> Delivered &amp; confirmed</div>

          <!-- cash remit if held -->
          <button v-if="detail.payMode==='cash' && detail.payState==='collected'" class="btn btn-go" @click="detailRemit(detail)">Remit {{ fmtTZS(detail.cod) }}</button>
        </div>
      </div>

      <button class="btn btn-ghost btn-block" style="margin-top:14px" @click="detail=null">Close</button>
    </div>
  </div>

  <!-- NEW CONSIGNMENT MODAL -->
  <div v-if="bookModal" class="overlay" v-escape="() => { closeBooking }" @click.self="closeBooking">
    <div class="modal">
      <!-- SUCCESS STATE -->
      <div v-if="bookedCode" class="book-success">
        <div class="book-success-ic"><Icon name="check" :size="30" /></div>
        <div class="book-success-code">{{ bookedCode }}</div>
        <div class="book-success-sub">Parcel booked on {{ carrier?.name }}. Share the tracking link with the receiver.</div>
        <div class="book-success-link" @click="copyTrackLink">
          <Icon name="link" :size="15" />
          <span class="code">{{ trackUrl }}</span>
          <Icon :name="copied ? 'check' : 'inbox'" :size="15" />
        </div>
        <div style="display:flex;gap:10px">
          <button class="btn btn-ghost" style="flex:1" @click="closeBooking">Done</button>
          <button class="btn btn-accent" style="flex:1" @click="startAnother"><Icon name="plus" :size="15" /> Book another</button>
        </div>
      </div>

      <!-- FORM STATE -->
      <template v-else>
        <h3>New consignment</h3>
        <p>Book a parcel for a walk-in customer on {{ carrier?.name }}.</p>

        <div class="form-section">
          <div class="form-section-h"><Icon name="user" :size="13" /> Receiver</div>
          <div class="row2">
            <div class="fg"><label>Receiver name <span class="req">*</span></label>
              <input v-model="bk.receiver" :class="{invalid: bkErr.receiver}" placeholder="Grace Mwangi" @blur="validateBk('receiver')" />
              <div v-if="bkErr.receiver" class="field-err"><Icon name="alert" :size="12" /> {{ bkErr.receiver }}</div>
            </div>
            <div class="fg"><label>Receiver phone <span class="req">*</span></label>
              <input v-model="bk.receiverPhone" type="tel" inputmode="tel" :class="{invalid: bkErr.receiverPhone}" placeholder="+255 712 345 678" @blur="validateBk('receiverPhone')" />
              <div v-if="bkErr.receiverPhone" class="field-err"><Icon name="alert" :size="12" /> {{ bkErr.receiverPhone }}</div>
            </div>
          </div>
          <div class="fg"><label>Delivery address <span class="req">*</span></label>
            <input v-model="bk.addr" :class="{invalid: bkErr.addr}" placeholder="Mikocheni, Dar es Salaam" @blur="validateBk('addr')" />
            <div v-if="bkErr.addr" class="field-err"><Icon name="alert" :size="12" /> {{ bkErr.addr }}</div>
          </div>
        </div>

        <div class="form-section">
          <div class="form-section-h"><Icon name="parcel" :size="13" /> Package</div>
          <div class="row2">
            <div class="fg"><label>What's inside <span class="req">*</span></label>
              <input v-model="bk.item" :class="{invalid: bkErr.item}" placeholder="Documents" @blur="validateBk('item')" />
              <div v-if="bkErr.item" class="field-err"><Icon name="alert" :size="12" /> {{ bkErr.item }}</div>
            </div>
            <div class="fg"><label>Weight (kg) <span class="opt">optional</span></label>
              <input v-model="bk.weight" type="number" inputmode="decimal" min="0" step="0.5" placeholder="1.0" />
            </div>
          </div>
        </div>

        <div class="form-section">
          <div class="form-section-h"><Icon name="cash" :size="13" /> Payment</div>
          <div class="fg"><label>How is this paid? <span class="req">*</span></label>
            <select v-model="bk.mode"><option value="prepaid">Prepaid — nothing to collect</option><option value="cod">Cash on delivery</option><option value="feeonly">Goods free (fee only)</option></select>
          </div>
          <div class="row2">
            <div class="fg" v-if="bk.mode==='cod'"><label>Cash to collect <span class="req">*</span></label>
              <div class="input-affix affix-tzs"><span class="affix">TZS</span>
                <input :value="fmtNum(bk.cod)" @input="bk.cod = unNum($event.target.value)" type="text" inputmode="numeric" :class="{invalid: bkErr.cod}" placeholder="0" @blur="validateBk('cod')" />
              </div>
              <div v-if="bkErr.cod" class="field-err"><Icon name="alert" :size="12" /> {{ bkErr.cod }}</div>
            </div>
            <div class="fg"><label>Delivery fee <span class="opt">optional</span></label>
              <div class="input-affix affix-tzs"><span class="affix">TZS</span>
                <input :value="fmtNum(bk.fee)" @input="bk.fee = unNum($event.target.value)" type="text" inputmode="numeric" placeholder="0" />
              </div>
            </div>
          </div>
        </div>

        <div class="form-section">
          <div class="form-section-h"><Icon name="send" :size="13" /> Sender <span class="opt" style="text-transform:none;letter-spacing:0">optional</span></div>
          <div class="row2">
            <div class="fg"><label>Sender name</label><input v-model="bk.senderName" placeholder="Walk-in customer" /></div>
            <div class="fg"><label>Sender phone</label><input v-model="bk.senderPhone" type="tel" inputmode="tel" placeholder="+255…" /></div>
          </div>
        </div>

        <div style="display:flex;gap:10px;margin-top:8px">
          <button class="btn btn-ghost" @click="closeBooking">Cancel</button>
          <button class="btn btn-accent" style="flex:1" :disabled="booking" @click="submitBooking">
            <Spinner v-if="booking" :size="15" /><span v-else>Book consignment</span>
          </button>
        </div>
      </template>
    </div>
  </div>

  <!-- ASSIGN MODAL -->
  <div v-if="assignModal" class="overlay" v-escape="() => { assignModal=null }" @click.self="assignModal=null">
    <div class="modal">
      <h3>Assign a local driver</h3>
      <p>Hand the last mile to a rider on your fleet — {{ assignModal.code }}.</p>
      <button v-for="d in drivers" :key="d.id" class="btn btn-ghost btn-block" style="margin-bottom:8px;justify-content:flex-start" @click="doAssign(d.id)">
        <Icon name="bike" :size="16" /> {{ d.name }} · {{ d.vehicle }}
      </button>
      <button class="btn btn-ghost btn-block" style="margin-top:6px" @click="assignModal=null">Cancel</button>
    </div>
  </div>
</template>
