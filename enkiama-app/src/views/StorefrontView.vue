<script setup>
import { ref, onMounted, computed, watch, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import { usePublic } from '../composables/usePublic'
import Icon from '../components/Icon.vue'
import AppHeader from '../components/AppHeader.vue'
import Avatar from '../components/Avatar.vue'
import SiteFooter from '../components/SiteFooter.vue'
import EmptyState from '../components/EmptyState.vue'
import ExperienceState from '../components/ExperienceState.vue'
import MediaFrame from '../components/MediaFrame.vue'
import { viewName, signalMotionReady } from '../lib/motion'
import { firstMedia } from '../lib/media'
import { supabase } from '../lib/supabase'

const route = useRoute()
const pub = usePublic()
const data = ref(null)
const loading = ref(true)
const loadError = ref('')
const shopRep = ref(null)
const productRatings = ref({})
const sfBroken = ref(new Set())
const coverBroken = ref(false)

const store = computed(() => data.value?.store || null)
const products = computed(() => data.value?.products || [])
const reviews = computed(() => data.value?.reviews || [])
const sections = computed(() => data.value?.sections || [])

const grouped = computed(() => {
  const secs = sections.value
  const byId = {}
  secs.forEach(s => { byId[s.id] = { id: s.id, name: s.name, items: [] } })
  const noSection = []
  products.value.forEach(p => {
    if (p.section_id && byId[p.section_id]) byId[p.section_id].items.push(p)
    else noSection.push(p)
  })
  const out = secs.filter(s => byId[s.id].items.length).map(s => byId[s.id])
  if (noSection.length) out.push({ id: 'more', name: secs.length ? 'More from the shop' : 'Collection', items: noSection })
  return out
})

const heroProduct = computed(() => products.value.find(p => p.available !== false && galleryImg(p)) || products.value.find(p => p.available !== false) || products.value[0] || null)
const shopRating = computed(() => data.value?.avg_rating || shopRep.value?.avg_rating || null)
const reviewCount = computed(() => data.value?.review_count || shopRep.value?.reviews || reviews.value.length || 0)
const onTime = computed(() => shopRep.value?.on_time_pct ?? shopRep.value?.fulfilment_pct ?? null)
const delivered = computed(() => shopRep.value?.delivered ?? null)
const liveProducts = computed(() => products.value.filter(p => p.available !== false).length)
const regionList = computed(() => {
  const value = store.value?.delivers_to
  if (!value) return []
  if (Array.isArray(value)) return value.filter(Boolean)
  return String(value).split(/[,;·]/).map(v => v.trim()).filter(Boolean)
})
const businessSince = computed(() => store.value?.since_year ? `Trading since ${store.value.since_year}` : 'Independent business')
const storefrontStyle = computed(() => ({ '--sf': store.value?.accent || '#0B6E5D' }))
const coverImage = computed(() => {
  if (coverBroken.value) return ''
  const u = String(store.value?.cover_url || '').trim()
  return u && u !== 'null' && u.startsWith('http') ? u : ''
})
const visualProducts = computed(() => products.value.filter(p => galleryImg(p)).slice(0, 4))
const heroVisual = computed(() => coverImage.value || galleryImg(heroProduct.value))
const heroVisualIsCover = computed(() => !!coverImage.value)
const reachSummary = computed(() => {
  if (regionList.value.length) return `${regionList.value.length} ${regionList.value.length === 1 ? 'delivery region' : 'delivery regions'}`
  if (store.value?.region) return `Based in ${store.value.region}`
  return 'Enkiama marketplace'
})

async function load() {
  loading.value = true
  loadError.value = ''
  data.value = null
  shopRep.value = null
  productRatings.value = {}
  sfBroken.value = new Set()
  coverBroken.value = false
  const { data: res, error } = await pub.getStorefront(route.params.slug)
  if (error) loadError.value = 'The business profile could not be loaded right now.'
  data.value = error ? null : res
  loading.value = false
  await nextTick()
  signalMotionReady()
  if (res?.store?.id) {
    try {
      const { data: r } = await supabase.rpc('shop_reputation', { p_storefront_id: res.store.id })
      shopRep.value = r || null
    } catch (e) {}
    try {
      const { data: pr } = await supabase.rpc('storefront_product_ratings', { p_storefront_id: res.store.id })
      productRatings.value = pr || {}
    } catch (e) {}
  }
}

function tzs(n) { return n !== null && n !== undefined && n !== '' ? 'TZS ' + Number(n).toLocaleString() : '' }
function prodRating(p) { return productRatings.value?.[p.id] || null }
function galleryImg(p) {
  if (!p || (p.id && sfBroken.value.has(p.id))) return ''
  return firstMedia(p)
}
function sfBrokenImg(p) {
  if (!p?.id) return
  sfBroken.value.add(p.id)
  sfBroken.value = new Set(sfBroken.value)
}
function heroVisualFailed() {
  if (heroVisualIsCover.value) coverBroken.value = true
  else sfBrokenImg(heroProduct.value)
}
function shareShop() {
  const url = window.location.href
  const text = `Explore ${store.value?.name} on Enkiama — products with tracked delivery: ${url}`
  if (navigator.share) navigator.share({ title: store.value?.name, text, url }).catch(() => {})
  else window.open(`https://wa.me/?text=${encodeURIComponent(text)}`, '_blank')
}
function collectionId(index) { return `collection-${index + 1}` }
function scrollToCollections() { document.querySelector('#collections')?.scrollIntoView({ behavior: 'smooth', block: 'start' }) }

onMounted(load)
watch(() => route.params.slug, (next, prev) => { if (next && next !== prev) load() })
</script>

<template>
  <div v-if="!loading && store" class="sf14" :style="storefrontStyle">
    <AppHeader :title="store.name" subtitle="Business" :market="true" />

    <!-- 01 / BUSINESS -->
    <section class="sf14-hero">
      <div class="sf14-shell">
        <div class="sf14-topline">
          <RouterLink to="/market" class="sf14-back"><Icon name="arrow" :size="14" /> Market</RouterLink>
          <span>01 / BUSINESS</span>
        </div>

        <div class="sf14-hero-grid">
          <div class="sf14-identity" v-reveal="{variant:'copy'}">
            <div class="sf14-brandline">
              <Avatar :name="store.name" :accent="store.accent" :logo="store.logo_url" :size="76" class="sf14-avatar" :style="{viewTransitionName:viewName('shop', store.slug || store.id)}" />
              <div>
                <span v-if="store.region">{{ store.region }}</span>
                <span v-else>Tanzania</span>
                <small>{{ businessSince }}</small>
              </div>
            </div>

            <h1>{{ store.name }}</h1>
            <p class="sf14-tagline">{{ store.tagline || store.ships_what || 'Independent commerce, moving through Enkiama.' }}</p>

            <div class="sf14-actions">
              <button v-if="products.length" class="sf14-action-primary" @click="scrollToCollections">Explore collection <Icon name="arrowRight" :size="14" /></button>
              <a v-if="store.phone" :href="`tel:${store.phone}`" class="sf14-action-line">Contact</a>
              <button class="sf14-action-line" @click="shareShop">Share</button>
            </div>

            <div class="sf14-identity-ledger">
              <div><span>Place</span><strong>{{ store.region || 'Tanzania' }}</strong></div>
              <div><span>Objects</span><strong>{{ liveProducts }} live</strong></div>
              <div><span>Reach</span><strong>{{ reachSummary }}</strong></div>
            </div>
          </div>

          <div class="sf14-visual" v-reveal="{variant:'media',delay:80}" :class="{'is-object': !heroVisualIsCover}">
            <MediaFrame class="sf14-visual-frame" v-depth="{pointer:3.6,scroll:8,rotate:.22,scale:1.006}" :src="heroVisual" :alt="heroVisualIsCover ? `${store.name} business` : heroProduct?.name" tone="business" :fit="heroVisualIsCover ? 'cover' : 'contain'" :eager="true" fallback-title="Business image not supplied" :fallback-note="store.region || 'Independent business'" @error="heroVisualFailed" />

            <div class="sf14-visual-caption">
              <span>{{ heroVisualIsCover ? 'THE BUSINESS' : 'FEATURED OBJECT' }}</span>
              <strong>{{ heroVisualIsCover ? (store.tagline || store.name) : heroProduct?.name }}</strong>
              <small>{{ heroVisualIsCover ? (store.region || businessSince) : tzs(heroProduct?.price_tzs) }}</small>
            </div>

            <RouterLink v-if="heroVisualIsCover && heroProduct" :to="`/shop/${store.slug}/product/${heroProduct.id}`" class="sf14-object-float" data-cursor="View" v-depth="{pointer:7,scroll:13,rotate:.38,scale:1.01,invert:true}">
              <MediaFrame class="sf14-object-float-media" :src="galleryImg(heroProduct)" :alt="heroProduct.name" tone="object" :transition-name="viewName('product', heroProduct.id)" fallback-title="Object image not supplied" @error="sfBrokenImg(heroProduct)" />
              <div><small>Featured object</small><strong>{{ heroProduct.name }}</strong><em>{{ tzs(heroProduct.price_tzs) }} ↗</em></div>
            </RouterLink>
          </div>
        </div>
      </div>
    </section>

    <!-- STORY / PLACE -->
    <section v-reveal="{variant:'section'}" class="sf14-story">
      <div class="sf14-shell">
        <div class="sf14-chapter"><span>THE STORY</span><i></i><small>02</small></div>
        <div class="sf14-story-grid">
          <div class="sf14-story-copy">
            <p class="sf14-story-eyebrow">{{ store.region ? `From ${store.region}` : 'Independent commerce' }}</p>
            <h2>{{ store.about ? 'The business behind the objects.' : 'A business made visible through what it moves.' }}</h2>
            <p class="sf14-about">{{ store.about || `${store.name} brings its collection into one visible Enkiama journey — from storefront and order through tracked movement and arrival.` }}</p>
          </div>

          <div class="sf14-story-side">
            <div class="sf14-note" v-if="store.ships_what"><span>What they sell</span><strong>{{ store.ships_what }}</strong></div>
            <div class="sf14-note" v-if="store.region"><span>Based in</span><strong>{{ store.region }}</strong></div>
            <div class="sf14-note" v-if="store.delivers_to"><span>Where it reaches</span><strong>{{ store.delivers_to }}</strong></div>
            <div class="sf14-note"><span>Marketplace path</span><strong>Business → Object → Movement → Arrival</strong></div>
          </div>
        </div>

        <div v-if="visualProducts.length > 1" class="sf14-story-media">
          <RouterLink v-for="(p,i) in visualProducts.slice(1,4)" :key="p.id" :to="`/shop/${store.slug}/product/${p.id}`" class="sf14-story-image" :class="`image-${i+1}`" data-cursor="View" v-reveal="{variant:'media',delay:Math.min(i*65,130)}">
            <MediaFrame class="sf14-story-media-frame" v-depth="{pointer:2.2,scroll:6,rotate:.12,scale:1.004}" :src="galleryImg(p)" :alt="p.name" tone="business" fallback-title="Object image not supplied" @error="sfBrokenImg(p)" />
            <span>{{ p.name }}</span>
          </RouterLink>
        </div>
      </div>
    </section>

    <!-- 03 / COLLECTIONS -->
    <section id="collections" class="sf14-collections">
      <div class="sf14-shell">
        <div class="sf14-section-head">
          <div>
            <span>03 / COLLECTIONS</span>
            <h2>What {{ store.name }}<br /><em>puts into the world.</em></h2>
          </div>
          <p>{{ liveProducts }} available now{{ grouped.length > 1 ? ` · ${grouped.length} collections` : '' }}. Every object continues into the same Enkiama order and tracked-delivery journey.</p>
        </div>

        <ExperienceState v-if="!products.length" kind="empty" world="business" eyebrow="Collection" title="The shelves are quiet for now." body="This business is visible, but it has not published a live collection yet." />
        <template v-else>
          <article v-for="(group,gi) in grouped" :id="collectionId(gi)" :key="group.id || gi" class="sf14-collection" :class="{'reverse': gi % 2 === 1}" v-reveal="{delay:Math.min(gi*45,180)}">
            <div class="sf14-collection-meta">
              <span>{{ String(gi + 1).padStart(2,'0') }}</span>
              <h3>{{ group.name || 'Collection' }}</h3>
              <p>{{ group.items.length }} {{ group.items.length === 1 ? 'object' : 'objects' }}</p>
            </div>

            <RouterLink v-if="group.items[0]" :to="`/shop/${store.slug}/product/${group.items[0].id}`" class="sf14-feature" data-cursor="View">
              <MediaFrame class="sf14-feature-media" v-depth="{pointer:2.4,scroll:6,rotate:.14,scale:1.004}" :src="galleryImg(group.items[0])" :alt="group.items[0].name" tone="object" :transition-name="viewName('product', group.items[0].id)" fallback-title="Object image not supplied" @error="sfBrokenImg(group.items[0])">
                <small v-if="group.items[0].available === false">Unavailable</small>
              </MediaFrame>
              <div class="sf14-feature-caption">
                <strong>{{ group.items[0].name }}</strong>
                <span>{{ tzs(group.items[0].price_tzs) }}</span>
                <em>View object ↗</em>
              </div>
            </RouterLink>

            <div class="sf14-ledger">
              <RouterLink v-for="(p,pi) in group.items.slice(1)" :key="p.id" :to="`/shop/${store.slug}/product/${p.id}`" class="sf14-row" :class="{muted:p.available === false}" data-cursor="View">
                <span class="sf14-row-no">{{ String(pi + 2).padStart(2,'0') }}</span>
                <MediaFrame class="sf14-row-thumb" :src="galleryImg(p)" :alt="p.name" tone="object" :transition-name="viewName('product', p.id)" fallback-title="" @error="sfBrokenImg(p)" />
                <div class="sf14-row-copy">
                  <strong>{{ p.name }}</strong>
                  <small v-if="prodRating(p)"><Icon name="star" :size="10" /> {{ prodRating(p).avg }} · {{ prodRating(p).count }} reviews</small>
                  <small v-else-if="p.category">{{ p.category }}</small>
                </div>
                <div class="sf14-row-price"><span>{{ p.available === false ? 'Unavailable' : tzs(p.price_tzs) }}</span><small v-if="p.compare_at_tzs > p.price_tzs && p.available !== false">was {{ tzs(p.compare_at_tzs) }}</small></div>
                <Icon name="arrowRight" :size="15" class="sf14-row-arrow" />
              </RouterLink>
            </div>
          </article>
        </template>
      </div>
    </section>

    <!-- 04 / MARKETPLACE RECORD -->
    <section v-reveal="{variant:'section'}" class="sf14-record">
      <div class="sf14-shell">
        <div class="sf14-record-head">
          <div>
            <span>04 / MARKETPLACE RECORD</span>
            <h2>Reputation should be<br /><em>visible, not decorative.</em></h2>
          </div>
          <p>These signals come from the business profile and Enkiama's tracked marketplace record. They are separated from the brand story so trust stays factual.</p>
        </div>

        <div class="sf14-record-grid">
          <div class="sf14-metrics">
            <div v-if="delivered !== null"><strong>{{ delivered }}</strong><span>tracked deliveries</span></div>
            <div v-if="onTime !== null"><strong>{{ onTime }}%</strong><span>on time</span></div>
            <div v-if="shopRating"><strong>{{ shopRating }}</strong><span>buyer rating{{ reviewCount ? ` · ${reviewCount}` : '' }}</span></div>
            <div v-if="delivered === null && onTime === null && !shopRating"><strong>{{ liveProducts }}</strong><span>objects listed</span></div>
          </div>

          <div class="sf14-proof-list">
            <div v-if="store.verified_delivery"><Icon name="shield" :size="17" /><div><strong>Verified delivery</strong><p>This storefront is marked for verified delivery in Enkiama's marketplace.</p></div></div>
            <div><Icon name="route" :size="17" /><div><strong>Tracked movement</strong><p>Orders move through Enkiama's carrier flow so custody remains visible through arrival.</p></div></div>
            <div v-if="store.since_year"><Icon name="check" :size="17" /><div><strong>Trading history</strong><p>{{ store.name }} reports trading since {{ store.since_year }}.</p></div></div>
          </div>
        </div>

        <div v-if="regionList.length" class="sf14-reach">
          <span>DELIVERY REACH</span>
          <div><i v-for="region in regionList" :key="region">{{ region }}</i></div>
        </div>
      </div>
    </section>

    <!-- BUYER NOTES -->
    <section v-if="reviews.length" v-reveal class="sf14-reviews">
      <div class="sf14-shell">
        <div class="sf14-chapter"><span>BUYER NOTES</span><i></i><small>{{ reviewCount || reviews.length }}</small></div>
        <div class="sf14-reviews-grid">
          <div class="sf14-review-intro">
            <h2>What arrival<br /><em>felt like.</em></h2>
            <p>Delivery feedback attached to this storefront. Product-specific reviews remain with each object.</p>
          </div>
          <div class="sf14-review-list">
            <blockquote v-for="(r,i) in reviews.slice(0,4)" :key="i">
              <div><Icon v-for="n in Number(r.rating || 0)" :key="n" name="star" :size="12" /></div>
              <p v-if="r.comment">“{{ r.comment }}”</p>
              <p v-else>Rated {{ r.rating }} out of 5.</p>
            </blockquote>
          </div>
        </div>
      </div>
    </section>

    <!-- 05 / CONTINUE -->
    <section v-reveal class="sf14-continue">
      <div class="sf14-shell">
        <span>05 / CONTINUE</span>
        <div class="sf14-continue-grid">
          <h2>Meet the business.<br />Choose the object.<br /><em>Follow the movement.</em></h2>
          <div class="sf14-continue-actions">
            <button v-if="products.length" class="sf14-action-primary dark" @click="scrollToCollections">Browse collection <Icon name="arrowRight" :size="14" /></button>
            <a v-if="store.phone" :href="`tel:${store.phone}`"><span>Contact {{ store.name }}</span><Icon name="phone" :size="14" /></a>
            <button @click="shareShop"><span>Share storefront</span><Icon name="arrowRight" :size="14" /></button>
            <RouterLink to="/track"><span>Track an existing order</span><Icon name="arrowRight" :size="14" /></RouterLink>
          </div>
        </div>
      </div>
    </section>

    <SiteFooter />
  </div>

  <ExperienceState v-else-if="loading" kind="loading" world="business" eyebrow="Business" title="Opening this storefront…" body="We are bringing the business identity, collection and marketplace record into view." />
  <ExperienceState v-else-if="loadError" kind="error" world="business" eyebrow="Business connection" title="This storefront did not load." :body="loadError"><button type="button" @click="load">Try again</button><RouterLink to="/market">Return to Market</RouterLink></ExperienceState>
  <ExperienceState v-else kind="empty" world="business" eyebrow="Business unavailable" title="This storefront is not currently published." body="It may have been removed or temporarily unpublished."><RouterLink to="/market">Explore other businesses</RouterLink></ExperienceState>
</template>

<style scoped>
.sf14{--sf:#0B6E5D;background:#f4efe5;color:var(--ink);overflow:hidden}
.sf14 *{box-sizing:border-box}
.sf14-shell{width:min(1240px,calc(100% - 84px));margin:0 auto}

/* HERO — warm paper + real business media, never a generic dark campaign panel */
.sf14-hero{position:relative;padding:34px 0 96px;background:
  radial-gradient(circle at 78% 20%,color-mix(in srgb,var(--sf) 8%,transparent),transparent 30%),
  linear-gradient(180deg,#f7f2e9 0%,#f1eadf 100%)}
.sf14-topline{display:flex;align-items:center;justify-content:space-between;padding-bottom:42px;border-bottom:1px solid rgba(45,38,31,.14);font-size:9px;letter-spacing:.17em;color:#7e756a;font-weight:700}
.sf14-back{display:inline-flex;align-items:center;gap:7px;text-decoration:none;color:#756c61;text-transform:uppercase;font-size:10px;letter-spacing:.12em}.sf14-back svg{transform:rotate(180deg)}.sf14-back:hover{color:#211f1b}
.sf14-hero-grid{display:grid;grid-template-columns:minmax(0,.82fr) minmax(460px,1.18fr);gap:86px;align-items:center;padding-top:72px}
.sf14-identity{padding:22px 0 10px}
.sf14-brandline{display:flex;align-items:center;gap:16px;margin-bottom:42px}.sf14-avatar{box-shadow:0 18px 46px rgba(77,61,43,.12);border:1px solid rgba(53,44,35,.12)}
.sf14-brandline>div{display:flex;flex-direction:column;gap:5px}.sf14-brandline span{font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:#665e55;font-weight:700}.sf14-brandline small{font:italic 17px/1.2 'Cormorant Garamond',serif;color:#95897b}
.sf14-identity h1{font:500 clamp(48px,6vw,82px)/.94 'Space Grotesk',sans-serif;letter-spacing:-.065em;max-width:620px;color:#1d211d}
.sf14-tagline{font:400 clamp(22px,2.4vw,31px)/1.22 'Cormorant Garamond',serif;color:#62594f;max-width:540px;margin-top:24px}
.sf14-actions{display:flex;align-items:center;gap:20px;flex-wrap:wrap;margin-top:38px}.sf14-action-primary{border:0;background:#20392f;color:#fff;min-height:47px;padding:0 18px;display:inline-flex;align-items:center;justify-content:space-between;gap:22px;font:700 10px/1 'Inter',sans-serif;letter-spacing:.1em;text-transform:uppercase;cursor:pointer;transition:transform .25s ease,background .25s ease}.sf14-action-primary:hover{transform:translateY(-2px);background:#172c24}.sf14-action-primary.dark{background:#1c2823}.sf14-action-line{border:0;border-bottom:1px solid rgba(40,35,30,.28);background:transparent;color:#544d45;padding:12px 0;font:650 11px/1 'Inter',sans-serif;text-decoration:none;cursor:pointer}.sf14-action-line:hover{border-color:#1f241f;color:#1f241f}
.sf14-identity-ledger{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;margin-top:64px;padding-top:20px;border-top:1px solid rgba(46,39,32,.15)}.sf14-identity-ledger div{display:flex;flex-direction:column;gap:7px}.sf14-identity-ledger span{font-size:8px;letter-spacing:.15em;text-transform:uppercase;color:#9b9083;font-weight:700}.sf14-identity-ledger strong{font-size:11px;line-height:1.45;color:#5e564d;font-weight:600}
.sf14-visual{position:relative;min-height:610px}.sf14-visual-frame{height:570px;overflow:hidden;background:#ded4c6;box-shadow:0 34px 80px rgba(74,56,38,.15)}.sf14-visual-frame img{width:100%;height:100%;display:block;object-fit:cover}.sf14-visual.is-object .sf14-visual-frame{background:linear-gradient(145deg,#e6ded3,#d8cdbc);padding:54px}.sf14-visual.is-object .sf14-visual-frame img{object-fit:contain;filter:drop-shadow(0 28px 34px rgba(52,41,31,.17))}
.sf14-visual-fallback{width:100%;height:100%;display:grid;place-content:center;text-align:center;gap:8px;background:linear-gradient(145deg,color-mix(in srgb,var(--sf) 8%,#e9dfd2),#d9cdbd)}.sf14-visual-fallback span{font:500 92px/1 'Cormorant Garamond',serif;color:color-mix(in srgb,var(--sf) 70%,#5b544c)}.sf14-visual-fallback small{font-size:9px;text-transform:uppercase;letter-spacing:.16em;color:#7b7064}
.sf14-visual-caption{display:grid;grid-template-columns:1fr auto;gap:5px 18px;padding-top:14px}.sf14-visual-caption>span{grid-column:1/-1;font-size:8px;letter-spacing:.16em;color:#9a8f82;font-weight:700}.sf14-visual-caption strong{font-size:12px;font-weight:600;color:#454038}.sf14-visual-caption small{font-size:10px;color:#80766b}
.sf14-object-float{position:absolute;left:-74px;bottom:34px;width:225px;padding:10px;background:#fbf8f2;box-shadow:0 24px 55px rgba(63,48,35,.2);color:#24231f;text-decoration:none}.sf14-object-float-media{height:170px;background:#eee7dc;overflow:hidden}.sf14-object-float-media img{width:100%;height:100%;object-fit:cover}.sf14-object-float-media>span{height:100%;display:grid;place-items:center;font:500 44px 'Cormorant Garamond',serif;color:#8f8171}.sf14-object-float>div:last-child{display:grid;grid-template-columns:1fr auto;gap:4px 10px;padding:10px 4px 2px}.sf14-object-float small{grid-column:1/-1;font-size:7.5px;letter-spacing:.14em;text-transform:uppercase;color:#a09283}.sf14-object-float strong{font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.sf14-object-float em{font-size:9px;font-style:normal;color:#756b61}

/* STORY */
.sf14-story{background:#fbf8f2;padding:118px 0 130px}.sf14-chapter{display:flex;align-items:center;gap:18px;margin-bottom:64px}.sf14-chapter>span{font-size:8px;font-weight:750;letter-spacing:.18em;color:#897e70}.sf14-chapter i{height:1px;background:rgba(47,40,33,.13);flex:1}.sf14-chapter small{font-size:9px;color:#ada192}
.sf14-story-grid{display:grid;grid-template-columns:1.12fr .88fr;gap:116px;align-items:start}.sf14-story-eyebrow{font:italic 20px 'Cormorant Garamond',serif;color:color-mix(in srgb,var(--sf) 62%,#766858);margin-bottom:15px}.sf14-story-copy h2{font:500 clamp(40px,5vw,66px)/.98 'Space Grotesk',sans-serif;letter-spacing:-.058em;max-width:720px}.sf14-about{font:400 19px/1.72 'Cormorant Garamond',serif;color:#5c554c;max-width:700px;margin-top:35px}.sf14-story-side{border-top:1px solid rgba(45,38,31,.16)}.sf14-note{display:grid;grid-template-columns:145px 1fr;gap:25px;padding:19px 0;border-bottom:1px solid rgba(45,38,31,.13)}.sf14-note span{font-size:8px;text-transform:uppercase;letter-spacing:.14em;color:#9a8e80;font-weight:700}.sf14-note strong{font-size:12px;line-height:1.5;color:#544d45;font-weight:600}
.sf14-story-media{display:grid;grid-template-columns:1.35fr .78fr .9fr;gap:18px;align-items:end;margin-top:88px}.sf14-story-image{position:relative;display:block;overflow:hidden;background:#e5dcd0;color:#fff;text-decoration:none}.sf14-story-image.image-1{height:480px}.sf14-story-image.image-2{height:330px}.sf14-story-image.image-3{height:390px}.sf14-story-image img{width:100%;height:100%;object-fit:cover;display:block;transition:transform .7s cubic-bezier(.2,.75,.2,1)}.sf14-story-image:hover img{transform:scale(1.025)}.sf14-story-image::after{content:"";position:absolute;inset:auto 0 0;height:40%;background:linear-gradient(transparent,rgba(17,17,14,.55))}.sf14-story-image span{position:absolute;left:16px;right:16px;bottom:14px;z-index:2;font-size:10px;font-weight:600}

/* COLLECTIONS */
.sf14-collections{background:#eee6da;padding:122px 0 140px}.sf14-section-head{display:flex;justify-content:space-between;align-items:end;gap:50px;margin-bottom:82px}.sf14-section-head>div>span,.sf14-record-head>div>span,.sf14-continue>.sf14-shell>span{font-size:8px;letter-spacing:.18em;color:#8e8274;font-weight:750}.sf14-section-head h2,.sf14-record-head h2{font:500 clamp(40px,5vw,64px)/1 'Space Grotesk',sans-serif;letter-spacing:-.058em;margin-top:16px}.sf14-section-head h2 em,.sf14-record-head h2 em,.sf14-review-intro h2 em,.sf14-continue h2 em{font-family:'Cormorant Garamond',serif;font-weight:400;color:color-mix(in srgb,var(--sf) 58%,#7b6650)}.sf14-section-head>p,.sf14-record-head>p{max-width:370px;font-size:11px;line-height:1.65;color:#81766a;text-align:right}
.sf14-collection{display:grid;grid-template-columns:145px minmax(380px,1.08fr) minmax(300px,.92fr);gap:38px;align-items:start;padding:74px 0;border-top:1px solid rgba(44,38,31,.16)}.sf14-collection.reverse{grid-template-columns:145px minmax(300px,.92fr) minmax(380px,1.08fr)}.sf14-collection.reverse .sf14-feature{grid-column:3}.sf14-collection.reverse .sf14-ledger{grid-column:2;grid-row:1}.sf14-collection-meta>span{font-size:9px;color:#a39484}.sf14-collection-meta h3{font:500 25px/1.05 'Space Grotesk',sans-serif;letter-spacing:-.04em;margin:17px 0 8px}.sf14-collection-meta p{font-size:9px;text-transform:uppercase;letter-spacing:.12em;color:#988b7c}
.sf14-feature{color:#25231f;text-decoration:none}.sf14-feature-media{height:545px;background:#ddd2c2;overflow:hidden;position:relative;box-shadow:0 22px 54px rgba(63,48,33,.1)}.sf14-feature-media img{width:100%;height:100%;object-fit:cover;display:block;transition:transform .7s cubic-bezier(.2,.75,.2,1)}.sf14-feature:hover img{transform:scale(1.022)}.sf14-feature-media>small{position:absolute;left:12px;top:12px;background:#f6f0e6;color:#4d463f;padding:7px 9px;font-size:8px;text-transform:uppercase;letter-spacing:.1em}.sf14-feature-fallback{height:100%;display:grid;place-items:center;background:linear-gradient(145deg,color-mix(in srgb,var(--sf) 12%,#e6dbcd),#d6c8b7)}.sf14-feature-fallback span{font:500 62px 'Cormorant Garamond',serif;color:#8f7f6d}.sf14-feature-caption{display:grid;grid-template-columns:1fr auto;gap:5px 15px;padding-top:14px}.sf14-feature-caption strong{font-size:13px;font-weight:600}.sf14-feature-caption>span{font-size:12px;font-weight:650}.sf14-feature-caption em{grid-column:1/-1;font-size:8px;text-transform:uppercase;letter-spacing:.12em;color:#968a7c;font-style:normal}
.sf14-ledger{border-top:1px solid rgba(45,38,31,.18)}.sf14-row{display:grid;grid-template-columns:24px 58px minmax(0,1fr) auto 16px;gap:12px;align-items:center;padding:14px 0;border-bottom:1px solid rgba(45,38,31,.13);text-decoration:none;color:#292722;transition:padding .2s ease}.sf14-row:hover{padding-left:4px}.sf14-row.muted{opacity:.48}.sf14-row-no{font-size:8px;color:#a99c8c}.sf14-row-thumb{width:58px;height:68px;background:#d8cbb9;overflow:hidden}.sf14-row-thumb img,.sf14-row-thumb>span{display:block;width:100%;height:100%;object-fit:cover}.sf14-row-copy{min-width:0;display:flex;flex-direction:column;gap:5px}.sf14-row-copy strong{font-size:11.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.sf14-row-copy small{font-size:9px;color:#8e8274;display:flex;align-items:center;gap:4px}.sf14-row-price{display:flex;flex-direction:column;gap:4px;text-align:right;white-space:nowrap}.sf14-row-price span{font-size:10.5px;font-weight:650}.sf14-row-price small{font-size:8px;color:#a39687;text-decoration:line-through}.sf14-row-arrow{color:#a09281}

/* MARKETPLACE RECORD — clay/paper, not another dark panel */
.sf14-record{background:linear-gradient(145deg,#d8c5ae 0%,#eadfd1 58%,#f2e9de 100%);padding:122px 0 128px}.sf14-record-head{display:flex;justify-content:space-between;gap:70px;align-items:end;margin-bottom:68px}.sf14-record-head>p{text-align:left}.sf14-record-grid{display:grid;grid-template-columns:1.05fr .95fr;gap:90px;padding:48px 0 62px;border-top:1px solid rgba(61,49,38,.18);border-bottom:1px solid rgba(61,49,38,.18)}.sf14-metrics{display:grid;grid-template-columns:repeat(3,1fr);gap:24px;align-content:start}.sf14-metrics div{display:flex;flex-direction:column;gap:8px}.sf14-metrics strong{font:500 clamp(39px,5vw,61px)/1 'Space Grotesk',sans-serif;letter-spacing:-.055em;color:#2d312b}.sf14-metrics span{font-size:8px;text-transform:uppercase;letter-spacing:.13em;color:#7f7265}.sf14-proof-list>div{display:grid;grid-template-columns:27px 1fr;gap:13px;padding:17px 0;border-bottom:1px solid rgba(58,48,39,.15)}.sf14-proof-list>div:first-child{padding-top:0}.sf14-proof-list svg{color:color-mix(in srgb,var(--sf) 75%,#435b4e)}.sf14-proof-list strong{display:block;font-size:11px;margin-bottom:5px}.sf14-proof-list p{font-size:10.5px;line-height:1.55;color:#706459}.sf14-reach{display:grid;grid-template-columns:170px 1fr;gap:35px;padding-top:34px}.sf14-reach>span{font-size:8px;letter-spacing:.16em;color:#837669;font-weight:750}.sf14-reach>div{display:flex;gap:9px 24px;flex-wrap:wrap}.sf14-reach i{font:400 21px 'Cormorant Garamond',serif;color:#4b4841;font-style:italic}

/* REVIEWS */
.sf14-reviews{background:#fbf8f2;padding:112px 0 124px}.sf14-reviews-grid{display:grid;grid-template-columns:340px 1fr;gap:100px}.sf14-review-intro h2{font:500 45px/1.02 'Space Grotesk',sans-serif;letter-spacing:-.05em}.sf14-review-intro p{font-size:10.5px;line-height:1.65;color:#897d70;margin-top:20px}.sf14-review-list{display:grid;grid-template-columns:repeat(2,1fr);gap:0 35px}.sf14-review-list blockquote{margin:0;padding:18px 0 28px;border-top:1px solid rgba(47,40,33,.14)}.sf14-review-list blockquote>div{display:flex;gap:2px;color:#b58d43;margin-bottom:14px}.sf14-review-list p{font:400 17px/1.55 'Cormorant Garamond',serif;color:#565047}

/* CONTINUE */
.sf14-continue{background:#f2eadf;padding:114px 0 128px}.sf14-continue-grid{display:grid;grid-template-columns:1fr 430px;gap:110px;align-items:start;margin-top:28px}.sf14-continue h2{font:500 clamp(39px,5vw,62px)/1.02 'Space Grotesk',sans-serif;letter-spacing:-.055em}.sf14-continue-actions{display:flex;flex-direction:column}.sf14-continue-actions .sf14-action-primary{align-self:flex-start;margin-bottom:25px}.sf14-continue-actions>a,.sf14-continue-actions>button:not(.sf14-action-primary){display:flex;justify-content:space-between;align-items:center;min-height:52px;padding:0;border:0;border-top:1px solid rgba(45,38,31,.15);background:transparent;color:#544d45;text-decoration:none;font:600 11px 'Inter',sans-serif;cursor:pointer;text-align:left}.sf14-continue-actions>*:last-child{border-bottom:1px solid rgba(45,38,31,.15)}

.sf14-loading{min-height:68vh;background:#f3ecdf;color:#2b2b25;display:grid;place-content:center;text-align:center;gap:12px}.sf14-loading span{font-size:8px;letter-spacing:.18em;color:#998c7d}.sf14-loading p{font:400 24px 'Cormorant Garamond',serif;font-style:italic;color:#686056}

@media(max-width:1080px){
  .sf14-shell{width:min(100% - 56px,1120px)}
  .sf14-hero-grid{grid-template-columns:.9fr 1.1fr;gap:52px}.sf14-object-float{left:-35px}.sf14-visual{min-height:560px}.sf14-visual-frame{height:520px}
  .sf14-story-grid{gap:65px}.sf14-story-media{grid-template-columns:1.25fr .8fr}.sf14-story-image.image-3{display:none}
  .sf14-collection,.sf14-collection.reverse{grid-template-columns:120px 1fr;gap:28px}.sf14-collection .sf14-feature,.sf14-collection.reverse .sf14-feature{grid-column:2;grid-row:1}.sf14-collection .sf14-ledger,.sf14-collection.reverse .sf14-ledger{grid-column:2;grid-row:2}.sf14-collection-meta{grid-row:1 / span 2}.sf14-feature-media{height:520px}
  .sf14-record-grid{gap:50px}.sf14-reviews-grid{gap:55px}.sf14-continue-grid{gap:65px}
}

@media(max-width:760px){
  .sf14-shell{width:calc(100% - 40px)}.sf14-hero{padding-top:24px;padding-bottom:72px}.sf14-topline{padding-bottom:26px}.sf14-hero-grid{grid-template-columns:1fr;gap:46px;padding-top:48px}.sf14-brandline{margin-bottom:30px}.sf14-avatar{width:66px!important;height:66px!important}.sf14-identity h1{font-size:clamp(44px,13vw,62px)}.sf14-tagline{font-size:24px}.sf14-actions{align-items:stretch}.sf14-action-primary{flex:1 0 100%}.sf14-identity-ledger{margin-top:44px}.sf14-visual{min-height:auto;padding-bottom:0}.sf14-visual-frame{height:auto;aspect-ratio:4/5}.sf14-visual.is-object .sf14-visual-frame{padding:28px}.sf14-object-float{position:relative;left:auto;bottom:auto;width:58%;margin:-95px 14px 0 auto;z-index:3}.sf14-object-float-media{height:auto;aspect-ratio:1/1}.sf14-visual-caption{padding-right:44%}
  .sf14-story{padding:84px 0 94px}.sf14-chapter{margin-bottom:42px}.sf14-story-grid{grid-template-columns:1fr;gap:46px}.sf14-story-copy h2{font-size:42px}.sf14-about{font-size:17px;margin-top:27px}.sf14-note{grid-template-columns:110px 1fr}.sf14-story-media{grid-template-columns:1.18fr .82fr;gap:10px;margin-top:58px}.sf14-story-image.image-1{height:390px}.sf14-story-image.image-2{height:285px}
  .sf14-collections{padding:86px 0 98px}.sf14-section-head,.sf14-record-head{align-items:start;flex-direction:column;gap:25px;margin-bottom:52px}.sf14-section-head h2,.sf14-record-head h2{font-size:42px}.sf14-section-head>p,.sf14-record-head>p{text-align:left}.sf14-collection,.sf14-collection.reverse{display:block;padding:54px 0}.sf14-collection-meta{display:grid;grid-template-columns:30px 1fr auto;gap:8px;align-items:end;margin-bottom:22px}.sf14-collection-meta h3{margin:0;font-size:23px}.sf14-feature-media{height:auto;aspect-ratio:4/5;margin-left:-20px;margin-right:-20px}.sf14-ledger{margin-top:28px}.sf14-row{min-height:74px;grid-template-columns:20px 51px minmax(0,1fr) auto 14px;gap:9px}.sf14-row-thumb{width:51px;height:61px}.sf14-row-price small{display:none}
  .sf14-record{padding:88px 0 94px}.sf14-record-grid{grid-template-columns:1fr;gap:48px;padding:38px 0 48px}.sf14-metrics{gap:18px}.sf14-metrics strong{font-size:43px}.sf14-reach{grid-template-columns:1fr;gap:18px}.sf14-reach i{font-size:19px}
  .sf14-reviews{padding:82px 0 94px}.sf14-reviews-grid{grid-template-columns:1fr;gap:42px}.sf14-review-intro h2{font-size:40px}.sf14-review-list{grid-template-columns:1fr}
  .sf14-continue{padding:85px 0 96px}.sf14-continue-grid{grid-template-columns:1fr;gap:48px}.sf14-continue h2{font-size:43px}
}

@media(max-width:470px){
  .sf14-shell{width:calc(100% - 28px)}.sf14-topline>span{display:none}.sf14-brandline small{font-size:15px}.sf14-identity h1{font-size:43px}.sf14-tagline{font-size:21px}.sf14-identity-ledger{grid-template-columns:1fr;gap:12px}.sf14-identity-ledger div{display:grid;grid-template-columns:80px 1fr;gap:10px}.sf14-visual-frame{margin-left:-14px;margin-right:-14px}.sf14-object-float{width:66%;margin-right:0}.sf14-visual-caption{padding-right:0}.sf14-story-copy h2,.sf14-section-head h2,.sf14-record-head h2,.sf14-continue h2{font-size:38px}.sf14-story-media{margin-left:-14px;margin-right:-14px}.sf14-story-image.image-1{height:340px}.sf14-story-image.image-2{height:250px}.sf14-note{grid-template-columns:1fr;gap:5px}.sf14-feature-media{margin-left:-14px;margin-right:-14px}.sf14-row{grid-template-columns:18px 44px minmax(0,1fr) 14px;grid-template-rows:auto auto}.sf14-row-no,.sf14-row-thumb{grid-row:1/3}.sf14-row-thumb{width:44px;height:54px}.sf14-row-copy{grid-column:3;grid-row:1}.sf14-row-price{grid-column:3;grid-row:2;text-align:left}.sf14-row-arrow{grid-column:4;grid-row:1/3}.sf14-row-copy small{display:none}.sf14-metrics{grid-template-columns:1fr 1fr}.sf14-review-intro h2{font-size:36px}
}

@media(prefers-reduced-motion:reduce){.sf14 *, .sf14 *::before, .sf14 *::after{scroll-behavior:auto!important;transition:none!important;animation:none!important}}

/* PHASE 18 — governed media behavior */
.sf14-story-image:hover .sf14-story-media-frame :deep(img),.sf14-feature:hover .sf14-feature-media :deep(img){transform:scale(1.022)}
.sf14-object-float:hover .sf14-object-float-media :deep(img){transform:scale(1.018)}
@media(prefers-reduced-motion:reduce){.sf14-story-media-frame :deep(img),.sf14-feature-media :deep(img),.sf14-object-float-media :deep(img){transform:none!important;transition:none!important}}
</style>
