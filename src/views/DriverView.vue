<script setup>
import { ref, computed, onMounted, onUnmounted, inject, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { useConsignments } from '../composables/useConsignments'
import { useDriver } from '../composables/useDriver'
import { fmtTZS } from '../lib/supabase'
import ConsignmentCard from '../components/ConsignmentCard.vue'
import Icon from '../components/Icon.vue'
import AppHeader from '../components/AppHeader.vue'
import CodeScanner from '../components/CodeScanner.vue'
import EmptyState from '../components/EmptyState.vue'
import Spinner from '../components/Spinner.vue'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

const router = useRouter()
const toast = inject('toast')
const { carrier, profile, signOut } = useAuth()
const { consignments, fetchAll, subscribe, unsubscribe, markDelivered, reportFailed } = useConsignments()
const drv = useDriver()

const exceptionFor = ref(null)
const proofFor = ref(null)      // parcel being delivered with proof
const proofBusy = ref(false)
// ── OCR waybill scan ──
const scanOpen = ref(false)
async function onCodeScanned(code) {
  scanOpen.value = false
  // is it already in this driver's list?
  const mine = consignments.value.find(c => c.code?.toUpperCase() === code.toUpperCase())
  if (mine) { toast(`Found ${code} in your run`, 'ok'); openProof(mine); return }
  // otherwise try to claim it from the office
  try {
    const { error } = await drv.claimParcel(code)
    if (error) throw error
    toast(`Claimed ${code}`, 'ok')
    await fetchAll(); await loadAvailable()
  } catch (e) { toast(e.message || `Couldn't find ${code} at your office`, 'warn') }
}
const rcvBy = ref('')          // who actually received it (if not the receiver)
const rcvRelation = ref('self')
const sigCanvas = ref(null)
const photoData = ref('')
let drawing = false
const REASONS = [
  { k:'not_home', ic:'🚪', label:'Receiver not home' },
  { k:'refused', ic:'🙅', label:'Receiver refused' },
  { k:'no_cash', ic:'💸', label:"Didn't have the cash" },
  { k:'wrong_address', ic:'🗺️', label:'Wrong / bad address' },
  { k:'phone_off', ic:'📵', label:'Phone off / no answer' },
  { k:'other', ic:'❓', label:'Other problem' },
]

// this driver's assigned parcels
const mine = computed(() => consignments.value.filter(p => ['with_driver','delivered','failed'].includes(p.stage)))
const pending = computed(() => mine.value.filter(p => p.stage === 'with_driver'))
const nextStop = computed(() => pending.value[0] || null)
const nextMoney = computed(() => {
  const p = nextStop.value; if (!p) return { owed: 0, goods: 0, fee: 0 }
  const goods = (p.payMode==='cash' && !['collected','remitted','settled'].includes(p.payState)) ? p.cod : 0
  // receiver-paid delivery fee is collected at handover too
  const fee = (p.feePayer==='receiver_on_delivery' && p.feeStatus!=='settled') ? (p.deliveryFee || 0) : 0
  return { owed: goods + fee, goods, fee }
})

// ── driver self-service: parcels available to claim at my office ──
const available = ref([])
const claiming = ref('')
async function loadAvailable() {
  try {
    const { data } = await drv.availableParcels()
    available.value = (data || []).map(r => ({
      id: r.id, code: r.code, receiver: r.receiver_name, addr: r.dest_address,
      item: r.item, weight: Number(r.weight_kg), fee: r.delivery_fee, feePayer: r.fee_payer, cod: r.cod_amount,
    }))
  } catch (e) { available.value = [] }
}
async function claim(p) {
  claiming.value = p.code
  try {
    const { error } = await drv.claimParcel(p.code)
    if (error) throw error
    toast(`You claimed ${p.code}`, 'ok')
    await fetchAll(); await loadAvailable()
  } catch (e) { toast(e.message || 'Could not claim', 'warn') }
  claiming.value = ''
}

// ── OCR: snap a waybill, auto-extract the ENK-#### code ──
const scanning = ref(false)
async function scanWaybill(e) {
  const file = e.target.files?.[0]; if (!file) return
  scanning.value = true
  try {
    const Tesseract = (await import('tesseract.js')).default
    const { data } = await Tesseract.recognize(file, 'eng')
    const text = (data.text || '').toUpperCase()
    // find an ENK-#### style code
    const m = text.match(/ENK[\s-]?(\d{3,5})/)
    if (m) {
      const code = 'ENK-' + m[1]
      const match = available.value.find(a => a.code.toUpperCase() === code)
      if (match) { toast(`Found ${code} — claiming…`, 'ok'); await claim(match) }
      else { toast(`Read ${code}, but it's not available at your office`, 'warn') }
    } else {
      toast('Couldn\u2019t read a code — try a clearer photo', 'warn')
    }
  } catch (err) { toast('Scan failed — enter the code manually', 'warn') }
  scanning.value = false
}

// freelancer driver records the fee they negotiated with the receiver
const feeEditFor = ref(null)
const feeAmt = ref('')
function startFeeEdit(p) { feeEditFor.value = p.code; feeAmt.value = p.deliveryFee || '' }
async function saveFee(p) {
  try {
    const { error } = await drv.setNegotiatedFee(p.code, Number(feeAmt.value)||0)
    if (error) throw error
    toast(`Delivery fee set: ${fmtTZS(Number(feeAmt.value)||0)}`, 'ok')
    feeEditFor.value = null
    await fetchAll()
  } catch (e) { toast(e.message || 'Could not set fee', 'warn') }
}

// ── map (Leaflet) ──────────────────────────────────────────────────
let map, markers = []
// demo coordinates for Dar es Salaam area keyed by rough address
const GEO = {
  'Mikocheni': [-6.7722, 39.2412], 'Kariakoo': [-6.8163, 39.2803],
  'Msasani': [-6.7500, 39.2700], 'Tabata': [-6.8400, 39.2200], 'Uyole': [-8.9200, 33.4600],
}
function geoFor(addr='') {
  for (const key in GEO) if (addr.includes(key)) return GEO[key]
  return [-6.7924, 39.2615] // Dar centre fallback
}
function renderMap() {
  if (!document.getElementById('drvmap')) return
  if (!map) {
    map = L.map('drvmap', { zoomControl: true }).setView([-6.7924, 39.2615], 12)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', { maxZoom: 19, attribution: '© OSM © CARTO' }).addTo(map)
  }
  markers.forEach(m => map.removeLayer(m)); markers = []
  const stops = pending.value
  const pts = []
  stops.forEach((p, i) => {
    const ll = geoFor(p.addr)
    pts.push(ll)
    const icon = L.divIcon({ html: `<div style="background:${carrier.value?.accent||'#3E5BD6'};color:#fff;width:26px;height:26px;border-radius:50% 50% 50% 0;transform:rotate(-45deg);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:12px;box-shadow:0 2px 8px rgba(0,0,0,.5)"><span style="transform:rotate(45deg)">${i+1}</span></div>`, className:'', iconSize:[26,26], iconAnchor:[13,26] })
    const m = L.marker(ll, { icon }).addTo(map).bindPopup(`<b>${p.receiver}</b><br>${p.addr}<br>${p.code}`)
    markers.push(m)
  })
  if (pts.length) map.fitBounds(L.latLngBounds(pts).pad(0.3))
}
function navigateTo(p) {
  const [lat, lng] = geoFor(p.addr)
  window.open(`https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`, '_blank')
}

const space = ref(null)
async function loadSpace() {
  try { const { data } = await drv.mySpace(); space.value = data } catch (e) {}
}
onMounted(async () => { await fetchAll(); await loadAvailable(); await loadSpace(); subscribe(); await nextTick(); renderMap() })
onUnmounted(() => { unsubscribe(); if (map) { map.remove(); map = null } })
watch(pending, async () => { await nextTick(); renderMap() })

function openProof(p) { proofFor.value = p; photoData.value = ''; rcvBy.value = ''; rcvRelation.value = 'self'; nextTickClearSig() }
function nextTickClearSig() { setTimeout(() => { const c = sigCanvas.value; if (c) { const x = c.getContext('2d'); x.fillStyle = '#FFFFFF'; x.fillRect(0,0,c.width,c.height) } }, 50) }
function sigStart(e){ drawing = true; sigDraw(e) }
function sigEnd(){ drawing = false; const c = sigCanvas.value; if (c) c.getContext('2d').beginPath() }
function sigDraw(e){
  if (!drawing) return
  const c = sigCanvas.value; const r = c.getBoundingClientRect()
  const pt = e.touches ? e.touches[0] : e
  const x = (pt.clientX - r.left) * (c.width/r.width)
  const y = (pt.clientY - r.top) * (c.height/r.height)
  const ctx = c.getContext('2d')
  ctx.lineWidth = 2.5; ctx.lineCap = 'round'; ctx.strokeStyle = '#1A1D21'
  ctx.lineTo(x,y); ctx.stroke(); ctx.beginPath(); ctx.moveTo(x,y)
}
function onPhoto(e){
  const file = e.target.files?.[0]; if (!file) return
  const reader = new FileReader(); reader.onload = () => { photoData.value = reader.result }; reader.readAsDataURL(file)
}
async function submitProof() {
  const p = proofFor.value; if (!p) return
  proofBusy.value = true
  try {
    if (photoData.value) {
      const blob = await (await fetch(photoData.value)).blob()
      const url = await drv.uploadPodPhoto(p.id, blob)
      const { error: aErr } = await drv.attachPodPhoto(p.code, url)
      if (aErr) throw aErr
    }
    // then mark delivered (atomic), recording who received it if not the named receiver
    const receivedBy = (rcvRelation.value !== 'self' && rcvBy.value.trim()) ? rcvBy.value.trim() : null
    const relation = receivedBy ? rcvRelation.value : null
    const { error } = await drv.deliverParcel(p.code, 'Delivered with photo proof', receivedBy, relation)
    if (error) throw error
    toast(`${p.code} delivered with proof`, 'ok')
    proofFor.value = null
    await fetchAll()
  } catch (e) { toast(e.message || 'Could not save proof', 'warn') }
  proofBusy.value = false
}
async function fail(reason) {
  await reportFailed(exceptionFor.value, reason.k, reason.label)
  toast(`${exceptionFor.value.code} marked failed — dispatch notified`, 'warn')
  exceptionFor.value = null
}
async function logout(){ await signOut(); router.push('/login') }
</script>

<template>
  <AppHeader :title="carrier?.name || 'Enkiama Cargos'" :subtitle="'Driver · ' + (profile?.name || '')" :carrier="carrier" live>
    <button class="btn btn-accent" @click="scanOpen=true"><Icon name="camera" :size="15" /> Scan code</button>
    <button class="btn btn-ghost" @click="logout">Sign out</button>
  </AppHeader>

  <div class="wrap">
    <div v-if="space" class="drv-stats">
      <div class="drv-stat"><div class="drv-stat-n">{{ space.active_tasks }}</div><div class="drv-stat-l">Active tasks</div></div>
      <div class="drv-stat"><div class="drv-stat-n">{{ space.delivered_total }}</div><div class="drv-stat-l">Delivered</div></div>
      <div class="drv-stat"><div class="drv-stat-n">{{ fmtTZS(space.fees_earned) }}</div><div class="drv-stat-l">Fees earned</div></div>
      <div class="drv-stat" :class="{alert: space.cash_to_remit>0}"><div class="drv-stat-n">{{ fmtTZS(space.cash_to_remit) }}</div><div class="drv-stat-l">Cash to remit</div></div>
    </div>

    <div id="drvmap" class="map"></div>

    <div v-if="nextStop" class="nextstop">
      <div class="ns-lab"><Icon name="pin" :size="12" /> Next stop</div>
      <div class="ns-who">{{ nextStop.receiver }}</div>
      <div class="ns-addr">{{ nextStop.addr }}</div>
      <div class="ns-meta">
        <span class="mono">{{ nextStop.code }}</span>
        <span>{{ nextStop.item }} · {{ nextStop.weight }}kg</span>
        <a :href="'tel:'+nextStop.receiverPhone" class="ns-call"><Icon name="phone" :size="13" /> {{ nextStop.receiverPhone }}</a>
      </div>
      <div v-if="nextMoney.owed>0" class="money-bar owed" style="margin-top:16px">
        <Icon name="cash" :size="16" /><span class="m-txt">Collect on handover</span><span class="m-amt mono">{{ fmtTZS(nextMoney.owed) }}</span>
      </div>
      <div v-if="nextMoney.goods>0 && nextMoney.fee>0" class="money-split">
        <span>Goods {{ fmtTZS(nextMoney.goods) }}</span><span>+ delivery fee {{ fmtTZS(nextMoney.fee) }}</span>
      </div>
      <div v-if="nextMoney.owed===0" class="money-bar done" style="margin-top:16px">
        <Icon name="check" :size="16" /><span class="m-txt">Nothing to collect — just deliver</span><span class="m-amt mono">{{ nextStop.payMode==='prepaid'?'Prepaid':'Free' }}</span>
      </div>

      <!-- freelancer driver records the delivery fee they negotiated with the receiver -->
      <div class="drv-fee">
        <template v-if="!feeEditFor">
          <div class="drv-fee-row">
            <span class="drv-fee-lab"><Icon name="cash" :size="13" /> Your delivery fee</span>
            <span class="drv-fee-val">{{ nextStop.deliveryFee ? fmtTZS(nextStop.deliveryFee) : 'Not set' }}
              <span class="drv-fee-status" :class="nextStop.feeStatus">{{ nextStop.feeStatus }}</span>
            </span>
            <button class="drv-fee-edit" @click="startFeeEdit(nextStop)">{{ nextStop.deliveryFee ? 'Edit' : 'Set fee' }}</button>
          </div>
          <div v-if="nextStop.feeStatus==='pending'" class="drv-fee-warn"><Icon name="alert" :size="12" /> Agree your fee before you can mark delivered.</div>
        </template>
        <div v-else class="drv-fee-edit-box">
          <label>What did you agree with the receiver?</label>
          <div class="drv-fee-input-row">
            <input v-model="feeAmt" type="number" inputmode="numeric" placeholder="Fee in TZS" @keyup.enter="saveFee(nextStop)" />
            <button class="btn btn-accent" @click="saveFee(nextStop)">Agree</button>
          </div>
          <button class="drv-fee-cancel" @click="feeEditFor=null">Cancel</button>
        </div>
      </div>

      <div class="ns-actions">
        <button class="btn btn-go btn-lg ns-primary" @click="openProof(nextStop)">
          <Icon name="check" :size="18" /> Deliver &amp; {{ nextMoney.owed>0?'collect':'sign' }}
        </button>
        <div class="ns-secondary">
          <button class="btn btn-ghost btn-lg" @click="navigateTo(nextStop)"><Icon name="pin" :size="16" /> Navigate</button>
          <button class="btn btn-ghost btn-lg" @click="exceptionFor=nextStop"><Icon name="alert" :size="16" /> Couldn't</button>
        </div>
      </div>
    </div>
    <EmptyState v-else icon="truck" title="No pending stops" hint="When dispatch hands you a consignment, it appears here for your run." />

    <!-- AVAILABLE AT MY OFFICE — driver self-service (pull) -->
    <template v-if="available.length">
      <div class="sec"><h2>Available at your office</h2><span class="ln"></span></div>
      <div class="avail-hint">Parcels ready for pickup at your carrier. Claim one to add it to your run.</div>
      <label class="scan-btn" :class="{busy:scanning}">
        <Spinner v-if="scanning" :size="16" /><Icon v-else name="camera" :size="16" />
        <span>{{ scanning ? 'Reading waybill…' : 'Scan a waybill to claim' }}</span>
        <input type="file" accept="image/*" capture="environment" style="display:none" :disabled="scanning" @change="scanWaybill" />
      </label>
      <div class="avail-list">
        <div v-for="p in available" :key="p.id" class="avail-card">
          <div class="avail-main">
            <div class="avail-code mono">{{ p.code }}</div>
            <div class="avail-to">{{ p.receiver }} · {{ p.addr }}</div>
            <div class="avail-meta">{{ p.item }} · {{ p.weight }}kg<span v-if="p.fee"> · fee {{ fmtTZS(p.fee) }}</span></div>
          </div>
          <button class="btn btn-accent" :disabled="claiming===p.code" @click="claim(p)">
            <Spinner v-if="claiming===p.code" :size="15" /><span v-else>Claim</span>
          </button>
        </div>
      </div>
    </template>

    <div class="sec"><h2>Your run today</h2><span class="ln"></span></div>
    <ConsignmentCard v-for="p in mine" :key="p.id" :p="p" />

    <template v-if="space && space.history && space.history.length">
      <div class="sec"><h2>Delivery history</h2><span class="ln"></span></div>
      <div class="drv-history">
        <div v-for="h in space.history" :key="h.code" class="drv-hrow">
          <div class="drv-hic"><Icon name="check" :size="14" /></div>
          <div style="flex:1;min-width:0">
            <div class="drv-htop"><span class="mono">{{ h.code }}</span> · {{ h.item }}</div>
            <div class="drv-hsub">{{ h.receiver }}<span v-if="h.received_by && h.received_by!==h.receiver"> · received by {{ h.received_by }}</span> · {{ h.dest }}</div>
          </div>
          <div class="drv-hdate">{{ h.pod_at ? new Date(h.pod_at).toLocaleDateString() : '' }}</div>
        </div>
      </div>
    </template>
  </div>

  <!-- PROOF OF DELIVERY MODAL -->
  <div v-if="proofFor" class="overlay" v-escape="() => { proofFor=null }" @click.self="proofFor=null">
    <div class="modal">
      <h3>Proof of delivery</h3>
      <p>{{ proofFor.code }} to {{ proofFor.receiver }}<span v-if="nextMoney.owed>0"> · collect {{ fmtTZS(nextMoney.owed) }}</span></p>

      <div class="fg"><label>Receiver signature</label>
        <canvas ref="sigCanvas" width="380" height="130"
          style="width:100%;border:1px solid var(--hairline-2);border-radius:11px;background:#FFFFFF;touch-action:none"
          @mousedown="sigStart" @mousemove="sigDraw" @mouseup="sigEnd" @mouseleave="sigEnd"
          @touchstart.prevent="sigStart" @touchmove.prevent="sigDraw" @touchend.prevent="sigEnd"></canvas>
        <div class="p-sub" style="margin-top:4px;cursor:pointer" @click="nextTickClearSig">↺ clear</div>
      </div>

      <div class="fg"><label>Photo (optional)</label>
        <input type="file" accept="image/*" capture="environment" @change="onPhoto" />
        <img v-if="photoData" :src="photoData" style="width:100%;border-radius:11px;margin-top:8px;max-height:160px;object-fit:cover" />
      </div>

      <div class="fg"><label>Who received it?</label>
        <div class="rcv-relation">
          <button v-for="r in ['self','family','neighbour','colleague','other']" :key="r"
            class="rcv-chip" :class="{on:rcvRelation===r}" @click="rcvRelation=r">{{ r==='self' ? 'The receiver' : r }}</button>
        </div>
        <input v-if="rcvRelation!=='self'" v-model="rcvBy" placeholder="Name of who picked it up" style="margin-top:8px" />
      </div>

      <div style="display:flex;gap:10px;margin-top:6px">
        <button class="btn btn-ghost" @click="proofFor=null">Cancel</button>
        <button class="btn btn-go" style="flex:1" :disabled="proofBusy" @click="submitProof">
          <Spinner v-if="proofBusy" :size="15" /><span v-else>Confirm delivery</span>
        </button>
      </div>
    </div>
  </div>

  <!-- EXCEPTION MODAL -->
  <div v-if="exceptionFor" class="overlay" v-escape="() => { exceptionFor=null }" @click.self="exceptionFor=null">
    <div class="modal">
      <h3>Couldn't deliver</h3>
      <p>What happened with {{ exceptionFor.code }} to {{ exceptionFor.receiver }}?</p>
      <div class="reasons">
        <button v-for="r in REASONS" :key="r.k" class="reason" @click="fail(r)"><span style="font-size:17px;margin-right:8px">{{ r.ic }}</span>{{ r.label }}</button>
      </div>
      <button class="btn btn-ghost btn-block" @click="exceptionFor=null">Cancel</button>
    </div>
  </div>

  <!-- OCR WAYBILL SCANNER -->
  <CodeScanner v-if="scanOpen" @found="onCodeScanned" @close="scanOpen=false" />
</template>
