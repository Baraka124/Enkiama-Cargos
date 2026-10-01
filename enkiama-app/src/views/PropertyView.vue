<script setup>
// ENKIAMA MARKET V4 — Property as place, not product.
// Existing contracts remain unchanged: browse_properties, property_map, my_properties, withdraw_property.
import { ref, computed, onMounted, onBeforeUnmount, inject, nextTick } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuth } from '../composables/useAuth'
import AppHeader from '../components/AppHeader.vue'
import Icon from '../components/Icon.vue'
import EmptyState from '../components/EmptyState.vue'
import PropertyForm from '../components/PropertyForm.vue'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { viewName, signalMotionReady } from '../lib/motion'

const toast = inject('toast')
const { session } = useAuth()

const KINDS = [
  { k: 'plot', label: 'Land plots', singular: 'Land plot', icon: 'pin' },
  { k: 'farm', label: 'Farms', singular: 'Farm', icon: 'globe' },
  { k: 'house', label: 'Houses', singular: 'House', icon: 'building' },
  { k: 'rental', label: 'Rentals', singular: 'Rental', icon: 'building' },
]

const listings = ref([])
const loading = ref(true)
const activeKind = ref('')
const showForm = ref(false)
const myListings = ref([])
const showMine = ref(false)
const propView = ref('list')
const selectedPin = ref(null)

let propMap = null
let markers = []

const featured = computed(() => listings.value[0] || null)
const listingCount = computed(() => listings.value.length)
const collectionLabel = computed(() => activeKind.value ? kindLabel(activeKind.value) : 'All verified property')

async function loadMine() {
  if (!session.value) return
  try {
    const { data } = await supabase.rpc('my_properties')
    myListings.value = data?.listings || []
  } catch (e) {}
}

async function withdraw(id) {
  try {
    const { data } = await supabase.rpc('withdraw_property', { p_id: id })
    if (data?.ok) {
      toast('Listing withdrawn', 'ok')
      loadMine()
    }
  } catch (e) {}
}

async function load() {
  loading.value = true
  try {
    const { data } = await supabase.rpc('browse_properties', {
      p_kind: activeKind.value || null,
      p_region: null,
    })
    listings.value = data || []
  } catch (e) {
    listings.value = []
  }
  loading.value = false
  await nextTick()
  signalMotionReady()
}

function kindLabel(k) {
  const match = KINDS.find(x => x.k === k)
  return match?.singular || k || 'Property'
}

function fmtPrice(l) {
  if (!l?.price_tzs) return 'Price on request'
  const basis = l.price_basis === 'per_acre'
    ? ' / acre'
    : l.price_basis === 'per_month'
      ? ' / month'
      : l.price_basis === 'per_sqm'
        ? ' / m²'
        : ''
  return 'TZS ' + Number(l.price_tzs).toLocaleString() + basis
}

function fmtSize(l) {
  if (!l?.size_value) return ''
  return `${l.size_value} ${l.size_unit || ''}`.trim()
}

async function setKind(k) {
  activeKind.value = activeKind.value === k ? '' : k
  selectedPin.value = null
  await load()
  if (propView.value === 'map') await renderMap()
}

async function setListView() {
  propView.value = 'list'
  selectedPin.value = null
}

async function setMapView() {
  propView.value = 'map'
  await nextTick()
  await renderMap()
}

async function renderMap() {
  try {
    const { data } = await supabase.rpc('property_map', {
      p_kind: activeKind.value || null,
      p_region: null,
      p_max_price: null,
    })
    const pins = (data || []).filter(p => p.lat && p.lng)

    if (!propMap) {
      propMap = L.map('propmap', {
        zoomControl: true,
        attributionControl: false,
        scrollWheelZoom: true,
        zoomSnap: 0.5,
      }).setView([-6.4, 35.0], 6)
      L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
        maxZoom: 19,
      }).addTo(propMap)
    }

    markers.forEach(m => propMap.removeLayer(m))
    markers = []

    for (const p of pins) {
      const shortPrice = p.price_tzs ? compactPrice(p.price_tzs) : 'View'
      const icon = L.divIcon({
        className: 'prop-pin',
        html: `<div class="prop-pin-badge"><span>${shortPrice}</span></div>`,
        iconSize: [1, 1],
      })
      const m = L.marker([p.lat, p.lng], { icon }).addTo(propMap)
      m.on('click', () => { selectedPin.value = p })
      markers.push(m)
    }

    if (pins.length) {
      const group = L.featureGroup(markers)
      propMap.fitBounds(group.getBounds().pad(0.28), { maxZoom: 11 })
    }
    setTimeout(() => propMap?.invalidateSize(), 120)
  } catch (e) {}
}

function compactPrice(n) {
  const num = Number(n)
  if (!Number.isFinite(num)) return 'View'
  if (num >= 1_000_000_000) return `TZS ${(num / 1_000_000_000).toFixed(num >= 10_000_000_000 ? 0 : 1)}B`
  if (num >= 1_000_000) return `TZS ${(num / 1_000_000).toFixed(num >= 10_000_000 ? 0 : 1)}M`
  if (num >= 1_000) return `TZS ${Math.round(num / 1_000)}K`
  return `TZS ${num.toLocaleString()}`
}

function scrollToExplore() {
  document.getElementById('property-explore')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

onMounted(() => {
  load()
  loadMine()
})

onBeforeUnmount(() => {
  if (propMap) {
    propMap.remove()
    propMap = null
  }
  markers = []
})
</script>

<template>
  <AppHeader title="Enkiama Property" subtitle="Land & property">
    <button v-if="session && myListings.length" class="btn btn-ghost" type="button" @click="showMine = !showMine">
      <Icon name="inbox" :size="15" /> My listings <span class="tb-count">{{ myListings.length }}</span>
    </button>
    <button v-if="session" class="btn btn-accent" type="button" @click="showForm = true">
      <Icon name="plus" :size="15" /> List a property
    </button>
    <RouterLink v-else to="/join/business" class="btn btn-accent">List a property</RouterLink>
  </AppHeader>

  <main class="prop-page">
    <!-- 01 / PLACE — an editorial entrance, not a property-card wall -->
    <section class="prop-stage">
      <div class="prop-stage-top">
        <div class="prop-stage-index"><span>01</span><span>Place / Tanzania</span></div>
        <div class="prop-stage-status"><span class="prop-live-dot"></span> Reviewed listings</div>
      </div>

      <div class="prop-stage-grid">
        <div class="prop-stage-copy">
          <div class="prop-kicker">LAND · HOME · FARM · RENTAL</div>
          <h1>Land &amp; property,<br><em>seen in context.</em></h1>
          <p>Explore place, access, services, ownership declarations and terms before you decide what deserves a closer look.</p>
          <div class="prop-stage-actions">
            <button type="button" class="prop-text-action" @click="scrollToExplore">Explore listings <Icon name="arrow" :size="15" /></button>
            <button type="button" class="prop-text-action quiet" @click="setMapView(); scrollToExplore()">Open map <Icon name="pin" :size="15" /></button>
          </div>
        </div>

        <RouterLink v-if="featured" :to="`/property/${featured.id}`" class="prop-feature" data-cursor="Place">
          <div class="prop-feature-media" :style="featured.images?.[0] ? {backgroundImage:`url(${featured.images[0]})`} : {}">
            <div v-if="!featured.images?.[0]" class="prop-feature-ph"><Icon name="pin" :size="38" /></div>
            <span class="prop-feature-count">Featured / 01</span>
            <span class="prop-feature-open">View place ↗</span>
          </div>
          <div class="prop-feature-meta">
            <div>
              <span class="prop-feature-type">{{ kindLabel(featured.kind) }} · {{ featured.region || 'Tanzania' }}</span>
              <h2>{{ featured.title }}</h2>
            </div>
            <div class="prop-feature-price">{{ fmtPrice(featured) }}</div>
          </div>
        </RouterLink>

        <div v-else-if="loading" class="prop-feature prop-feature-loading">
          <div class="prop-feature-media"></div>
          <div class="prop-feature-meta"><div><span>Loading collection</span><h2>Finding verified places…</h2></div></div>
        </div>
      </div>

      <div class="prop-stage-foot">
        <div class="prop-stage-fact"><span>01</span><b>Listing review</b><small>Reviewed before publication.</small></div>
        <div class="prop-stage-fact"><span>02</span><b>Place clarity</b><small>Location, size, utilities and context.</small></div>
        <div class="prop-stage-fact"><span>03</span><b>Buyer control</b><small>Final legal due diligence remains yours.</small></div>
      </div>
    </section>

    <div class="wrap prop-wrap">
      <!-- seller's own listings remain operational, but quieter -->
      <section v-if="showMine && myListings.length" class="mine-panel">
        <div class="mine-head">
          <div><span>Seller workspace</span><h3>My listings</h3></div>
          <button class="mine-close" type="button" aria-label="Close my listings" @click="showMine=false"><Icon name="plus" :size="16" style="transform:rotate(45deg)" /></button>
        </div>
        <div v-for="m in myListings" :key="m.id" class="mine-row">
          <div class="mine-thumb" :style="m.images?.[0] ? {backgroundImage:`url(${m.images[0]})`} : {}"><Icon v-if="!m.images?.[0]" name="pin" :size="16" /></div>
          <div class="mine-info"><b>{{ m.title }}</b><span>{{ m.location }} · {{ fmtPrice(m) }}</span></div>
          <span class="mine-status" :class="'st-'+m.status">
            <template v-if="m.status==='verified'"><Icon name="check" :size="11" /> Live</template>
            <template v-else-if="m.status==='pending'"><Icon name="clock" :size="11" /> Under review</template>
            <template v-else><Icon name="alert" :size="11" /> Rejected</template>
          </span>
          <button class="mine-withdraw" type="button" @click="withdraw(m.id)">Withdraw</button>
        </div>
        <p v-if="myListings.some(m => m.status==='rejected' && m.admin_note)" class="mine-note">Rejected listings include a reason — check with support to resolve and resubmit.</p>
      </section>

      <!-- 02 / EXPLORE — expressive choice, then quiet utility -->
      <section id="property-explore" class="prop-explore">
        <div class="prop-section-head">
          <div class="prop-section-index"><span>02</span><span>Explore</span></div>
          <div class="prop-section-summary">
            <span>{{ collectionLabel }}</span>
            <strong>{{ loading ? '—' : listingCount }}</strong>
            <small>{{ listingCount === 1 ? 'place' : 'places' }}</small>
          </div>
        </div>

        <div class="prop-kind-nav" aria-label="Property type">
          <button type="button" class="prop-kind" :class="{on:!activeKind}" @click="setKind('')"><span>All</span><small>00</small></button>
          <button v-for="(k,i) in KINDS" :key="k.k" type="button" class="prop-kind" :class="{on:activeKind===k.k}" @click="setKind(k.k)">
            <span>{{ k.label }}</span><small>0{{ i + 1 }}</small>
          </button>
        </div>

        <div class="prop-viewbar">
          <div class="prop-viewbar-copy">
            <span>{{ propView === 'map' ? 'Spatial view' : 'Collection view' }}</span>
            <small>{{ propView === 'map' ? 'Browse by geography. Pin precision is controlled by the listing data.' : 'Browse places as an editorial collection.' }}</small>
          </div>
          <div class="prop-viewtoggle" role="group" aria-label="Property view">
            <button type="button" class="prop-vt" :class="{on:propView==='list'}" @click="setListView"><Icon name="menu" :size="14" /> Collection</button>
            <button type="button" class="prop-vt" :class="{on:propView==='map'}" @click="setMapView"><Icon name="pin" :size="14" /> Map</button>
          </div>
        </div>

        <!-- MAP / geography becomes an environment, not a utility box -->
        <div v-show="propView==='map'" v-reveal class="prop-map-shell">
          <div class="prop-map-label"><span>TANZANIA</span><small>Property geography</small></div>
          <div id="propmap" class="prop-map"></div>
          <div class="prop-map-key"><span><i></i> Select a price marker to inspect a place</span></div>

          <transition name="prop-panel">
            <aside v-if="selectedPin" class="prop-mapcard">
              <button class="prop-mapcard-x" type="button" aria-label="Close property preview" @click="selectedPin=null"><Icon name="plus" :size="16" style="transform:rotate(45deg)" /></button>
              <div class="prop-mapcard-index">Place / {{ kindLabel(selectedPin.kind) }}</div>
              <div class="prop-mapcard-title">{{ selectedPin.title }}</div>
              <div class="prop-mapcard-loc"><Icon name="pin" :size="12" /> {{ selectedPin.location || selectedPin.region }}<span v-if="!selectedPin.exact">Approximate location</span></div>
              <div class="prop-mapcard-price">{{ fmtPrice(selectedPin) }}</div>
              <div class="prop-mapcard-trust"><Icon name="shield" :size="13" /> Reviewed listing</div>
              <RouterLink :to="`/property/${selectedPin.id}`" class="prop-mapcard-link" data-cursor="Place">Enter this place <Icon name="arrow" :size="15" /></RouterLink>
            </aside>
          </transition>
        </div>

        <!-- COLLECTION / large place objects rather than commodity cards -->
        <div v-show="propView==='list'" class="prop-collection">
          <div v-if="loading" class="prop-loading-list">
            <div v-for="i in 4" :key="i" class="prop-object prop-object-sk"><div class="prop-object-media"></div><div class="prop-object-copy"></div></div>
          </div>

          <EmptyState v-else-if="!listings.length" icon="pin" title="No verified listings yet" hint="Verified plots, farms, houses and rentals will appear here after review." />

          <div v-else class="prop-object-list">
            <RouterLink v-for="(l,i) in listings" :key="l.id" :to="`/property/${l.id}`" class="prop-object" :class="{reverse:i%2===1}" data-cursor="Place" v-reveal="{delay:Math.min(i*35,175)}">
              <div class="prop-object-media" :style="Object.assign({}, l.images?.[0] ? {backgroundImage:`url(${l.images[0]})`} : {}, {viewTransitionName:viewName('property', l.id)})">
                <span v-if="!l.images?.[0]" class="prop-object-ph"><Icon name="pin" :size="32" /></span>
                <span class="prop-object-index">{{ String(i + 1).padStart(2,'0') }} / {{ String(listings.length).padStart(2,'0') }}</span>
                <span class="prop-object-view">Enter ↗</span>
              </div>

              <div class="prop-object-copy">
                <div class="prop-object-top"><span>{{ kindLabel(l.kind) }}</span><span>{{ l.region || 'Tanzania' }}</span></div>
                <h3>{{ l.title }}</h3>
                <div class="prop-object-loc"><Icon name="pin" :size="13" /> {{ l.location || l.region }}</div>

                <div class="prop-object-facts">
                  <div v-if="fmtSize(l)"><span>Size</span><b>{{ fmtSize(l) }}</b></div>
                  <div><span>Utilities</span><b>{{ l.has_electricity && l.has_water ? 'Power + water' : l.has_electricity ? 'Power' : l.has_water ? 'Water' : 'Ask seller' }}</b></div>
                  <div><span>Review</span><b>{{ l.fair_price_ok ? 'Price reviewed' : 'Listing reviewed' }}</b></div>
                </div>

                <div class="prop-object-foot">
                  <div class="prop-object-price">{{ fmtPrice(l) }}</div>
                  <div class="prop-object-trust"><Icon name="shield" :size="13" /> Verified listing</div>
                </div>
              </div>
            </RouterLink>
          </div>
        </div>
      </section>

      <!-- 03 / TRUST — what the badge actually means -->
      <section class="prop-trust">
        <div class="prop-section-index"><span>03</span><span>Verification</span></div>
        <div class="prop-trust-grid">
          <div class="prop-trust-title">
            <h2>A checkpoint,<br>not a shortcut.</h2>
            <p>Enkiama review improves listing quality and transparency. It does not replace independent legal verification before a property transaction.</p>
          </div>
          <div class="prop-trust-ledger">
            <div><span>01</span><b>Before publication</b><p>Listing information is reviewed before it appears in this collection.</p></div>
            <div><span>02</span><b>Ownership clarity</b><p>The listing states whether it is submitted by the owner or a representative and records an ownership declaration.</p></div>
            <div><span>03</span><b>Before purchase</b><p>Verify title, identity, boundaries and legal ownership independently before completing a sale.</p></div>
          </div>
        </div>
      </section>
    </div>
  </main>

  <PropertyForm v-if="showForm" @close="showForm=false" @submitted="showForm=false; toast('Submitted for review — we\'ll verify it shortly','ok'); loadMine()" />
</template>

<style scoped>
.prop-page{background:var(--surface);color:var(--ink);overflow:hidden}
.prop-stage{background:#0d1514;color:#f5f3ed;padding:30px max(24px,calc((100vw - 1240px)/2)) 34px;min-height:720px;display:flex;flex-direction:column;justify-content:space-between;position:relative}
.prop-stage::before{content:"";position:absolute;inset:-15% -10% auto auto;width:520px;height:520px;border-radius:50%;background:radial-gradient(circle,rgba(98,139,105,.20),rgba(13,21,20,0) 68%);pointer-events:none}
.prop-stage-top{display:flex;align-items:center;justify-content:space-between;gap:20px;position:relative;z-index:1}
.prop-stage-index,.prop-section-index{display:flex;align-items:center;gap:12px;font-size:11px;letter-spacing:.12em;text-transform:uppercase}
.prop-stage-index span:first-child,.prop-section-index span:first-child{font-family:'Space Grotesk',sans-serif;font-weight:700}
.prop-stage-index span:last-child{color:rgba(245,243,237,.55)}
.prop-stage-status{display:flex;align-items:center;gap:8px;font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:rgba(245,243,237,.62)}
.prop-live-dot{width:6px;height:6px;border-radius:50%;background:#8fbf98;box-shadow:0 0 0 5px rgba(143,191,152,.08)}
.prop-stage-grid{display:grid;grid-template-columns:minmax(0,.82fr) minmax(420px,1.18fr);gap:7vw;align-items:center;position:relative;z-index:1;padding:48px 0 54px}
.prop-kicker{font-size:10.5px;letter-spacing:.18em;color:rgba(245,243,237,.48);margin-bottom:18px}
.prop-stage-copy h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(48px,6vw,86px);font-weight:540;line-height:.94;letter-spacing:-.055em;margin:0;max-width:700px}
.prop-stage-copy h1 em{font-family:Georgia,'Times New Roman',serif;font-weight:400;color:#b8c9b6}
.prop-stage-copy p{max-width:510px;font-size:15px;line-height:1.7;color:rgba(245,243,237,.62);margin:26px 0 0}
.prop-stage-actions{display:flex;align-items:center;gap:26px;margin-top:30px}
.prop-text-action{display:inline-flex;align-items:center;gap:10px;border:0;background:transparent;color:#fff;font:inherit;font-size:13px;font-weight:650;padding:0 0 7px;border-bottom:1px solid rgba(255,255,255,.42);cursor:pointer}
.prop-text-action.quiet{color:rgba(245,243,237,.62);border-bottom-color:rgba(255,255,255,.16)}
.prop-feature{text-decoration:none;color:inherit;display:block;min-width:0}
.prop-feature-media{height:430px;background:#172220 center/cover no-repeat;position:relative;overflow:hidden}
.prop-feature-media::after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(0,0,0,.02),rgba(0,0,0,.32));transition:opacity .4s ease}
.prop-feature:hover .prop-feature-media::after{opacity:.65}
.prop-feature-ph{height:100%;display:flex;align-items:center;justify-content:center;color:rgba(255,255,255,.3)}
.prop-feature-count,.prop-feature-open{position:absolute;z-index:2;top:18px;font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:rgba(255,255,255,.82)}
.prop-feature-count{left:18px}.prop-feature-open{right:18px;transform:translateY(-4px);opacity:0;transition:.3s ease}
.prop-feature:hover .prop-feature-open{transform:none;opacity:1}
.prop-feature-meta{display:flex;justify-content:space-between;align-items:flex-end;gap:24px;padding-top:15px}
.prop-feature-type{display:block;font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:rgba(245,243,237,.46);margin-bottom:6px}
.prop-feature-meta h2{font-family:'Space Grotesk',sans-serif;font-size:20px;font-weight:600;letter-spacing:-.02em;margin:0;max-width:440px}
.prop-feature-price{font-family:'Space Grotesk',sans-serif;font-size:13px;color:rgba(245,243,237,.78);white-space:nowrap}
.prop-feature-loading{opacity:.55}.prop-feature-loading .prop-feature-media{animation:propPulse 1.3s ease-in-out infinite alternate}.prop-feature-loading h2{font-size:16px;color:rgba(255,255,255,.55)}
@keyframes propPulse{from{opacity:.45}to{opacity:.8}}
.prop-stage-foot{display:grid;grid-template-columns:repeat(3,1fr);border-top:1px solid rgba(255,255,255,.12);position:relative;z-index:1}
.prop-stage-fact{padding:18px 24px 0 0;display:grid;grid-template-columns:32px 1fr;gap:2px 8px}
.prop-stage-fact+ .prop-stage-fact{border-left:1px solid rgba(255,255,255,.1);padding-left:24px}
.prop-stage-fact>span{grid-row:1/3;font-family:'Space Grotesk',sans-serif;font-size:10px;color:rgba(255,255,255,.28);padding-top:2px}
.prop-stage-fact b{font-size:12px;font-weight:650;color:rgba(255,255,255,.86)}
.prop-stage-fact small{font-size:11px;color:rgba(255,255,255,.4);line-height:1.45}

.prop-wrap{max-width:1240px;padding-top:72px;padding-bottom:90px}
.mine-panel{border-top:1px solid var(--hairline-2);border-bottom:1px solid var(--hairline-2);padding:24px 0;margin-bottom:70px}
.mine-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:18px}.mine-head span{display:block;font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:var(--ink-faint);margin-bottom:3px}.mine-head h3{font-family:'Space Grotesk',sans-serif;font-size:20px;margin:0}.mine-close{border:0;background:none;color:var(--ink-faint);cursor:pointer;padding:7px}
.mine-row{display:grid;grid-template-columns:58px minmax(0,1fr) auto auto;align-items:center;gap:14px;padding:10px 0;border-top:1px solid var(--hairline)}
.mine-thumb{width:58px;height:44px;background:var(--surface-3) center/cover no-repeat;display:flex;align-items:center;justify-content:center;color:var(--ink-ghost)}
.mine-info{min-width:0}.mine-info b{display:block;font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.mine-info span{display:block;font-size:11.5px;color:var(--ink-faint);margin-top:2px}
.mine-status{display:inline-flex;align-items:center;gap:4px;font-size:11px;font-weight:650}.st-verified{color:var(--go-ink)}.st-pending{color:var(--warn-ink)}.st-rejected{color:var(--owed-ink)}
.mine-withdraw{border:0;background:none;color:var(--ink-faint);font:inherit;font-size:11px;text-decoration:underline;cursor:pointer}.mine-note{font-size:11.5px;color:var(--ink-faint);margin:10px 0 0}

.prop-explore{scroll-margin-top:90px}
.prop-section-head{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;border-bottom:1px solid var(--hairline-2);padding-bottom:18px}
.prop-section-index{color:var(--ink-faint)}
.prop-section-summary{display:flex;align-items:baseline;gap:7px;color:var(--ink-faint);font-size:11px}.prop-section-summary>span{text-transform:uppercase;letter-spacing:.08em}.prop-section-summary strong{font-family:'Space Grotesk',sans-serif;font-size:18px;color:var(--ink);font-weight:650}.prop-section-summary small{font-size:11px}
.prop-kind-nav{display:grid;grid-template-columns:repeat(5,1fr);border-bottom:1px solid var(--hairline-2)}
.prop-kind{position:relative;display:flex;justify-content:space-between;align-items:flex-end;min-height:102px;padding:22px 18px 18px;border:0;border-right:1px solid var(--hairline);background:transparent;color:var(--ink-faint);font:inherit;cursor:pointer;text-align:left;transition:background .2s,color .2s}
.prop-kind:first-child{padding-left:0}.prop-kind:last-child{border-right:0}.prop-kind span{font-family:'Space Grotesk',sans-serif;font-size:16px;font-weight:560;letter-spacing:-.02em}.prop-kind small{font-size:9px;letter-spacing:.1em}.prop-kind.on{color:var(--ink)}.prop-kind.on::after{content:"";position:absolute;left:0;right:18px;bottom:-1px;height:2px;background:var(--ink)}.prop-kind:hover{background:var(--surface-2)}
.prop-viewbar{display:flex;justify-content:space-between;align-items:center;gap:20px;padding:20px 0 22px}
.prop-viewbar-copy>span{display:block;font-size:12px;font-weight:650}.prop-viewbar-copy small{display:block;font-size:11px;color:var(--ink-faint);margin-top:2px;max-width:600px}
.prop-viewtoggle{display:flex;gap:4px}.prop-vt{display:inline-flex;align-items:center;gap:7px;border:0;background:transparent;color:var(--ink-faint);font:inherit;font-size:11.5px;font-weight:650;padding:8px 11px;cursor:pointer}.prop-vt.on{background:var(--ink);color:#fff}

.prop-collection{min-height:360px}
.prop-object-list{border-top:1px solid var(--hairline-2)}
.prop-object{display:grid;grid-template-columns:minmax(0,1.12fr) minmax(330px,.88fr);gap:5vw;align-items:center;padding:56px 0;border-bottom:1px solid var(--hairline-2);text-decoration:none;color:inherit}
.prop-object.reverse .prop-object-media{order:2}.prop-object.reverse .prop-object-copy{order:1}
.prop-object-media{height:390px;background:var(--surface-3) center/cover no-repeat;position:relative;overflow:hidden}
.prop-object-media::after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,transparent 55%,rgba(7,15,14,.34));transition:.35s ease}.prop-object:hover .prop-object-media::after{background:linear-gradient(180deg,rgba(7,15,14,.04),rgba(7,15,14,.44))}
.prop-object-ph{height:100%;display:flex;align-items:center;justify-content:center;color:var(--ink-ghost)}
.prop-object-index,.prop-object-view{position:absolute;z-index:2;color:#fff;font-size:9.5px;letter-spacing:.1em;text-transform:uppercase;bottom:16px}.prop-object-index{left:16px}.prop-object-view{right:16px;opacity:0;transform:translateX(-6px);transition:.3s}.prop-object:hover .prop-object-view{opacity:1;transform:none}
.prop-object-top{display:flex;justify-content:space-between;gap:20px;font-size:9.5px;letter-spacing:.1em;text-transform:uppercase;color:var(--ink-faint);padding-bottom:14px;border-bottom:1px solid var(--hairline)}
.prop-object-copy h3{font-family:'Space Grotesk',sans-serif;font-size:clamp(30px,3.6vw,52px);font-weight:540;line-height:1.02;letter-spacing:-.045em;margin:22px 0 12px}
.prop-object-loc{display:flex;align-items:center;gap:6px;font-size:12px;color:var(--ink-faint)}
.prop-object-facts{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-top:34px}.prop-object-facts>div{padding-top:11px;border-top:1px solid var(--hairline)}.prop-object-facts span{display:block;font-size:9.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-faint)}.prop-object-facts b{display:block;font-size:12px;font-weight:600;margin-top:5px;color:var(--ink-soft)}
.prop-object-foot{display:flex;justify-content:space-between;align-items:flex-end;gap:20px;margin-top:38px}.prop-object-price{font-family:'Space Grotesk',sans-serif;font-size:18px;font-weight:650;letter-spacing:-.02em}.prop-object-trust{display:flex;align-items:center;gap:6px;font-size:10.5px;color:var(--go-ink)}
.prop-loading-list{border-top:1px solid var(--hairline-2)}.prop-object-sk{pointer-events:none}.prop-object-sk .prop-object-media,.prop-object-sk .prop-object-copy{background:linear-gradient(90deg,var(--surface-2),var(--surface-3),var(--surface-2));background-size:220% 100%;animation:propShimmer 1.4s linear infinite}.prop-object-sk .prop-object-copy{height:230px}
@keyframes propShimmer{to{background-position:-220% 0}}

.prop-map-shell{height:min(72vh,720px);min-height:560px;position:relative;background:#e8ebe5;overflow:hidden}
.prop-map{position:absolute;inset:0;z-index:1}.prop-map-label{position:absolute;z-index:450;left:20px;top:18px;background:rgba(255,255,255,.88);backdrop-filter:blur(12px);padding:11px 14px}.prop-map-label span{display:block;font-family:'Space Grotesk',sans-serif;font-size:13px;font-weight:700;letter-spacing:.08em}.prop-map-label small{display:block;font-size:9.5px;color:var(--ink-faint);margin-top:2px}
.prop-map-key{position:absolute;z-index:450;left:20px;bottom:18px;background:rgba(13,21,20,.87);color:#fff;padding:9px 12px;font-size:10px;backdrop-filter:blur(10px)}.prop-map-key span{display:flex;align-items:center;gap:7px}.prop-map-key i{display:block;width:5px;height:5px;border-radius:50%;background:#b7c8b5}
.prop-mapcard{position:absolute;z-index:500;right:18px;bottom:18px;width:min(360px,calc(100% - 36px));background:rgba(255,255,255,.94);backdrop-filter:blur(18px);padding:24px;box-shadow:0 20px 60px rgba(23,30,28,.18)}
.prop-mapcard-x{position:absolute;right:12px;top:12px;border:0;background:transparent;color:var(--ink-faint);cursor:pointer}.prop-mapcard-index{font-size:9.5px;letter-spacing:.11em;text-transform:uppercase;color:var(--ink-faint);padding-right:28px}.prop-mapcard-title{font-family:'Space Grotesk',sans-serif;font-size:24px;font-weight:600;line-height:1.05;letter-spacing:-.035em;margin:14px 0 8px}.prop-mapcard-loc{display:flex;align-items:center;gap:5px;font-size:11.5px;color:var(--ink-faint);flex-wrap:wrap}.prop-mapcard-loc span{padding-left:7px;margin-left:2px;border-left:1px solid var(--hairline-2);font-size:9.5px;text-transform:uppercase;letter-spacing:.05em}.prop-mapcard-price{font-family:'Space Grotesk',sans-serif;font-size:16px;font-weight:650;margin-top:22px}.prop-mapcard-trust{display:flex;align-items:center;gap:6px;font-size:10.5px;color:var(--go-ink);margin-top:6px}.prop-mapcard-link{display:flex;align-items:center;justify-content:space-between;color:var(--ink);text-decoration:none;font-size:12px;font-weight:700;border-top:1px solid var(--hairline-2);padding-top:14px;margin-top:18px}.prop-panel-enter-active,.prop-panel-leave-active{transition:.28s ease}.prop-panel-enter-from,.prop-panel-leave-to{opacity:0;transform:translateY(10px)}
:deep(.prop-pin){background:transparent!important;border:0!important}:deep(.prop-pin-badge){position:relative;transform:translate(-50%,-100%);white-space:nowrap;background:#0d1514;color:#fff;border:1px solid rgba(255,255,255,.4);box-shadow:0 7px 20px rgba(0,0,0,.18);padding:7px 9px;font-family:'Space Grotesk',sans-serif;font-size:10px;font-weight:650}:deep(.prop-pin-badge::after){content:"";position:absolute;left:50%;bottom:-5px;width:8px;height:8px;background:#0d1514;transform:translateX(-50%) rotate(45deg)}:deep(.leaflet-control-zoom){border:0!important;box-shadow:0 8px 24px rgba(0,0,0,.12)!important}:deep(.leaflet-control-zoom a){border:0!important;color:#0d1514!important}

.prop-trust{padding:100px 0 10px}.prop-trust>.prop-section-index{padding-bottom:18px;border-bottom:1px solid var(--hairline-2)}.prop-trust-grid{display:grid;grid-template-columns:.8fr 1.2fr;gap:9vw;padding-top:40px}.prop-trust-title h2{font-family:'Space Grotesk',sans-serif;font-size:clamp(38px,5vw,64px);font-weight:540;line-height:.98;letter-spacing:-.05em;margin:0}.prop-trust-title p{font-size:13px;line-height:1.7;color:var(--ink-faint);max-width:430px;margin:20px 0 0}.prop-trust-ledger{border-top:1px solid var(--hairline-2)}.prop-trust-ledger>div{display:grid;grid-template-columns:46px 180px 1fr;gap:18px;padding:20px 0;border-bottom:1px solid var(--hairline)}.prop-trust-ledger span{font-size:9.5px;letter-spacing:.1em;color:var(--ink-faint)}.prop-trust-ledger b{font-size:12.5px}.prop-trust-ledger p{font-size:12px;line-height:1.55;color:var(--ink-faint);margin:0}

@media(max-width:960px){
  .prop-stage{min-height:auto;padding-top:26px}.prop-stage-grid{grid-template-columns:1fr;gap:44px;padding:50px 0}.prop-feature{max-width:720px}.prop-stage-foot{margin-top:14px}
  .prop-kind-nav{grid-template-columns:repeat(5,minmax(120px,1fr));overflow-x:auto}.prop-kind{min-width:130px}
  .prop-object{grid-template-columns:1fr;gap:24px}.prop-object.reverse .prop-object-media,.prop-object.reverse .prop-object-copy{order:initial}.prop-object-copy{max-width:720px}.prop-object-media{height:min(58vw,460px)}
  .prop-trust-grid{grid-template-columns:1fr;gap:40px}.prop-trust-ledger>div{grid-template-columns:40px 170px 1fr}
}
@media(max-width:680px){
  .prop-stage{padding-left:18px;padding-right:18px}.prop-stage-top{align-items:flex-start}.prop-stage-status{font-size:9px}.prop-stage-copy h1{font-size:48px}.prop-stage-copy p{font-size:13px}.prop-stage-actions{gap:18px;flex-wrap:wrap}.prop-feature-media{height:58vw;min-height:260px}.prop-feature-meta{align-items:flex-start;flex-direction:column;gap:8px}
  .prop-stage-foot{grid-template-columns:1fr}.prop-stage-fact,.prop-stage-fact+ .prop-stage-fact{border-left:0;border-top:1px solid rgba(255,255,255,.08);padding:12px 0}.prop-stage-fact:first-child{border-top:0}
  .prop-wrap{padding:52px 16px 64px}.mine-row{grid-template-columns:48px minmax(0,1fr) auto}.mine-thumb{width:48px}.mine-withdraw{grid-column:2;text-align:left;padding:0}.mine-status{grid-column:3;grid-row:1/3}
  .prop-section-head{align-items:flex-start}.prop-section-summary>span{display:none}.prop-kind-nav{margin-left:-16px;margin-right:-16px;padding-left:16px}.prop-kind:first-child{padding-left:12px}.prop-viewbar{align-items:flex-start;flex-direction:column}.prop-viewtoggle{width:100%}.prop-vt{flex:1;justify-content:center;border:1px solid var(--hairline)}.prop-vt+.prop-vt{margin-left:-1px}
  .prop-object{padding:38px 0}.prop-object-media{height:66vw;min-height:260px}.prop-object-copy h3{font-size:34px}.prop-object-facts{grid-template-columns:1fr 1fr}.prop-object-facts>div:last-child{display:none}.prop-object-foot{align-items:flex-start;flex-direction:column;gap:8px;margin-top:28px}
  .prop-map-shell{height:68vh;min-height:520px;margin-left:-16px;margin-right:-16px}.prop-map-label{left:12px;top:12px}.prop-map-key{left:12px;bottom:12px;max-width:calc(100% - 24px)}.prop-mapcard{right:12px;bottom:12px;width:calc(100% - 24px)}
  .prop-trust{padding-top:72px}.prop-trust-title h2{font-size:42px}.prop-trust-ledger>div{grid-template-columns:30px 1fr;gap:7px 12px}.prop-trust-ledger p{grid-column:2}.prop-trust-ledger b{font-size:12px}
}
@media(prefers-reduced-motion:reduce){.prop-feature-open,.prop-object-view,.prop-panel-enter-active,.prop-panel-leave-active{transition:none!important}.prop-feature-loading .prop-feature-media,.prop-object-sk .prop-object-media,.prop-object-sk .prop-object-copy{animation:none!important}}

/* PHASE 9 — PLACE DISCOVERY / geography first on small screens */
@media(max-width:680px){
  .prop-kind-nav{scroll-snap-type:x proximity;scrollbar-width:none;overscroll-behavior-inline:contain}.prop-kind-nav::-webkit-scrollbar{display:none}.prop-kind{scroll-snap-align:start;min-height:48px}
  .prop-viewbar{position:sticky;top:calc(58px + env(safe-area-inset-top));z-index:420;background:rgba(255,255,255,.9);backdrop-filter:blur(16px);margin-left:-16px;margin-right:-16px;padding:10px 16px;border-bottom:1px solid var(--hairline)}
  .prop-vt{min-height:44px}
  .prop-object-media{margin-left:-16px;margin-right:-16px;height:min(74svh,470px)}
  .prop-object-view{opacity:1;transform:none}
  .prop-map-shell{height:calc(100svh - 118px);min-height:540px}
  .prop-mapcard{bottom:calc(12px + env(safe-area-inset-bottom));max-height:46%;overflow:auto;overscroll-behavior:contain;padding:20px}
  .prop-map-key{bottom:calc(12px + env(safe-area-inset-bottom))}
}
@media(max-width:420px){
  .prop-stage{padding-left:14px;padding-right:14px}.prop-stage-copy h1{font-size:43px}
  .prop-wrap{padding-left:14px;padding-right:14px}.prop-kind-nav{margin-left:-14px;margin-right:-14px;padding-left:14px}
  .prop-viewbar{margin-left:-14px;margin-right:-14px;padding-left:14px;padding-right:14px}
  .prop-object-media{margin-left:-14px;margin-right:-14px}.prop-object-copy h3{font-size:31px}
  .prop-object-facts{gap:8px}.prop-object-price{font-size:17px}
  .prop-map-shell{margin-left:-14px;margin-right:-14px}
}
</style>
