<script setup>
import { ref, computed, onMounted, onUnmounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { useConsignments } from '../composables/useConsignments'
import { useI18n } from '../composables/useI18n'
import { fmtTZS, supabase } from '../lib/supabase'
import ConsignmentCard from '../components/ConsignmentCard.vue'
import EmptyState from '../components/EmptyState.vue'
import Skeleton from '../components/Skeleton.vue'
import Spinner from '../components/Spinner.vue'
import Icon from '../components/Icon.vue'

const router = useRouter()
const toast = inject('toast')
const { carrier, profile, signOut, isPlatformAdmin, setHat } = useAuth()
const { setLang, isSwahili } = useI18n()
const { consignments, loading, fetchAll, subscribe, unsubscribe, advance, assignDriver, markDelivered, remitCash, confirmMomo, book } = useConsignments()

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

// new-consignment (walk-in booking by dispatch)
const bookModal = ref(false)
const bk = ref({ receiver:'', receiverPhone:'', addr:'', item:'', weight:1, mode:'prepaid', cod:0, fee:0, senderName:'', senderPhone:'' })
const booking = ref(false)
async function submitBooking() {
  if (!bk.value.receiver || !bk.value.receiverPhone) { toast('Receiver name and phone required','warn'); return }
  booking.value = true
  try {
    const code = await book({
      carrierId: profile.value.carrier_id,
      receiver: bk.value.receiver, receiverPhone: bk.value.receiverPhone,
      addr: bk.value.addr, item: bk.value.item, weight: Number(bk.value.weight)||1,
      mode: bk.value.mode, cod: Number(bk.value.cod)||0, fee: Number(bk.value.fee)||0,
      senderName: bk.value.senderName || 'Walk-in', senderPhone: bk.value.senderPhone || '',
    })
    toast(`Booked — ${code}`, 'ok')
    bookModal.value = false
    bk.value = { receiver:'', receiverPhone:'', addr:'', item:'', weight:1, mode:'prepaid', cod:0, fee:0, senderName:'', senderPhone:'' }
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
    const { data } = await supabase.from('driver').select('*').eq('carrier_id', cid)
    drivers.value = data || []
    const { data: led } = await supabase.rpc('my_cash_ledger')
    ledger.value = led || []
  } catch (e) { ledger.value = [] }
}
async function addDriver() {
  if (!newDriver.value.name || !newDriver.value.phone) { toast('Name and phone required', 'warn'); return }
  savingTeam.value = true
  const { error } = await supabase.from('driver').insert({
    carrier_id: profile.value.carrier_id, name: newDriver.value.name,
    phone: newDriver.value.phone, vehicle: newDriver.value.vehicle,
  })
  savingTeam.value = false
  if (error) { toast(error.message, 'warn'); return }
  toast('Driver added', 'ok'); newDriver.value = { name: '', phone: '', vehicle: 'bajaji' }; loadDrivers()
}
async function toggleDriver(d) {
  const { error } = await supabase.rpc('set_driver_active', { p_driver: d.id, p_active: !d.active })
  if (error) { toast(error.message, 'warn'); return }
  toast(d.active ? 'Driver deactivated' : 'Driver reactivated', 'ok'); loadDrivers()
}
async function sendStaffInvite() {
  if (!newStaff.value.email) { toast('Staff email required', 'warn'); return }
  const { error } = await supabase.rpc('invite_staff', { p_email: newStaff.value.email, p_role: 'dispatch' })
  if (error) { toast(error.message, 'warn'); return }
  toast(`Invite created for ${newStaff.value.email} — they join by signing up with it`, 'ok')
  newStaff.value = { email: '' }
}
function switchToPlatform() { setHat('platform'); router.push('/platform') }

onMounted(async () => {
  try { await fetchAll() } catch (e) {}
  try { subscribe() } catch (e) {}
  try { await loadDrivers() } catch (e) {}
  try { await loadCash() } catch (e) {}
})
onUnmounted(unsubscribe)

const owedTotal = computed(() => consignments.value.filter(p => (p.payMode==='cash') && !['collected','remitted','settled'].includes(p.payState)).reduce((a,p)=>a+p.cod,0))
const heldTotal = computed(() => consignments.value.filter(p => p.payMode==='cash' && p.payState==='collected').reduce((a,p)=>a+p.cod,0))
const active = computed(() => consignments.value.filter(p => !['confirmed','cancelled'].includes(p.stage)))
const filteredLedger = computed(() => consignments.value.filter(matchesSearch))
const actionList = computed(() => consignments.value.filter(p =>
  ['booked','collected','linehaul','failed'].includes(p.stage) || (p.payMode==='cash' && p.payState==='collected')))

const customers = computed(() => {
  const map = {}
  for (const p of consignments.value) {
    for (const [nm, ph, r] of [[p.sender, p.senderPhone, 'sender'], [p.receiver, p.receiverPhone, 'receiver']]) {
      if (!nm) continue
      const k = ph || nm
      map[k] = map[k] || { name: nm, phone: ph, roles: new Set(), count: 0 }
      map[k].roles.add(r); map[k].count++
    }
  }
  return Object.values(map).sort((a,b)=>b.count-a.count)
})

function whyLine(p) {
  if (p.stage==='failed') return `Failed: ${p.lastReason||'attempt failed'} — needs retry`
  if (p.stage==='booked') return 'Awaiting pickup by carrier'
  if (p.stage==='linehaul' && !p.driver) return 'No local driver assigned'
  if (p.payMode==='cash' && p.payState==='collected') return 'Cash held by driver — awaiting remit'
  return ''
}
async function doAssign(driverId) {
  await assignDriver(assignModal.value, driverId)
  toast(`${assignModal.value.code} assigned`, 'ok')
  assignModal.value = null
}
async function retry(p) { await advance(p, 'with_driver', 'Retry scheduled'); toast(`${p.code} back on driver's run`, 'ok') }
function initials(n){ return (n||'?').split(' ').map(w=>w[0]).slice(0,2).join('').toUpperCase() }
async function logout(){ await signOut(); router.push('/login') }

// cash ledger — who's holding what (v7 view)
const cashLedger = ref([])
async function loadCash() {
  try {
    const { data } = await supabase.rpc('my_cash_ledger')
    cashLedger.value = data || []
  } catch (e) { cashLedger.value = [] }
}
const totalHolding = computed(() => cashLedger.value.reduce((a,r)=>a + (r.cash_holding||0), 0))
async function doRemit(p) {
  try { await remitCash(p); await loadDrivers(); toast(`${fmtTZS(p.cod)} remitted for ${p.code}`, 'ok') }
  catch (e) { toast(e.message || 'Remit failed', 'warn') }
}
async function doMomo(p) {
  try { await confirmMomo(p, 'M-Pesa'); toast(`${p.code} marked paid by mobile money`, 'ok') }
  catch (e) { toast(e.message || 'Could not confirm', 'warn') }
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
    const { data } = await supabase.from('custody_event')
      .select('*').eq('consignment_id', p.id).order('created_at', { ascending: true })
    detailEvents.value = data || []
  } catch (e) { /* non-fatal */ }
  detailLoading.value = false
}
function fmtWhen(ts) {
  if (!ts) return ''
  const d = new Date(ts)
  return d.toLocaleDateString() + ' · ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <div class="topbar"><div class="inner">
    <div class="tb-mark">{{ carrier?.mark || 'EC' }}</div>
    <div><div class="tb-name">{{ carrier?.name || 'Enkiama Cargos' }}</div><div class="tb-role">{{ isAdmin ? 'Admin' : 'Dispatch' }} · {{ profile?.name }}</div></div>
    <div class="tb-spacer"></div>
    <button v-if="isPlatformAdmin" class="btn btn-ghost" style="margin-right:8px" @click="switchToPlatform">↔ Platform console</button>
    <button class="btn btn-ghost" style="margin-right:8px" @click="setLang(isSwahili?'en':'sw')">{{ isSwahili ? 'EN' : 'SW' }}</button>
    <div class="tb-enk">powered by<br><b>Enkiama Cargos</b></div>
    <button class="btn btn-ghost" style="margin-left:12px" @click="logout">Sign out</button>
  </div></div>

  <div class="wrap">
    <div class="strip">
      <div class="cell"><div class="cl">Active consignments</div><div class="cv">{{ active.length }}</div></div>
      <div class="cell owed"><div class="cl">Needs action</div><div class="cv">{{ actionList.length }}</div></div>
      <div class="cell owed money"><div class="cl">Cash to collect</div><div class="cv mono">{{ fmtTZS(owedTotal) }}</div></div>
      <div class="cell go money"><div class="cl">Collected · unremitted</div><div class="cv mono">{{ fmtTZS(heldTotal) }}</div></div>
    </div>

    <div class="dtabs" style="align-items:center">
      <button class="dtab" :class="{on:tab==='action'}" @click="tab='action'">Needs action <span class="tb-count">{{ actionList.length }}</span></button>
      <button v-if="isAdmin" class="dtab" :class="{on:tab==='dash'}" @click="tab='dash'">Dashboard</button>
      <button class="dtab" :class="{on:tab==='ledger'}" @click="tab='ledger'">Ledger <span class="tb-count">{{ consignments.length }}</span></button>
      <button class="dtab" :class="{on:tab==='customers'}" @click="tab='customers'">Customers <span class="tb-count">{{ customers.length }}</span></button>
      <button class="dtab" :class="{on:tab==='cash'}" @click="tab='cash'">Cash <span class="tb-count">{{ cashLedger.length }}</span></button>
      <button v-if="isAdmin" class="dtab" :class="{on:tab==='team'}" @click="tab='team'">Team <span class="tb-count">{{ drivers.length }}</span></button>
      <button class="btn btn-accent" style="margin-left:auto" @click="bookModal=true">+ New consignment</button>
    </div>

    <!-- ACTION -->
    <div v-if="tab==='action'">
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
      <EmptyState v-else-if="!actionList.length" icon="check" title="All clear" hint="New bookings and problems will surface here." />
      <div v-for="p in actionList" :key="p.id" :class="{selrow: bulkMode}" style="position:relative">
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

    <!-- CUSTOMERS -->
    <div v-else-if="tab==='customers'">
      <div v-if="!customers.length" class="empty"><span class="e-ic">👥</span><p>No customers yet</p></div>
      <div v-for="c in customers" :key="c.phone||c.name" class="cons" style="padding:14px 16px;display:flex;align-items:center;gap:13px">
        <div style="width:40px;height:40px;border-radius:50%;background:#3A4150;display:flex;align-items:center;justify-content:center;font-weight:700;font-family:'Space Grotesk',sans-serif">{{ initials(c.name) }}</div>
        <div><div style="font-weight:600">{{ c.name }}</div><div class="p-sub">{{ c.phone || 'no phone' }} · {{ [...c.roles].join(' & ') }}</div></div>
        <div style="margin-left:auto;text-align:right"><div style="font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:18px">{{ c.count }}</div><div class="p-sub">parcels</div></div>
      </div>
    </div>

    <!-- CASH LEDGER (v7) -->
    <div v-else-if="tab==='cash'">
      <div class="strip" style="grid-template-columns:1fr">
        <div class="cell owed money"><div class="cl">Total cash held by drivers</div><div class="cv mono">{{ fmtTZS(totalHolding) }}</div></div>
      </div>
      <div class="sub" style="margin:0 2px 14px">Live view of collected cash-on-delivery each driver is holding and owes the carrier. Updates as parcels are delivered and remitted.</div>
      <EmptyState v-if="!cashLedger.length" icon="cash" title="No cash activity yet" />
      <div v-for="r in cashLedger" :key="r.driver_id" class="cons" style="padding:14px 16px;display:flex;align-items:center;gap:13px">
        <div style="width:40px;height:40px;border-radius:50%;background:#3A4150;display:flex;align-items:center;justify-content:center;font-weight:700">{{ initials(r.driver_name) }}</div>
        <div>
          <div style="font-weight:600">{{ r.driver_name }}</div>
          <div class="p-sub">{{ r.parcels_holding }} parcel(s) with uncollected remit · {{ fmtTZS(r.cash_remitted) }} remitted</div>
        </div>
        <div style="margin-left:auto;text-align:right">
          <div class="mono" :style="{color: r.cash_holding>0 ? 'var(--owed-ink)' : 'var(--ink-3)', fontWeight:700, fontSize:'17px'}">{{ fmtTZS(r.cash_holding) }}</div>
          <div class="p-sub">holding</div>
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
        <div style="width:40px;height:40px;border-radius:50%;background:#3A4150;display:flex;align-items:center;justify-content:center;font-weight:700">{{ initials(l.driver_name) }}</div>
        <div><div style="font-weight:600">{{ l.driver_name }}</div><div class="p-sub">{{ l.parcels_holding }} parcel{{ l.parcels_holding===1?'':'s' }} · {{ fmtTZS(l.cash_remitted) }} remitted</div></div>
        <div style="margin-left:auto;text-align:right">
          <div class="mono" :style="{fontWeight:700,fontSize:'18px',color: l.cash_holding>0 ? 'var(--owed-ink)' : 'var(--ink-3)'}">{{ fmtTZS(l.cash_holding) }}</div>
          <div class="p-sub">holding</div>
        </div>
      </div>

      <div class="sec"><h2>Drivers</h2><span class="ln"></span></div>
      <EmptyState v-if="!drivers.length" icon="bike" title="No drivers yet" />
      <div v-for="d in drivers" :key="d.id" class="cons" style="padding:14px 16px;display:flex;align-items:center;gap:13px">
        <div style="width:40px;height:40px;border-radius:50%;background:#3A4150;display:flex;align-items:center;justify-content:center;font-weight:700">{{ initials(d.name) }}</div>
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

  <!-- BULK ASSIGN MODAL -->
  <div v-if="bulkAssignModal" class="overlay" @click.self="bulkAssignModal=false">
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
  <div v-if="detail" class="overlay" @click.self="detail=null">
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
            <div class="tl-when">{{ fmtWhen(e.created_at) }}<span v-if="e.actor_name"> · {{ e.actor_name }}</span></div>
          </div>
        </div>
      </div>

      <button class="btn btn-ghost btn-block" style="margin-top:18px" @click="detail=null">Close</button>
    </div>
  </div>

  <!-- NEW CONSIGNMENT MODAL -->
  <div v-if="bookModal" class="overlay" @click.self="bookModal=false">
    <div class="modal">
      <h3>New consignment</h3>
      <p>Book a parcel for a walk-in customer on {{ carrier?.name }}.</p>
      <div class="row2">
        <div class="fg"><label>Sender name</label><input v-model="bk.senderName" placeholder="Walk-in customer" /></div>
        <div class="fg"><label>Sender phone</label><input v-model="bk.senderPhone" placeholder="+255…" /></div>
      </div>
      <div class="row2">
        <div class="fg"><label>Receiver name</label><input v-model="bk.receiver" placeholder="Grace Mwangi" /></div>
        <div class="fg"><label>Receiver phone</label><input v-model="bk.receiverPhone" placeholder="+255712345678" /></div>
      </div>
      <div class="fg"><label>Delivery address</label><input v-model="bk.addr" placeholder="Mikocheni, Dar es Salaam" /></div>
      <div class="row2">
        <div class="fg"><label>Item</label><input v-model="bk.item" placeholder="Documents" /></div>
        <div class="fg"><label>Weight (kg)</label><input v-model="bk.weight" type="number" min="0" step="0.5" /></div>
      </div>
      <div class="fg"><label>Payment</label>
        <select v-model="bk.mode"><option value="prepaid">Prepaid</option><option value="cod">Cash on delivery</option><option value="feeonly">Goods free (fee only)</option></select>
      </div>
      <div class="row2">
        <div class="fg" v-if="bk.mode==='cod'"><label>Cash to collect (TZS)</label><input v-model="bk.cod" type="number" min="0" /></div>
        <div class="fg"><label>Delivery fee (TZS)</label><input v-model="bk.fee" type="number" min="0" /></div>
      </div>
      <div style="display:flex;gap:10px;margin-top:4px">
        <button class="btn btn-ghost" @click="bookModal=false">Cancel</button>
        <button class="btn btn-accent" style="flex:1" :disabled="booking" @click="submitBooking">Book consignment</button>
      </div>
    </div>
  </div>

  <!-- ASSIGN MODAL -->
  <div v-if="assignModal" class="overlay" @click.self="assignModal=null">
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
