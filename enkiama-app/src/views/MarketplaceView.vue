<script setup>
import { ref, onMounted } from 'vue'
import { useI18n } from '../composables/useI18n'
import { usePublic } from '../composables/usePublic'
import { useAuth } from '../composables/useAuth'
import Icon from '../components/Icon.vue'
import BrandMark from '../components/BrandMark.vue'
import EmptyState from '../components/EmptyState.vue'

const { t, setLang, isSwahili } = useI18n()
const stores = ref([])
const products = ref([])
const categories = ref([])
const view = ref('products')   // products | shops — products is the marketplace default
const activeCategory = ref('')
const sortBy = ref('relevant')
const filterVerified = ref(false)
const filterInStock = ref(false)
const filterDeal = ref(false)
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
const loading = ref(true)
const pub = usePublic()
const { session } = useAuth()
const corridor = ref('')
const corridors = ['Dar es Salaam', 'Arusha', 'Mwanza', 'Dodoma', 'Mbeya', 'Tanga', 'Morogoro', 'Zanzibar Urban/West']
const search = ref('')
const sort = ref('recommended')
let searchTimer = null

// group products by category → "same category" clusters, exposed all at once
import { computed } from 'vue'

// product image helpers — robust fallback to gradient+letter tile
function pImg(p) {
  const url = (Array.isArray(p.images) && p.images.length ? p.images[0] : p.image_url) || ''
  const u = String(url).trim()
  return (u && u !== 'null' && u.startsWith('http')) ? u : ''
}
function pctOff(p) {
  if (!p.compare_at_tzs || !p.price_tzs || p.compare_at_tzs <= p.price_tzs) return 0
  return Math.round((1 - p.price_tzs / p.compare_at_tzs) * 100)
}
function brokenImg(e) { if (e && e.target) e.target.style.display = 'none' }

const groupedProducts = computed(() => {
  if (activeCategory.value) return null  // focused on one category → flat grid
  const groups = {}
  for (const p of displayProducts.value) {
    const cat = p.category || 'Other'
    if (!groups[cat]) groups[cat] = []
    groups[cat].push(p)
  }
  return Object.entries(groups).map(([category, items]) => ({ category, items }))
})

async function load() {
  loading.value = true
  if (view.value === 'shops') {
    const { data } = await pub.browseStorefrontsV2(corridor.value, search.value, sort.value)
    stores.value = data || []
  } else {
    const { data } = await pub.searchProducts(search.value, activeCategory.value, corridor.value)
    products.value = data || []
  }
  loading.value = false
}
async function loadCategories() {
  const { data } = await pub.productCategories()
  categories.value = data || []
}

// tier a shop from data already on the card — no extra query
function shopTier(s) {
  const d = s.delivered_count || 0, r = s.avg_rating || 5
  if (d >= 50 && r >= 4.5) return 'trusted'
  if (d >= 10) return 'established'
  if (d >= 1) return 'active'
  return 'new'
}

function setView(v) { view.value = v; load() }
function setCategory(c) { activeCategory.value = activeCategory.value === c ? '' : c; view.value = 'products'; load() }
function filterCorridor(c) { corridor.value = corridor.value === c ? '' : c; load() }
function onSearch() { clearTimeout(searchTimer); searchTimer = setTimeout(load, 300) }
function setSort(s) { sort.value = s; load() }
onMounted(() => { load(); loadCategories() })
</script>

<template>
  <div class="mk">
    <div class="mk-dark">
      <div class="mk-dark-inner">
        <header class="mk-nav">
          <RouterLink to="/" class="mk-logo"><BrandMark variant="full" :height="32" light /></RouterLink>
          <div class="mk-navsearch">
            <input v-model="search" @input="onSearch" placeholder="Search shops or products across Tanzania…" aria-label="Search" />
            <button v-if="search" class="mk-navsearch-clear" @click="search=''; onSearch()" aria-label="Clear"><Icon name="plus" :size="16" style="transform:rotate(45deg)" /></button>
            <button class="mk-navsearch-btn" @click="onSearch"><Icon name="search" :size="18" /></button>
          </div>
          <div class="mk-head-actions">
            <template v-if="session">
              <RouterLink to="/" class="mk-navlink">← My dashboard</RouterLink>
            </template>
            <template v-else>
              <RouterLink to="/join/business" class="mk-navlink">Sell on Enkiama</RouterLink>
              <RouterLink to="/login" class="btn btn-accent">Sign in</RouterLink>
            </template>
          </div>
        </header>

        <nav class="mk-utilbar">
          <button v-for="c in categories.slice(0,7)" :key="c.category" class="mk-utilcat" :class="{on:activeCategory===c.category}" @click="setCategory(c.category)">{{ c.category }}</button>
        </nav>

        <section class="mk-hero">
          <h1 class="mk-h1">Everything you need, <span class="grad">delivered</span> &amp; tracked.</h1>
          <p class="mk-sub">Discover businesses across Tanzania — every order shipped with end-to-end tracked delivery through Enkiama Cargos carriers.</p>

          <div class="mk-corridors">
            <span class="mk-corr-lab">Delivers to:</span>
            <button v-for="c in corridors" :key="c" class="mk-corr" :class="{on:corridor===c}" @click="filterCorridor(c)">{{ c }}</button>
          </div>
        </section>
      </div>
    </div>

    <div class="mk-body">
    <div class="mk-toolbar">
      <div class="mk-viewtoggle">
        <button class="mk-vt" :class="{on:view==='shops'}" @click="setView('shops')"><Icon name="building" :size="14" /> Shops</button>
        <button class="mk-vt" :class="{on:view==='products'}" @click="setView('products')"><Icon name="package" :size="14" /> Products</button>
        <RouterLink to="/property" class="mk-vt"><Icon name="pin" :size="14" /> Property &amp; Land</RouterLink>
      </div>
      <div v-if="view==='shops'" class="mk-sort">
        <button class="mk-sort-b" :class="{on:sort==='recommended'}" @click="setSort('recommended')">Recommended</button>
        <button class="mk-sort-b" :class="{on:sort==='rating'}" @click="setSort('rating')">Top rated</button>
        <button class="mk-sort-b" :class="{on:sort==='newest'}" @click="setSort('newest')">Newest</button>
      </div>
      <span v-else class="mk-count">{{ products.length }} product{{ products.length===1?'':'s' }}</span>
    </div>

    <!-- PRODUCTS VIEW -->
    <div v-if="view==='products'">
      <div v-if="search" class="mk-searchinfo">
        <span>{{ displayProducts.length }} result{{ displayProducts.length===1?'':'s' }} for "<b>{{ search }}</b>"</span>
        <button class="mk-clearsearch" @click="search=''; onSearch()">Clear search</button>
      </div>
      <!-- category filter chips -->
      <div v-if="categories.length" class="mk-cats">
        <button class="mk-cat" :class="{on:!activeCategory}" @click="setCategory('')">All products</button>
        <button v-for="c in categories" :key="c.category" class="mk-cat" :class="{on:activeCategory===c.category}" @click="setCategory(c.category)">
          {{ c.category }} <span class="mk-cat-n">{{ c.count }}</span>
        </button>
      </div>

      <!-- sort + filter bar -->
      <div class="mk-toolbar">
        <div class="mk-filters">
          <button class="mk-fchip" :class="{on:filterVerified}" @click="filterVerified=!filterVerified"><Icon name="shield" :size="13" /> Verified shops</button>
          <button class="mk-fchip" :class="{on:filterInStock}" @click="filterInStock=!filterInStock"><Icon name="check" :size="13" /> In stock</button>
          <button class="mk-fchip" :class="{on:filterDeal}" @click="filterDeal=!filterDeal"><Icon name="star" :size="13" /> On offer</button>
        </div>
        <div class="mk-sort">
          <label>Sort</label>
          <select v-model="sortBy">
            <option value="relevant">Most relevant</option>
            <option value="price_low">Price: low to high</option>
            <option value="price_high">Price: high to low</option>
            <option value="newest">Newest</option>
          </select>
        </div>
      </div>

      <div v-if="loading" class="mk-pgrid">
        <div v-for="i in 8" :key="i" class="mk-pcard sk"></div>
      </div>
      <EmptyState v-else-if="!displayProducts.length" icon="package" title="No products found" hint="Try a different search, category, or filter." />

      <!-- FOCUSED: one category → flat grid -->
      <div v-else-if="activeCategory" class="mk-pgrid">
        <RouterLink v-for="p in displayProducts" :key="p.id" :to="`/shop/${p.shop_slug}/product/${p.id}`" class="mk-pcard">
          <div class="mk-pimg" :style="{background:`linear-gradient(135deg, ${p.shop_accent||'#0B6E5D'}, ${(p.shop_accent||'#075446')}cc)`}">
            <img v-if="pImg(p)" :src="pImg(p)" :alt="p.name" class="mk-pimg-el" loading="lazy" @error="brokenImg($event)" />
            <span class="mk-pimg-ph">{{ (p.name||'?').slice(0,1).toUpperCase() }}</span>
            <span v-if="pctOff(p)" class="mk-poff">{{ pctOff(p) }}% off</span>
          </div>
          <div class="mk-pbody">
            <div class="mk-pname">{{ p.name }}</div>
            <div class="mk-pshop">{{ p.shop_name }}<Icon v-if="p.verified_delivery" name="check" :size="11" /></div>
            <div class="mk-pfoot">
              <div class="mk-pprice-wrap">
                <span class="mk-pprice">TZS {{ Number(p.price_tzs).toLocaleString() }}</span>
                <span v-if="p.compare_at_tzs && p.compare_at_tzs > p.price_tzs" class="mk-pwas">{{ Number(p.compare_at_tzs).toLocaleString() }}</span>
              </div>
            </div>
          </div>
        </RouterLink>
      </div>

      <!-- BROWSE ALL: grouped into category sections (exposed to everything, organized) -->
      <div v-else class="mk-sections">
        <section v-for="g in groupedProducts" :key="g.category" class="mk-section">
          <div class="mk-section-head">
            <h2 class="mk-section-title">{{ g.category }}</h2>
            <button class="mk-section-more" @click="setCategory(g.category)">See all {{ g.items.length }} <Icon name="arrowRight" :size="13" /></button>
          </div>
          <div class="mk-prow">
            <RouterLink v-for="p in g.items.slice(0,6)" :key="p.id" :to="`/shop/${p.shop_slug}/product/${p.id}`" class="mk-pcard">
              <div class="mk-pimg" :style="{background:`linear-gradient(135deg, ${p.shop_accent||'#0B6E5D'}, ${(p.shop_accent||'#075446')}cc)`}">
                <img v-if="pImg(p)" :src="pImg(p)" :alt="p.name" class="mk-pimg-el" loading="lazy" @error="brokenImg($event)" />
                <span class="mk-pimg-ph">{{ (p.name||'?').slice(0,1).toUpperCase() }}</span>
                <span v-if="pctOff(p)" class="mk-poff">{{ pctOff(p) }}% off</span>
              </div>
              <div class="mk-pbody">
                <div class="mk-pname">{{ p.name }}</div>
                <div class="mk-pshop">{{ p.shop_name }}<Icon v-if="p.verified_delivery" name="check" :size="11" /></div>
                <div class="mk-pfoot">
                  <div class="mk-pprice-wrap">
                    <span class="mk-pprice">TZS {{ Number(p.price_tzs).toLocaleString() }}</span>
                    <span v-if="p.compare_at_tzs && p.compare_at_tzs > p.price_tzs" class="mk-pwas">{{ Number(p.compare_at_tzs).toLocaleString() }}</span>
                  </div>
                </div>
              </div>
            </RouterLink>
          </div>
        </section>
      </div>
    </div>

    <div v-else-if="loading" class="mk-grid">
      <div v-for="i in 3" :key="i" class="mk-card sk"></div>
    </div>
    <EmptyState v-else-if="!stores.length" icon="search" title="No shops here yet" :hint="corridor ? `No storefronts delivering to ${corridor} yet.` : 'Be the first business on the marketplace.'" />
    <div v-else class="mk-grid">
      <RouterLink v-for="s in stores" :key="s.id" :to="`/shop/${s.slug}`" class="mk-card" :style="{'--sf': s.accent || 'var(--accent)'}">
        <div class="mk-cover" :style="s.cover_url ? {backgroundImage:`url(${s.cover_url})`} : {}">
          <span v-if="shopTier(s) === 'trusted'" class="mk-badge trusted"><Icon name="shield" :size="10" /> Enkiama Trusted</span>
          <span v-else-if="s.featured" class="mk-badge feat"><Icon name="star" :size="10" /> Featured</span>
          <span v-if="s.verified_delivery" class="mk-badge verif"><Icon name="check" :size="11" /> Verified</span>
        </div>
        <div class="mk-card-body">
          <div class="mk-avatar" :style="{background:s.accent || 'var(--accent)'}">
            <img v-if="s.logo_url" :src="s.logo_url" alt="" />
            <span v-else>{{ s.name.slice(0,2).toUpperCase() }}</span>
          </div>
          <div class="mk-name">{{ s.name }}</div>
          <div class="mk-tag">{{ s.tagline }}</div>
          <div class="mk-meta">
            <span v-if="s.avg_rating" class="mk-rating"><Icon name="star" :size="13" /> {{ s.avg_rating }} <span class="mk-rc">({{ s.review_count }})</span></span>
            <span v-if="s.delivered_count > 0" class="mk-delivered"><Icon name="truck" :size="12" /> {{ s.delivered_count }} delivered</span>
          </div>
          <div class="mk-foot">
            <span class="mk-prods">{{ s.product_count }} product{{ s.product_count===1?'':'s' }}</span>
            <span v-if="s.delivers_to" class="mk-delivers"><Icon name="pin" :size="12" /> {{ s.delivers_to }}</span>
          </div>
        </div>
      </RouterLink>
    </div>

    <footer class="mk-cta">
      <h3>Run a business? Sell with delivery built in.</h3>
      <p>Open a storefront, list your products, and every order ships tracked through the platform.</p>
      <RouterLink to="/join/business" class="btn btn-accent btn-lg">Open a storefront</RouterLink>
    </footer>
    </div>
  </div>
</template>

<style scoped>
.mk{min-height:100vh;background:var(--paper);padding-bottom:60px}
.mk-dark{position:relative;background:var(--nav);overflow:hidden}
.mk-dark::before{content:'';position:absolute;inset:0;pointer-events:none;background:
  radial-gradient(800px 500px at 75% -20%, rgba(11,110,93,.35), transparent 60%),
  radial-gradient(600px 400px at 15% 120%, rgba(15,157,88,.12), transparent 55%)}
.mk-dark::after{content:'';position:absolute;inset:0;pointer-events:none;opacity:.35;
  background-image:linear-gradient(rgba(255,255,255,.03) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.03) 1px,transparent 1px);
  background-size:44px 44px;mask-image:radial-gradient(circle at 50% 30%,black,transparent 75%)}
.mk-dark-inner{position:relative;z-index:1;max-width:1240px;margin:0 auto;padding:0 20px 44px}
.mk-body{max-width:1240px;margin:0 auto;padding:0 20px}
.mk-head{display:flex;align-items:center;justify-content:space-between;padding:20px 0}
.mk-logo{display:flex;align-items:center;flex-shrink:0}
.mk-hero{text-align:center;padding:36px 0 30px}
.mk-h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(30px,6vw,46px);font-weight:700;letter-spacing:-.03em;margin-bottom:14px;color:#fff}
/* grad */
.mk-h1 .grad{background:linear-gradient(100deg,#818CF8,#34D399) !important;-webkit-background-clip:text !important;background-clip:text !important;-webkit-text-fill-color:transparent !important;color:transparent !important}
.unused-grad{background:linear-gradient(120deg,var(--accent-ink),var(--go-ink));-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.mk-sub{font-size:15px;color:rgba(255,255,255,.62);max-width:560px;margin:0 auto 24px;line-height:1.6}
.mk-corridors{display:flex;align-items:center;gap:8px;justify-content:center;flex-wrap:wrap}
.mk-corr-lab{font-size:13px;color:rgba(255,255,255,.5);font-weight:500}
.mk-corr{padding:7px 14px;border:1px solid rgba(255,255,255,.14);background:rgba(255,255,255,.06);border-radius:18px;font-size:13px;font-weight:600;color:rgba(255,255,255,.85);cursor:pointer;transition:.15s;font-family:inherit}
.mk-corr:hover{border-color:var(--accent)}
.mk-corr.on{background:var(--accent);color:#fff;border-color:var(--accent)}
.mk-grid{align-items:stretch;display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px;margin-top:10px}
.mk-card{position:relative;display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--hairline);border-radius:16px;overflow:hidden;text-decoration:none;transition:box-shadow var(--dur) var(--ease),transform var(--dur-fast) var(--ease);box-shadow:var(--shadow-sm)}
.mk-card:hover{box-shadow:var(--shadow-md);transform:translateY(-3px)}
.mk-cover{position:relative;height:88px;background:linear-gradient(135deg, var(--sf,var(--accent)), color-mix(in srgb, var(--sf,var(--accent)) 55%, #000));background-size:cover;background-position:center}
.mk-cover::after{content:'';position:absolute;inset:0;background:linear-gradient(180deg,transparent 40%,rgba(0,0,0,.12))}
.mk-card-body{padding:0 18px 18px;position:relative}
.mk-avatar{width:56px;height:56px;border-radius:14px;color:#fff;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:18px;display:flex;align-items:center;justify-content:center;flex-shrink:0;margin-top:-28px;border:3px solid var(--surface);box-shadow:0 4px 12px rgba(0,0,0,.15);position:relative;z-index:2;overflow:hidden}
.mk-avatar img{width:100%;height:100%;object-fit:cover}
.mk-card:hover{box-shadow:var(--shadow-lg);transform:translateY(-3px)}
.mk-card.sk{height:180px;background:linear-gradient(90deg,var(--surface-2) 25%,var(--hairline) 37%,var(--surface-2) 63%);background-size:400% 100%;animation:mksh 1.4s infinite}
@keyframes mksh{0%{background-position:100% 0}100%{background-position:-100% 0}}


.mk-name{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:16px;color:var(--ink);margin-top:10px;letter-spacing:-.01em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.mk-badge.feat{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.03em;padding:3px 8px;border-radius:8px;background:var(--accent-soft);color:var(--accent-ink);display:inline-flex;align-items:center;gap:3px}
.mk-tag{font-size:13px;color:var(--ink-faint);margin-top:2px}
.mk-meta{display:flex;gap:14px;margin-bottom:14px;flex-wrap:wrap}
.mk-verified{display:inline-flex;align-items:center;gap:5px;font-size:12.5px;font-weight:650;color:var(--go-ink);background:var(--go-soft);padding:4px 10px;border-radius:18px}
.mk-rating{display:inline-flex;align-items:center;gap:4px;font-size:13px;font-weight:600;color:#B5791E}
.mk-rc{color:var(--ink-faint);font-weight:400}
.mk-foot{display:flex;align-items:center;justify-content:space-between;padding-top:14px;border-top:1px solid var(--hairline);font-size:12.5px}
.mk-prods{font-weight:600;color:var(--ink-soft)}
.mk-delivers{display:inline-flex;align-items:center;gap:4px;color:var(--ink-faint)}
.mk-cta{text-align:center;margin-top:50px;padding:40px 24px;background:var(--surface);border:1px solid var(--hairline);border-radius:22px}
.mk-cta h3{font-size:20px;font-weight:700;margin-bottom:8px}
.mk-cta p{font-size:14px;color:var(--ink-soft);margin-bottom:22px}

.mk-badge.feat{position:absolute;top:14px;right:14px;display:inline-flex;align-items:center;gap:4px;background:var(--warn-soft);color:var(--warn-ink);font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.03em;padding:3px 8px;border-radius:var(--r-full)}
.mk-name{font-family:'Space Grotesk',sans-serif;font-weight:650;font-size:var(--t-md);color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;padding-right:60px}
.mk-tag{font-size:var(--t-sm);color:var(--ink-faint);margin-top:2px;display:-webkit-box;-webkit-line-clamp:1;-webkit-box-orient:vertical;overflow:hidden}
.mk-meta{margin:14px 0}
.mk-foot{margin-top:auto;padding-top:14px;border-top:1px solid var(--hairline);display:flex;align-items:center;justify-content:space-between;gap:10px}
.mk-delivers{display:inline-flex;align-items:center;gap:4px;font-size:var(--t-xs);color:var(--ink-faint);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:55%}
.mk-prods{font-size:var(--t-sm);color:var(--ink-soft);font-weight:550;white-space:nowrap}

.mk-searchbar{position:relative;max-width:520px;margin:22px auto 0}
.mk-search-ic{position:absolute;left:16px;top:50%;transform:translateY(-50%);color:var(--ink-faint);pointer-events:none}
.mk-searchbar input{width:100%;padding:14px 16px 14px 46px;border:1px solid var(--hairline-2);border-radius:var(--r-full);font-size:var(--t-base);background:var(--surface);box-shadow:var(--shadow-sm)}
.mk-searchbar input:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px var(--accent-soft)}
.mk-toolbar{max-width:1000px;margin:26px auto 14px;padding:0 4px;display:flex;align-items:center;justify-content:space-between;gap:12px}
.mk-count{font-size:var(--t-sm);color:var(--ink-faint);font-weight:550}
.mk-sort{display:flex;gap:4px;background:var(--surface-2);padding:4px;border-radius:var(--r-full)}
.mk-sort-b{padding:6px 14px;border:none;background:none;border-radius:var(--r-full);font-size:var(--t-sm);font-family:inherit;color:var(--ink-soft);cursor:pointer;font-weight:550;transition:all var(--dur-fast) var(--ease)}
.mk-sort-b.on{background:var(--surface);color:var(--ink);box-shadow:var(--shadow-xs)}
.mk-delivered{display:inline-flex;align-items:center;gap:4px;font-size:var(--t-xs);color:var(--go-ink);font-weight:600;background:var(--go-soft);padding:3px 8px;border-radius:var(--r-full)}

.mk-cats{display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin-top:18px}
.mk-cat{padding:7px 14px;border:1px solid rgba(255,255,255,.14);border-radius:var(--r-full);background:rgba(255,255,255,.06);font-size:var(--t-sm);font-family:inherit;cursor:pointer;color:rgba(255,255,255,.85);font-weight:600;transition:all var(--dur-fast) var(--ease)}
.mk-cat.on{background:var(--accent);border-color:var(--accent);color:#fff}
.mk-cat-n{opacity:.6;font-size:var(--t-xs)}
.mk-viewtoggle{display:flex;gap:4px;background:var(--surface-2);padding:4px;border-radius:var(--r-full)}
.mk-vt{display:inline-flex;align-items:center;gap:6px;padding:6px 14px;border:none;background:none;border-radius:var(--r-full);font-size:var(--t-sm);font-family:inherit;color:var(--ink-soft);cursor:pointer;font-weight:600;transition:all var(--dur-fast) var(--ease)}
.mk-vt.on{background:var(--surface);color:var(--ink);box-shadow:var(--shadow-xs)}
.mk-pgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:16px}
.mk-pcard{display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--hairline);border-radius:16px;overflow:hidden;text-decoration:none;transition:box-shadow var(--dur) var(--ease),transform var(--dur-fast) var(--ease);box-shadow:var(--shadow-sm)}
.mk-pcard:hover{transform:translateY(-4px);box-shadow:var(--shadow-lg)}
.mk-pcard:hover{box-shadow:var(--shadow-md);transform:translateY(-2px)}
.mk-pcard.sk{height:280px;background:var(--surface-2);animation:pulse 1.5s ease-in-out infinite}
.mk-pimg{position:relative;height:180px;background-size:cover;background-position:center;display:flex;align-items:center;justify-content:center;overflow:hidden}
.mk-pimg::after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,transparent 55%,rgba(20,24,31,.12));pointer-events:none}
.mk-pimg-ph{font-family:'Space Grotesk',sans-serif;font-size:40px;font-weight:700;color:rgba(255,255,255,.7)}
.mk-pbody{padding:15px 16px 16px;display:flex;flex-direction:column;gap:5px;flex:1}
.mk-pname{font-family:"Space Grotesk",sans-serif;font-weight:650;font-size:15px;letter-spacing:-.01em;color:var(--ink);line-height:1.3;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.mk-pshop{display:flex;align-items:center;gap:4px;font-size:var(--t-xs);color:var(--ink-faint)}
.mk-pshop :deep(svg){color:var(--go-ink)}
.mk-pfoot{margin-top:auto;padding-top:8px;display:flex;align-items:center;justify-content:space-between;gap:6px}
.mk-pprice{font-family:"Space Grotesk",sans-serif;font-weight:700;font-size:17px;letter-spacing:-.02em;color:var(--ink);font-variant-numeric:tabular-nums}
.mk-pdel{font-size:10px;color:var(--go-ink);font-weight:600;white-space:nowrap}
.mk-head-actions{display:flex;align-items:center;gap:10px}

.mk-head-actions .btn-ghost{background:rgba(255,255,255,.08);border-color:rgba(255,255,255,.14);color:#fff}
.mk-head-actions .btn-ghost:hover{background:rgba(255,255,255,.14);border-color:rgba(255,255,255,.25)}

/* ── Amazon-style command nav ── */
.mk-nav{display:flex;align-items:center;gap:20px;padding:14px 0}
.mk-navsearch{flex:1;display:flex;max-width:640px;background:#fff;border-radius:10px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.25)}
.mk-navsearch input{flex:1;border:none;padding:12px 16px;font-size:14px;outline:none;background:#fff;color:var(--ink)}
.mk-navsearch input::placeholder{color:var(--ink-faint)}
.mk-navsearch-btn{border:none;background:var(--accent);color:#fff;padding:0 18px;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:background .15s ease}
.mk-navsearch-btn:hover{background:var(--accent-ink)}
.mk-navlink{color:var(--nav-ink);text-decoration:none;font-size:13px;font-weight:600;padding:8px 12px;border-radius:8px;white-space:nowrap;transition:background .15s ease}
.mk-navlink:hover{background:rgba(255,255,255,.08)}
.mk-utilbar{display:flex;align-items:center;gap:4px;padding:0 0 8px;flex-wrap:wrap;border-bottom:1px solid rgba(255,255,255,.08);margin-bottom:8px}
.mk-utilcat{background:none;border:none;color:rgba(255,255,255,.75);font-family:inherit;font-size:13px;font-weight:600;padding:8px 12px;border-radius:8px;cursor:pointer;transition:all .15s ease}
.mk-utilcat:hover{background:rgba(255,255,255,.08);color:#fff}
.mk-utilcat.on{background:rgba(255,255,255,.12);color:#fff}

.mk-badge{position:absolute;top:10px;display:inline-flex;align-items:center;gap:4px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;padding:5px 9px;border-radius:999px;z-index:2}
.mk-badge.feat{left:10px;background:rgba(255,255,255,.92);color:var(--warn-ink)}
.mk-badge.verif{right:10px;background:rgba(255,255,255,.92);color:var(--go-ink)}

/* ═══ CATEGORY-GROUPED PRODUCT MARKETPLACE ═══ */
.mk-cats{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:24px}
.mk-cat{padding:8px 16px;border-radius:999px;border:1px solid var(--hairline-2);background:var(--surface);font-family:inherit;font-size:13px;font-weight:600;color:var(--ink-soft);cursor:pointer;transition:.15s;display:inline-flex;align-items:center;gap:6px}
.mk-cat:hover{border-color:var(--accent);color:var(--accent-ink)}
.mk-cat.on{background:var(--ink);color:#fff;border-color:var(--ink)}
.mk-cat-n{font-size:11px;opacity:.6;font-variant-numeric:tabular-nums}
.mk-cat.on .mk-cat-n{opacity:.8}
.mk-sections{display:flex;flex-direction:column;gap:36px}
.mk-section-head{display:flex;align-items:baseline;justify-content:space-between;margin-bottom:16px;padding-bottom:12px;border-bottom:1px solid var(--hairline)}
.mk-section-title{font-family:'Space Grotesk',sans-serif;font-size:20px;font-weight:700;letter-spacing:-.02em;color:var(--ink)}
.mk-section-more{background:none;border:none;font-family:inherit;font-size:13px;font-weight:600;color:var(--accent-ink);cursor:pointer;display:inline-flex;align-items:center;gap:4px;white-space:nowrap}
.mk-section-more:hover{gap:7px}
.mk-prow{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:16px}
.mk-poff{position:absolute;top:8px;left:8px;background:var(--owed);color:#fff;font-size:10px;font-weight:700;padding:3px 8px;border-radius:6px;letter-spacing:.02em}
.mk-pprice-wrap{display:flex;align-items:baseline;gap:7px}
.mk-pwas{font-size:12.5px;color:var(--ink-ghost);text-decoration:line-through}

.mk-pimg-el{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;z-index:1}
.mk-pimg-ph{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-family:"Space Grotesk",sans-serif;font-size:40px;font-weight:700;color:rgba(255,255,255,.85);z-index:0}
.mk-poff{z-index:2}

.mk-badge.trusted{background:linear-gradient(135deg,rgba(11,110,93,.95),rgba(18,184,134,.95));color:#fff;box-shadow:0 2px 8px rgba(11,110,93,.4)}

.mk-navsearch-clear{border:none;background:#fff;color:var(--ink-faint);padding:0 8px;cursor:pointer;display:flex;align-items:center}
.mk-navsearch-clear:hover{color:var(--ink)}
.mk-searchinfo{display:flex;align-items:center;justify-content:space-between;gap:14px;margin-bottom:18px;font-size:14px;color:var(--ink-soft)}
.mk-searchinfo b{color:var(--ink)}
.mk-clearsearch{font-size:13px;font-weight:600;color:var(--accent-ink);background:none;border:none;cursor:pointer}
</style>
