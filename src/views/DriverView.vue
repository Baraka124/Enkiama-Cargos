<script setup>
import { ref, computed, onMounted, onUnmounted, inject, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { useConsignments } from '../composables/useConsignments'
import { fmtTZS, supabase } from '../lib/supabase'
import ConsignmentCard from '../components/ConsignmentCard.vue'
import Icon from '../components/Icon.vue'
import EmptyState from '../components/EmptyState.vue'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

const router = useRouter()
const toast = inject('toast')
const { carrier, profile, signOut } = useAuth()
const { consignments, fetchAll, subscribe, unsubscribe, markDelivered, reportFailed } = useConsignments()

const exceptionFor = ref(null)
const proofFor = ref(null)      // parcel being delivered with proof
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
  const p = nextStop.value; if (!p) return { owed: 0 }
  if (p.payMode==='cash' && !['collected','remitted','settled'].includes(p.payState)) return { owed: p.cod }
  return { owed: 0 }
})

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

onMounted(async () => { await fetchAll(); subscribe(); await nextTick(); renderMap() })
onUnmounted(() => { unsubscribe(); if (map) { map.remove(); map = null } })
watch(pending, async () => { await nextTick(); renderMap() })

function openProof(p) { proofFor.value = p; photoData.value = ''; nextTickClearSig() }
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
  let photoUrl = ''
  try {
    if (photoData.value) {
      const blob = await (await fetch(photoData.value)).blob()
      const path = `${p.id}-${Date.now()}.jpg`
      const { error: upErr } = await supabase.storage.from('pod').upload(path, blob, { contentType: 'image/jpeg', upsert: true })
      if (!upErr) { photoUrl = supabase.storage.from('pod').getPublicUrl(path).data.publicUrl }
    }
    const sig = sigCanvas.value ? sigCanvas.value.toDataURL('image/png') : ''
    const { error } = await supabase.rpc('deliver_with_proof', { p_consignment: p.id, p_photo_url: photoUrl, p_signature: sig })
    if (error) throw error
    toast(`${p.code} delivered with proof`, 'ok')
    proofFor.value = null
    await fetchAll()
  } catch (e) { toast(e.message || 'Could not save proof', 'warn') }
}
async function fail(reason) {
  await reportFailed(exceptionFor.value, reason.k, reason.label)
  toast(`${exceptionFor.value.code} marked failed — dispatch notified`, 'warn')
  exceptionFor.value = null
}
async function logout(){ await signOut(); router.push('/login') }
</script>

<template>
  <div class="topbar"><div class="inner">
    <div class="tb-mark">{{ carrier?.mark || 'EC' }}</div>
    <div><div class="tb-name">{{ carrier?.name || 'Enkiama Cargos' }}</div><div class="tb-role">Driver · {{ profile?.name }}</div></div>
    <div class="tb-spacer"></div>
    <button class="btn btn-ghost" @click="logout">Sign out</button>
  </div></div>

  <div class="wrap">
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
        <Icon name="cash" :size="16" /><span class="m-txt">Collect cash on handover</span><span class="m-amt mono">{{ fmtTZS(nextMoney.owed) }}</span>
      </div>
      <div v-else class="money-bar done" style="margin-top:16px">
        <Icon name="check" :size="16" /><span class="m-txt">Nothing to collect — just deliver</span><span class="m-amt mono">{{ nextStop.payMode==='prepaid'?'Prepaid':'Free' }}</span>
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

    <div class="sec"><h2>Your run today</h2><span class="ln"></span></div>
    <ConsignmentCard v-for="p in mine" :key="p.id" :p="p" />
  </div>

  <!-- PROOF OF DELIVERY MODAL -->
  <div v-if="proofFor" class="overlay" @click.self="proofFor=null">
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

      <div style="display:flex;gap:10px;margin-top:6px">
        <button class="btn btn-ghost" @click="proofFor=null">Cancel</button>
        <button class="btn btn-go" style="flex:1" @click="submitProof">Confirm delivery</button>
      </div>
    </div>
  </div>

  <!-- EXCEPTION MODAL -->
  <div v-if="exceptionFor" class="overlay" @click.self="exceptionFor=null">
    <div class="modal">
      <h3>Couldn't deliver</h3>
      <p>What happened with {{ exceptionFor.code }} to {{ exceptionFor.receiver }}?</p>
      <div class="reasons">
        <button v-for="r in REASONS" :key="r.k" class="reason" @click="fail(r)"><span style="font-size:17px;margin-right:8px">{{ r.ic }}</span>{{ r.label }}</button>
      </div>
      <button class="btn btn-ghost btn-block" @click="exceptionFor=null">Cancel</button>
    </div>
  </div>
</template>
