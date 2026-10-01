<script setup>
import { ref, onMounted, computed, watch, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import { usePublic } from '../composables/usePublic'
import Icon from '../components/Icon.vue'
import AppHeader from '../components/AppHeader.vue'
import Avatar from '../components/Avatar.vue'
import BrandMark from '../components/BrandMark.vue'
import EmptyState from '../components/EmptyState.vue'
import { viewName, signalMotionReady } from '../lib/motion'
import { supabase } from '../lib/supabase'

const route = useRoute()
const pub = usePublic()
const data = ref(null)
const loading = ref(true)
const shopRep = ref(null)
const productRatings = ref({})
const sfBroken = ref(new Set())

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
const businessSince = computed(() => store.value?.since_year ? `Since ${store.value.since_year}` : 'Independent business')
const storefrontStyle = computed(() => ({ '--sf': store.value?.accent || '#0B6E5D' }))

async function load() {
  loading.value = true
  data.value = null
  shopRep.value = null
  productRatings.value = {}
  sfBroken.value = new Set()
  const { data: res } = await pub.getStorefront(route.params.slug)
  data.value = res
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
  const url = (Array.isArray(p.images) && p.images.length ? p.images[0] : p.image_url) || ''
  const u = String(url).trim()
  return (u && u !== 'null' && u.startsWith('http')) ? u : ''
}
function sfBrokenImg(p) {
  if (!p?.id) return
  sfBroken.value.add(p.id)
  sfBroken.value = new Set(sfBroken.value)
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
  <div v-if="!loading && store" class="sf6" :style="storefrontStyle">
    <AppHeader :title="store.name" subtitle="Business" :market="true" />

    <!-- 01 / IDENTITY -->
    <section class="sf6-hero">
      <div class="sf6-cover" :class="{'has-image': !!store.cover_url}" :style="store.cover_url ? {backgroundImage:`url(${store.cover_url})`} : {}">
        <div class="sf6-cover-wash"></div>
        <div class="sf6-cover-orbit sf6-orbit-a"></div>
        <div class="sf6-cover-orbit sf6-orbit-b"></div>
      </div>

      <div class="sf6-hero-inner">
        <div class="sf6-topline">
          <RouterLink to="/market" class="sf6-back"><Icon name="arrow" :size="14" /> Market</RouterLink>
          <span class="sf6-index">01 / IDENTITY</span>
        </div>

        <div class="sf6-identity-grid">
          <div class="sf6-identity-main">
            <Avatar :name="store.name" :accent="store.accent" :logo="store.logo_url" :size="88" class="sf6-avatar" :style="{viewTransitionName:viewName('shop', store.slug || store.id)}" />
            <div class="sf6-kicker">
              <span v-if="store.region">{{ store.region }}</span>
              <span v-if="store.region" class="sf6-dot">•</span>
              <span>{{ businessSince }}</span>
            </div>
            <h1>{{ store.name }}</h1>
            <p v-if="store.tagline" class="sf6-tagline">{{ store.tagline }}</p>
            <p v-else-if="store.ships_what" class="sf6-tagline">{{ store.ships_what }}</p>

            <div class="sf6-hero-actions">
              <button v-if="products.length" class="sf6-primary" @click="scrollToCollections">Explore collection <Icon name="arrowRight" :size="14" /></button>
              <a v-if="store.phone" :href="`tel:${store.phone}`" class="sf6-text-action">Contact business</a>
              <button class="sf6-text-action" @click="shareShop">Share</button>
            </div>
          </div>

          <div class="sf6-identity-side">
            <div class="sf6-record-line">
              <span>Marketplace record</span>
              <strong v-if="delivered !== null">{{ delivered }} delivered</strong>
              <strong v-else>{{ liveProducts }} live products</strong>
            </div>
            <div class="sf6-record-line" v-if="onTime !== null">
              <span>On-time fulfilment</span><strong>{{ onTime }}%</strong>
            </div>
            <div class="sf6-record-line" v-if="shopRating">
              <span>Buyer rating</span><strong>{{ shopRating }} / 5 <small v-if="reviewCount">· {{ reviewCount }}</small></strong>
            </div>
            <div class="sf6-record-line" v-if="store.verified_delivery">
              <span>Delivery status</span><strong class="sf6-verified"><Icon name="check" :size="12" /> Verified delivery</strong>
            </div>
          </div>
        </div>

        <RouterLink v-if="heroProduct" :to="`/shop/${store.slug}/product/${heroProduct.id}`" class="sf6-hero-object" data-cursor="View">
          <div class="sf6-hero-object-media">
            <img v-if="galleryImg(heroProduct)" :src="galleryImg(heroProduct)" :alt="heroProduct.name" @error="sfBrokenImg(heroProduct)" />
            <div v-else class="sf6-hero-object-ph"><span>{{ (heroProduct.name || '?').slice(0,1).toUpperCase() }}</span></div>
          </div>
          <div class="sf6-hero-object-caption">
            <span>Featured object</span>
            <strong>{{ heroProduct.name }}</strong>
            <em>{{ tzs(heroProduct.price_tzs) }} ↗</em>
          </div>
        </RouterLink>
      </div>
    </section>

    <!-- BUSINESS STORY -->
    <section v-reveal class="sf6-story">
      <div class="sf6-section-label"><span>THE BUSINESS</span><i></i></div>
      <div class="sf6-story-grid">
        <h2>{{ store.about ? 'A storefront with a point of view.' : 'Built to move through Enkiama.' }}</h2>
        <div>
          <p v-if="store.about" class="sf6-about">{{ store.about }}</p>
          <p v-else class="sf6-about">Products from {{ store.name }} move through tracked Enkiama delivery, giving the buyer one visible journey from order to arrival.</p>
          <div class="sf6-story-facts">
            <div v-if="store.ships_what"><span>What moves</span><strong>{{ store.ships_what }}</strong></div>
            <div v-if="store.region"><span>Based in</span><strong>{{ store.region }}</strong></div>
            <div v-if="store.delivers_to"><span>Reaches</span><strong>{{ store.delivers_to }}</strong></div>
          </div>
        </div>
      </div>
    </section>

    <!-- 02 / COLLECTIONS -->
    <section id="collections" class="sf6-collections">
      <div class="sf6-section-head">
        <div>
          <span class="sf6-index dark">02 / COLLECTIONS</span>
          <h2>Objects from {{ store.name }}</h2>
        </div>
        <p>{{ liveProducts }} available now{{ grouped.length > 1 ? ` · ${grouped.length} collections` : '' }}</p>
      </div>

      <EmptyState v-if="!products.length" icon="package" title="No products listed yet" />
      <template v-else>
        <article v-for="(group,gi) in grouped" :id="collectionId(gi)" :key="group.id || gi" class="sf6-collection" :class="{'reverse': gi % 2 === 1}" v-reveal="{delay:Math.min(gi*45,180)}">
          <div class="sf6-collection-title">
            <span>{{ String(gi + 1).padStart(2,'0') }}</span>
            <h3>{{ group.name || 'Collection' }}</h3>
            <p>{{ group.items.length }} {{ group.items.length === 1 ? 'piece' : 'pieces' }}</p>
          </div>

          <RouterLink v-if="group.items[0]" :to="`/shop/${store.slug}/product/${group.items[0].id}`" class="sf6-feature-product" data-cursor="View">
            <div class="sf6-feature-media" :style="{viewTransitionName:viewName('product', group.items[0].id)}">
              <img v-if="galleryImg(group.items[0])" :src="galleryImg(group.items[0])" :alt="group.items[0].name" loading="lazy" @error="sfBrokenImg(group.items[0])" />
              <div v-else class="sf6-feature-ph"><span>{{ (group.items[0].name || '?').slice(0,1).toUpperCase() }}</span></div>
              <span v-if="group.items[0].available === false" class="sf6-state">Unavailable</span>
              <span v-else-if="group.items[0].compare_at_tzs > group.items[0].price_tzs" class="sf6-state">{{ Math.round((1 - group.items[0].price_tzs/group.items[0].compare_at_tzs)*100) }}% less</span>
            </div>
            <div class="sf6-feature-copy">
              <strong>{{ group.items[0].name }}</strong>
              <span>{{ tzs(group.items[0].price_tzs) }}</span>
              <em>View object ↗</em>
            </div>
          </RouterLink>

          <div class="sf6-product-ledger">
            <RouterLink v-for="(p,pi) in group.items.slice(1)" :key="p.id" :to="`/shop/${store.slug}/product/${p.id}`" class="sf6-product-row" :class="{muted:p.available === false}" data-cursor="View">
              <span class="sf6-product-no">{{ String(pi + 2).padStart(2,'0') }}</span>
              <div class="sf6-product-thumb" :style="{viewTransitionName:viewName('product', p.id)}">
                <img v-if="galleryImg(p)" :src="galleryImg(p)" :alt="p.name" loading="lazy" @error="sfBrokenImg(p)" />
                <span v-else :style="{background:store.accent || '#0B6E5D'}"></span>
              </div>
              <div class="sf6-product-copy">
                <strong>{{ p.name }}</strong>
                <small v-if="prodRating(p)"><Icon name="star" :size="10" /> {{ prodRating(p).avg }} · {{ prodRating(p).count }} reviews</small>
                <small v-else-if="p.category">{{ p.category }}</small>
              </div>
              <div class="sf6-product-price">
                <span>{{ p.available === false ? 'Unavailable' : tzs(p.price_tzs) }}</span>
                <small v-if="p.compare_at_tzs > p.price_tzs && p.available !== false">was {{ tzs(p.compare_at_tzs) }}</small>
              </div>
              <Icon name="arrowRight" :size="15" class="sf6-row-arrow" />
            </RouterLink>
          </div>
        </article>
      </template>
    </section>

    <!-- 03 / PROVENANCE -->
    <section v-reveal class="sf6-provenance">
      <div class="sf6-provenance-inner">
        <div class="sf6-section-head light">
          <div>
            <span class="sf6-index">03 / PROVENANCE</span>
            <h2>How this business moves.</h2>
          </div>
          <p>Signals below come from the business profile and Enkiama's tracked marketplace record.</p>
        </div>

        <div class="sf6-provenance-grid">
          <div class="sf6-provenance-main">
            <div class="sf6-metric" v-if="delivered !== null"><strong>{{ delivered }}</strong><span>tracked deliveries</span></div>
            <div class="sf6-metric" v-if="onTime !== null"><strong>{{ onTime }}%</strong><span>on time</span></div>
            <div class="sf6-metric" v-if="shopRating"><strong>{{ shopRating }}</strong><span>buyer rating{{ reviewCount ? ` · ${reviewCount} reviews` : '' }}</span></div>
            <div class="sf6-metric" v-if="delivered === null && onTime === null && !shopRating"><strong>{{ liveProducts }}</strong><span>products currently listed</span></div>
          </div>

          <div class="sf6-provenance-copy">
            <div class="sf6-proof" v-if="store.verified_delivery">
              <Icon name="shield" :size="17" />
              <div><strong>Verified delivery</strong><p>This storefront is marked for verified delivery in Enkiama's marketplace.</p></div>
            </div>
            <div class="sf6-proof">
              <Icon name="route" :size="17" />
              <div><strong>Tracked movement</strong><p>Orders move through the platform's carrier flow so buyer and seller can follow custody through arrival.</p></div>
            </div>
            <div class="sf6-proof" v-if="store.since_year">
              <Icon name="check" :size="17" />
              <div><strong>Trading history</strong><p>{{ store.name }} reports trading since {{ store.since_year }}.</p></div>
            </div>
          </div>
        </div>

        <div v-if="regionList.length" class="sf6-regions">
          <span>DELIVERY REACH</span>
          <div><i v-for="region in regionList" :key="region">{{ region }}</i></div>
        </div>

        <div v-if="reviews.length" class="sf6-reviews">
          <div class="sf6-review-intro">
            <span>BUYER EXPERIENCE</span>
            <h3>What arrival felt like.</h3>
            <p>Delivery feedback attached to this storefront. Product-specific reviews remain with each object.</p>
          </div>
          <div class="sf6-review-list">
            <blockquote v-for="(r,i) in reviews.slice(0,4)" :key="i">
              <div class="sf6-stars"><Icon v-for="n in Number(r.rating || 0)" :key="n" name="star" :size="12" /></div>
              <p v-if="r.comment">“{{ r.comment }}”</p>
              <p v-else>Rated {{ r.rating }} out of 5.</p>
            </blockquote>
          </div>
        </div>
      </div>
    </section>

    <!-- 04 / CONTINUE -->
    <section v-reveal class="sf6-continue">
      <span class="sf6-index dark">04 / CONTINUE</span>
      <div class="sf6-continue-grid">
        <h2>Start with the business.<br />Continue with the object.</h2>
        <div class="sf6-continue-actions">
          <button v-if="products.length" class="sf6-primary dark" @click="scrollToCollections">Browse collection <Icon name="arrowRight" :size="14" /></button>
          <a v-if="store.phone" :href="`tel:${store.phone}`" class="sf6-line-action"><span>Contact {{ store.name }}</span><Icon name="phone" :size="14" /></a>
          <button class="sf6-line-action" @click="shareShop"><span>Share storefront</span><Icon name="arrowRight" :size="14" /></button>
          <RouterLink to="/track" class="sf6-line-action"><span>Track an existing order</span><Icon name="arrowRight" :size="14" /></RouterLink>
        </div>
      </div>
    </section>

    <footer class="sf6-foot"><BrandMark variant="full" :height="32" /><p>Enkiama · Business, object and movement in one visible journey.</p></footer>
  </div>

  <div v-else-if="loading" class="sf6-loading">
    <span>ENKIAMA / BUSINESS</span>
    <p>Opening storefront…</p>
  </div>
  <EmptyState v-else icon="search" title="Shop not found" hint="This storefront doesn't exist or was removed." />
</template>

<style scoped>
.sf6{--sf:#0B6E5D;background:var(--surface);color:var(--ink);overflow:hidden}
.sf6 *{box-sizing:border-box}
.sf6-hero{position:relative;min-height:720px;background:#0d1512;color:#fff;isolation:isolate}
.sf6-cover{position:absolute;inset:0;overflow:hidden;background:radial-gradient(circle at 72% 28%,color-mix(in srgb,var(--sf) 58%,#243c32),transparent 32%),linear-gradient(145deg,#15211d 0%,#0b100e 68%);background-size:cover;background-position:center}
.sf6-cover.has-image{filter:saturate(.82)}
.sf6-cover-wash{position:absolute;inset:0;background:linear-gradient(90deg,rgba(8,13,11,.94) 0%,rgba(8,13,11,.73) 44%,rgba(8,13,11,.35) 72%,rgba(8,13,11,.64) 100%),linear-gradient(0deg,rgba(7,10,9,.94),transparent 45%)}
.sf6-cover-orbit{position:absolute;border:1px solid rgba(255,255,255,.09);border-radius:50%;pointer-events:none}
.sf6-orbit-a{width:620px;height:620px;right:-160px;top:-220px}
.sf6-orbit-b{width:420px;height:420px;right:40px;top:-80px;border-color:color-mix(in srgb,var(--sf) 40%,transparent)}
.sf6-hero-inner{position:relative;z-index:2;max-width:1240px;margin:0 auto;padding:34px 42px 70px;min-height:720px}
.sf6-topline{display:flex;justify-content:space-between;align-items:center}
.sf6-back{display:inline-flex;align-items:center;gap:7px;color:rgba(255,255,255,.68);font-size:12px;font-weight:650;letter-spacing:.04em;text-transform:uppercase;text-decoration:none}
.sf6-back svg{transform:rotate(180deg)}
.sf6-back:hover{color:#fff}
.sf6-index{font-size:10px;letter-spacing:.19em;font-weight:700;color:rgba(255,255,255,.52)}
.sf6-index.dark{color:var(--ink-faint)}
.sf6-identity-grid{display:grid;grid-template-columns:minmax(0,1.2fr) 310px;gap:80px;align-items:end;padding-top:138px;max-width:980px}
.sf6-identity-main{position:relative}
.sf6-avatar{margin-bottom:28px;border:1px solid rgba(255,255,255,.28);box-shadow:0 16px 42px rgba(0,0,0,.28)}
.sf6-kicker{display:flex;align-items:center;gap:9px;font-size:11px;text-transform:uppercase;letter-spacing:.16em;color:rgba(255,255,255,.54);font-weight:650;margin-bottom:18px}
.sf6-dot{font-size:8px}
.sf6-identity-main h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(50px,7vw,96px);font-weight:500;letter-spacing:-.065em;line-height:.9;max-width:780px;color:#fff}
.sf6-tagline{margin-top:24px;font-size:clamp(17px,2vw,23px);line-height:1.45;max-width:600px;color:rgba(255,255,255,.67);font-weight:350}
.sf6-hero-actions{display:flex;align-items:center;gap:22px;flex-wrap:wrap;margin-top:38px}
.sf6-primary{border:0;background:#fff;color:#0d1512;padding:13px 18px;display:inline-flex;align-items:center;gap:16px;font:inherit;font-size:12px;font-weight:750;letter-spacing:.05em;text-transform:uppercase;cursor:pointer;transition:transform .25s ease,background .25s ease}
.sf6-primary:hover{transform:translateY(-2px)}
.sf6-primary.dark{background:#101713;color:#fff}
.sf6-text-action{border:0;border-bottom:1px solid rgba(255,255,255,.35);padding:8px 0;background:transparent;color:rgba(255,255,255,.75);font:inherit;font-size:12px;font-weight:650;cursor:pointer;text-decoration:none}
.sf6-text-action:hover{color:#fff;border-color:#fff}
.sf6-identity-side{padding-bottom:8px;border-top:1px solid rgba(255,255,255,.2)}
.sf6-record-line{display:flex;justify-content:space-between;gap:24px;padding:15px 0;border-bottom:1px solid rgba(255,255,255,.13);font-size:11px}
.sf6-record-line span{color:rgba(255,255,255,.49);text-transform:uppercase;letter-spacing:.09em}
.sf6-record-line strong{font-weight:600;color:#fff;text-align:right}
.sf6-record-line small{font-weight:400;color:rgba(255,255,255,.48)}
.sf6-record-line .sf6-verified{display:inline-flex;align-items:center;gap:5px;color:#d8f6ea;text-transform:none;letter-spacing:0}
.sf6-hero-object{position:absolute;right:42px;bottom:48px;width:245px;text-decoration:none;color:#fff;z-index:3}
.sf6-hero-object-media{height:155px;overflow:hidden;background:color-mix(in srgb,var(--sf) 42%,#202925);position:relative}
.sf6-hero-object-media img{width:100%;height:100%;object-fit:cover;transition:transform .7s cubic-bezier(.2,.75,.2,1)}
.sf6-hero-object:hover img{transform:scale(1.035)}
.sf6-hero-object-ph{height:100%;display:grid;place-items:center;background:linear-gradient(145deg,color-mix(in srgb,var(--sf) 65%,#1b2822),#121a16)}
.sf6-hero-object-ph span{font:600 42px 'Space Grotesk',sans-serif;color:rgba(255,255,255,.68)}
.sf6-hero-object-caption{display:grid;grid-template-columns:1fr auto;gap:4px 12px;padding-top:11px;border-top:1px solid rgba(255,255,255,.38);margin-top:8px}
.sf6-hero-object-caption>span{grid-column:1/-1;font-size:9px;text-transform:uppercase;letter-spacing:.14em;color:rgba(255,255,255,.45)}
.sf6-hero-object-caption strong{font-size:12px;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.sf6-hero-object-caption em{font-size:11px;color:rgba(255,255,255,.63);font-style:normal}

.sf6-story{max-width:1180px;margin:0 auto;padding:115px 42px 125px}
.sf6-section-label{display:flex;align-items:center;gap:18px;margin-bottom:65px;font-size:9px;letter-spacing:.18em;color:var(--ink-faint);font-weight:700}
.sf6-section-label i{height:1px;background:var(--hairline);flex:1}
.sf6-story-grid{display:grid;grid-template-columns:.92fr 1.08fr;gap:100px;align-items:start}
.sf6-story h2{font:500 clamp(38px,5vw,67px)/.98 'Space Grotesk',sans-serif;letter-spacing:-.055em;max-width:520px}
.sf6-about{font-size:18px;line-height:1.7;color:var(--ink-soft);max-width:620px}
.sf6-story-facts{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin-top:52px;padding-top:22px;border-top:1px solid var(--hairline)}
.sf6-story-facts div{display:flex;flex-direction:column;gap:7px}
.sf6-story-facts span{font-size:9px;text-transform:uppercase;letter-spacing:.14em;color:var(--ink-faint);font-weight:700}
.sf6-story-facts strong{font-size:12px;line-height:1.45;font-weight:600;color:var(--ink-soft)}

.sf6-collections{background:#f4f2ec;padding:118px max(42px,calc((100vw - 1180px)/2)) 135px;scroll-margin-top:0}
.sf6-section-head{display:flex;justify-content:space-between;align-items:end;gap:30px;margin-bottom:78px}
.sf6-section-head h2{font:500 clamp(36px,4.8vw,64px)/1 'Space Grotesk',sans-serif;letter-spacing:-.055em;margin-top:14px}
.sf6-section-head>p{max-width:340px;text-align:right;font-size:12px;line-height:1.6;color:var(--ink-faint)}
.sf6-collection{display:grid;grid-template-columns:170px minmax(360px,1.05fr) minmax(300px,.95fr);gap:34px;align-items:start;padding:78px 0;border-top:1px solid rgba(25,31,28,.16)}
.sf6-collection.reverse{grid-template-columns:170px minmax(300px,.95fr) minmax(360px,1.05fr)}
.sf6-collection.reverse .sf6-feature-product{grid-column:3;grid-row:1}
.sf6-collection.reverse .sf6-product-ledger{grid-column:2;grid-row:1}
.sf6-collection-title span{font-size:10px;color:var(--ink-faint);letter-spacing:.15em}
.sf6-collection-title h3{font:500 25px/1.05 'Space Grotesk',sans-serif;letter-spacing:-.035em;margin-top:12px}
.sf6-collection-title p{font-size:11px;color:var(--ink-faint);margin-top:9px}
.sf6-feature-product{text-decoration:none;color:var(--ink);display:block}
.sf6-feature-media{height:475px;position:relative;overflow:hidden;background:#dedbd2}
.sf6-feature-media img{width:100%;height:100%;object-fit:cover;transition:transform .75s cubic-bezier(.2,.72,.2,1)}
.sf6-feature-product:hover img{transform:scale(1.025)}
.sf6-feature-ph{height:100%;display:grid;place-items:center;background:linear-gradient(150deg,color-mix(in srgb,var(--sf) 65%,#dedbd2),#1d2924)}
.sf6-feature-ph span{font:500 72px 'Space Grotesk',sans-serif;color:rgba(255,255,255,.55)}
.sf6-state{position:absolute;left:16px;top:16px;background:rgba(10,15,13,.76);backdrop-filter:blur(7px);color:#fff;padding:6px 9px;font-size:9px;letter-spacing:.09em;text-transform:uppercase}
.sf6-feature-copy{display:grid;grid-template-columns:1fr auto;gap:7px 20px;padding-top:14px}
.sf6-feature-copy strong{font-size:15px;font-weight:600}
.sf6-feature-copy>span{font-size:14px;font-weight:650}
.sf6-feature-copy em{grid-column:1/-1;font-size:10px;font-style:normal;color:var(--ink-faint);text-transform:uppercase;letter-spacing:.1em}
.sf6-product-ledger{border-top:1px solid rgba(25,31,28,.2)}
.sf6-product-row{display:grid;grid-template-columns:28px 60px minmax(0,1fr) auto 18px;gap:13px;align-items:center;padding:15px 0;border-bottom:1px solid rgba(25,31,28,.14);text-decoration:none;color:var(--ink);transition:padding .2s ease,opacity .2s ease}
.sf6-product-row:hover{padding-left:5px}
.sf6-product-row.muted{opacity:.5}
.sf6-product-no{font-size:9px;color:var(--ink-ghost);letter-spacing:.1em}
.sf6-product-thumb{width:60px;height:70px;background:#dedbd2;overflow:hidden}
.sf6-product-thumb img,.sf6-product-thumb>span{width:100%;height:100%;object-fit:cover;display:block}
.sf6-product-copy{min-width:0;display:flex;flex-direction:column;gap:5px}
.sf6-product-copy strong{font-size:12.5px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.sf6-product-copy small{font-size:10px;color:var(--ink-faint);display:flex;align-items:center;gap:4px}
.sf6-product-price{text-align:right;display:flex;flex-direction:column;gap:4px;white-space:nowrap}
.sf6-product-price span{font-size:11.5px;font-weight:650}
.sf6-product-price small{font-size:9px;color:var(--ink-ghost);text-decoration:line-through}
.sf6-row-arrow{color:var(--ink-ghost)}

.sf6-provenance{background:#0f1714;color:#fff;padding:120px 42px 130px}
.sf6-provenance-inner{max-width:1180px;margin:0 auto}
.sf6-section-head.light{margin-bottom:72px}
.sf6-section-head.light h2{color:#fff}
.sf6-section-head.light>p{color:rgba(255,255,255,.42)}
.sf6-provenance-grid{display:grid;grid-template-columns:1.1fr .9fr;gap:95px;padding:52px 0 80px;border-top:1px solid rgba(255,255,255,.15);border-bottom:1px solid rgba(255,255,255,.15)}
.sf6-provenance-main{display:grid;grid-template-columns:repeat(3,1fr);gap:35px;align-content:start}
.sf6-metric{display:flex;flex-direction:column;gap:9px}
.sf6-metric strong{font:450 clamp(46px,6vw,76px)/1 'Space Grotesk',sans-serif;letter-spacing:-.055em;color:#fff}
.sf6-metric span{font-size:10px;text-transform:uppercase;letter-spacing:.13em;color:rgba(255,255,255,.45)}
.sf6-provenance-copy{display:flex;flex-direction:column}
.sf6-proof{display:grid;grid-template-columns:28px 1fr;gap:15px;padding:20px 0;border-bottom:1px solid rgba(255,255,255,.13)}
.sf6-proof:first-child{padding-top:0}
.sf6-proof svg{color:color-mix(in srgb,var(--sf) 48%,#a7e6ce)}
.sf6-proof strong{display:block;font-size:12px;letter-spacing:.01em;margin-bottom:6px}
.sf6-proof p{font-size:11px;line-height:1.6;color:rgba(255,255,255,.46)}
.sf6-regions{display:grid;grid-template-columns:170px 1fr;gap:35px;padding:37px 0;border-bottom:1px solid rgba(255,255,255,.15)}
.sf6-regions>span,.sf6-review-intro>span{font-size:9px;font-weight:700;letter-spacing:.16em;color:rgba(255,255,255,.4)}
.sf6-regions>div{display:flex;gap:10px 26px;flex-wrap:wrap}
.sf6-regions i{font-style:normal;font:450 20px 'Space Grotesk',sans-serif;color:rgba(255,255,255,.78)}
.sf6-reviews{display:grid;grid-template-columns:330px 1fr;gap:95px;padding-top:72px}
.sf6-review-intro h3{font:500 34px/1.08 'Space Grotesk',sans-serif;letter-spacing:-.04em;margin:13px 0}
.sf6-review-intro p{font-size:11px;line-height:1.6;color:rgba(255,255,255,.42)}
.sf6-review-list{display:grid;grid-template-columns:repeat(2,1fr);gap:0 34px}
.sf6-review-list blockquote{margin:0;padding:20px 0 28px;border-top:1px solid rgba(255,255,255,.15)}
.sf6-stars{display:flex;gap:2px;color:#dcb35a;margin-bottom:15px}
.sf6-review-list p{font:400 15px/1.65 'Space Grotesk',sans-serif;color:rgba(255,255,255,.72)}

.sf6-continue{max-width:1180px;margin:0 auto;padding:120px 42px 135px}
.sf6-continue-grid{display:grid;grid-template-columns:1fr 440px;gap:100px;margin-top:30px;align-items:start}
.sf6-continue h2{font:500 clamp(38px,5vw,65px)/1 'Space Grotesk',sans-serif;letter-spacing:-.055em}
.sf6-continue-actions{display:flex;flex-direction:column;align-items:stretch;gap:0}
.sf6-continue-actions .sf6-primary{align-self:flex-start;margin-bottom:27px}
.sf6-line-action{display:flex;justify-content:space-between;align-items:center;border:0;border-top:1px solid var(--hairline);background:transparent;padding:18px 0;color:var(--ink-soft);font:inherit;font-size:12px;text-decoration:none;cursor:pointer;text-align:left}
.sf6-line-action:last-child{border-bottom:1px solid var(--hairline)}
.sf6-line-action:hover{color:var(--ink)}
.sf6-foot{max-width:1180px;margin:0 auto;border-top:1px solid var(--hairline);padding:32px 42px 55px;display:flex;justify-content:space-between;align-items:center;gap:25px}
.sf6-foot p{font-size:10px;color:var(--ink-faint)}
.sf6-loading{min-height:65vh;background:#0f1714;color:#fff;display:grid;place-content:center;text-align:center;gap:13px}
.sf6-loading span{font-size:9px;letter-spacing:.18em;color:rgba(255,255,255,.4)}
.sf6-loading p{font:400 22px 'Space Grotesk',sans-serif}

@media(max-width:1020px){
  .sf6-identity-grid{grid-template-columns:1fr;gap:52px;max-width:720px;padding-top:105px}
  .sf6-identity-side{max-width:480px}
  .sf6-hero-object{right:32px;bottom:35px;width:210px}
  .sf6-story-grid{gap:55px}
  .sf6-collection,.sf6-collection.reverse{grid-template-columns:120px 1fr;gap:26px}
  .sf6-collection .sf6-feature-product,.sf6-collection.reverse .sf6-feature-product{grid-column:2;grid-row:1}
  .sf6-collection .sf6-product-ledger,.sf6-collection.reverse .sf6-product-ledger{grid-column:2;grid-row:2}
  .sf6-collection-title{grid-column:1;grid-row:1 / span 2}
  .sf6-feature-media{height:520px}
  .sf6-provenance-grid{gap:52px}
  .sf6-reviews{gap:55px}
}
@media(max-width:760px){
  .sf6-hero{min-height:700px}
  .sf6-hero-inner{padding:24px 20px 42px;min-height:700px}
  .sf6-identity-grid{padding-top:80px;gap:42px}
  .sf6-avatar{width:68px!important;height:68px!important;margin-bottom:22px}
  .sf6-identity-main h1{font-size:clamp(46px,14vw,68px)}
  .sf6-tagline{font-size:17px;margin-top:18px}
  .sf6-record-line{padding:12px 0}
  .sf6-hero-object{display:none}
  .sf6-cover-wash{background:linear-gradient(0deg,rgba(7,11,9,.94) 0%,rgba(7,11,9,.72) 70%,rgba(7,11,9,.55) 100%)}
  .sf6-story{padding:82px 20px 92px}
  .sf6-section-label{margin-bottom:42px}
  .sf6-story-grid{grid-template-columns:1fr;gap:42px}
  .sf6-story h2{font-size:43px}
  .sf6-about{font-size:16px}
  .sf6-story-facts{grid-template-columns:1fr;gap:17px;margin-top:38px}
  .sf6-collections{padding:82px 20px 95px}
  .sf6-section-head{align-items:start;flex-direction:column;margin-bottom:50px}
  .sf6-section-head h2{font-size:42px}
  .sf6-section-head>p{text-align:left}
  .sf6-collection,.sf6-collection.reverse{display:block;padding:55px 0}
  .sf6-collection-title{margin-bottom:24px;display:grid;grid-template-columns:36px 1fr auto;align-items:end;gap:8px}
  .sf6-collection-title h3{margin:0;font-size:24px}
  .sf6-collection-title p{margin:0}
  .sf6-feature-media{height:auto;aspect-ratio:4/5}
  .sf6-product-ledger{margin-top:30px}
  .sf6-product-row{grid-template-columns:23px 52px minmax(0,1fr) auto 15px;gap:10px}
  .sf6-product-thumb{width:52px;height:61px}
  .sf6-product-price small{display:none}
  .sf6-provenance{padding:85px 20px 95px}
  .sf6-provenance-grid{grid-template-columns:1fr;gap:50px;padding:42px 0 55px}
  .sf6-provenance-main{gap:20px}
  .sf6-metric strong{font-size:48px}
  .sf6-regions{grid-template-columns:1fr;gap:18px}
  .sf6-regions i{font-size:17px}
  .sf6-reviews{grid-template-columns:1fr;gap:42px;padding-top:55px}
  .sf6-review-list{grid-template-columns:1fr}
  .sf6-continue{padding:85px 20px 95px}
  .sf6-continue-grid{grid-template-columns:1fr;gap:55px}
  .sf6-continue h2{font-size:44px}
  .sf6-foot{margin:0 20px;padding:28px 0 42px;flex-direction:column;align-items:flex-start}
}
@media(max-width:470px){
  .sf6-topline .sf6-index{display:none}
  .sf6-identity-grid{padding-top:60px}
  .sf6-identity-main h1{font-size:48px}
  .sf6-hero-actions{gap:13px}
  .sf6-primary{padding:12px 14px}
  .sf6-provenance-main{grid-template-columns:1fr 1fr}
  .sf6-product-row{grid-template-columns:20px 46px minmax(0,1fr) auto}
  .sf6-product-thumb{width:46px;height:55px}
  .sf6-row-arrow{display:none}
  .sf6-product-copy small{display:none}
  .sf6-product-price span{font-size:10.5px}
}
@media(prefers-reduced-motion:reduce){
  .sf6 *, .sf6 *::before, .sf6 *::after{scroll-behavior:auto!important;transition:none!important;animation:none!important}
}

/* PHASE 9 — BUSINESS / storefront becomes a full mobile destination */
@media(max-width:760px){
  .sf6-hero,.sf6-hero-inner{min-height:max(700px,100svh)}
  .sf6-hero-inner{padding-bottom:calc(42px + env(safe-area-inset-bottom))}
  .sf6-hero-actions{align-items:stretch;flex-wrap:wrap}.sf6-primary{min-height:50px;justify-content:space-between;flex:1 0 100%}.sf6-text-action{min-height:44px;display:inline-flex;align-items:center}
  .sf6-feature-media{margin-left:-20px;margin-right:-20px;aspect-ratio:4/5}
  .sf6-product-row{min-height:76px}
  .sf6-continue-action{min-height:48px}
}
@media(max-width:470px){
  .sf6-hero-inner,.sf6-story,.sf6-collections,.sf6-provenance,.sf6-continue{padding-left:14px;padding-right:14px}
  .sf6-identity-main h1{font-size:44px;line-height:.92}.sf6-tagline{font-size:16px;line-height:1.45}
  .sf6-feature-media{margin-left:-14px;margin-right:-14px}
  .sf6-product-row{grid-template-columns:18px 46px minmax(0,1fr) 14px;grid-template-rows:auto auto;gap:5px 9px}
  .sf6-product-no{grid-row:1/3}.sf6-product-thumb{grid-row:1/3}.sf6-product-copy{grid-column:3;grid-row:1}.sf6-product-price{grid-column:3;grid-row:2;text-align:left}.sf6-row-arrow{display:block;grid-column:4;grid-row:1/3;align-self:center}
  .sf6-product-copy small{display:block;font-size:9px}.sf6-product-price small{display:none}
  .sf6-foot{margin-left:14px;margin-right:14px;padding-bottom:calc(42px + env(safe-area-inset-bottom))}
}
</style>
