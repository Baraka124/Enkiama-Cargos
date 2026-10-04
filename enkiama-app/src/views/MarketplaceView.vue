<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { usePublic } from '../composables/usePublic'
import Avatar from '../components/Avatar.vue'
import Icon from '../components/Icon.vue'
import EmptyState from '../components/EmptyState.vue'
import ExperienceState from '../components/ExperienceState.vue'
import AppHeader from '../components/AppHeader.vue'
import SiteFooter from '../components/SiteFooter.vue'
import MediaFrame from '../components/MediaFrame.vue'
import { viewName, signalMotionReady } from '../lib/motion'
import { firstMedia, validMediaUrl } from '../lib/media'
import { formatNumber } from '../lib/format'

const stores = ref([])
const heroStores = ref([])
const products = ref([])
const categories = ref([])
const view = ref('products')
const activeCategory = ref('')
const sortBy = ref('relevant')
const filterVerified = ref(false)
const filterInStock = ref(false)
const filterDeal = ref(false)
const loading = ref(true)
const loadError = ref('')
const pub = usePublic()
const corridor = ref('')
const corridors = ['Dar es Salaam', 'Arusha', 'Mwanza', 'Dodoma', 'Mbeya', 'Tanga', 'Morogoro', 'Zanzibar Urban/West']
const corridorNodes = [
  { name:'Mwanza', x:18, y:20, code:'MWZ' },
  { name:'Arusha', x:61, y:17, code:'ARK' },
  { name:'Tanga', x:79, y:36, code:'TGT' },
  { name:'Dodoma', x:48, y:46, code:'DOD' },
  { name:'Morogoro', x:66, y:58, code:'MOR' },
  { name:'Dar es Salaam', x:82, y:70, code:'DAR' },
  { name:'Mbeya', x:29, y:73, code:'MBY' },
  { name:'Zanzibar Urban/West', x:91, y:53, code:'ZNZ' },
]
const search = ref('')
const sort = ref('recommended')
let searchTimer = null

const displayProducts = computed(() => {
  let list = [...products.value]
  if (filterVerified.value) list = list.filter(p => p.verified_delivery || p.shop_verified)
  if (filterInStock.value) list = list.filter(p => p.available !== false)
  if (filterDeal.value) list = list.filter(p => p.compare_at_tzs && p.compare_at_tzs > p.price_tzs)
  if (sortBy.value === 'price_low') list.sort((a,b) => (a.price_tzs||0) - (b.price_tzs||0))
  else if (sortBy.value === 'price_high') list.sort((a,b) => (b.price_tzs||0) - (a.price_tzs||0))
  else if (sortBy.value === 'newest') list.sort((a,b) => new Date(b.created_at||0) - new Date(a.created_at||0))
  return list
})

const groupedProducts = computed(() => {
  if (activeCategory.value) return null
  const groups = {}
  for (const p of displayProducts.value) {
    const cat = p.category || 'Other'
    if (!groups[cat]) groups[cat] = []
    groups[cat].push(p)
  }
  return Object.entries(groups).map(([category, items]) => ({ category, items }))
})

const heroProducts = computed(() => displayProducts.value.filter(p => pImg(p)).slice(0, 2))
const heroStore = computed(() => heroStores.value[0] || stores.value[0] || null)
const featuredStore = computed(() => stores.value[0] || null)
const otherStores = computed(() => stores.value.slice(1))
const selectedCorridorLabel = computed(() => corridor.value ? corridor.value.replace(' Urban/West','') : 'All Tanzania')
const activeFilterCount = computed(() => [filterVerified.value, filterInStock.value, filterDeal.value].filter(Boolean).length)

function pImg(p) { return firstMedia(p) }

function pctOff(p) {
  if (!p.compare_at_tzs || !p.price_tzs || p.compare_at_tzs <= p.price_tzs) return 0
  return Math.round((1 - p.price_tzs / p.compare_at_tzs) * 100)
}

async function load() {
  loading.value = true
  loadError.value = ''
  try {
    if (view.value === 'shops') {
      const { data, error } = await pub.browseStorefrontsV2(corridor.value, search.value, sort.value)
      if (error) throw error
      stores.value = data || []
    } else {
      const { data, error } = await pub.searchProducts(search.value, activeCategory.value, corridor.value)
      if (error) throw error
      products.value = data || []
    }
  } catch (e) {
    loadError.value = 'The market could not be refreshed right now.'
    if (view.value === 'shops') stores.value = []
    else products.value = []
  }
  loading.value = false
  await nextTick()
  signalMotionReady()
}
async function loadCategories() {
  const { data } = await pub.productCategories()
  categories.value = data || []
}

async function loadHeroStores() {
  const { data } = await pub.browseStorefrontsV2('', '', 'recommended')
  heroStores.value = data || []
}

function shopTier(s) {
  const d = s.delivered_count || 0, r = s.avg_rating || 5
  if (d >= 50 && r >= 4.5) return 'trusted'
  if (d >= 10) return 'established'
  if (d >= 1) return 'active'
  return 'new'
}

function setView(v) {
  view.value = v
  activeCategory.value = ''
  load()
  requestAnimationFrame(() => document.querySelector('#market-discovery')?.scrollIntoView({ behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' }))
}
function setCategory(c) {
  activeCategory.value = activeCategory.value === c ? '' : c
  view.value = 'products'
  load()
}
function filterCorridor(c) {
  corridor.value = corridor.value === c ? '' : c
  load()
}
function onSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(load, 280)
}
function submitSearch() {
  clearTimeout(searchTimer)
  load()
  requestAnimationFrame(() => document.querySelector('#market-discovery')?.scrollIntoView({ behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' }))
}
function setSort(s) { sort.value = s; load() }
function clearFilters() {
  filterVerified.value = false
  filterInStock.value = false
  filterDeal.value = false
}
onMounted(() => { load(); loadCategories(); loadHeroStores() })
</script>

<template>
  <div class="mk">
    <AppHeader title="Market" subtitle="Tanzania" />
    <!-- PHASE 12 / MARKET ART DIRECTION — media leads, typography supports -->
    <section class="mk12-hero">
      <div class="mk12-ambient" aria-hidden="true"></div>
      <div class="mk12-shell">
        <div class="mk12-intro">
          <div class="mk12-kicker"><span>01</span><span>Market · Tanzania</span></div>

          <div class="mk12-copy" v-reveal="{variant:'copy'}">
            <h1>A market <em>in motion.</em></h1>
            <p>Discover useful objects, independent businesses and places across Tanzania — connected to Enkiama's tracked delivery network.</p>
          </div>

          <form class="mk12-search" v-reveal="{variant:'copy',delay:60}" @submit.prevent="submitSearch">
            <label for="market-search">{{ view === 'shops' ? 'Find a business' : 'Find an object' }}</label>
            <div class="mk12-search-line">
              <Icon name="search" :size="19" />
              <input id="market-search" v-model="search" @input="onSearch" :placeholder="view === 'shops' ? 'Search businesses across Tanzania' : 'Search products across Tanzania'" />
              <button v-if="search" type="button" class="mk12-clear" @click="search=''; submitSearch()">Clear</button>
              <button type="submit" class="mk12-search-action">Search <span>↗</span></button>
            </div>
          </form>

          <div class="mk12-realms" v-reveal="{variant:'section',delay:110}" role="group" aria-label="Market worlds">
            <button type="button" class="mk12-realm" :class="{active:view==='products'}" :aria-pressed="view==='products'" @click="setView('products')">
              <span class="mk12-realm-no">01</span>
              <span class="mk12-realm-copy"><strong>Goods</strong><small>{{ displayProducts.length ? `${displayProducts.length} objects available` : 'Objects for everyday life' }}</small></span>
              <span class="mk12-realm-arrow">↗</span>
            </button>
            <button type="button" class="mk12-realm" :class="{active:view==='shops'}" :aria-pressed="view==='shops'" @click="setView('shops')">
              <span class="mk12-realm-no">02</span>
              <span class="mk12-realm-copy"><strong>Businesses</strong><small>{{ heroStore ? `Meet ${heroStore.name}` : 'People behind the market' }}</small></span>
              <span class="mk12-realm-arrow">↗</span>
            </button>
            <RouterLink to="/property" class="mk12-realm">
              <span class="mk12-realm-no">03</span>
              <span class="mk12-realm-copy"><strong>Property</strong><small>Land, homes &amp; places</small></span>
              <span class="mk12-realm-arrow">↗</span>
            </RouterLink>
          </div>

          <a href="#market-discovery" class="mk12-scroll">Explore the market <span>↓</span></a>
        </div>

        <div class="mk12-gallery" aria-label="Featured market objects">
          <RouterLink v-if="heroProducts[0]" :to="`/shop/${heroProducts[0].shop_slug}/product/${heroProducts[0].id}`" class="mk12-main-object" data-cursor="View" v-reveal="{variant:'media',delay:80}">
            <MediaFrame class="mk12-main-media" v-depth="{pointer:4.5,scroll:9,rotate:.28,scale:1.008}" :src="pImg(heroProducts[0])" :alt="heroProducts[0].name" tone="object" :eager="true" :transition-name="viewName('product', heroProducts[0].id)" fallback-title="Object image not supplied">
              <span class="mk12-media-index">Object / 01</span>
              <span class="mk12-media-open">Open ↗</span>
            </MediaFrame>
            <div class="mk12-main-caption">
              <span>Featured object</span>
              <strong>{{ heroProducts[0].name }}</strong>
              <small>{{ heroProducts[0].shop_name }} · TZS {{ formatNumber(heroProducts[0].price_tzs) }}</small>
            </div>
          </RouterLink>
          <div v-else class="mk12-main-object mk12-media-fallback" aria-hidden="true">
            <div class="mk12-fallback-mark">E</div>
            <span>Market objects appear here as sellers publish them.</span>
          </div>

          <RouterLink v-if="heroProducts[1]" :to="`/shop/${heroProducts[1].shop_slug}/product/${heroProducts[1].id}`" class="mk12-second-object" data-cursor="View" v-reveal="{variant:'media',delay:150}">
            <MediaFrame class="mk12-second-media" v-depth="{pointer:7,scroll:14,rotate:.42,scale:1.012,invert:true}" :src="pImg(heroProducts[1])" :alt="heroProducts[1].name" tone="object" :eager="true" :transition-name="viewName('product', heroProducts[1].id)" fallback-title="Object image not supplied" />
            <div><span>Object / 02</span><strong>{{ heroProducts[1].name }}</strong></div>
          </RouterLink>

          <button type="button" v-if="heroStore" class="mk12-business-object" v-reveal="{variant:'media',delay:190}" @click="setView('shops')" data-cursor="Enter">
            <MediaFrame v-if="validMediaUrl(heroStore.cover_url)" class="mk12-business-media" v-depth="{pointer:3.2,scroll:7,rotate:.22,scale:1.006}" :src="heroStore.cover_url" :alt="`${heroStore.name} storefront`" tone="business" fallback-title="Storefront media">
              <div class="mk12-business-shade"></div>
              <div class="mk12-business-avatar" :style="{viewTransitionName:viewName('shop', heroStore.slug || heroStore.id)}"><Avatar :name="heroStore.name" :accent="heroStore.accent" :logo="heroStore.logo_url" :size="58" /></div>
            </MediaFrame>
            <div v-else class="mk12-business-media mk12-business-media-fallback" aria-hidden="true">
              <div class="mk12-business-fallback-lines"><i></i><i></i><i></i></div>
              <div class="mk12-business-avatar" :style="{viewTransitionName:viewName('shop', heroStore.slug || heroStore.id)}"><Avatar :name="heroStore.name" :accent="heroStore.accent" :logo="heroStore.logo_url" :size="58" /></div>
            </div>
            <div class="mk12-business-copy"><span>Independent business</span><strong>{{ heroStore.name }}</strong><small>{{ heroStore.tagline || 'A storefront inside Enkiama Market.' }}</small></div>
            <span class="mk12-card-arrow">↗</span>
          </button>

          <RouterLink to="/property" class="mk12-place-object" data-cursor="Place" v-reveal="{variant:'copy',delay:220}">
            <div class="mk12-contours" aria-hidden="true">
              <span></span><span></span><span></span><span></span>
            </div>
            <span class="mk12-place-index">03 / Place</span>
            <strong>Property &amp; land</strong>
            <small>Explore reviewed places across Tanzania.</small>
            <span class="mk12-card-arrow">↗</span>
          </RouterLink>
        </div>
      </div>

      <div class="mk12-status" v-reveal="{variant:'line',delay:240}">
        <span>Local discovery</span>
        <span>Tracked movement</span>
        <span>Visible provenance</span>
      </div>
    </section>

    <!-- UTILITY LAYER: progressively quieter -->
    <main id="market-discovery" class="mk-body">
      <section class="mk-utility" aria-label="Market controls">
        <div class="mk-modebar">
          <div class="mk-modegroup">
            <span class="mk-util-label">Explore</span>
            <button type="button" class="mk-mode" :class="{on:view==='products'}" :aria-pressed="view==='products'" @click="setView('products')">Products</button>
            <button type="button" class="mk-mode" :class="{on:view==='shops'}" :aria-pressed="view==='shops'" @click="setView('shops')">Businesses</button>
            <RouterLink to="/property" class="mk-mode">Property &amp; land</RouterLink>
          </div>
          <span v-if="view==='products'" class="mk-count">{{ displayProducts.length }} product{{ displayProducts.length===1?'':'s' }}</span>
          <div v-else class="mk-shop-sort" aria-label="Sort shops">
            <button type="button" :class="{on:sort==='recommended'}" :aria-pressed="sort==='recommended'" @click="setSort('recommended')">Recommended</button>
            <button type="button" :class="{on:sort==='rating'}" :aria-pressed="sort==='rating'" @click="setSort('rating')">Top rated</button>
            <button type="button" :class="{on:sort==='newest'}" :aria-pressed="sort==='newest'" @click="setSort('newest')">Newest</button>
          </div>
        </div>

        <div class="mk-locationbar">
          <span class="mk-util-label">Deliver to</span>
          <div class="mk-corridors">
            <button type="button" class="mk-corr" :class="{on:!corridor}" :aria-pressed="!corridor" @click="filterCorridor('')">All Tanzania</button>
            <button type="button" v-for="c in corridors" :key="c" class="mk-corr" :class="{on:corridor===c}" :aria-pressed="corridor===c" @click="filterCorridor(c)">{{ c.replace(' Urban/West','') }}</button>
          </div>
        </div>

        <template v-if="view==='products'">
          <div v-if="categories.length" class="mk-categorybar">
            <button type="button" class="mk-cat" :class="{on:!activeCategory}" :aria-pressed="!activeCategory" @click="setCategory('')">All</button>
            <button type="button" v-for="c in categories" :key="c.category" class="mk-cat" :class="{on:activeCategory===c.category}" :aria-pressed="activeCategory===c.category" @click="setCategory(c.category)">
              {{ c.category }} <sup>{{ c.count }}</sup>
            </button>
          </div>
          <div class="mk-filterbar">
            <div class="mk-filters">
              <button type="button" class="mk-filter" :class="{on:filterVerified}" :aria-pressed="filterVerified" @click="filterVerified=!filterVerified"><span class="mk-filter-dot"></span>Verified</button>
              <button type="button" class="mk-filter" :class="{on:filterInStock}" :aria-pressed="filterInStock" @click="filterInStock=!filterInStock"><span class="mk-filter-dot"></span>Available</button>
              <button type="button" class="mk-filter" :class="{on:filterDeal}" :aria-pressed="filterDeal" @click="filterDeal=!filterDeal"><span class="mk-filter-dot"></span>Offers</button>
              <button type="button" v-if="activeFilterCount" class="mk-filter-clear" @click="clearFilters">Clear {{ activeFilterCount }}</button>
            </div>
            <label class="mk-sortselect">
              <span>Sort</span>
              <select v-model="sortBy">
                <option value="relevant">Most relevant</option>
                <option value="price_low">Price: low to high</option>
                <option value="price_high">Price: high to low</option>
                <option value="newest">Newest</option>
              </select>
            </label>
          </div>
        </template>
      </section>

      <section v-if="view==='products' && !search && !activeCategory" v-reveal class="mk-network" aria-label="Delivery network">
        <div class="mk-network-copy">
          <span class="mk-network-index">Movement / Delivery network</span>
          <h2>Shop by where
            <em>it needs to go.</em>
          </h2>
          <p>Location is not an afterthought. Choose a corridor and the market reorganises around what can move there.</p>
          <div class="mk-network-state">
            <span>Current reach</span>
            <strong>{{ selectedCorridorLabel }}</strong>
            <button type="button" v-if="corridor" @click="filterCorridor(corridor)">Reset</button>
          </div>
        </div>

        <div class="mk-network-map">
          <svg class="mk-network-lines" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
            <path d="M18 20 C33 23 43 32 48 46" />
            <path d="M61 17 C58 28 54 37 48 46" />
            <path d="M61 17 C71 22 76 29 79 36" />
            <path d="M48 46 C57 48 62 53 66 58" />
            <path d="M66 58 C73 61 78 66 82 70" />
            <path d="M79 36 C84 42 88 47 91 53" />
            <path d="M48 46 C40 56 34 65 29 73" />
            <path d="M91 53 C89 60 86 65 82 70" />
          </svg>
          <button type="button" v-for="n in corridorNodes" :key="n.name" class="mk-network-node" :class="{on:corridor===n.name}" :aria-pressed="corridor===n.name" :style="{left:n.x+'%',top:n.y+'%'}" @click="filterCorridor(n.name)">
            <span class="mk-node-dot"></span>
            <span class="mk-node-label"><b>{{ n.name.replace(' Urban/West','') }}</b><small>{{ n.code }}</small></span>
          </button>
          <div class="mk-network-watermark">TZ</div>
        </div>
      </section>

      <!-- PRODUCTS -->
      <section v-if="view==='products'" class="mk-content">
        <div v-if="search" class="mk-searchinfo">
          <span>{{ displayProducts.length }} result{{ displayProducts.length===1?'':'s' }} for <strong>“{{ search }}”</strong></span>
          <button type="button" @click="search=''; submitSearch()">Clear search</button>
        </div>

        <div v-if="loading" class="mk-pgrid">
          <div v-for="i in 8" :key="i" class="mk-pcard mk-skeleton"></div>
        </div>
        <ExperienceState v-else-if="loadError" kind="error" world="market" eyebrow="Market connection" title="The market did not arrive." :body="loadError">
          <button type="button" @click="load">Try again</button>
          <button type="button" @click="search='';activeCategory='';corridor='';filterVerified=false;filterInStock=false;filterDeal=false;load()">Reset discovery</button>
        </ExperienceState>
        <ExperienceState v-else-if="!displayProducts.length" kind="empty" world="market" eyebrow="No matching objects" title="Nothing matches this view yet." body="Try widening the place, category, search, or availability filters. The market stays composed even when the answer is zero.">
          <button type="button" @click="search='';activeCategory='';corridor='';filterVerified=false;filterInStock=false;filterDeal=false;load()">Show the full market</button>
        </ExperienceState>

        <div v-else-if="activeCategory" class="mk-focused">
          <div class="mk-focused-head">
            <div><span>Category</span><h2>{{ activeCategory }}</h2></div>
            <button type="button" @click="setCategory(activeCategory)">View all market <span>↗</span></button>
          </div>
          <div class="mk-pgrid">
            <RouterLink v-for="p in displayProducts" :key="p.id" :to="`/shop/${p.shop_slug}/product/${p.id}`" class="mk-pcard" data-cursor="View">
              <MediaFrame class="mk-pimg" :src="pImg(p)" :alt="p.name" tone="object" :transition-name="viewName('product', p.id)" fallback-title="Object image not supplied">
                <span v-if="pctOff(p)" class="mk-poff">−{{ pctOff(p) }}%</span>
                <span v-if="p.available === false" class="mk-psold">Sold out</span>
                <span class="mk-open">↗</span>
              </MediaFrame>
              <div class="mk-pbody">
                <div class="mk-pname">{{ p.name }}</div>
                <div class="mk-pprice-row"><span class="mk-pprice">TZS {{ formatNumber(p.price_tzs) }}</span><span v-if="p.compare_at_tzs && p.compare_at_tzs > p.price_tzs" class="mk-pwas">{{ formatNumber(p.compare_at_tzs) }}</span></div>
                <div class="mk-pfoot"><span>{{ p.shop_name }}</span><span v-if="p.verified_delivery" class="mk-pverif"><Icon name="check" :size="10" /> Verified</span></div>
              </div>
            </RouterLink>
          </div>
        </div>

        <div v-else class="mk-sections">
          <section v-for="(g,index) in groupedProducts" :key="g.category" class="mk-section" v-reveal="{delay:Math.min(index*45,180)}">
            <div class="mk-section-head">
              <div class="mk-section-index">{{ String(index + 2).padStart(2,'0') }}</div>
              <div class="mk-section-copy"><span>Collection</span><h2>{{ g.category }}</h2></div>
              <button type="button" class="mk-section-more" @click="setCategory(g.category)">Explore {{ g.items.length }} <span>↗</span></button>
            </div>
            <div class="mk-editorial" :class="{'mk-editorial--flip': index % 2 === 1}">
              <RouterLink v-if="g.items[0]" :to="`/shop/${g.items[0].shop_slug}/product/${g.items[0].id}`" class="mk-feature-object" data-cursor="View">
                <MediaFrame class="mk-feature-media" v-depth="{pointer:2.2,scroll:6,rotate:.16,scale:1.005}" :src="pImg(g.items[0])" :alt="g.items[0].name" tone="object" :transition-name="viewName('product', g.items[0].id)" fallback-title="Object image not supplied">
                  <span v-if="pctOff(g.items[0])" class="mk-poff">−{{ pctOff(g.items[0]) }}%</span>
                  <span v-if="g.items[0].available === false" class="mk-psold">Sold out</span>
                  <span class="mk-feature-open">Explore ↗</span>
                </MediaFrame>
                <div class="mk-feature-copy">
                  <span class="mk-feature-shop">{{ g.items[0].shop_name }}</span>
                  <h3>{{ g.items[0].name }}</h3>
                  <div class="mk-feature-price"><strong>TZS {{ formatNumber(g.items[0].price_tzs) }}</strong><span v-if="g.items[0].compare_at_tzs && g.items[0].compare_at_tzs > g.items[0].price_tzs">{{ formatNumber(g.items[0].compare_at_tzs) }}</span></div>
                </div>
              </RouterLink>

              <div class="mk-object-index">
                <RouterLink v-for="(p,pIndex) in g.items.slice(1,5)" :key="p.id" :to="`/shop/${p.shop_slug}/product/${p.id}`" class="mk-object-row" data-cursor="View">
                  <span class="mk-object-no">{{ String(pIndex + 2).padStart(2,'0') }}</span>
                  <MediaFrame class="mk-object-thumb" :src="pImg(p)" :alt="p.name" tone="object" :transition-name="viewName('product', p.id)" fallback-title="" />
                  <div class="mk-object-copy">
                    <b>{{ p.name }}</b>
                    <span>{{ p.shop_name }}</span>
                  </div>
                  <div class="mk-object-price">TZS {{ formatNumber(p.price_tzs) }}</div>
                  <span class="mk-object-arrow">↗</span>
                </RouterLink>
                <button type="button" v-if="g.items.length > 5" class="mk-object-all" @click="setCategory(g.category)">See all {{ g.items.length }} in {{ g.category }} <span>↗</span></button>
              </div>
            </div>
          </section>
        </div>
      </section>

      <!-- BUSINESSES -->
      <section v-else class="mk-content mk-businesses">
        <div class="mk-business-intro">
          <span>02 / Businesses</span>
          <h2>Meet the people<br>behind the market.</h2>
          <p>Independent businesses connected to delivery, verification and a visible fulfilment history.</p>
        </div>

        <ExperienceState v-if="!loading && loadError" kind="error" world="business" eyebrow="Business directory" title="Businesses could not be loaded." :body="loadError"><button type="button" @click="load">Try again</button></ExperienceState>
        <div v-else-if="loading" class="mk-shopgrid">
          <div v-for="i in 3" :key="i" class="mk-shopcard mk-skeleton"></div>
        </div>
        <EmptyState v-else-if="!stores.length" icon="search" title="No businesses here yet" :hint="corridor ? `No storefronts delivering to ${corridor} yet.` : 'Be the first business on the marketplace.'" />
        <div v-else class="mk-business-ledger">
          <RouterLink v-if="featuredStore" :to="`/shop/${featuredStore.slug}`" class="mk-shop-feature" data-cursor="Enter" :style="{'--sf': featuredStore.accent || 'var(--accent)'}">
            <div class="mk-shop-feature-visual" :style="featuredStore.cover_url ? {backgroundImage:`url(${featuredStore.cover_url})`} : {}">
              <div class="mk-shopvisual-wash"></div>
              <div class="mk-shop-feature-mark" :style="{viewTransitionName:viewName('shop', featuredStore.slug || featuredStore.id)}"><Avatar :name="featuredStore.name" :accent="featuredStore.accent" :logo="featuredStore.logo_url" :size="88" /></div>
              <span class="mk-shop-feature-open">Visit storefront ↗</span>
            </div>
            <div class="mk-shop-feature-copy">
              <span class="mk-shop-feature-kicker">Featured independent business</span>
              <h3>{{ featuredStore.name }}</h3>
              <p>{{ featuredStore.tagline || 'Independent business on Enkiama Market.' }}</p>
              <div class="mk-shop-feature-facts">
                <span><b>{{ featuredStore.product_count || 0 }}</b> products</span>
                <span v-if="featuredStore.delivered_count > 0"><b>{{ featuredStore.delivered_count }}</b> delivered</span>
                <span v-if="featuredStore.avg_rating"><b>{{ featuredStore.avg_rating }}</b> rating</span>
              </div>
              <div class="mk-shop-feature-trust">
                <span v-if="shopTier(featuredStore)==='trusted'"><Icon name="shield" :size="12" /> Enkiama trusted</span>
                <span v-else-if="featuredStore.verified_delivery"><Icon name="check" :size="12" /> Verified delivery</span>
                <span v-if="featuredStore.delivers_to">Moves to {{ featuredStore.delivers_to }}</span>
              </div>
            </div>
          </RouterLink>

          <div v-if="otherStores.length" class="mk-shopgrid">
            <RouterLink v-for="s in otherStores" :key="s.id" :to="`/shop/${s.slug}`" class="mk-shopcard" data-cursor="Enter" :style="{'--sf': s.accent || 'var(--accent)'}">
              <div class="mk-shopvisual" :style="s.cover_url ? {backgroundImage:`url(${s.cover_url})`} : {}">
                <div class="mk-shopvisual-wash"></div>
                <div class="mk-shopmark" :style="{viewTransitionName:viewName('shop', s.slug || s.id)}"><Avatar :name="s.name" :accent="s.accent" :logo="s.logo_url" :size="66" /></div>
                <span class="mk-shop-open">↗</span>
              </div>
              <div class="mk-shopbody">
                <div class="mk-shop-eyebrow">
                  <span v-if="shopTier(s)==='trusted'">Enkiama trusted</span>
                  <span v-else-if="s.verified_delivery">Verified delivery</span>
                  <span v-else>Storefront</span>
                  <span v-if="s.avg_rating">★ {{ s.avg_rating }}</span>
                </div>
                <h3>{{ s.name }}</h3>
                <p>{{ s.tagline || 'Independent business on Enkiama Market.' }}</p>
                <div class="mk-shopfacts">
                  <span>{{ s.product_count }} product{{ s.product_count===1?'':'s' }}</span>
                  <span v-if="s.delivered_count > 0">{{ s.delivered_count }} delivered</span>
                  <span v-if="s.delivers_to">{{ s.delivers_to }}</span>
                </div>
              </div>
            </RouterLink>
          </div>
        </div>
      </section>

      <footer class="mk-cta">
        <span>For businesses</span>
        <h2>Your storefront.<br>Delivery already built in.</h2>
        <p>List products, reach new customers and move every order through Enkiama's tracked delivery network.</p>
        <RouterLink to="/join/business" class="mk-cta-link">Open a storefront <span>↗</span></RouterLink>
      </footer>
    </main>
    <SiteFooter />
  </div>
</template>

<style scoped>
/* ═══════════════════════════════════════════════════════════════
   ENKIAMA MARKET V2.2 — Spatial Commerce / Discovery
   Expressive entrance → quiet discovery → invisible transaction.
   No commerce/data contracts are changed here; this is UI only.
   ═══════════════════════════════════════════════════════════════ */
.mk{--market-paper:#f4f2ec;--market-ink:#121713;--market-muted:#687069;--market-line:rgba(18,23,19,.14);--market-green:#0b6e5d;min-height:100vh;background:var(--market-paper);color:var(--market-ink);overflow-x:hidden}


/* ═══════════════════════════════════════════════════════════════
   PHASE 12 — MARKET ART DIRECTION
   Media and useful objects carry the composition. Typography is
   architecture, not the entire experience. No decorative orbits.
   ═══════════════════════════════════════════════════════════════ */
.mk12-hero{--mk12-cream:#f2ede3;--mk12-paper:#faf8f2;--mk12-ink:#182019;--mk12-muted:#687067;--mk12-leaf:#31584c;--mk12-clay:#a96748;--mk12-gold:#b48a42;position:relative;overflow:hidden;background:linear-gradient(118deg,#f4efe6 0%,#f1ecdf 50%,#e9e1d3 100%);color:var(--mk12-ink);border-bottom:1px solid rgba(24,32,25,.12);isolation:isolate}
.mk12-ambient{position:absolute;inset:0;pointer-events:none;z-index:-1;background:radial-gradient(46% 60% at 77% 23%,rgba(180,138,66,.12),transparent 72%),radial-gradient(36% 48% at 10% 88%,rgba(49,88,76,.10),transparent 72%)}
.mk12-ambient::after{content:"";position:absolute;inset:0;opacity:.22;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120' viewBox='0 0 120 120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.82' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='.075'/%3E%3C/svg%3E");mix-blend-mode:multiply}
.mk12-shell{width:min(1460px,calc(100% - 64px));min-height:760px;margin:0 auto;display:grid;grid-template-columns:minmax(390px,.82fr) minmax(580px,1.18fr);gap:clamp(50px,6vw,104px);align-items:stretch;padding:70px 0 52px}
.mk12-intro{min-width:0;display:flex;flex-direction:column;justify-content:center;padding:12px 0 6px}
.mk12-kicker{display:flex;align-items:center;gap:16px;margin-bottom:54px;font:600 9px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.14em;color:#858a82}.mk12-kicker span:first-child{color:var(--mk12-clay)}
.mk12-copy{max-width:600px}.mk12-copy h1{max-width:580px;font:520 clamp(54px,5.8vw,86px)/.94 'Space Grotesk',sans-serif;letter-spacing:-.062em;color:var(--mk12-ink);text-wrap:balance}.mk12-copy h1 em{font-family:'Cormorant Garamond',Georgia,serif;font-size:1.08em;font-weight:500;letter-spacing:-.045em;color:var(--mk12-clay)}.mk12-copy p{max-width:46ch;margin-top:26px;font:400 14px/1.75 'Inter',sans-serif;color:var(--mk12-muted)}
.mk12-search{margin-top:47px;max-width:590px}.mk12-search>label{display:block;margin-bottom:11px;font:600 8px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.14em;color:#888e86}.mk12-search-line{display:grid;grid-template-columns:auto minmax(0,1fr) auto auto;align-items:center;gap:13px;border-bottom:1px solid rgba(24,32,25,.38);padding:0 0 10px;color:#727970;transition:border-color .25s ease}.mk12-search:focus-within .mk12-search-line{border-color:var(--mk12-ink)}.mk12-search-line input{min-width:0!important;border:0!important;background:transparent!important;box-shadow:none!important;outline:0!important;padding:8px 0!important;color:var(--mk12-ink)!important;font:450 14px/1.4 'Inter',sans-serif!important}.mk12-search-line input::placeholder{color:#969a93}.mk12-clear{border:0;background:none;color:#8b9089;font:500 10px/1 'Inter',sans-serif;cursor:pointer}.mk12-search-action{display:inline-flex;align-items:center;gap:7px;border:0;background:none;padding:9px 0 9px 10px;color:var(--mk12-ink);font:650 10px/1 'Inter',sans-serif;cursor:pointer}.mk12-search-action span{transition:transform .28s var(--ease)}.mk12-search-action:hover span{transform:translate(3px,-3px)}
.mk12-realms{margin-top:52px;border-top:1px solid rgba(24,32,25,.16)}.mk12-realm{width:100%;display:grid;grid-template-columns:34px minmax(0,1fr) auto;align-items:center;gap:13px;padding:17px 1px;border:0;border-bottom:1px solid rgba(24,32,25,.13);background:transparent;color:var(--mk12-ink);text-align:left;text-decoration:none;cursor:pointer;transition:padding .3s var(--ease),background .25s ease}.mk12-realm:hover,.mk12-realm.active{padding-left:10px;background:rgba(255,255,255,.28)}.mk12-realm-no{font:600 8px/1 'Spline Sans Mono',monospace;color:#9a7a46}.mk12-realm-copy{display:flex;align-items:baseline;justify-content:space-between;gap:20px;min-width:0}.mk12-realm-copy strong{font:540 19px/1.15 'Space Grotesk',sans-serif;letter-spacing:-.035em}.mk12-realm-copy small{color:#7c827a;font:400 10px/1.4 'Inter',sans-serif;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.mk12-realm-arrow{font-size:12px;color:#5e665e;transition:transform .28s var(--ease)}.mk12-realm:hover .mk12-realm-arrow{transform:translate(3px,-3px)}
.mk12-scroll{display:inline-flex;align-items:center;gap:12px;align-self:flex-start;margin-top:30px;color:#858a82;font:600 8px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.14em;text-decoration:none}.mk12-scroll span{color:var(--mk12-ink);font-size:12px}
.mk12-gallery{position:relative;min-height:650px;margin:0;align-self:center}
.mk12-main-object{position:absolute;left:1%;top:4%;width:63%;height:78%;display:flex;flex-direction:column;color:var(--mk12-ink);text-decoration:none;z-index:3}.mk12-main-media{position:relative;flex:1;min-height:0;overflow:hidden;background:#dad2c4;box-shadow:0 38px 80px rgba(46,38,26,.16)}.mk12-main-media::after{content:"";position:absolute;inset:0;background:linear-gradient(to top,rgba(10,14,11,.16),transparent 32%);pointer-events:none}.mk12-main-media img{width:100%;height:100%;display:block;object-fit:cover;transition:transform .9s var(--ease),filter .45s ease;filter:saturate(.92) contrast(.98)}.mk12-main-object:hover img{transform:scale(1.018)}.mk12-media-index{position:absolute;left:16px;top:15px;z-index:2;padding:6px 8px;background:rgba(250,248,242,.82);backdrop-filter:blur(10px);color:#4f574f;font:600 7px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.12em}.mk12-media-open{position:absolute;right:16px;bottom:15px;z-index:2;color:#fff;font:600 9px/1 'Inter',sans-serif;text-shadow:0 1px 8px rgba(0,0,0,.4)}.mk12-main-caption{display:grid;grid-template-columns:1fr auto;gap:4px 20px;padding:13px 2px 0}.mk12-main-caption>span{grid-column:1/-1;color:#858b83;font:600 7px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.12em}.mk12-main-caption strong{font:560 16px/1.25 'Space Grotesk',sans-serif;letter-spacing:-.025em}.mk12-main-caption small{align-self:center;color:#777e76;font-size:9px;white-space:nowrap}
.mk12-media-fallback{justify-content:flex-end;padding:34px;background:linear-gradient(145deg,#d7d0c2,#ebe4d8);box-shadow:0 38px 80px rgba(46,38,26,.12)}.mk12-fallback-mark{position:absolute;right:8%;top:6%;font:500 240px/.8 'Cormorant Garamond',serif;color:rgba(49,88,76,.10)}.mk12-media-fallback>span{position:relative;max-width:24ch;color:#657067;font-size:11px;line-height:1.6}
.mk12-second-object{position:absolute;right:0;top:8%;width:35%;height:39%;z-index:4;color:var(--mk12-ink);text-decoration:none}.mk12-second-media{height:calc(100% - 58px);overflow:hidden;background:#d5cec1;box-shadow:0 24px 54px rgba(46,38,26,.14)}.mk12-second-media img{width:100%;height:100%;object-fit:cover;display:block;transition:transform .8s var(--ease)}.mk12-second-object:hover img{transform:scale(1.025)}.mk12-second-object>div:last-child{padding-top:10px;display:flex;flex-direction:column;gap:3px}.mk12-second-object span{color:#8d918a;font:600 7px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.11em}.mk12-second-object strong{font:540 13px/1.25 'Space Grotesk',sans-serif;letter-spacing:-.02em}
.mk12-business-object{position:absolute;right:1%;bottom:22%;width:42%;min-height:132px;z-index:5;display:grid;grid-template-columns:110px minmax(0,1fr) auto;gap:14px;align-items:center;padding:11px;border:1px solid rgba(24,32,25,.13);background:rgba(250,248,242,.86);box-shadow:0 22px 48px rgba(46,38,26,.10);backdrop-filter:blur(12px);color:var(--mk12-ink);text-align:left;cursor:pointer}.mk12-business-media{position:relative;width:110px;height:108px;overflow:hidden;background:linear-gradient(145deg,var(--store-accent,#31584c),#15261f);background-size:cover;background-position:center}.mk12-business-shade{position:absolute;inset:0;background:linear-gradient(to top,rgba(9,15,12,.34),transparent 68%)}.mk12-business-avatar{position:absolute;left:10px;bottom:10px;padding:2px;background:#f7f3ea}.mk12-business-avatar :deep(.avatar){border-radius:0!important}.mk12-business-copy{min-width:0;display:flex;flex-direction:column;gap:4px}.mk12-business-copy span{color:#8d918a;font:600 7px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.1em}.mk12-business-copy strong{font:560 15px/1.2 'Space Grotesk',sans-serif;letter-spacing:-.03em}.mk12-business-copy small{display:-webkit-box;overflow:hidden;color:#777e76;font-size:9px;line-height:1.45;-webkit-line-clamp:2;-webkit-box-orient:vertical}.mk12-card-arrow{align-self:start;padding:4px;color:#626a62;font-size:12px;transition:transform .28s var(--ease)}.mk12-business-object:hover .mk12-card-arrow,.mk12-place-object:hover .mk12-card-arrow{transform:translate(3px,-3px)}
.mk12-place-object{position:absolute;right:9%;bottom:0;width:31%;height:142px;z-index:4;display:flex;flex-direction:column;justify-content:flex-end;overflow:hidden;padding:17px 18px;background:#d8d0bd;color:#253229;text-decoration:none;box-shadow:0 18px 38px rgba(46,38,26,.09)}.mk12-contours{position:absolute;inset:-20%;opacity:.42;transform:rotate(-11deg)}.mk12-contours span{position:absolute;border:1px solid rgba(49,88,76,.28);border-radius:50%}.mk12-contours span:nth-child(1){width:90%;height:65%;left:6%;top:10%}.mk12-contours span:nth-child(2){width:74%;height:52%;left:16%;top:20%}.mk12-contours span:nth-child(3){width:56%;height:38%;left:27%;top:30%}.mk12-contours span:nth-child(4){width:36%;height:25%;left:38%;top:38%}.mk12-place-index,.mk12-place-object strong,.mk12-place-object small,.mk12-place-object .mk12-card-arrow{position:relative;z-index:1}.mk12-place-index{margin-bottom:auto;font:600 7px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.11em;color:#6c765f}.mk12-place-object strong{font:560 15px/1.1 'Space Grotesk',sans-serif;letter-spacing:-.03em}.mk12-place-object small{margin-top:5px;color:#667063;font-size:8.5px;line-height:1.35}.mk12-place-object .mk12-card-arrow{position:absolute;right:13px;top:12px}
.mk12-status{width:min(1460px,calc(100% - 64px));margin:0 auto;display:flex;justify-content:flex-end;gap:34px;padding:13px 0 17px;border-top:1px solid rgba(24,32,25,.10);color:#7c837a;font:600 7px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.12em}.mk12-status span{display:inline-flex;align-items:center;gap:8px}.mk12-status span::before{content:"";width:4px;height:4px;border-radius:50%;background:#a96748}

/* Phase 12 also quietens the discovery layer so the media-led arrival has contrast. */
.mk-body{width:min(1400px,calc(100% - 64px))}
.mk-utility{padding-top:27px;padding-bottom:25px}
.mk-network{padding:78px 0 94px}
.mk-network-copy h2{font-size:clamp(42px,5.2vw,68px);line-height:.94;letter-spacing:-.055em}.mk-network-copy h2 em{font-family:'Cormorant Garamond',Georgia,serif;color:#8e593e;letter-spacing:-.03em}
.mk-network-map{background:radial-gradient(circle at 55% 48%,rgba(49,88,76,.095),transparent 42%),linear-gradient(135deg,rgba(169,103,72,.035),rgba(18,23,19,0))}
.mk-sections{gap:104px}.mk-section-copy h2,.mk-focused-head h2{font-size:clamp(31px,3.6vw,49px);letter-spacing:-.047em}.mk-feature-media{box-shadow:0 26px 58px rgba(35,31,23,.08)}
.mk-business-intro h2{font-size:clamp(40px,5.2vw,68px);line-height:.94;letter-spacing:-.055em}
.mk-cta{margin-top:116px;padding:58px 42px 48px;background:#e7dfd1;border-top:0;grid-template-columns:.7fr 1.8fr 1fr}.mk-cta h2{font-size:clamp(36px,4.6vw,60px)}

@media(max-width:1120px){
  .mk12-shell{grid-template-columns:minmax(340px,.8fr) minmax(500px,1.2fr);gap:44px;min-height:710px}.mk12-gallery{min-height:590px}.mk12-copy h1{font-size:clamp(50px,6vw,72px)}.mk12-realm-copy small{max-width:160px}.mk12-business-object{width:45%}.mk12-place-object{width:34%}
}
@media(max-width:860px){
  .mk12-shell{width:min(100% - 40px,720px);min-height:auto;grid-template-columns:1fr;padding:52px 0 42px;gap:46px}.mk12-intro{padding:0}.mk12-kicker{margin-bottom:36px}.mk12-copy{max-width:660px}.mk12-copy h1{max-width:630px;font-size:clamp(52px,9.8vw,76px)}.mk12-copy p{max-width:52ch}.mk12-search{max-width:100%;margin-top:36px}.mk12-realms{margin-top:38px}.mk12-gallery{min-height:620px;width:100%;max-width:680px;margin:0 auto}.mk12-status{width:min(100% - 40px,720px);justify-content:flex-start;overflow-x:auto;white-space:nowrap;scrollbar-width:none}.mk12-main-object{left:0;width:64%;height:78%}.mk12-second-object{width:37%}.mk12-business-object{width:45%;right:0}.mk12-place-object{right:4%;width:35%}
}
@media(max-width:600px){
  .mk12-shell{width:calc(100% - 24px);padding:36px 0 28px;gap:36px}.mk12-kicker{margin-bottom:28px}.mk12-copy h1{font-size:clamp(46px,14vw,62px);line-height:.96}.mk12-copy p{margin-top:19px;font-size:12.5px;line-height:1.65}.mk12-search{margin-top:30px}.mk12-search-line{grid-template-columns:auto minmax(0,1fr) auto;gap:10px}.mk12-search-action{width:42px;height:42px;padding:0;display:grid;place-items:center;border:1px solid rgba(24,32,25,.18);border-radius:50%;font-size:0}.mk12-search-action span{font-size:13px}.mk12-realm{grid-template-columns:26px minmax(0,1fr) auto;padding:15px 0}.mk12-realm-copy{display:block}.mk12-realm-copy strong{font-size:17px}.mk12-realm-copy small{display:block;margin-top:3px;max-width:none;font-size:8.5px}.mk12-gallery{display:grid;grid-template-columns:1.15fr .85fr;grid-template-rows:auto auto auto;gap:10px;min-height:0}.mk12-main-object,.mk12-second-object,.mk12-business-object,.mk12-place-object{position:relative;inset:auto;width:auto;height:auto}.mk12-main-object{grid-column:1/-1}.mk12-main-media{height:min(62svh,500px);min-height:390px}.mk12-main-caption{grid-template-columns:1fr}.mk12-main-caption small{white-space:normal}.mk12-second-object{grid-column:1;grid-row:2}.mk12-second-media{height:210px}.mk12-business-object{grid-column:2;grid-row:2;display:flex;flex-direction:column;align-items:stretch;min-height:0;padding:9px;gap:9px}.mk12-business-media{width:100%;height:130px}.mk12-business-copy strong{font-size:13px}.mk12-business-copy small{font-size:8px}.mk12-business-object>.mk12-card-arrow{position:absolute;right:13px;top:13px;color:#fff;text-shadow:0 1px 5px #000}.mk12-place-object{grid-column:1/-1;grid-row:3;height:128px;right:auto}.mk12-status{width:calc(100% - 24px);gap:24px;padding-bottom:15px}.mk-network{padding-top:58px}.mk-cta{margin-left:-12px;margin-right:-12px;padding:45px 24px 40px}.mk-cta h2{font-size:40px}
}
@media(max-width:380px){
  .mk12-gallery{grid-template-columns:1fr}.mk12-main-object,.mk12-second-object,.mk12-business-object,.mk12-place-object{grid-column:1}.mk12-second-object{grid-row:2}.mk12-business-object{grid-row:3}.mk12-place-object{grid-row:4}.mk12-second-media{height:260px}.mk12-business-object{display:grid;grid-template-columns:100px 1fr auto}.mk12-business-media{width:100px;height:100px}
}
@media(prefers-reduced-motion:reduce){.mk12-main-media img,.mk12-second-media img,.mk12-realm,.mk12-realm-arrow,.mk12-search-action span,.mk12-card-arrow{transition:none!important;transform:none!important}}

/* ── 01 / IMMERSIVE ENTRANCE ───────────────────────────────── */
.mk-stage{--orbit-x:0px;--orbit-y:0px;--orbit2-x:0px;--orbit2-y:0px;--goods-x:0px;--goods-y:0px;--business-x:0px;--business-y:0px;--property-x:0px;--property-y:0px;--float-a-x:0px;--float-a-y:0px;--float-b-x:0px;--float-b-y:0px;position:relative;min-height:min(860px,100svh);overflow:hidden;background:#101712;color:#f6f3ea;isolation:isolate}
.mk-stage::before{content:"";position:absolute;inset:-10%;z-index:-3;background:radial-gradient(70% 65% at 50% 47%,rgba(20,115,94,.22),transparent 70%),radial-gradient(38% 42% at 82% 15%,rgba(226,204,154,.08),transparent 70%)}
.mk-stage-grid{position:absolute;inset:0;z-index:-2;opacity:.22;background-image:linear-gradient(rgba(255,255,255,.045) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.045) 1px,transparent 1px);background-size:clamp(70px,8vw,124px) clamp(70px,8vw,124px);mask-image:linear-gradient(to bottom,black,transparent 86%)}
.mk-stage-orbit{position:absolute;border:1px solid rgba(246,243,234,.13);border-radius:50%;pointer-events:none;z-index:-1;transition:transform 1.2s cubic-bezier(.16,1,.3,1)}
.mk-stage-orbit::after{content:"";position:absolute;width:7px;height:7px;border-radius:50%;background:#d9be7a;box-shadow:0 0 22px rgba(217,190,122,.55)}
.mk-stage-orbit-a{width:52vw;height:52vw;min-width:620px;min-height:620px;left:50%;top:49%;transform:translate(calc(-50% + var(--orbit-x)),calc(-50% + var(--orbit-y))) rotate(-12deg)}
.mk-stage-orbit-a::after{right:15%;top:14%}
.mk-stage-orbit-b{width:29vw;height:29vw;min-width:360px;min-height:360px;left:50%;top:52%;transform:translate(calc(-50% + var(--orbit2-x)),calc(-50% + var(--orbit2-y)))}
.mk-stage-orbit-b::after{left:7%;bottom:23%;width:5px;height:5px;background:#85b7a9}
.mk-nav{position:relative;z-index:20;width:min(1460px,calc(100% - 64px));height:76px;margin:0 auto;display:grid;grid-template-columns:1fr auto 1fr;align-items:center;border-bottom:1px solid rgba(255,255,255,.12)}
.mk-logo{justify-self:start;display:flex;align-items:center}
.mk-nav-mid{display:flex;align-items:center;gap:30px}
.mk-nav-mid button,.mk-nav-mid a,.mk-navlink{position:relative;border:0;background:none;color:rgba(246,243,234,.62);font:500 12px/1.2 'Inter',sans-serif;letter-spacing:.06em;text-transform:uppercase;cursor:pointer;text-decoration:none;padding:8px 0}
.mk-nav-mid button::after,.mk-nav-mid a::after{content:"";position:absolute;left:0;right:100%;bottom:0;height:1px;background:#f6f3ea;transition:right .35s var(--ease)}
.mk-nav-mid button:hover,.mk-nav-mid button.on,.mk-nav-mid a:hover{color:#fff}
.mk-nav-mid button:hover::after,.mk-nav-mid button.on::after,.mk-nav-mid a:hover::after{right:0}
.mk-head-actions{justify-self:end;display:flex;align-items:center;gap:14px}
.mk-signin{color:#101712;background:#f6f3ea;border-radius:999px;padding:9px 15px;font-size:12px;font-weight:650;text-decoration:none}
.mk-userchip{display:inline-flex;align-items:center;gap:9px;padding:5px 11px 5px 5px;border:1px solid rgba(255,255,255,.16);border-radius:999px;text-decoration:none;background:rgba(255,255,255,.045);backdrop-filter:blur(14px)}
.mk-userchip-admin{border-color:rgba(217,190,122,.45)}
.mk-userchip-id{display:flex;flex-direction:column;line-height:1.08}.mk-userchip-name{max-width:140px;color:#fff;font-size:12px;font-weight:650;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.mk-userchip-role{color:rgba(255,255,255,.52);font-size:9.5px}.mk-admin-tag{color:#d9be7a;display:inline-flex;align-items:center;gap:3px;text-transform:uppercase;letter-spacing:.04em;font-weight:700}
.mk-stage-inner{position:relative;width:min(1460px,calc(100% - 64px));min-height:calc(min(860px,100svh) - 76px);margin:0 auto;padding:66px 0 44px}
.mk-kicker{display:flex;gap:20px;align-items:center;color:rgba(246,243,234,.48);font-size:10px;text-transform:uppercase;letter-spacing:.18em}.mk-kicker span:first-child{color:#d9be7a}
.mk-hero-copy{position:absolute;left:50%;top:45%;width:min(780px,70vw);transform:translate(-50%,-50%);text-align:center;z-index:4}
.mk-hero-copy h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(72px,10.5vw,158px);line-height:.76;letter-spacing:-.075em;font-weight:500;color:#f6f3ea;text-wrap:balance}.mk-hero-copy h1 em{font-family:Georgia,'Times New Roman',serif;font-weight:400;letter-spacing:-.07em;color:#d9be7a}
.mk-hero-copy p{width:min(500px,80%);margin:34px auto 0;color:rgba(246,243,234,.62);font-size:14px;line-height:1.75}
.mk-realm{position:absolute;z-index:7;display:grid;grid-template-columns:auto auto;grid-template-rows:auto auto auto;gap:0 10px;text-align:left;color:#f6f3ea;border:0;background:none;text-decoration:none;cursor:pointer;padding:10px;transition:transform .55s var(--ease),opacity .3s ease}.mk-realm:hover,.mk-realm.active{transform:translateY(-5px)}
.mk-realm-no{grid-row:1/4;font:500 9px/1.2 'Spline Sans Mono',monospace;color:#d9be7a;margin-top:7px}.mk-realm-name{font:500 clamp(21px,2vw,32px)/1 'Space Grotesk',sans-serif;letter-spacing:-.04em}.mk-realm-note{font-size:10px;line-height:1.4;color:rgba(246,243,234,.44);margin-top:6px}.mk-realm-arrow{position:absolute;right:-18px;top:7px;font-size:13px;opacity:0;transform:translate(-4px,4px);transition:.3s var(--ease)}.mk-realm:hover .mk-realm-arrow{opacity:1;transform:none}
.mk-realm-goods{left:7%;top:35%;transform:translate(var(--goods-x),var(--goods-y))}.mk-realm-goods:hover,.mk-realm-goods.active{transform:translate(var(--goods-x),calc(var(--goods-y) - 5px))}
.mk-realm-business{right:5%;top:31%;transform:translate(var(--business-x),var(--business-y))}.mk-realm-business:hover,.mk-realm-business.active{transform:translate(var(--business-x),calc(var(--business-y) - 5px))}
.mk-realm-property{right:13%;bottom:23%;transform:translate(var(--property-x),var(--property-y))}.mk-realm-property:hover{transform:translate(var(--property-x),calc(var(--property-y) - 5px))}
.mk-float-product{position:absolute;z-index:3;width:clamp(80px,8vw,126px);aspect-ratio:4/5;overflow:hidden;text-decoration:none;box-shadow:0 28px 70px rgba(0,0,0,.28);transition:transform .8s var(--ease),opacity .4s ease;opacity:.75}.mk-float-product img{width:100%;height:100%;object-fit:cover;filter:saturate(.8) contrast(.95);transition:transform .8s var(--ease)}.mk-float-product span{position:absolute;inset:auto 7px 7px;color:white;font-size:8px;line-height:1.2;text-shadow:0 1px 4px #000;opacity:0;transition:.25s}.mk-float-product:hover{opacity:1}.mk-float-product:hover img{transform:scale(1.045)}.mk-float-product:hover span{opacity:.85}
.mk-float-a{left:20%;bottom:18%;transform:rotate(-6deg) translate(var(--float-a-x),var(--float-a-y))}.mk-float-b{right:23%;top:20%;width:clamp(72px,7vw,108px);transform:rotate(5deg) translate(var(--float-b-x),var(--float-b-y))}
.mk-search{position:absolute;left:50%;bottom:54px;z-index:10;width:min(680px,64vw);transform:translateX(-50%)}
.mk-search-label{display:block;margin-bottom:8px;color:rgba(246,243,234,.42);font-size:9px;text-transform:uppercase;letter-spacing:.16em}
.mk-search-line{display:flex;align-items:center;gap:13px;border-bottom:1px solid rgba(246,243,234,.38);padding:0 0 11px;color:rgba(246,243,234,.48);transition:border-color .25s}.mk-search:focus-within .mk-search-line{border-color:#f6f3ea}.mk-search-line input{min-width:0;flex:1;border:0;background:none;box-shadow:none!important;color:#fff;font:400 15px/1.4 'Inter',sans-serif;padding:3px 0}.mk-search-line input:focus{outline:0}.mk-search-line input::placeholder{color:rgba(246,243,234,.42)}.mk-search-clear{border:0;background:none;color:rgba(246,243,234,.48);font-size:11px;cursor:pointer}.mk-search-go{width:34px;height:34px;border:1px solid rgba(246,243,234,.22);border-radius:50%;background:rgba(255,255,255,.04);color:#fff;display:grid;place-items:center;cursor:pointer}.mk-search-go:hover{background:#f6f3ea;color:#101712}
.mk-scrollcue{position:absolute;left:0;bottom:35px;display:flex;gap:12px;align-items:center;color:rgba(246,243,234,.4);font-size:9px;text-transform:uppercase;letter-spacing:.14em;text-decoration:none}

/* ── DISCOVERY / UTILITY ───────────────────────────────────── */
.mk-body{width:min(1460px,calc(100% - 64px));margin:0 auto;padding:0 0 110px}
.mk-utility{scroll-margin-top:0;padding:34px 0 30px;border-bottom:1px solid var(--market-line)}
.mk-modebar,.mk-locationbar,.mk-filterbar{display:flex;align-items:center;justify-content:space-between;gap:30px}.mk-modebar{min-height:45px}.mk-locationbar{padding:18px 0;border-top:1px solid var(--market-line);border-bottom:1px solid var(--market-line)}
.mk-modegroup{display:flex;align-items:center;gap:23px}.mk-util-label{font:500 9px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.12em;color:#919791;min-width:55px}.mk-mode{position:relative;border:0;background:none;padding:6px 0;color:#7a827b;text-decoration:none;font:500 14px/1.2 'Inter',sans-serif;cursor:pointer}.mk-mode::after{content:"";position:absolute;left:0;right:100%;bottom:-3px;height:1px;background:var(--market-ink);transition:right .3s var(--ease)}.mk-mode.on,.mk-mode:hover{color:var(--market-ink)}.mk-mode.on::after,.mk-mode:hover::after{right:0}.mk-count{font:500 10px/1 'Spline Sans Mono',monospace;color:#8a918b;text-transform:uppercase;letter-spacing:.07em}
.mk-corridors{display:flex;align-items:center;gap:22px;overflow-x:auto;scrollbar-width:none}.mk-corridors::-webkit-scrollbar{display:none}.mk-corr{flex:0 0 auto;border:0;background:none;color:#7c837d;font:500 12px/1.2 'Inter',sans-serif;cursor:pointer;padding:7px 0;position:relative}.mk-corr::before{content:"";position:absolute;width:4px;height:4px;left:-10px;top:50%;border-radius:50%;background:transparent;transform:translateY(-50%)}.mk-corr:hover,.mk-corr.on{color:var(--market-ink)}.mk-corr.on::before{background:var(--market-green)}
.mk-categorybar{display:flex;gap:26px;overflow:auto;padding:24px 0 20px;scrollbar-width:none}.mk-categorybar::-webkit-scrollbar{display:none}.mk-cat{flex:0 0 auto;border:0;background:none;color:#858b85;font:500 clamp(15px,1.5vw,20px)/1.15 'Space Grotesk',sans-serif;letter-spacing:-.025em;cursor:pointer;padding:0}.mk-cat sup{font:500 8px/1 'Spline Sans Mono',monospace;color:#a1a6a1;margin-left:3px;vertical-align:super}.mk-cat:hover,.mk-cat.on{color:var(--market-ink)}
.mk-filterbar{padding-top:15px}.mk-filters{display:flex;align-items:center;gap:18px}.mk-filter{display:inline-flex;align-items:center;gap:7px;border:0;background:none;color:#727a73;font-size:11px;font-family:inherit;cursor:pointer}.mk-filter-dot{width:9px;height:9px;border:1px solid #9da39e;border-radius:50%;transition:.2s}.mk-filter.on{color:var(--market-ink)}.mk-filter.on .mk-filter-dot{border-color:var(--market-green);background:var(--market-green);box-shadow:inset 0 0 0 2px var(--market-paper)}.mk-filter-clear{border:0;background:none;color:var(--market-green);font-size:10px;cursor:pointer}.mk-sortselect{display:flex;align-items:center;gap:8px;color:#858b85;font-size:10px}.mk-sortselect select{width:auto;border:0;border-bottom:1px solid var(--market-line);border-radius:0;background:transparent;box-shadow:none;padding:6px 24px 6px 2px;font-size:11px;color:var(--market-ink)}
.mk-shop-sort{display:flex;gap:20px}.mk-shop-sort button{border:0;background:none;color:#858b85;font-size:11px;cursor:pointer}.mk-shop-sort button.on,.mk-shop-sort button:hover{color:var(--market-ink)}

/* ── PRODUCT DISCOVERY: objects, not cards ─────────────────── */
.mk-content{padding-top:54px}.mk-searchinfo{display:flex;justify-content:space-between;align-items:center;padding-bottom:28px;color:#747b75;font-size:12px}.mk-searchinfo strong{color:var(--market-ink);font-weight:600}.mk-searchinfo button{border:0;background:none;color:var(--market-green);font-size:11px;cursor:pointer}
.mk-sections{display:flex;flex-direction:column;gap:90px}.mk-section{position:relative}.mk-section-head{display:grid;grid-template-columns:80px 1fr auto;align-items:end;gap:18px;margin-bottom:26px;padding-bottom:17px;border-bottom:1px solid var(--market-line)}.mk-section-index{font:500 10px/1 'Spline Sans Mono',monospace;color:#9aa09a}.mk-section-copy span,.mk-focused-head>div>span{display:block;color:#929892;font-size:9px;text-transform:uppercase;letter-spacing:.13em;margin-bottom:7px}.mk-section-copy h2,.mk-focused-head h2{font:500 clamp(32px,4vw,58px)/.95 'Space Grotesk',sans-serif;letter-spacing:-.055em;color:var(--market-ink)}.mk-section-more,.mk-focused-head button{border:0;background:none;color:var(--market-ink);font-size:11px;cursor:pointer;padding:7px 0}.mk-section-more span,.mk-focused-head button span{display:inline-block;margin-left:7px;transition:transform .3s var(--ease)}.mk-section-more:hover span,.mk-focused-head button:hover span{transform:translate(3px,-3px)}
.mk-prow{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:26px 16px}.mk-pgrid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:46px 18px}.mk-focused-head{display:flex;align-items:end;justify-content:space-between;margin-bottom:30px;padding-bottom:18px;border-bottom:1px solid var(--market-line)}
.mk-pcard{min-width:0;display:flex;flex-direction:column;color:var(--market-ink);text-decoration:none;background:transparent;border:0;border-radius:0;overflow:visible}.mk-pimg{position:relative;aspect-ratio:1/1.08;overflow:hidden;background:#e9e7e0}.mk-pimg img{width:100%;height:100%;object-fit:cover;display:block;transition:transform .8s var(--ease),filter .4s ease}.mk-pcard:hover .mk-pimg img{transform:scale(1.035)}.mk-pimg-ph{position:absolute;inset:0;display:grid;place-items:center}.mk-pimg-ph::after{content:"";position:absolute;inset:0;background:radial-gradient(circle at 50% 35%,rgba(255,255,255,.22),transparent 58%)}.mk-pimg-ph span{position:relative;z-index:1;color:rgba(255,255,255,.88);font:500 34px/1 'Space Grotesk',sans-serif}.mk-open{position:absolute;right:10px;bottom:10px;z-index:2;width:34px;height:34px;border-radius:50%;background:rgba(244,242,236,.92);color:#121713;display:grid;place-items:center;font-size:13px;opacity:0;transform:translate(-5px,5px);transition:.35s var(--ease)}.mk-pcard:hover .mk-open{opacity:1;transform:none}.mk-poff,.mk-psold{position:absolute;top:10px;z-index:2;padding:5px 8px;background:rgba(16,23,18,.78);backdrop-filter:blur(8px);color:#fff;font:600 9px/1 'Spline Sans Mono',monospace;letter-spacing:.03em}.mk-poff{left:10px}.mk-psold{right:10px;text-transform:uppercase}
.mk-pbody{padding:12px 0 0;display:flex;flex-direction:column;gap:7px}.mk-pname{font-size:12.5px;font-weight:500;line-height:1.4;color:var(--market-ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.mk-pprice-row{display:flex;align-items:baseline;gap:7px}.mk-pprice{font:550 13px/1.2 'Space Grotesk',sans-serif;letter-spacing:-.015em}.mk-pwas{font-size:10px;color:#9aa09a;text-decoration:line-through}.mk-pfoot{display:flex;align-items:center;justify-content:space-between;gap:7px;color:#8d938e;font-size:9.5px;padding-top:2px}.mk-pfoot>span:first-child{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.mk-pverif{display:inline-flex;align-items:center;gap:2px;color:var(--market-green);font-size:8.5px;font-weight:650;flex-shrink:0}
.mk-skeleton{min-height:290px;background:linear-gradient(100deg,#eae7df 30%,#f5f3ed 45%,#eae7df 60%);background-size:300% 100%;animation:mkShimmer 1.5s linear infinite}@keyframes mkShimmer{to{background-position:-150% 0}}

/* ── 02 / GEOGRAPHIC DISCOVERY ─────────────────────────────── */
.mk-network{display:grid;grid-template-columns:minmax(260px,.72fr) minmax(520px,1.45fr);gap:clamp(48px,8vw,130px);align-items:center;padding:88px 0 110px;border-bottom:1px solid var(--market-line)}
.mk-network-copy{align-self:center}.mk-network-index{display:block;font:500 9px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.12em;color:#929892;margin-bottom:28px}.mk-network-copy h2{font:500 clamp(46px,6vw,84px)/.9 'Space Grotesk',sans-serif;letter-spacing:-.065em;max-width:640px}.mk-network-copy h2 em{font-family:Georgia,serif;font-weight:400;color:var(--market-green)}.mk-network-copy>p{max-width:390px;margin-top:24px;color:#737a74;font-size:12px;line-height:1.75}.mk-network-state{display:grid;grid-template-columns:1fr auto;align-items:end;gap:5px 18px;margin-top:44px;padding-top:15px;border-top:1px solid var(--market-line);max-width:390px}.mk-network-state span{font-size:8px;text-transform:uppercase;letter-spacing:.12em;color:#969c96}.mk-network-state strong{grid-column:1;font:550 15px/1.2 'Space Grotesk',sans-serif}.mk-network-state button{grid-column:2;grid-row:1/3;align-self:center;border:0;background:none;color:var(--market-green);font-size:10px;cursor:pointer}
.mk-network-map{position:relative;aspect-ratio:1.48/1;min-height:500px;background:radial-gradient(circle at 54% 48%,rgba(11,110,93,.08),transparent 42%),linear-gradient(135deg,rgba(18,23,19,.025),rgba(18,23,19,0));border-left:1px solid var(--market-line);overflow:hidden}.mk-network-map::before{content:"";position:absolute;inset:8% 5%;border:1px solid rgba(18,23,19,.06);border-radius:48% 52% 43% 57%/45% 49% 51% 55%;transform:rotate(-8deg)}.mk-network-lines{position:absolute;inset:0;width:100%;height:100%;overflow:visible}.mk-network-lines path{fill:none;stroke:rgba(18,23,19,.17);stroke-width:.19;stroke-dasharray:1.2 1.35;vector-effect:non-scaling-stroke}.mk-network-node{position:absolute;z-index:3;transform:translate(-50%,-50%);border:0;background:transparent;color:var(--market-ink);cursor:pointer;padding:12px;display:flex;align-items:center;gap:9px;text-align:left}.mk-node-dot{position:relative;width:8px;height:8px;border-radius:50%;background:var(--market-paper);border:1px solid rgba(18,23,19,.55);box-shadow:0 0 0 0 rgba(11,110,93,.15);transition:.35s var(--ease)}.mk-node-dot::after{content:"";position:absolute;inset:2px;border-radius:50%;background:transparent;transition:.35s var(--ease)}.mk-node-label{display:flex;flex-direction:column;gap:2px;white-space:nowrap;transition:transform .35s var(--ease)}.mk-node-label b{font:550 11px/1.2 'Space Grotesk',sans-serif}.mk-node-label small{font:500 7px/1 'Spline Sans Mono',monospace;color:#9a9f9a;letter-spacing:.12em}.mk-network-node:hover .mk-node-label,.mk-network-node.on .mk-node-label{transform:translateX(3px)}.mk-network-node:hover .mk-node-dot,.mk-network-node.on .mk-node-dot{border-color:var(--market-green);box-shadow:0 0 0 7px rgba(11,110,93,.09)}.mk-network-node.on .mk-node-dot::after{background:var(--market-green)}.mk-network-watermark{position:absolute;right:1%;bottom:-8%;font:500 clamp(150px,22vw,330px)/1 'Space Grotesk',sans-serif;letter-spacing:-.08em;color:rgba(18,23,19,.028);pointer-events:none}

/* ── EDITORIAL COLLECTIONS ─────────────────────────────────── */
.mk-editorial{display:grid;grid-template-columns:minmax(0,1.65fr) minmax(310px,.78fr);gap:clamp(28px,4vw,64px);align-items:stretch}.mk-editorial--flip{grid-template-columns:minmax(310px,.78fr) minmax(0,1.65fr)}.mk-editorial--flip .mk-feature-object{grid-column:2;grid-row:1}.mk-editorial--flip .mk-object-index{grid-column:1;grid-row:1}.mk-feature-object{display:grid;grid-template-rows:minmax(0,1fr) auto;min-width:0;color:var(--market-ink);text-decoration:none}.mk-feature-media{position:relative;min-height:520px;overflow:hidden;background:#e9e7e0}.mk-feature-media img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;transition:transform 1s var(--ease)}.mk-feature-object:hover .mk-feature-media img{transform:scale(1.025)}.mk-feature-open{position:absolute;left:18px;bottom:18px;padding:9px 12px;background:rgba(244,242,236,.9);backdrop-filter:blur(10px);font:600 9px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.08em;transition:transform .35s var(--ease)}.mk-feature-object:hover .mk-feature-open{transform:translate(3px,-3px)}.mk-feature-copy{display:grid;grid-template-columns:1fr auto;gap:7px 18px;padding-top:16px}.mk-feature-shop{grid-column:1/-1;font-size:9px;text-transform:uppercase;letter-spacing:.1em;color:#929892}.mk-feature-copy h3{font:550 clamp(25px,3vw,40px)/1.05 'Space Grotesk',sans-serif;letter-spacing:-.045em;max-width:680px}.mk-feature-price{display:flex;flex-direction:column;align-items:flex-end;gap:4px;white-space:nowrap}.mk-feature-price strong{font:550 15px/1.2 'Space Grotesk',sans-serif}.mk-feature-price span{font-size:9px;color:#9aa09a;text-decoration:line-through}
.mk-object-index{display:flex;flex-direction:column;border-top:1px solid var(--market-line)}.mk-object-row{display:grid;grid-template-columns:28px 72px minmax(0,1fr) auto 18px;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid var(--market-line);color:var(--market-ink);text-decoration:none;min-width:0;transition:padding .35s var(--ease)}.mk-object-row:hover{padding-left:6px}.mk-object-no{font:500 8px/1 'Spline Sans Mono',monospace;color:#a2a7a2}.mk-object-thumb{position:relative;width:72px;aspect-ratio:1/1;overflow:hidden;background:#e9e7e0}.mk-object-thumb img,.mk-object-thumb-ph{width:100%;height:100%;object-fit:cover;display:block}.mk-object-copy{min-width:0}.mk-object-copy b{display:block;font:550 12px/1.35 'Space Grotesk',sans-serif;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.mk-object-copy span{display:block;margin-top:4px;color:#8c928c;font-size:9px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.mk-object-price{font:550 10px/1.2 'Space Grotesk',sans-serif;white-space:nowrap}.mk-object-arrow{font-size:12px;transition:transform .3s var(--ease)}.mk-object-row:hover .mk-object-arrow{transform:translate(3px,-3px)}.mk-object-all{margin-top:auto;padding:18px 0 0;border:0;background:none;text-align:left;color:var(--market-ink);font-size:10px;font-weight:600;cursor:pointer}.mk-object-all span{display:inline-block;margin-left:7px;transition:transform .3s var(--ease)}.mk-object-all:hover span{transform:translate(3px,-3px)}

/* ── BUSINESS DISCOVERY ────────────────────────────────────── */
.mk-business-intro{display:grid;grid-template-columns:1fr 2fr 1fr;gap:24px;align-items:end;margin:8px 0 58px}.mk-business-intro>span{align-self:start;font:500 9px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.12em;color:#939993}.mk-business-intro h2{font:500 clamp(43px,6vw,84px)/.9 'Space Grotesk',sans-serif;letter-spacing:-.065em;color:var(--market-ink)}.mk-business-intro p{color:#737a74;font-size:12px;line-height:1.7;max-width:290px}
.mk-business-ledger{display:flex;flex-direction:column;gap:72px}.mk-shop-feature{display:grid;grid-template-columns:minmax(0,1.5fr) minmax(320px,.72fr);min-height:560px;color:var(--market-ink);text-decoration:none;border-top:1px solid var(--market-line);border-bottom:1px solid var(--market-line)}.mk-shop-feature-visual{position:relative;min-height:560px;background:linear-gradient(145deg,var(--sf),#15241e);background-size:cover;background-position:center;overflow:hidden}.mk-shop-feature-visual::after{content:"";position:absolute;inset:0;background:linear-gradient(120deg,transparent 50%,rgba(10,18,14,.22))}.mk-shop-feature-mark{position:absolute;left:24px;bottom:24px;z-index:2;padding:5px;background:var(--market-paper)}.mk-shop-feature-open{position:absolute;right:22px;top:22px;z-index:3;padding:9px 12px;border:1px solid rgba(255,255,255,.48);background:rgba(10,18,14,.12);backdrop-filter:blur(8px);color:#fff;font:600 8px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.08em;transition:.35s var(--ease)}.mk-shop-feature:hover .mk-shop-feature-open{transform:translate(3px,-3px);background:rgba(10,18,14,.28)}.mk-shop-feature-copy{padding:44px 0 44px clamp(28px,4vw,58px);display:flex;flex-direction:column;justify-content:center}.mk-shop-feature-kicker{font:500 8px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.13em;color:#969c96}.mk-shop-feature-copy h3{font:550 clamp(40px,5vw,72px)/.92 'Space Grotesk',sans-serif;letter-spacing:-.06em;margin-top:18px}.mk-shop-feature-copy>p{font-size:12px;line-height:1.7;color:#737a74;margin-top:20px;max-width:360px}.mk-shop-feature-facts{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-top:42px;padding-top:18px;border-top:1px solid var(--market-line)}.mk-shop-feature-facts span{display:flex;flex-direction:column;gap:3px;color:#929892;font-size:8px;text-transform:uppercase;letter-spacing:.08em}.mk-shop-feature-facts b{font:550 18px/1 'Space Grotesk',sans-serif;color:var(--market-ink);letter-spacing:-.03em}.mk-shop-feature-trust{display:flex;gap:16px;flex-wrap:wrap;margin-top:28px;color:#737a74;font-size:9.5px}.mk-shop-feature-trust span{display:inline-flex;align-items:center;gap:5px}
.mk-shopgrid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:42px 18px}.mk-shopcard{min-width:0;color:var(--market-ink);text-decoration:none}.mk-shopvisual{position:relative;aspect-ratio:4/3;background:linear-gradient(145deg,var(--sf),#15241e);background-size:cover;background-position:center;overflow:hidden}.mk-shopvisual-wash{position:absolute;inset:0;background:linear-gradient(to top,rgba(10,18,14,.38),transparent 65%)}.mk-shopmark{position:absolute;left:18px;bottom:18px;padding:4px;background:#f4f2ec}.mk-shopmark :deep(.avatar){border-radius:0!important}.mk-shop-open{position:absolute;right:14px;top:14px;width:37px;height:37px;border:1px solid rgba(255,255,255,.45);border-radius:50%;display:grid;place-items:center;color:#fff;opacity:.65;transition:.35s var(--ease)}.mk-shopcard:hover .mk-shop-open{opacity:1;transform:translate(3px,-3px)}.mk-shopbody{padding-top:15px}.mk-shop-eyebrow{display:flex;justify-content:space-between;color:#899089;font-size:8.5px;text-transform:uppercase;letter-spacing:.08em}.mk-shopbody h3{font:550 24px/1.15 'Space Grotesk',sans-serif;letter-spacing:-.035em;margin-top:9px}.mk-shopbody p{font-size:11px;line-height:1.55;color:#787f79;margin-top:6px;min-height:34px}.mk-shopfacts{display:flex;gap:14px;flex-wrap:wrap;margin-top:14px;padding-top:12px;border-top:1px solid var(--market-line);font-size:9.5px;color:#8a918b}

/* ── QUIET CONVERSION ──────────────────────────────────────── */
.mk-cta{margin-top:130px;padding:70px 0 16px;border-top:1px solid var(--market-line);display:grid;grid-template-columns:1fr 2fr 1.15fr;gap:30px;align-items:start}.mk-cta>span{font:500 9px/1 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.12em;color:#939993}.mk-cta h2{font:500 clamp(38px,5vw,68px)/.94 'Space Grotesk',sans-serif;letter-spacing:-.055em;color:var(--market-ink)}.mk-cta p{color:#737a74;font-size:12px;line-height:1.7}.mk-cta-link{display:inline-flex;align-items:center;gap:9px;margin-top:20px;padding-bottom:6px;border-bottom:1px solid currentColor;color:var(--market-ink);font-size:11px;font-weight:600;text-decoration:none}.mk-cta-link span{transition:transform .3s var(--ease)}.mk-cta-link:hover span{transform:translate(3px,-3px)}

/* ── RESPONSIVE / MOTION SAFETY ────────────────────────────── */
@media(max-width:1050px){
  .mk-stage{min-height:760px}.mk-stage-inner{min-height:684px}.mk-realm-goods{left:2%}.mk-realm-business{right:1%}.mk-realm-property{right:5%}.mk-float-a{left:16%}.mk-float-b{right:17%}
  .mk-prow{grid-template-columns:repeat(3,1fr)}.mk-pgrid{grid-template-columns:repeat(3,1fr)}.mk-shopgrid{grid-template-columns:repeat(2,1fr)}.mk-network{grid-template-columns:.8fr 1.2fr;gap:48px}.mk-network-map{min-height:450px}.mk-feature-media{min-height:450px}.mk-shop-feature{grid-template-columns:1.2fr .8fr}
}
@media(max-width:760px){
  .mk-nav,.mk-stage-inner,.mk-body{width:min(100% - 32px,1460px)}.mk-nav{grid-template-columns:1fr auto;height:66px}.mk-nav-mid{display:none}.mk-navlink{display:none}.mk-stage{min-height:790px}.mk-stage-inner{min-height:724px;padding-top:34px}.mk-hero-copy{top:30%;width:100%}.mk-hero-copy h1{font-size:clamp(66px,20vw,110px)}.mk-hero-copy p{width:min(440px,92%);margin-top:24px}.mk-stage-orbit-a{min-width:540px;min-height:540px;top:38%}.mk-stage-orbit-b{min-width:330px;min-height:330px;top:40%}
  .mk-realm{top:auto!important;bottom:205px!important}.mk-realm-goods{left:0}.mk-realm-business{left:34%;right:auto}.mk-realm-property{right:0}.mk-realm-note{display:none}.mk-realm-name{font-size:18px}.mk-realm-no{font-size:7px}.mk-realm-arrow{display:none}.mk-float-product{display:none}.mk-search{width:100%;bottom:88px}.mk-scrollcue{bottom:31px}
  .mk-modebar{align-items:flex-start}.mk-modegroup{gap:15px;flex-wrap:wrap}.mk-modegroup .mk-util-label{width:100%}.mk-count{padding-top:6px}.mk-locationbar{align-items:flex-start;gap:12px}.mk-locationbar .mk-util-label{padding-top:8px}.mk-categorybar{gap:20px}.mk-filterbar{align-items:flex-start}.mk-filters{gap:12px;flex-wrap:wrap}.mk-sortselect{flex-shrink:0}
  .mk-network{grid-template-columns:1fr;padding:68px 0 82px;gap:36px}.mk-network-copy>p,.mk-network-state{max-width:520px}.mk-network-map{border-left:0;border-top:1px solid var(--market-line);min-height:430px}.mk-section-head{grid-template-columns:42px 1fr auto}.mk-prow,.mk-pgrid{grid-template-columns:repeat(2,1fr);gap:34px 12px}.mk-sections{gap:74px}.mk-editorial,.mk-editorial--flip{grid-template-columns:1fr}.mk-editorial--flip .mk-feature-object,.mk-editorial--flip .mk-object-index{grid-column:auto;grid-row:auto}.mk-feature-media{min-height:460px}.mk-business-intro{grid-template-columns:1fr;gap:14px}.mk-business-intro p{max-width:460px}.mk-shop-feature{grid-template-columns:1fr}.mk-shop-feature-visual{min-height:430px}.mk-shop-feature-copy{padding:34px 0}.mk-shopgrid{grid-template-columns:1fr}.mk-cta{grid-template-columns:1fr;gap:18px;margin-top:90px}
}
@media(max-width:480px){
  .mk-stage{min-height:760px}.mk-stage-inner{min-height:694px}.mk-head-actions .mk-userchip-id{display:none}.mk-signin{padding:8px 12px}.mk-hero-copy{top:28%}.mk-hero-copy h1{font-size:clamp(62px,22vw,96px)}.mk-hero-copy p{font-size:12.5px}.mk-realm{bottom:208px!important;padding:6px}.mk-realm-business{left:33%}.mk-realm-name{font-size:16px}.mk-search-line input{font-size:13px}.mk-scrollcue{font-size:8px}.mk-body{width:calc(100% - 24px)}.mk-utility{padding-top:28px}.mk-modebar{gap:8px}.mk-modegroup{gap:13px}.mk-mode{font-size:12px}.mk-count{font-size:8px}.mk-corridors{gap:18px}.mk-corr{font-size:11px}.mk-categorybar{padding-top:20px}.mk-cat{font-size:15px}.mk-filterbar{gap:10px}.mk-filters{gap:10px}.mk-filter{font-size:10px}.mk-sortselect>span{display:none}.mk-sortselect select{max-width:110px;font-size:10px}.mk-content{padding-top:40px}.mk-section-head{grid-template-columns:28px 1fr auto;gap:8px}.mk-section-copy h2,.mk-focused-head h2{font-size:30px}.mk-section-more{font-size:9px}.mk-network{padding:54px 0 68px}.mk-network-copy h2{font-size:46px}.mk-network-map{min-height:355px;margin-left:-4px;margin-right:-4px}.mk-node-label b{font-size:9px}.mk-node-label small{font-size:6px}.mk-network-node{padding:8px;gap:6px}.mk-feature-media{min-height:360px}.mk-feature-copy{grid-template-columns:1fr}.mk-feature-price{align-items:flex-start}.mk-object-row{grid-template-columns:22px 58px minmax(0,1fr) 15px;gap:8px}.mk-object-thumb{width:58px}.mk-object-price{display:none}.mk-shop-feature-visual{min-height:340px}.mk-shop-feature-copy h3{font-size:40px}.mk-shop-feature-facts{grid-template-columns:repeat(3,1fr)}.mk-pbody{padding-top:9px}.mk-pname{font-size:11.5px}.mk-pprice{font-size:11.5px}.mk-pfoot{font-size:8.5px}.mk-business-intro h2{font-size:45px}.mk-shopbody h3{font-size:21px}
}
@media(prefers-reduced-motion:reduce){.mk-stage-orbit,.mk-realm,.mk-float-product,.mk-pimg img,.mk-open,.mk-feature-media img,.mk-feature-open,.mk-object-row,.mk-object-arrow,.mk-network-node,.mk-node-dot,.mk-node-label,.mk-shop-feature-open{transform:none!important;transition:none!important}.mk-scrollcue{scroll-behavior:auto}}

/* PHASE 9 — MARKET / mobile is an intentional discovery canvas */
@media(max-width:760px){
  .mk-stage{min-height:max(700px,100svh)}
  .mk-stage-inner{min-height:calc(max(700px,100svh) - 66px);padding-bottom:env(safe-area-inset-bottom)}
  .mk-search-go{width:44px;height:44px;flex:0 0 44px}
  .mk-mode,.mk-corr,.mk-filter{min-height:44px;display:inline-flex;align-items:center}
  .mk-categorybar{overflow-x:auto;scroll-snap-type:x proximity;scrollbar-width:none;padding-bottom:3px}
  .mk-categorybar::-webkit-scrollbar{display:none}
  .mk-cat{flex:0 0 auto;min-height:46px;display:inline-flex;align-items:center;scroll-snap-align:start}
  .mk-corridors{scroll-snap-type:x proximity;overscroll-behavior-inline:contain}
  .mk-corr{scroll-snap-align:start}
  .mk-prow,.mk-pgrid{scroll-margin-top:76px}
  .mk-pcard,.mk-object-row,.mk-shopcard{-webkit-tap-highlight-color:transparent}
  .mk-open,.mk-shop-open{opacity:1;transform:none}
  .mk-feature-open,.mk-shop-feature-open{transform:none}
  .mk-network-map{min-height:min(66svh,560px)}
  .mk-feature-media{min-height:min(72svh,520px)}
  .mk-shop-feature-visual{min-height:min(66svh,480px)}
}
@media(max-width:480px){
  .mk-nav,.mk-stage-inner{width:calc(100% - 24px)}
  .mk-hero-copy h1{font-size:clamp(58px,21vw,86px);line-height:.79}
  .mk-hero-copy p{max-width:32ch;line-height:1.6}
  .mk-realm{bottom:212px!important;max-width:31%}
  .mk-realm-name{font-size:15px;overflow-wrap:anywhere}
  .mk-search{bottom:82px}
  .mk-scrollcue{bottom:24px}
  .mk-section-head{grid-template-columns:30px minmax(0,1fr);gap:10px}
  .mk-section-more{grid-column:2;justify-self:start}
  .mk-section-copy h2,.mk-focused-head h2{font-size:34px}
  .mk-prow,.mk-pgrid{gap:28px 9px}
  .mk-pbody{padding-top:9px}.mk-pname{font-size:11.5px}.mk-pprice{font-size:12px}
  .mk-object-row{grid-template-columns:22px 54px minmax(0,1fr) 16px;grid-template-rows:auto auto;gap:7px 9px;padding:11px 0}
  .mk-object-no{grid-row:1/3}.mk-object-thumb{width:54px;grid-row:1/3}.mk-object-copy{grid-column:3;grid-row:1}.mk-object-price{grid-column:3;grid-row:2;color:#727a73}.mk-object-arrow{grid-column:4;grid-row:1/3;align-self:center}
  .mk-business-intro h2{font-size:42px}
  .mk-shop-feature-copy h3{font-size:40px}
  .mk-shop-feature-facts{grid-template-columns:repeat(3,minmax(0,1fr));gap:6px}.mk-shop-feature-facts b{font-size:16px}
}
@media(pointer:coarse){
  .mk-pcard:hover .mk-pimg img,.mk-shopcard:hover .mk-shop-open,.mk-object-row:hover,.mk-shop-feature:hover .mk-shop-feature-open{transform:none}
}

/* Phase 17 — discovery controls recede behind the market content */
.mk-utility{padding:24px 0 22px;border-bottom:1px solid var(--market-line);background:transparent}
.mk-modebar,.mk-locationbar,.mk-filterbar{gap:24px}
.mk-modegroup{display:flex;align-items:center;gap:18px}.mk-util-label{font:500 8.5px/1 var(--font-mono);letter-spacing:.1em;text-transform:uppercase;color:#91978f}
.mk-mode{font-size:11px;font-weight:600;color:#737b73;padding:6px 0;border-bottom:1px solid transparent}.mk-mode.on,.mk-mode:hover{color:var(--market-ink);border-bottom-color:var(--market-ink)}
.mk-shop-sort{display:flex;gap:14px}.mk-shop-sort button{font-size:10px;padding:5px 0;border:0;border-bottom:1px solid transparent;background:transparent;color:#838981}.mk-shop-sort button.on{color:var(--market-ink);border-color:var(--market-ink)}
.mk-locationbar{padding:14px 0}.mk-corridors{gap:16px}.mk-corr{font-size:10px;padding:7px 0;border:0;border-bottom:1px solid transparent;background:transparent;color:#7b827b}.mk-corr.on{color:var(--market-ink);border-color:var(--market-ink)}
.mk-categorybar{padding:18px 0 14px;gap:22px}.mk-cat{font-size:14px}.mk-filterbar{padding-top:12px}.mk-filters{gap:14px}.mk-filter{font-size:10px;min-height:32px}.mk-filter-clear{font:600 9px var(--font-mono);text-transform:uppercase;letter-spacing:.05em}.mk-sortselect{font-size:9px}.mk-sortselect select{min-height:34px;padding-top:4px;padding-bottom:4px}
@media(max-width:640px){.mk-utility{padding:18px 0}.mk-modebar{align-items:flex-start}.mk-modegroup{gap:14px}.mk-locationbar{padding:10px 0}.mk-filterbar{gap:12px}.mk-filter{min-height:40px}.mk-sortselect select{min-height:40px}}


/* PHASE 18 — governed media behavior */
.mk12-main-object:hover .mk12-main-media :deep(img),.mk12-second-object:hover .mk12-second-media :deep(img),.mk-pcard:hover .mk-pimg :deep(img),.mk-feature-object:hover .mk-feature-media :deep(img){transform:scale(1.022)}
.mk-object-row:hover .mk-object-thumb :deep(img){transform:scale(1.025)}
.mk12-business-media :deep(img){filter:saturate(.9) contrast(.98)}
@media(prefers-reduced-motion:reduce){.mk12-main-media :deep(img),.mk12-second-media :deep(img),.mk-pimg :deep(img),.mk-feature-media :deep(img),.mk-object-thumb :deep(img){transform:none!important;transition:none!important}}

/* ═══ PHASE 21 — MARKET RESPONSIVE ART DIRECTION ═══ */
@media(min-width:1600px){
  .mk12-shell{width:min(1520px,calc(100% - 112px));min-height:820px;grid-template-columns:minmax(420px,.84fr) minmax(660px,1.16fr);gap:104px;padding:82px 0 60px}
  .mk12-gallery{min-height:700px}.mk12-copy h1{font-size:clamp(68px,4.9vw,88px)}
  .mk12-status{width:min(1520px,calc(100% - 112px))}.mk-body{width:min(1480px,calc(100% - 112px))}
  .mk-network{gap:120px}.mk-network-map{min-height:540px}.mk-feature-media{min-height:560px}
  .mk-prow{grid-template-columns:repeat(6,minmax(0,1fr))}.mk-pgrid{grid-template-columns:repeat(4,minmax(0,1fr))}
}
@media(min-width:1180px) and (max-width:1599px){
  .mk12-shell{width:min(1320px,calc(100% - 64px));min-height:700px;grid-template-columns:minmax(350px,.88fr) minmax(520px,1.12fr);gap:52px;padding:58px 0 44px}
  .mk12-gallery{min-height:570px}.mk12-copy h1{font-size:clamp(54px,5.2vw,72px)}.mk12-kicker{margin-bottom:38px}.mk12-realms{margin-top:38px}
  .mk12-status{width:min(1320px,calc(100% - 64px))}.mk-body{width:min(1320px,calc(100% - 64px))}
  .mk-prow{grid-template-columns:repeat(5,minmax(0,1fr))}.mk-pgrid{grid-template-columns:repeat(4,minmax(0,1fr))}.mk-shopgrid{grid-template-columns:repeat(3,minmax(0,1fr))}
  .mk-network{gap:60px}.mk-network-map{min-height:430px}.mk-feature-media{min-height:470px}
}
@media(min-width:768px) and (max-width:1179px){
  .mk12-shell{width:min(900px,calc(100% - 48px));grid-template-columns:1fr;min-height:auto;padding:48px 0 38px;gap:42px}
  .mk12-intro{max-width:780px}.mk12-copy h1{font-size:clamp(54px,7.2vw,68px);max-width:660px}.mk12-copy p{max-width:56ch}
  .mk12-search{max-width:720px}.mk12-realms{max-width:720px}.mk12-gallery{width:100%;max-width:820px;min-height:590px;margin-inline:auto}
  .mk12-status{width:min(900px,calc(100% - 48px));justify-content:flex-start;overflow-x:auto}.mk-body{width:min(900px,calc(100% - 48px))}
  .mk-network{grid-template-columns:1fr;gap:34px;padding:68px 0 78px}.mk-network-copy{max-width:680px}.mk-network-map{min-height:500px}
  .mk-editorial,.mk-editorial--flip{grid-template-columns:1fr}.mk-editorial--flip .mk-feature-object,.mk-editorial--flip .mk-object-index{grid-column:auto;grid-row:auto}
  .mk-prow,.mk-pgrid{grid-template-columns:repeat(3,minmax(0,1fr))}.mk-shop-feature{grid-template-columns:1fr}.mk-shop-feature-visual{min-height:500px}.mk-shopgrid{grid-template-columns:repeat(2,minmax(0,1fr))}
  .mk-business-intro,.mk-cta{grid-template-columns:1fr;gap:18px}.mk-business-intro p{max-width:520px}.mk-cta{padding-inline:28px}
}
@media(max-width:767px){
  .mk12-shell{width:calc(100% - 28px);padding:34px 0 26px;gap:32px}.mk12-kicker{margin-bottom:24px}.mk12-copy h1{font-size:clamp(45px,13.5vw,60px)}.mk12-copy p{max-width:38ch}
  .mk12-gallery{min-height:0}.mk12-main-media{height:clamp(340px,58svh,500px);min-height:0}.mk12-status{width:calc(100% - 28px)}.mk-body{width:calc(100% - 28px)}
  .mk-network-map{min-height:min(60svh,500px)}.mk-prow,.mk-pgrid{grid-template-columns:repeat(2,minmax(0,1fr))}
  .mk-section-head{grid-template-columns:34px 1fr auto}.mk-sections{gap:66px}.mk-feature-media{min-height:min(64svh,500px)}
}
@media(max-width:430px){
  .mk12-shell,.mk12-status,.mk-body{width:calc(100% - 24px)}
  .mk12-gallery{grid-template-columns:1fr}.mk12-main-object,.mk12-second-object,.mk12-business-object,.mk12-place-object{grid-column:1!important;grid-row:auto!important}
  .mk12-second-media{height:auto;aspect-ratio:4/3}.mk12-business-object{display:grid;grid-template-columns:92px minmax(0,1fr) auto;align-items:center}.mk12-business-media{width:92px;height:92px}.mk12-place-object{height:124px}
  .mk12-main-media{height:clamp(330px,55svh,450px)}.mk-prow,.mk-pgrid{grid-template-columns:1fr 1fr;gap:28px 10px}.mk-shopgrid{grid-template-columns:1fr}
}


/* SCREENSHOT QA — quiet media fallback and tighter discovery transition */
.mk12-business-media-fallback{
  position:relative;
  background:
    radial-gradient(circle at 72% 28%,rgba(255,255,255,.32),transparent 24%),
    linear-gradient(145deg,#dfd0bd,#c6ae90);
}
.mk12-business-fallback-lines{position:absolute;inset:14px;opacity:.32}
.mk12-business-fallback-lines i{
  position:absolute;inset:auto 0;border-top:1px solid rgba(62,47,35,.34);transform-origin:left center
}
.mk12-business-fallback-lines i:nth-child(1){top:27%;transform:rotate(-8deg)}
.mk12-business-fallback-lines i:nth-child(2){top:51%;transform:rotate(5deg)}
.mk12-business-fallback-lines i:nth-child(3){top:73%;transform:rotate(-3deg)}
.mk-network{padding-top:52px;padding-bottom:76px}
@media(min-width:1180px) and (max-width:1599px){
  .mk-network{padding-top:44px;padding-bottom:68px}
}
@media(max-width:767px){
  .mk-network{padding-top:44px;padding-bottom:58px}
}



/* PHASE 26 — market usability: discovery first, context second */
.mk-body{display:flex;flex-direction:column}
.mk-utility{order:1}
.mk-content{order:2}
.mk-network{order:3}
.mk-cta{order:4}
.mk-locationbar{
  display:grid;
  grid-template-columns:90px minmax(0,1fr);
  gap:18px;
  align-items:start;
  padding-top:18px;
  margin-top:16px;
  border-top:1px solid var(--market-line);
}
.mk-locationbar .mk-util-label{padding-top:4px}
.mk-corridors{display:flex;gap:8px 18px;flex-wrap:wrap}
.mk-corr{
  position:relative;
  border:0;background:transparent;padding:3px 0 7px;
  color:#777f78;font:550 11px/1.25 var(--font-body);cursor:pointer
}
.mk-corr::after{content:"";position:absolute;left:0;right:100%;bottom:0;height:1px;background:var(--market-ink);transition:right .22s var(--ease)}
.mk-corr:hover,.mk-corr.on{color:var(--market-ink)}
.mk-corr.on::after{right:0}
.mk-content{padding-top:42px}
.mk-network{margin-top:76px;border-top:1px solid var(--market-line)}
@media(max-width:767px){
  .mk-locationbar{grid-template-columns:1fr;gap:10px}
  .mk-corridors{flex-wrap:nowrap;overflow-x:auto;scrollbar-width:none;padding-bottom:4px}
  .mk-corridors::-webkit-scrollbar{display:none}
  .mk-corr{flex:0 0 auto;min-height:34px}
  .mk-content{padding-top:32px}
  .mk-network{margin-top:56px}
}

</style>
