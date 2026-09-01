<script setup>
// Enkiama Property & Land — a focused, verified category on the marketplace.
import { ref, computed, onMounted, inject, nextTick } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuth } from '../composables/useAuth'
import AppHeader from '../components/AppHeader.vue'
import Icon from '../components/Icon.vue'
import EmptyState from '../components/EmptyState.vue'
import Spinner from '../components/Spinner.vue'
import { humanError } from '../lib/humanError'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

const toast = inject('toast')
const { session } = useAuth()

// map-first browsing
const propView = ref('list')
const selectedPin = ref(null)
let propMap = null
let markers = []
async function setMapView() {
  propView.value = 'map'
  await nextTick()
  await renderMap()
}
async function renderMap() {
  try {
    const { data } = await supabase.rpc('property_map', { p_kind: activeKind.value || null, p_region: null, p_max_price: null })
    const pins = (data || []).filter(p => p.lat && p.lng)
    if (!propMap) {
      propMap = L.map('propmap', { zoomControl: true, attributionControl: false, scrollWheelZoom: true }).setView([-6.4, 35.0], 6)
      L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', { maxZoom: 19 }).addTo(propMap)
    }
    markers.forEach(m => propMap.removeLayer(m)); markers = []
    const green = '#0B6E5D'
    for (const p of pins) {
      const price = p.price_tzs ? 'TZS ' + Number(p.price_tzs).toLocaleString() : ''
      const icon = L.divIcon({ className: 'prop-pin', html: `<div class="prop-pin-badge">${price || 'View'}</div>`, iconSize: [1, 1] })
      const m = L.marker([p.lat, p.lng], { icon }).addTo(propMap)
      m.on('click', () => { selectedPin.value = p })
      markers.push(m)
    }
    if (pins.length) {
      const grp = L.featureGroup(markers)
      propMap.fitBounds(grp.getBounds().pad(0.3), { maxZoom: 12 })
    }
    setTimeout(() => propMap && propMap.invalidateSize(), 100)
  } catch (e) {}
}

const KINDS = [
  { k: 'plot', label: 'Land plots', icon: 'pin' },
  { k: 'farm', label: 'Farms', icon: 'globe' },
  { k: 'house', label: 'Houses', icon: 'building' },
  { k: 'rental', label: 'Rentals', icon: 'building' },
]
const listings = ref([])
const loading = ref(true)
const activeKind = ref('')
const showForm = ref(false)
const myListings = ref([])
const showMine = ref(false)

async function loadMine() {
  if (!session.value) return
  try { const { data } = await supabase.rpc('my_properties'); myListings.value = data?.listings || [] } catch (e) {}
}
async function withdraw(id) {
  try { const { data } = await supabase.rpc('withdraw_property', { p_id: id }); if (data?.ok) { toast('Listing withdrawn', 'ok'); loadMine() } } catch (e) {}
}

async function load() {
  loading.value = true
  try {
    const { data } = await supabase.rpc('browse_properties', { p_kind: activeKind.value || null, p_region: null })
    listings.value = data || []
  } catch (e) { listings.value = [] }
  loading.value = false
}
function setKind(k) { activeKind.value = activeKind.value === k ? '' : k; load(); if (propView.value==='map') renderMap() }
function fmtPrice(l) {
  if (!l.price_tzs) return 'Price on request'
  const basis = l.price_basis === 'per_acre' ? '/acre' : l.price_basis === 'per_month' ? '/month' : ''
  return 'TZS ' + Number(l.price_tzs).toLocaleString() + basis
}
function fmtSize(l) {
  if (!l.size_value) return ''
  return `${l.size_value} ${l.size_unit || ''}`.trim()
}
function kindLabel(k) { return (KINDS.find(x => x.k === k) || {}).label || k }

onMounted(() => { load(); loadMine() })
</script>

<template>
  <AppHeader title="Enkiama Property" subtitle="Land & property">
    <button v-if="session && myListings.length" class="btn btn-ghost" @click="showMine = !showMine"><Icon name="inbox" :size="15" /> My listings <span class="tb-count">{{ myListings.length }}</span></button>
    <button v-if="session" class="btn btn-accent" @click="showForm = true"><Icon name="plus" :size="15" /> List a property</button>
    <RouterLink v-else to="/join/business" class="btn btn-accent">List a property</RouterLink>
  </AppHeader>

  <div class="prop-hero">
    <div class="prop-hero-inner">
      <div class="prop-eyebrow"><Icon name="shield" :size="14" /> Verified listings only</div>
      <h1 class="prop-h1">Land &amp; property, <span class="prop-grad">checked before it's shown.</span></h1>
      <p class="prop-sub">Every plot, farm, house and rental on Enkiama is reviewed by our team before it goes live. Buy with eyes open — final purchase remains subject to your own due diligence.</p>
    </div>
  </div>

  <div class="wrap prop-wrap">
    <!-- seller's own listings + status -->
    <div v-if="showMine && myListings.length" class="mine-panel">
      <div class="mine-head"><h3>My listings</h3><button class="mine-close" @click="showMine=false"><Icon name="plus" :size="16" style="transform:rotate(45deg)" /></button></div>
      <div v-for="m in myListings" :key="m.id" class="mine-row">
        <div class="mine-thumb" :style="m.images && m.images[0] ? {backgroundImage:`url(${m.images[0]})`} : {}"><Icon v-if="!m.images || !m.images[0]" name="pin" :size="16" /></div>
        <div class="mine-info">
          <b>{{ m.title }}</b>
          <span>{{ m.location }} · {{ m.price_tzs ? 'TZS '+Number(m.price_tzs).toLocaleString() : 'Price on request' }}</span>
        </div>
        <span class="mine-status" :class="'st-'+m.status">
          <template v-if="m.status==='verified'"><Icon name="check" :size="11" /> Live</template>
          <template v-else-if="m.status==='pending'"><Icon name="clock" :size="11" /> Under review</template>
          <template v-else><Icon name="alert" :size="11" /> Rejected</template>
        </span>
        <button class="mine-withdraw" @click="withdraw(m.id)" aria-label="Withdraw">Withdraw</button>
      </div>
      <p v-if="myListings.some(m => m.status==='rejected' && m.admin_note)" class="mine-note">
        Rejected listings include a reason — check with support to resolve and resubmit.
      </p>
    </div>

    <div class="prop-kinds">
      <button class="prop-kind" :class="{on:!activeKind}" @click="setKind('')">All</button>
      <button v-for="k in KINDS" :key="k.k" class="prop-kind" :class="{on:activeKind===k.k}" @click="setKind(k.k)">
        <Icon :name="k.icon" :size="14" /> {{ k.label }}
      </button>
      <div class="prop-viewtoggle">
        <button class="prop-vt" :class="{on:propView==='list'}" @click="propView='list'"><Icon name="menu" :size="14" /> List</button>
        <button class="prop-vt" :class="{on:propView==='map'}" @click="setMapView"><Icon name="pin" :size="14" /> Map</button>
      </div>
    </div>

    <!-- MAP VIEW -->
    <div v-show="propView==='map'" class="prop-maparea">
      <div id="propmap" class="prop-map"></div>
      <div v-if="selectedPin" class="prop-mapcard">
        <button class="prop-mapcard-x" @click="selectedPin=null"><Icon name="plus" :size="15" style="transform:rotate(45deg)" /></button>
        <div class="prop-mapcard-kind">{{ kindLabel(selectedPin.kind) }}<span v-if="selectedPin.status==='verified'" class="prop-mapcard-vf"><Icon name="shield" :size="10" /> Verified</span></div>
        <div class="prop-mapcard-title">{{ selectedPin.title }}</div>
        <div class="prop-mapcard-loc"><Icon name="pin" :size="12" /> {{ selectedPin.location || selectedPin.region }}<span v-if="!selectedPin.exact" class="prop-approx">approx.</span></div>
        <div class="prop-mapcard-price">{{ fmtPrice(selectedPin) }}</div>
        <RouterLink :to="`/property/${selectedPin.id}`" class="btn btn-accent btn-block">View full details</RouterLink>
      </div>
    </div>

    <div v-show="propView==='list'">
    <div v-if="loading" class="prop-grid">
      <div v-for="i in 6" :key="i" class="prop-card sk"></div>
    </div>
    <EmptyState v-else-if="!listings.length" icon="pin" title="No verified listings yet"
      hint="Verified plots, farms and houses will appear here. List yours and our team will review it." />
    <div v-else class="prop-grid">
      <RouterLink v-for="l in listings" :key="l.id" :to="`/property/${l.id}`" class="prop-card">
        <div class="prop-card-img" :style="l.images && l.images[0] ? {backgroundImage:`url(${l.images[0]})`} : {}">
          <span v-if="!l.images || !l.images[0]" class="prop-card-ph"><Icon name="pin" :size="30" /></span>
          <span class="prop-card-kind">{{ kindLabel(l.kind) }}</span>
          <span class="prop-card-verified"><Icon name="shield" :size="11" /> Verified</span>
        </div>
        <div class="prop-card-body">
          <div class="prop-card-title">{{ l.title }}</div>
          <div class="prop-card-loc"><Icon name="pin" :size="12" /> {{ l.location || l.region }}</div>
          <div class="prop-card-meta">
            <span v-if="fmtSize(l)" class="prop-chip">{{ fmtSize(l) }}</span>
            <span v-if="l.has_electricity" class="prop-chip"><Icon name="display" :size="11" /> Power</span>
            <span v-if="l.has_water" class="prop-chip">Water</span>
          </div>
          <div class="prop-card-foot">
            <div class="prop-card-price">{{ fmtPrice(l) }}</div>
            <span v-if="l.fair_price_ok" class="prop-fair"><Icon name="check" :size="11" /> Fair price</span>
          </div>
        </div>
      </RouterLink>
    </div>
    </div>
  </div>

  <PropertyForm v-if="showForm" @close="showForm=false" @submitted="showForm=false; toast('Submitted for review — we\'ll verify it shortly','ok')" />
</template>

<script>
import PropertyForm from '../components/PropertyForm.vue'
export default { components: { PropertyForm } }
</script>

<style scoped>
.prop-hero{background:linear-gradient(160deg,var(--ink),#1A2430 70%,var(--accent));color:#fff;padding:44px 24px 40px}
.prop-hero-inner{max-width:900px;margin:0 auto}
.prop-eyebrow{display:inline-flex;align-items:center;gap:7px;font-size:12.5px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:#4FD1B5;margin-bottom:16px}
.prop-h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(28px,4vw,44px);font-weight:700;letter-spacing:-.03em;line-height:1.08;margin-bottom:14px;max-width:760px}
.prop-grad{background:linear-gradient(110deg,#4FD1B5,#7EE8CF);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.prop-sub{font-size:15px;line-height:1.6;color:rgba(255,255,255,.72);max-width:600px}
.prop-wrap{padding-top:26px}
.prop-kinds{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:24px}
.prop-kind{display:inline-flex;align-items:center;gap:6px;padding:8px 15px;border-radius:999px;border:1px solid var(--hairline-2);background:var(--surface);font-family:inherit;font-size:13px;font-weight:600;color:var(--ink-soft);cursor:pointer;transition:.15s}
.prop-kind:hover{border-color:var(--accent);color:var(--accent-ink)}
.prop-kind.on{background:var(--ink);color:#fff;border-color:var(--ink)}
.prop-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:20px}
.prop-card{display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--hairline-soft,rgba(20,24,31,.05));border-radius:20px;overflow:hidden;text-decoration:none;box-shadow:0 1px 3px rgba(20,24,31,.04);transition:box-shadow .25s ease,transform .2s ease}
.prop-card:hover{box-shadow:var(--shadow-md);transform:translateY(-3px)}
.prop-card.sk{height:320px;background:var(--surface-2)}
.prop-card-img{position:relative;height:180px;background:linear-gradient(135deg,var(--accent),var(--accent-ink));background-size:cover;background-position:center;display:flex;align-items:center;justify-content:center;color:rgba(255,255,255,.7)}
.prop-card-kind{position:absolute;top:10px;left:10px;background:rgba(20,24,31,.8);color:#fff;font-size:11px;font-weight:600;padding:4px 10px;border-radius:8px;backdrop-filter:blur(4px)}
.prop-card-verified{position:absolute;top:12px;right:12px;display:inline-flex;align-items:center;gap:3px;background:rgba(255,255,255,.92);backdrop-filter:blur(8px);color:var(--go-ink);font-size:10px;font-weight:600;padding:4px 9px;border-radius:8px;box-shadow:0 1px 4px rgba(20,24,31,.12)}
.prop-card-body{padding:15px}
.prop-card-title{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:16px;color:var(--ink);letter-spacing:-.01em;margin-bottom:5px}
.prop-card-loc{display:flex;align-items:center;gap:4px;font-size:13px;color:var(--ink-faint);margin-bottom:10px}
.prop-card-meta{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:12px}
.prop-chip{display:inline-flex;align-items:center;gap:3px;font-size:11px;font-weight:600;color:var(--ink-soft);background:var(--surface-2);border:1px solid var(--hairline);padding:3px 9px;border-radius:999px}
.prop-card-foot{display:flex;align-items:center;justify-content:space-between;border-top:1px solid var(--hairline);padding-top:12px}
.prop-card-price{font-family:'Space Grotesk',sans-serif;font-weight:600;font-size:17px;letter-spacing:-.02em;color:var(--ink)}
.prop-fair{display:inline-flex;align-items:center;gap:3px;font-size:11px;font-weight:700;color:var(--go-ink);background:var(--go-soft);padding:3px 8px;border-radius:999px}

.mine-panel{background:var(--surface);border:1px solid var(--hairline-2);border-radius:14px;padding:18px;margin-bottom:24px;box-shadow:var(--shadow-sm)}
.mine-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px}
.mine-head h3{font-family:"Space Grotesk",sans-serif;font-size:16px;font-weight:700;color:var(--ink)}
.mine-close{width:30px;height:30px;border-radius:8px;border:1px solid var(--hairline);background:var(--surface-2);color:var(--ink-faint);cursor:pointer;display:flex;align-items:center;justify-content:center}
.mine-row{display:flex;align-items:center;gap:12px;padding:11px 0;border-bottom:1px solid var(--hairline)}
.mine-row:last-of-type{border-bottom:none}
.mine-thumb{width:48px;height:38px;border-radius:8px;background-size:cover;background-position:center;background-color:var(--surface-2);display:flex;align-items:center;justify-content:center;color:var(--ink-ghost);flex-shrink:0}
.mine-info{flex:1;min-width:0}
.mine-info b{display:block;font-size:14px;color:var(--ink)}
.mine-info span{font-size:12.5px;color:var(--ink-faint)}
.mine-status{display:inline-flex;align-items:center;gap:4px;font-size:11px;font-weight:700;padding:4px 10px;border-radius:999px}
.mine-status.st-verified{background:var(--go-soft);color:var(--go-ink)}
.mine-status.st-pending{background:var(--warn-soft);color:var(--warn-ink)}
.mine-status.st-rejected{background:var(--owed-soft);color:var(--owed-ink)}
.mine-withdraw{background:none;border:none;font-family:inherit;font-size:12.5px;font-weight:600;color:var(--ink-faint);cursor:pointer;padding:4px 8px}
.mine-withdraw:hover{color:var(--owed-ink)}
.mine-note{font-size:12.5px;color:var(--ink-faint);margin-top:12px}

@media(max-width:560px){
  .prop-hero-inner{padding:24px 16px 28px}
  .prop-hero h1{font-size:26px}
  .prop-kinds{gap:7px}
  .prop-kind{font-size:13px;padding:8px 13px}
  .prop-viewtoggle{margin-left:0;width:100%;justify-content:center;margin-top:4px}
  .prop-grid{grid-template-columns:1fr;gap:14px}
  .prop-map{height:420px}
}
</style>
