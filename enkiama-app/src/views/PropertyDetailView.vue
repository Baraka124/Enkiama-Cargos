<script setup>
// ENKIAMA MARKET V15 — Property / Geographic World. Place → Ground → Verification → Terms.
// Existing contracts remain unchanged: property_detail, property_map, start_property_deal.
import { ref, computed, onMounted, onBeforeUnmount, nextTick, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import AppHeader from '../components/AppHeader.vue'
import SiteFooter from '../components/SiteFooter.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import MediaFrame from '../components/MediaFrame.vue'
import ExperienceState from '../components/ExperienceState.vue'
import { loadLeaflet } from '../lib/leaflet'
import { viewName, signalMotionReady } from '../lib/motion'
import { formatNumber, formatTZS, finiteNumber } from '../lib/format'

const route = useRoute()
const router = useRouter()

const listing = ref(null)
const loading = ref(true)
const loadError = ref('')
const activeImg = ref(0)
const galleryOpen = ref(false)
const showContact = ref(false)
const locationPin = ref(null)

let Leaflet = null
let detailMap = null
let detailMarker = null
let approxCircle = null

const imgs = computed(() => (listing.value?.images || []).filter(Boolean))
const kindLabel = computed(() => ({
  plot: 'Land plot',
  farm: 'Farm',
  house: 'House / building',
  rental: 'Rental',
}[listing.value?.kind] || listing.value?.kind || 'Property'))
const basisLabel = computed(() => ({
  total: 'Total price',
  per_acre: 'Per acre',
  per_month: 'Per month',
  per_sqm: 'Per m²',
}[listing.value?.price_basis] || 'Total price'))
const placeLabel = computed(() => [listing.value?.location, listing.value?.region].filter(Boolean).join(', ') || 'Tanzania')
const ownerContext = computed(() => listing.value?.lister_role === 'representative'
  ? 'Representative on behalf of owner'
  : 'Listed by owner')
const utilityLabel = computed(() => {
  const l = listing.value
  if (!l) return 'Ask seller'
  if (l.has_electricity && l.has_water) return l.water_potable ? 'Power + potable water' : 'Power + water'
  if (l.has_electricity) return 'Electricity available'
  if (l.has_water) return l.water_potable ? 'Potable water' : 'Water available'
  return 'Utilities not declared'
})

function fmtPrice(l) {
  if (!l?.price_tzs) return 'Price on request'
  const basis = l.price_basis === 'per_acre'
    ? ' / acre'
    : l.price_basis === 'per_month'
      ? ' / month'
      : l.price_basis === 'per_sqm'
        ? ' / m²'
        : ''
  return 'TZS ' + formatNumber(l.price_tzs) + basis
}

function tzs(n) {
  return n || n === 0 ? formatTZS(n, { fallback: '' }) : ''
}

const depositAmount = computed(() => {
  const l = listing.value
  const price = finiteNumber(l?.price_tzs), pct = finiteNumber(l?.deposit_pct)
  if (!l?.installments_ok || price === null || pct === null || pct <= 0) return 0
  return Math.max(0, Math.round(price * pct / 100))
})

const monthlyAmount = computed(() => {
  const l = listing.value
  const price = finiteNumber(l?.price_tzs), months = finiteNumber(l?.installment_months)
  if (!l?.installments_ok || price === null || months === null || months <= 0) return 0
  return Math.max(0, Math.round((price - depositAmount.value) / months))
})

async function load() {
  loading.value = true
  loadError.value = ''
  listing.value = null
  activeImg.value = 0
  galleryOpen.value = false
  showContact.value = false
  locationPin.value = null
  destroyMap()

  try {
    const { data, error } = await supabase.rpc('property_detail', { p_id: route.params.id })
    if (error) throw error
    listing.value = data || null
    if (listing.value) await loadLocationPin()
  } catch (e) {
    listing.value = null
    loadError.value = 'The place record could not be loaded right now.'
  }

  loading.value = false
  await nextTick()
  signalMotionReady()
  if (listing.value && locationPin.value) await renderContextMap()
}

async function loadLocationPin() {
  try {
    const { data } = await supabase.rpc('property_map', {
      p_kind: listing.value?.kind || null,
      p_region: listing.value?.region || null,
      p_max_price: null,
    })
    locationPin.value = (data || []).find(p => String(p.id) === String(listing.value?.id)) || null
  } catch (e) {
    locationPin.value = null
  }
}

async function renderContextMap() {
  try { Leaflet ||= await loadLeaflet() } catch (e) { return }
  const p = locationPin.value
  const lat = finiteNumber(p?.lat), lng = finiteNumber(p?.lng)
  if (lat === null || lng === null || Math.abs(lat) > 90 || Math.abs(lng) > 180 || !document.getElementById('property-context-map')) return
  destroyMap()

  detailMap = Leaflet.map('property-context-map', {
    zoomControl: true,
    attributionControl: false,
    scrollWheelZoom: false,
    zoomSnap: 0.5,
  }).setView([lat, lng], p.exact ? 13 : 11)

  Leaflet.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '&copy; OpenStreetMap contributors' }).addTo(detailMap)

  const icon = Leaflet.divIcon({
    className: 'pd-map-pin',
    html: '<div class="pd-map-pin-dot"><span></span></div>',
    iconSize: [1, 1],
  })
  detailMarker = Leaflet.marker([lat, lng], { icon }).addTo(detailMap)

  if (!p.exact) {
    approxCircle = Leaflet.circle([lat, lng], {
      radius: 2500,
      color: '#536d5b',
      weight: 1,
      fillColor: '#7a967f',
      fillOpacity: 0.12,
    }).addTo(detailMap)
  }

  setTimeout(() => detailMap?.invalidateSize(), 100)
}

function destroyMap() {
  if (detailMap) {
    detailMap.remove()
    detailMap = null
  }
  detailMarker = null
  approxCircle = null
}

function nextImage(dir = 1) {
  if (imgs.value.length < 2) return
  activeImg.value = (activeImg.value + dir + imgs.value.length) % imgs.value.length
}

function scrollToContext() {
  document.getElementById('pd-context')?.scrollIntoView({ behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' })
}
function scrollToTerms() {
  document.getElementById('pd-terms')?.scrollIntoView({ behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' })
}

async function startDeal() {
  try {
    const { data: sess } = await supabase.auth.getSession()
    if (!sess?.session) {
      router.push('/login')
      return
    }
    const name = sess.session.user?.user_metadata?.name || ''
    const { data: res } = await supabase.rpc('start_property_deal', {
      p_listing_id: listing.value.id,
      p_buyer_name: name,
      p_buyer_phone: '',
      p_note: null,
    })
    if (res?.ok) router.push(`/property-deal/${res.id}`)
  } catch (e) {}
}

onMounted(load)
onBeforeUnmount(destroyMap)
watch(() => route.params.id, (next, prev) => {
  if (next && next !== prev) {
    window.scrollTo({ top: 0, behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
    load()
  }
})
</script>

<template>
  <AppHeader title="Property" subtitle="Place" />

  <main class="pd-page">
    <ExperienceState v-if="loading" kind="loading" :world="'place'" eyebrow="Place" title="Reading the place record…" body="Location, verification context and terms will appear together." />

    <div v-else-if="loadError" class="pd-missing"><ExperienceState kind="error" world="place" eyebrow="Place connection" title="The place record did not load." :body="loadError"><button type="button" @click="load">Try again</button><RouterLink to="/property">Return to Property</RouterLink></ExperienceState></div>
    <div v-else-if="!listing" class="pd-missing"><ExperienceState kind="empty" world="place" eyebrow="Listing unavailable" title="This place is not currently published." body="It may have been withdrawn, sold, or returned to verification."><RouterLink to="/property">Explore other places</RouterLink></ExperienceState></div>

    <template v-else>
      <!-- 01 / PLACE -->
      <section class="pd-place">
        <div class="pd-shell">
          <div class="pd-topline">
            <RouterLink to="/property" class="pd-back"><Icon name="arrow" :size="14" style="transform:rotate(180deg)" /> Property</RouterLink>
            <div class="pd-index"><span>01</span><span>Place / {{ listing.region || 'Tanzania' }}</span></div>
          </div>

          <div class="pd-place-grid">
            <div class="pd-media-col">
              <button v-if="imgs.length" type="button" class="pd-main-image" data-cursor="Open" aria-label="Open property gallery" @click="galleryOpen=true">
                <MediaFrame class="pd-main-media" v-depth="{pointer:3,scroll:7,rotate:.18,scale:1.005}" :src="imgs[activeImg]" :alt="`${listing.title} — image ${activeImg + 1}`" tone="place" :eager="activeImg===0" :transition-name="activeImg===0 ? viewName('property', listing.id) : ''" fallback-title="Property image unavailable">
                  <span class="pd-image-count">{{ String(activeImg + 1).padStart(2,'0') }} / {{ String(imgs.length).padStart(2,'0') }}</span>
                  <span class="pd-image-open">View image ↗</span>
                </MediaFrame>
              </button>
              <MediaFrame v-else class="pd-main-image pd-no-image" tone="place" :alt="listing.title" fallback-title="Property image not supplied" fallback-note="Use the location, map and listing record to understand the place." />

              <div v-if="imgs.length > 1" class="pd-thumbs">
                <button v-for="(im,i) in imgs" :key="i" type="button" class="pd-thumb" :class="{on:i===activeImg}" :aria-label="`View image ${i+1}`" :aria-pressed="i===activeImg" @click="activeImg=i"><MediaFrame class="pd-thumb-media" :src="im" :alt="`${listing.title} — image ${i+1}`" tone="place" /><span>{{ String(i + 1).padStart(2,'0') }}</span></button>
              </div>
            </div>

            <aside class="pd-identity">
              <div class="pd-eyebrow"><span>{{ kindLabel }}</span><span>{{ listing.status === 'verified' ? 'Reviewed' : 'Pending review' }}</span></div>
              <h1>{{ listing.title }}</h1>
              <div class="pd-location"><Icon name="pin" :size="14" /> {{ placeLabel }}</div>
              <div class="pd-place-signal">
                <span>{{ locationPin ? (locationPin.exact ? 'Pinned location' : 'Approximate area') : 'Location context' }}</span>
                <small>{{ locationPin ? 'Geography supplied with this listing' : 'Map point not supplied' }}</small>
              </div>

              <div class="pd-price">{{ fmtPrice(listing) }}</div>
              <div class="pd-price-meta">
                <span>{{ basisLabel }}</span>
                <span v-if="listing.price_negotiable">Negotiable</span>
                <span v-if="listing.fair_price_ok">Price reviewed</span>
              </div>

              <div class="pd-fact-ledger">
                <div v-if="listing.size_value"><span>Size</span><b>{{ listing.size_value }} {{ listing.size_unit }}</b></div>
                <div><span>Utilities</span><b>{{ utilityLabel }}</b></div>
                <div><span>Listing</span><b>{{ ownerContext }}</b></div>
                <div><span>Region</span><b>{{ listing.region || 'Tanzania' }}</b></div>
              </div>

              <div class="pd-early-actions">
                <button type="button" class="pd-early-primary" @click="scrollToTerms">Enquire <Icon name="arrow" :size="14" /></button>
                <button type="button" class="pd-early-secondary" @click="startDeal"><Icon name="shield" :size="14" /> Start protected purchase</button>
              </div>
              <button type="button" class="pd-scroll-cue" @click="scrollToContext">Understand the place <Icon name="arrow" :size="14" style="transform:rotate(90deg)" /></button>
            </aside>
          </div>
        </div>
      </section>

      <!-- 02 / CONTEXT -->
      <section id="pd-context" v-reveal="{variant:'section'}" class="pd-section pd-context">
        <div class="pd-shell">
          <div class="pd-section-head"><div class="pd-index dark"><span>02</span><span>Ground / Context</span></div><p>Read the listing against its actual geography: access, neighbouring area, utilities and location precision.</p></div>

          <div class="pd-context-grid">
            <div class="pd-context-map-wrap" :class="{empty:!locationPin}">
              <div v-if="locationPin" id="property-context-map" class="pd-context-map" role="region" aria-label="Property location map"></div>
              <div v-else class="pd-map-empty"><Icon name="pin" :size="26" /><span>No map point supplied for this listing.</span></div>
              <div v-if="locationPin" class="pd-map-caption">
                <span>{{ locationPin.exact ? 'Pinned location' : 'Approximate area' }}</span>
                <small>{{ locationPin.exact ? 'Location point supplied with this listing.' : 'The map intentionally communicates an area rather than an exact point.' }}</small>
              </div>
            </div>

            <div class="pd-context-copy">
              <div class="pd-context-intro">
                <span>Ground notes</span>
                <h2>{{ placeLabel }}</h2>
                <p v-if="listing.description">{{ listing.description }}</p>
                <p v-else>No additional property description was supplied.</p>
              </div>

              <div class="pd-context-ledger">
                <div>
                  <span>Neighbouring area</span>
                  <p>{{ listing.neighbours || 'Neighbouring context has not been added to this listing.' }}</p>
                </div>
                <div>
                  <span>Services within 5 km</span>
                  <p>{{ listing.services_5km || 'Nearby services have not been described by the lister.' }}</p>
                </div>
                <div>
                  <span>Utilities</span>
                  <p>{{ utilityLabel }}<template v-if="listing.has_water && !listing.water_potable"> · Potability not declared</template>.</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- 03 / VERIFICATION -->
      <section v-reveal="{variant:'section'}" class="pd-section pd-verification">
        <div class="pd-shell">
          <div class="pd-section-head"><div class="pd-index dark"><span>03</span><span>Verification</span></div><p>Separate the physical place from the legal claim: what was reviewed, what was declared, and what remains yours to verify.</p></div>

          <div class="pd-ver-grid">
            <div class="pd-ver-title">
              <div class="pd-shield"><Icon name="shield" :size="24" /></div>
              <h2>See the ground.<br><em>Verify the claim.</em></h2>
              <p>Enkiama review is a transparency checkpoint. It does not replace title searches, boundary checks, identity verification, contracts or professional legal advice.</p>
            </div>

            <div class="pd-ver-ledger">
              <div>
                <span class="pd-ver-num">01</span>
                <div><b>Listing review</b><p>{{ listing.status === 'verified' ? 'This listing was reviewed before publication.' : 'This listing is not currently marked as verified.' }}</p></div>
                <strong :class="listing.status === 'verified' ? 'yes' : 'wait'">{{ listing.status === 'verified' ? 'Reviewed' : 'Pending' }}</strong>
              </div>
              <div>
                <span class="pd-ver-num">02</span>
                <div><b>Ownership declaration</b><p>{{ listing.ownership_declared ? 'The lister made an ownership / authority declaration.' : 'No ownership declaration is shown.' }}</p></div>
                <strong :class="listing.ownership_declared ? 'yes' : 'wait'">{{ listing.ownership_declared ? 'Declared' : 'Check' }}</strong>
              </div>
              <div>
                <span class="pd-ver-num">03</span>
                <div><b>Who is listing</b><p>{{ ownerContext }}<template v-if="listing.lister_role==='representative' && listing.owner_name"> · Named legal owner: {{ listing.owner_name }}<template v-if="listing.owner_relation"> ({{ listing.owner_relation }})</template>.</template></p></div>
                <strong>{{ listing.lister_role === 'representative' ? 'Representative' : 'Owner' }}</strong>
              </div>
              <div>
                <span class="pd-ver-num">04</span>
                <div><b>Price context</b><p>{{ listing.fair_price_ok ? 'The asking price is marked as reviewed in the listing.' : 'No fair-price review is displayed. Compare independently.' }}</p></div>
                <strong :class="listing.fair_price_ok ? 'yes' : ''">{{ listing.fair_price_ok ? 'Reviewed' : 'Compare' }}</strong>
              </div>
            </div>
          </div>

          <div class="pd-due">
            <span>Before any final payment</span>
            <p>Confirm legal owner, title, boundaries, encumbrances and transaction documents independently. If a representative listed the property, final sale documents must come from the legal owner or validly authorised party.</p>
          </div>
        </div>
      </section>

      <!-- 04 / TERMS — transaction becomes the quietest chapter -->
      <section id="pd-terms" v-reveal="{variant:'section'}" class="pd-section pd-terms">
        <div class="pd-shell">
          <div class="pd-section-head"><div class="pd-index dark"><span>04</span><span>Terms</span></div><p>Move forward only when the place and verification context make sense to you.</p></div>

          <div class="pd-terms-grid">
            <div class="pd-terms-price">
              <span>Asking price</span>
              <h2>{{ fmtPrice(listing) }}</h2>
              <div class="pd-term-tags">
                <span>{{ basisLabel }}</span>
                <span v-if="listing.price_negotiable">Negotiable</span>
                <span v-if="listing.installments_ok">Payment plan available</span>
              </div>

              <div v-if="listing.installments_ok" class="pd-plan">
                <div class="pd-plan-top"><span>Illustrative payment plan</span><small>Seller terms</small></div>
                <div class="pd-plan-grid">
                  <div v-if="depositAmount"><span>Deposit</span><b>{{ tzs(depositAmount) }}</b><small>{{ listing.deposit_pct }}%</small></div>
                  <div v-if="monthlyAmount"><span>Then monthly</span><b>{{ tzs(monthlyAmount) }}</b><small>× {{ listing.installment_months }} months</small></div>
                </div>
                <p>Terms are agreed with the seller. A protected purchase journey can record the process and support escrow-style deposit handling where available.</p>
              </div>
            </div>

            <div class="pd-action-panel">
              <div class="pd-action-index">NEXT / ENQUIRY</div>
              <h3>Interested in this place?</h3>
              <p>Ask questions first, then start a protected purchase journey when you are ready to move beyond enquiry.</p>

              <button type="button" class="pd-primary-action" @click="showContact = !showContact"><Icon name="phone" :size="15" /> {{ showContact ? 'Hide enquiry contact' : 'Enquire about this property' }}</button>
              <button type="button" class="pd-secondary-action" @click="startDeal"><Icon name="shield" :size="15" /> Start a protected purchase</button>

              <transition name="pd-contact">
                <div v-if="showContact" class="pd-contact">
                  <span>Contact for enquiries</span>
                  <a v-if="listing.contact_phone" :href="`tel:${listing.contact_phone}`"><Icon name="phone" :size="14" /> {{ listing.contact_phone }}</a>
                  <p v-else>No public enquiry phone was supplied for this listing.</p>
                  <p v-if="listing.lister_role==='representative'" class="pd-rep-note">Listed by a representative<template v-if="listing.owner_relation"> ({{ listing.owner_relation }})</template><template v-if="listing.owner_name">. Named legal owner: <b>{{ listing.owner_name }}</b></template>.</p>
                </div>
              </transition>

              <div class="pd-action-note"><Icon name="alert" :size="14" /><span>Never make full payment solely on the basis of an online listing.</span></div>
            </div>
          </div>
        </div>
      </section>
    </template>
  </main>
  <SiteFooter />

  <!-- full-screen property gallery -->
  <div v-if="galleryOpen && imgs.length" v-focus-trap v-escape="() => galleryOpen=false" class="pd-lightbox" role="dialog" aria-modal="true" aria-label="Property gallery" tabindex="-1" @click.self="galleryOpen=false">
    <button type="button" class="pd-lightbox-close" aria-label="Close gallery" @click="galleryOpen=false"><Icon name="plus" :size="22" style="transform:rotate(45deg)" /></button>
    <button type="button" v-if="imgs.length > 1" class="pd-lightbox-nav prev" aria-label="Previous image" @click="nextImage(-1)"><Icon name="arrow" :size="20" style="transform:rotate(180deg)" /></button>
    <MediaFrame class="pd-lightbox-media" :src="imgs[activeImg]" :alt="`${listing?.title || 'Property'} image ${activeImg + 1}`" tone="night" fit="contain" :eager="true" />
    <button type="button" v-if="imgs.length > 1" class="pd-lightbox-nav next" aria-label="Next image" @click="nextImage(1)"><Icon name="arrow" :size="20" /></button>
    <div class="pd-lightbox-count">{{ String(activeImg + 1).padStart(2,'0') }} / {{ String(imgs.length).padStart(2,'0') }}</div>
  </div>
</template>

<style scoped>
.pd-page{background:var(--surface);color:var(--ink)}
.pd-shell{width:min(1240px,calc(100% - 48px));margin:0 auto}
.pd-load{display:flex;justify-content:center;padding:100px 20px}
.pd-missing{min-height:58vh;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:40px 20px;color:var(--ink-faint)}
.pd-missing h2{font-family:'Space Grotesk',sans-serif;font-size:28px;color:var(--ink);letter-spacing:-.03em;margin:15px 0 5px}.pd-missing p{font-size:13px}.pd-missing-link{display:inline-flex;align-items:center;gap:9px;color:var(--ink);text-decoration:none;font-size:12px;font-weight:700;border-bottom:1px solid var(--ink);padding-bottom:5px;margin-top:18px}

.pd-place{background:#f3f1ea;padding:24px 0 76px}
.pd-topline{display:flex;align-items:center;justify-content:space-between;gap:20px;padding-bottom:22px;border-bottom:1px solid rgba(30,36,33,.14)}
.pd-back{display:flex;align-items:center;gap:7px;color:var(--ink-faint);text-decoration:none;font-size:11px;font-weight:650}.pd-back:hover{color:var(--ink)}
.pd-index{display:flex;align-items:center;gap:11px;font-size:9.5px;letter-spacing:.12em;text-transform:uppercase;color:var(--ink-faint)}.pd-index span:first-child{font-family:'Space Grotesk',sans-serif;font-weight:700;color:var(--ink)}.pd-index.dark{color:var(--ink-faint)}
.pd-place-grid{display:grid;grid-template-columns:minmax(0,1.18fr) minmax(360px,.82fr);gap:6vw;align-items:start;padding-top:46px}
.pd-main-image{position:relative;display:block;width:100%;height:min(64vw,650px);min-height:480px;border:0;background:#d8dcd4 center/cover no-repeat;cursor:zoom-in;overflow:hidden;text-align:left}.pd-main-image::after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(0,0,0,.01),rgba(0,0,0,.2));transition:.35s}.pd-main-image:hover::after{background:linear-gradient(180deg,rgba(0,0,0,.03),rgba(0,0,0,.28))}.pd-no-image{display:flex;align-items:center;justify-content:center;flex-direction:column;gap:10px;color:rgba(30,36,33,.35);cursor:default;font:inherit;font-size:11px;letter-spacing:.08em;text-transform:uppercase}
.pd-image-count,.pd-image-open{position:absolute;z-index:2;bottom:17px;color:#fff;font-size:9.5px;letter-spacing:.1em;text-transform:uppercase}.pd-image-count{left:17px}.pd-image-open{right:17px;opacity:0;transform:translateY(5px);transition:.3s}.pd-main-image:hover .pd-image-open{opacity:1;transform:none}
.pd-thumbs{display:flex;gap:7px;padding-top:8px;overflow-x:auto}.pd-thumb{width:82px;height:60px;flex:0 0 auto;border:0;background:center/cover no-repeat;position:relative;cursor:pointer;opacity:.5;transition:.2s}.pd-thumb.on{opacity:1}.pd-thumb.on::after{content:"";position:absolute;inset:auto 0 -3px;height:2px;background:var(--ink)}.pd-thumb span{position:absolute;left:5px;bottom:4px;color:#fff;font-size:8px;text-shadow:0 1px 4px rgba(0,0,0,.45)}
.pd-identity{padding-top:9px;position:sticky;top:90px}.pd-eyebrow{display:flex;justify-content:space-between;gap:18px;padding-bottom:13px;border-bottom:1px solid rgba(30,36,33,.14);font-size:9.5px;letter-spacing:.1em;text-transform:uppercase;color:var(--ink-faint)}.pd-identity h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(44px,5vw,72px);font-weight:540;line-height:.95;letter-spacing:-.055em;margin:28px 0 13px}.pd-location{display:flex;align-items:center;gap:6px;font-size:12.5px;color:var(--ink-faint)}
.pd-price{font-family:'Space Grotesk',sans-serif;font-size:21px;font-weight:650;letter-spacing:-.02em;margin-top:40px}.pd-price-meta{display:flex;gap:6px;flex-wrap:wrap;margin-top:7px}.pd-price-meta span{font-size:9.5px;text-transform:uppercase;letter-spacing:.06em;color:var(--ink-faint);padding-right:8px;border-right:1px solid rgba(30,36,33,.16)}.pd-price-meta span:last-child{border-right:0}
.pd-fact-ledger{border-top:1px solid rgba(30,36,33,.14);margin-top:34px}.pd-fact-ledger>div{display:grid;grid-template-columns:90px 1fr;gap:16px;padding:12px 0;border-bottom:1px solid rgba(30,36,33,.1)}.pd-fact-ledger span{font-size:9.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-faint)}.pd-fact-ledger b{font-size:12px;font-weight:600;text-align:right}
.pd-scroll-cue{display:flex;align-items:center;gap:8px;border:0;background:transparent;color:var(--ink);font:inherit;font-size:11px;font-weight:700;padding:0 0 5px;border-bottom:1px solid rgba(30,36,33,.35);cursor:pointer;margin-top:27px}

.pd-section{padding:92px 0;border-top:1px solid var(--hairline)}.pd-section-head{display:flex;justify-content:space-between;align-items:flex-start;gap:30px;border-bottom:1px solid var(--hairline-2);padding-bottom:18px;margin-bottom:42px}.pd-section-head>p{max-width:440px;font-size:11.5px;line-height:1.55;color:var(--ink-faint);margin:0;text-align:right}
.pd-context-grid{display:grid;grid-template-columns:minmax(0,1.15fr) minmax(340px,.85fr);gap:6vw;align-items:start}.pd-context-map-wrap{height:590px;position:relative;background:#e9ece6;overflow:hidden}.pd-context-map{position:absolute;inset:0}.pd-map-empty{height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:9px;color:var(--ink-ghost);font-size:11px}.pd-map-caption{position:absolute;z-index:450;left:16px;bottom:16px;background:rgba(255,255,255,.9);backdrop-filter:blur(14px);max-width:310px;padding:12px 14px}.pd-map-caption span{display:block;font-size:10px;font-weight:700;letter-spacing:.08em;text-transform:uppercase}.pd-map-caption small{display:block;font-size:10.5px;line-height:1.45;color:var(--ink-faint);margin-top:4px}
.pd-context-copy{padding-top:6px}.pd-context-intro>span{font-size:9.5px;letter-spacing:.1em;text-transform:uppercase;color:var(--ink-faint)}.pd-context-intro h2{font-family:'Space Grotesk',sans-serif;font-size:clamp(34px,4vw,56px);font-weight:540;line-height:1;letter-spacing:-.05em;margin:16px 0}.pd-context-intro p{font-size:13.5px;line-height:1.75;color:var(--ink-soft);margin:0;white-space:pre-line}.pd-context-ledger{border-top:1px solid var(--hairline-2);margin-top:36px}.pd-context-ledger>div{padding:16px 0;border-bottom:1px solid var(--hairline)}.pd-context-ledger span{display:block;font-size:9.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-faint);margin-bottom:6px}.pd-context-ledger p{font-size:12.5px;line-height:1.55;color:var(--ink-soft);margin:0}
:deep(.pd-map-pin){background:transparent!important;border:0!important}:deep(.pd-map-pin-dot){width:28px;height:28px;border-radius:50%;background:rgba(13,21,20,.92);transform:translate(-50%,-50%);display:flex;align-items:center;justify-content:center;box-shadow:0 6px 22px rgba(0,0,0,.24)}:deep(.pd-map-pin-dot span){width:7px;height:7px;border-radius:50%;background:#e7eee4}:deep(.leaflet-control-zoom){border:0!important;box-shadow:0 8px 24px rgba(0,0,0,.12)!important}:deep(.leaflet-control-zoom a){border:0!important;color:#0d1514!important}

.pd-verification{background:#0d1514;color:#f5f3ed;border-top:0}.pd-verification .pd-section-head{border-color:rgba(255,255,255,.12)}.pd-verification .pd-index{color:rgba(255,255,255,.5)}.pd-verification .pd-index span:first-child{color:#fff}.pd-verification .pd-section-head>p{color:rgba(255,255,255,.42)}
.pd-ver-grid{display:grid;grid-template-columns:.78fr 1.22fr;gap:8vw;align-items:start}.pd-shield{width:52px;height:52px;border:1px solid rgba(255,255,255,.18);display:flex;align-items:center;justify-content:center;color:#b6cab5;margin-bottom:22px}.pd-ver-title h2{font-family:'Space Grotesk',sans-serif;font-size:clamp(42px,5vw,68px);font-weight:520;line-height:.95;letter-spacing:-.055em;margin:0}.pd-ver-title>p{font-size:12.5px;line-height:1.7;color:rgba(255,255,255,.48);max-width:450px;margin:22px 0 0}
.pd-ver-ledger{border-top:1px solid rgba(255,255,255,.14)}.pd-ver-ledger>div{display:grid;grid-template-columns:38px 1fr auto;gap:16px;padding:20px 0;border-bottom:1px solid rgba(255,255,255,.1);align-items:start}.pd-ver-num{font-size:9.5px;color:rgba(255,255,255,.28)}.pd-ver-ledger b{display:block;font-size:12.5px;font-weight:650}.pd-ver-ledger p{font-size:11.5px;line-height:1.55;color:rgba(255,255,255,.43);margin:5px 0 0;max-width:480px}.pd-ver-ledger strong{font-size:9.5px;letter-spacing:.08em;text-transform:uppercase;font-weight:650;color:rgba(255,255,255,.58)}.pd-ver-ledger strong.yes{color:#9dc4a4}.pd-ver-ledger strong.wait{color:#d5bd86}
.pd-due{display:grid;grid-template-columns:190px 1fr;gap:30px;padding-top:26px;margin-top:42px;border-top:1px solid rgba(255,255,255,.12)}.pd-due span{font-size:9.5px;letter-spacing:.1em;text-transform:uppercase;color:#b7c8b5}.pd-due p{font-size:12px;line-height:1.65;color:rgba(255,255,255,.48);max-width:760px;margin:0}

.pd-terms{padding-bottom:120px}.pd-terms-grid{display:grid;grid-template-columns:1fr minmax(340px,.72fr);gap:8vw;align-items:start}.pd-terms-price>span{font-size:9.5px;letter-spacing:.1em;text-transform:uppercase;color:var(--ink-faint)}.pd-terms-price>h2{font-family:'Space Grotesk',sans-serif;font-size:clamp(42px,5.5vw,76px);font-weight:540;line-height:1;letter-spacing:-.055em;margin:15px 0}.pd-term-tags{display:flex;flex-wrap:wrap;gap:7px}.pd-term-tags span{font-size:9.5px;letter-spacing:.05em;text-transform:uppercase;color:var(--ink-faint);padding:6px 9px;border:1px solid var(--hairline-2)}
.pd-plan{margin-top:38px;border-top:1px solid var(--hairline-2);padding-top:20px;max-width:620px}.pd-plan-top{display:flex;justify-content:space-between;gap:20px;font-size:10px;text-transform:uppercase;letter-spacing:.08em}.pd-plan-top span{font-weight:700}.pd-plan-top small{color:var(--ink-faint)}.pd-plan-grid{display:grid;grid-template-columns:1fr 1fr;gap:1px;background:var(--hairline-2);margin-top:14px;border:1px solid var(--hairline-2)}.pd-plan-grid>div{background:var(--surface);padding:16px}.pd-plan-grid span,.pd-plan-grid small{display:block;font-size:9.5px;color:var(--ink-faint);text-transform:uppercase;letter-spacing:.06em}.pd-plan-grid b{display:block;font-family:'Space Grotesk',sans-serif;font-size:17px;margin:5px 0 2px}.pd-plan>p{font-size:11px;line-height:1.6;color:var(--ink-faint);margin:12px 0 0}
.pd-action-panel{border-top:1px solid var(--ink);padding-top:18px}.pd-action-index{font-size:9.5px;letter-spacing:.1em;text-transform:uppercase;color:var(--ink-faint)}.pd-action-panel h3{font-family:'Space Grotesk',sans-serif;font-size:30px;font-weight:560;letter-spacing:-.04em;margin:18px 0 8px}.pd-action-panel>p{font-size:12px;line-height:1.65;color:var(--ink-faint);max-width:430px;margin:0 0 24px}.pd-primary-action,.pd-secondary-action{width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;border:0;font:inherit;font-size:12px;font-weight:700;padding:14px 0;cursor:pointer}.pd-primary-action{background:var(--ink);color:#fff;padding-left:14px;padding-right:14px}.pd-secondary-action{background:transparent;color:var(--ink);border-bottom:1px solid var(--hairline-2)}
.pd-contact{padding:18px 0;border-bottom:1px solid var(--hairline-2)}.pd-contact>span{display:block;font-size:9.5px;letter-spacing:.08em;text-transform:uppercase;color:var(--ink-faint);margin-bottom:9px}.pd-contact>a{display:flex;align-items:center;gap:8px;color:var(--ink);text-decoration:none;font-family:'Space Grotesk',sans-serif;font-size:18px;font-weight:650}.pd-contact>p{font-size:11.5px;line-height:1.55;color:var(--ink-faint);margin:8px 0 0}.pd-rep-note{padding-top:9px;border-top:1px solid var(--hairline)}.pd-action-note{display:flex;align-items:flex-start;gap:8px;color:var(--owed-ink);font-size:10.5px;line-height:1.5;margin-top:17px}.pd-action-note svg{margin-top:1px}
.pd-contact-enter-active,.pd-contact-leave-active{transition:.25s ease}.pd-contact-enter-from,.pd-contact-leave-to{opacity:0;transform:translateY(-5px)}

.pd-lightbox{position:fixed;inset:0;background:rgba(7,11,10,.96);z-index:1300;display:flex;align-items:center;justify-content:center;padding:54px}.pd-lightbox img{max-width:min(1180px,86vw);max-height:84vh;object-fit:contain}.pd-lightbox-close,.pd-lightbox-nav{position:absolute;border:0;background:rgba(255,255,255,.07);color:#fff;display:flex;align-items:center;justify-content:center;cursor:pointer}.pd-lightbox-close{width:44px;height:44px;right:24px;top:22px}.pd-lightbox-nav{width:48px;height:48px;top:50%;transform:translateY(-50%)}.pd-lightbox-nav.prev{left:24px}.pd-lightbox-nav.next{right:24px}.pd-lightbox-count{position:absolute;left:24px;bottom:22px;color:rgba(255,255,255,.55);font-size:10px;letter-spacing:.12em}

@media(max-width:960px){
  .pd-place-grid{grid-template-columns:1fr;gap:40px}.pd-identity{position:static;max-width:760px}.pd-main-image{height:68vw;min-height:440px}.pd-context-grid{grid-template-columns:1fr}.pd-context-map-wrap{height:520px}.pd-context-copy{max-width:760px}.pd-ver-grid,.pd-terms-grid{grid-template-columns:1fr;gap:50px}.pd-ver-title>p{max-width:600px}.pd-action-panel{max-width:620px}
}
@media(max-width:680px){
  .pd-shell{width:calc(100% - 32px)}.pd-place{padding-top:18px;padding-bottom:58px}.pd-topline{padding-bottom:15px}.pd-place-grid{padding-top:28px;gap:30px}.pd-main-image{height:72vw;min-height:300px}.pd-thumbs{margin-right:-16px}.pd-identity h1{font-size:46px}.pd-price{margin-top:30px}.pd-fact-ledger>div{grid-template-columns:82px 1fr}.pd-section{padding:68px 0}.pd-section-head{flex-direction:column;gap:10px;margin-bottom:30px}.pd-section-head>p{text-align:left}.pd-context-map-wrap{height:70vw;min-height:340px;margin-left:-16px;margin-right:-16px}.pd-map-caption{left:10px;bottom:10px;max-width:calc(100% - 20px)}.pd-context-intro h2{font-size:38px}.pd-ver-title h2{font-size:44px}.pd-ver-ledger>div{grid-template-columns:30px 1fr}.pd-ver-ledger strong{grid-column:2;margin-top:4px}.pd-due{grid-template-columns:1fr;gap:8px}.pd-terms{padding-bottom:82px}.pd-terms-price>h2{font-size:46px}.pd-plan-grid{grid-template-columns:1fr}.pd-action-panel h3{font-size:28px}.pd-lightbox{padding:58px 16px}.pd-lightbox img{max-width:100%;max-height:75vh}.pd-lightbox-nav{top:auto;bottom:20px;transform:none}.pd-lightbox-nav.prev{left:auto;right:76px}.pd-lightbox-nav.next{right:20px}.pd-lightbox-count{left:20px;bottom:36px}
}
@media(prefers-reduced-motion:reduce){.pd-image-open,.pd-contact-enter-active,.pd-contact-leave-active{transition:none!important}}

/* PHASE 9 — PLACE DETAIL / landscape, maps and terms built for one hand */
@media(max-width:680px){
  .pd-main-image{margin-left:-16px;width:calc(100% + 32px);height:min(72svh,520px);min-height:320px}
  .pd-image-open{opacity:1;transform:none}
  .pd-thumbs{scroll-snap-type:x proximity;scrollbar-width:none;overscroll-behavior-inline:contain}.pd-thumbs::-webkit-scrollbar{display:none}.pd-thumb{scroll-snap-align:start;min-width:76px;min-height:58px}
  .pd-context-map-wrap{height:min(68svh,540px)}
  .pd-primary-action,.pd-secondary-action{min-height:52px}
  .pd-action-panel{padding-bottom:calc(8px + env(safe-area-inset-bottom))}
  .pd-lightbox{padding-top:calc(58px + env(safe-area-inset-top));padding-bottom:calc(76px + env(safe-area-inset-bottom))}
}
@media(max-width:420px){
  .pd-shell{width:calc(100% - 28px)}
  .pd-main-image{margin-left:-14px;width:calc(100% + 28px)}
  .pd-identity h1{font-size:41px}.pd-context-intro h2{font-size:34px}.pd-ver-title h2{font-size:40px}.pd-terms-price>h2{font-size:41px}
  .pd-fact-ledger>div{grid-template-columns:74px 1fr}
  .pd-map-caption{max-height:42%;overflow:auto}
}

/* PHASE 15 — PROPERTY DETAIL / GEOGRAPHIC WORLD */
.pd-page{background:#f5f1e8;color:#1d2922}
.pd-place{background:#e8e0d2;padding-top:24px;padding-bottom:84px;position:relative;isolation:isolate;overflow:hidden}
.pd-place::before{content:"";position:absolute;right:-15vw;top:-20vw;width:70vw;height:70vw;border-radius:50%;background:repeating-radial-gradient(ellipse at 50% 50%,transparent 0 31px,rgba(43,65,50,.05) 32px 33px);transform:rotate(-12deg) scaleY(.58);z-index:-1;pointer-events:none}
.pd-topline{border-bottom-color:rgba(44,58,48,.15)}
.pd-place-grid{grid-template-columns:minmax(0,1.32fr) minmax(350px,.68fr);gap:5.5vw;padding-top:42px}
.pd-main-image{height:min(62vw,700px);min-height:520px;background-color:#d7d0c3;box-shadow:0 30px 76px rgba(69,56,41,.17);border:1px solid rgba(85,69,49,.08)}
.pd-main-image::after{background:linear-gradient(180deg,rgba(10,18,13,.01) 52%,rgba(10,18,13,.28))}
.pd-thumbs{gap:9px;padding-top:12px}.pd-thumb{width:94px;height:68px;border:1px solid rgba(61,75,64,.1)}
.pd-identity{top:86px;padding-top:4px}
.pd-eyebrow{border-bottom-color:rgba(44,58,48,.14);color:rgba(29,41,34,.56)}
.pd-identity h1{font-size:clamp(42px,4.6vw,66px);line-height:.98;margin-top:24px}
.pd-location{color:rgba(29,41,34,.64)}
.pd-place-signal{display:grid;grid-template-columns:1fr;gap:3px;margin-top:18px;padding:13px 0;border-top:1px solid rgba(44,58,48,.12);border-bottom:1px solid rgba(44,58,48,.12)}
.pd-place-signal span{font-size:10px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:#385342}
.pd-place-signal small{font-size:10.5px;color:rgba(29,41,34,.5)}
.pd-price{margin-top:30px;font-size:20px}
.pd-fact-ledger{border-top-color:rgba(44,58,48,.14);margin-top:28px}.pd-fact-ledger>div{border-bottom-color:rgba(44,58,48,.1)}
.pd-scroll-cue{border-bottom-color:rgba(29,41,34,.28)}

.pd-section{border-top-color:rgba(51,66,56,.12);padding:88px 0}
.pd-context{background:#f6f2e9}
.pd-section-head{border-bottom-color:rgba(51,66,56,.14);margin-bottom:38px}
.pd-context-grid{grid-template-columns:minmax(0,1.28fr) minmax(330px,.72fr);gap:5.5vw}
.pd-context-map-wrap{height:640px;background:#d8d5ca;border:1px solid rgba(58,73,61,.13);box-shadow:0 20px 60px rgba(66,55,41,.08)}
.pd-map-caption{background:rgba(246,242,233,.93);border:1px solid rgba(62,73,62,.11);box-shadow:0 12px 34px rgba(57,46,34,.1)}
.pd-context-intro>span{color:#806a50}
.pd-context-intro h2{font-size:clamp(32px,3.6vw,50px)}
.pd-context-intro p{color:rgba(29,41,34,.72)}
.pd-context-ledger{border-top-color:rgba(51,66,56,.14)}.pd-context-ledger>div{border-bottom-color:rgba(51,66,56,.12)}
:deep(.leaflet-tile-pane){filter:saturate(.72) sepia(.09) contrast(.93) brightness(1.03)}
:deep(.pd-map-pin-dot){background:#263c30;box-shadow:0 7px 24px rgba(36,54,42,.24)}
:deep(.pd-map-pin-dot span){background:#d8c19a}

.pd-verification{background:#ded3c3;color:#1d2922;border-top:1px solid rgba(81,65,46,.08)}
.pd-verification .pd-section-head{border-color:rgba(68,55,41,.16)}
.pd-verification .pd-index{color:rgba(29,41,34,.5)}.pd-verification .pd-index span:first-child{color:#1d2922}.pd-verification .pd-section-head>p{color:rgba(29,41,34,.54)}
.pd-shield{border-color:rgba(45,62,49,.18);color:#385742;background:rgba(247,243,234,.36)}
.pd-ver-title h2{font-size:clamp(38px,4.5vw,60px)}
.pd-ver-title h2 em{font-family:'Cormorant Garamond',Georgia,serif;font-weight:500;color:#704d34}
.pd-ver-title>p{color:rgba(29,41,34,.6)}
.pd-ver-ledger{border-top-color:rgba(68,55,41,.16)}.pd-ver-ledger>div{border-bottom-color:rgba(68,55,41,.13)}
.pd-ver-num{color:rgba(29,41,34,.32)}.pd-ver-ledger p{color:rgba(29,41,34,.58)}.pd-ver-ledger strong{color:rgba(29,41,34,.6)}.pd-ver-ledger strong.yes{color:#3f684d}.pd-ver-ledger strong.wait{color:#8a672f}
.pd-due{border-top-color:rgba(68,55,41,.15)}.pd-due span{color:#6f563a}.pd-due p{color:rgba(29,41,34,.62)}

.pd-terms{background:#f5f1e8;padding-bottom:110px}.pd-terms-price>h2{font-size:clamp(38px,4.8vw,66px)}
.pd-term-tags span{border-color:rgba(51,66,56,.14)}
.pd-plan{border-top-color:rgba(51,66,56,.16)}.pd-plan-grid{background:rgba(51,66,56,.13);border-color:rgba(51,66,56,.13)}.pd-plan-grid>div{background:#f9f6ef}
.pd-action-panel{border-top-color:#263c30}.pd-primary-action{background:#263c30;color:#f8f3ea}.pd-secondary-action{border-bottom-color:rgba(51,66,56,.14)}

@media(max-width:960px){
  .pd-place-grid{grid-template-columns:1fr;gap:38px}.pd-main-image{height:min(70vw,640px)}.pd-identity{max-width:820px}
  .pd-context-grid{grid-template-columns:1fr}.pd-context-map-wrap{height:560px}.pd-context-copy{max-width:820px}
}
@media(max-width:680px){
  .pd-place{padding-bottom:62px}.pd-place::before{width:130vw;height:130vw;right:-70vw;top:-10vw}
  .pd-main-image{height:min(74svh,540px);min-height:330px;box-shadow:none}.pd-identity h1{font-size:42px}
  .pd-place-signal{margin-top:15px}.pd-context-map-wrap{height:min(70svh,560px)}
  .pd-ver-title h2{font-size:40px}.pd-terms-price>h2{font-size:42px}
}
@media(max-width:420px){
  .pd-identity h1{font-size:38px}.pd-context-intro h2{font-size:32px}.pd-ver-title h2{font-size:37px}.pd-terms-price>h2{font-size:39px}
}


/* PHASE 18 — governed media behavior */
.pd-main-image{position:relative}.pd-main-media{position:absolute;inset:0}.pd-main-image:hover .pd-main-media :deep(img){transform:scale(1.012)}
.pd-thumb{position:relative;overflow:hidden}.pd-thumb-media{position:absolute;inset:0}.pd-thumb:hover .pd-thumb-media :deep(img),.pd-thumb.on .pd-thumb-media :deep(img){transform:scale(1.015)}
.pd-lightbox-media{width:min(90vw,1450px);height:88vh;max-height:88vh}
@media(max-width:640px){.pd-lightbox-media{width:100%;height:75vh}}
@media(prefers-reduced-motion:reduce){.pd-main-media :deep(img),.pd-thumb-media :deep(img){transform:none!important;transition:none!important}}

/* ═══ PHASE 21 — PROPERTY DETAIL RESPONSIVE ART DIRECTION ═══ */
@media(min-width:1600px){
  .pd-shell{width:min(1400px,calc(100% - 112px))}.pd-place-grid{grid-template-columns:minmax(0,1.38fr) minmax(380px,.62fr);gap:88px}.pd-main-image{height:680px}
  .pd-context-grid{grid-template-columns:minmax(0,1.3fr) minmax(360px,.7fr);gap:88px}.pd-context-map-wrap{height:650px}.pd-terms-grid{gap:110px}
}
@media(min-width:1180px) and (max-width:1599px){
  .pd-shell{width:min(1240px,calc(100% - 64px))}.pd-place-grid{grid-template-columns:minmax(0,1.25fr) minmax(350px,.75fr);gap:52px}.pd-main-image{height:min(56vw,610px)}
  .pd-context-grid{grid-template-columns:minmax(0,1.2fr) minmax(330px,.8fr);gap:52px}.pd-context-map-wrap{height:540px}.pd-terms-grid{gap:64px}
}
@media(min-width:768px) and (max-width:1179px){
  .pd-shell{width:min(900px,calc(100% - 48px))}.pd-place-grid{grid-template-columns:1fr;gap:34px}.pd-main-image{height:min(64vw,590px)}.pd-identity{max-width:760px}
  .pd-context-grid{grid-template-columns:1fr}.pd-context-map-wrap{height:min(62svh,560px)}.pd-context-copy{max-width:760px}.pd-ver-grid,.pd-terms-grid{grid-template-columns:1fr;gap:46px}.pd-action-panel{max-width:620px}
}
@media(max-width:767px){
  .pd-shell{width:calc(100% - 32px)}.pd-place{padding-top:16px}.pd-main-image{height:min(70svh,540px);min-height:320px;margin-inline:-16px}.pd-thumbs{margin-right:-16px}.pd-identity h1{font-size:clamp(38px,10vw,44px)}
  .pd-context-map-wrap{height:min(68svh,560px);margin-inline:-16px}.pd-verification,.pd-terms{padding-left:0;padding-right:0}.pd-section{padding:64px 0}
}
@media(max-width:390px){
  .pd-shell{width:calc(100% - 24px)}.pd-main-image,.pd-context-map-wrap{margin-inline:-12px}.pd-thumbs{margin-right:-12px}.pd-identity h1{font-size:36px}.pd-context-intro h2{font-size:31px}.pd-ver-title h2{font-size:35px}
}


/* PHASE 26 — buyer decisions stay reachable */
.pd-early-actions{display:grid;grid-template-columns:1fr;gap:8px;margin-top:26px}
.pd-early-primary,.pd-early-secondary{
  min-height:46px;width:100%;display:flex;align-items:center;justify-content:space-between;gap:12px;
  padding:0 14px;border:1px solid rgba(29,41,34,.22);font:650 11px/1 var(--font-body);cursor:pointer
}
.pd-early-primary{background:#263c30;color:#f8f3ea;border-color:#263c30}
.pd-early-secondary{background:transparent;color:#263c30}
#pd-terms{scroll-margin-top:72px}
@media(max-width:960px){
  .pd-early-actions{grid-template-columns:1fr 1fr;max-width:620px}
}
@media(max-width:680px){
  .pd-early-actions{
    position:sticky;bottom:0;z-index:30;grid-template-columns:1fr;
    margin:24px -16px 0;padding:10px 16px calc(10px + env(safe-area-inset-bottom));
    background:color-mix(in srgb,#e8e0d2 95%,transparent);backdrop-filter:blur(14px);
    border-top:1px solid rgba(44,58,48,.14)
  }
  .pd-early-primary,.pd-early-secondary{min-height:50px}
}

</style>
