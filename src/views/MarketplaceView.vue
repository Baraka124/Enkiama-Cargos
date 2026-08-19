<script setup>
import { ref, onMounted } from 'vue'
import { usePublic } from '../composables/usePublic'
import { useAuth } from '../composables/useAuth'
import Icon from '../components/Icon.vue'
import BrandMark from '../components/BrandMark.vue'
import EmptyState from '../components/EmptyState.vue'

const stores = ref([])
const products = ref([])
const categories = ref([])
const view = ref('shops')   // shops | products
const activeCategory = ref('')
const loading = ref(true)
const pub = usePublic()
const { session } = useAuth()
const corridor = ref('')
const corridors = ['Mbeya', 'Arusha', 'Mwanza', 'Dodoma', 'Dar es Salaam']
const search = ref('')
const sort = ref('recommended')
let searchTimer = null

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
function setView(v) { view.value = v; load() }
function setCategory(c) { activeCategory.value = activeCategory.value === c ? '' : c; view.value = 'products'; load() }
function filterCorridor(c) { corridor.value = corridor.value === c ? '' : c; load() }
function onSearch() { clearTimeout(searchTimer); searchTimer = setTimeout(load, 300) }
function setSort(s) { sort.value = s; load() }
onMounted(() => { load(); loadCategories() })
</script>

<template>
  <div class="mk">
    <header class="mk-head">
      <RouterLink to="/" class="mk-logo"><BrandMark variant="full" :height="34" /></RouterLink>
      <div class="mk-head-actions">
        <template v-if="session">
          <RouterLink to="/" class="btn btn-ghost">← My dashboard</RouterLink>
        </template>
        <template v-else>
          <RouterLink to="/login?role=sender" class="btn btn-ghost">Sell on Enkiama</RouterLink>
          <RouterLink to="/login" class="btn btn-accent">Sign in</RouterLink>
        </template>
      </div>
    </header>

    <section class="mk-hero">
      <h1 class="mk-h1">Shops that <span class="grad">deliver</span>, tracked.</h1>
      <p class="mk-sub">Discover businesses across Tanzania — every order shipped with end-to-end tracked delivery through Enkiama Cargos carriers.</p>

      <div class="mk-searchbar">
        <Icon name="search" :size="18" class="mk-search-ic" />
        <input v-model="search" @input="onSearch" placeholder="Search shops or products — kitenge, phones, spices…" aria-label="Search the marketplace" />
      </div>

      <div v-if="categories.length" class="mk-cats">
        <button v-for="c in categories" :key="c.category" class="mk-cat" :class="{on:activeCategory===c.category}" @click="setCategory(c.category)">{{ c.category }} <span class="mk-cat-n">{{ c.count }}</span></button>
      </div>

      <div class="mk-corridors">
        <span class="mk-corr-lab">Delivers to:</span>
        <button v-for="c in corridors" :key="c" class="mk-corr" :class="{on:corridor===c}" @click="filterCorridor(c)">{{ c }}</button>
      </div>
    </section>

    <div class="mk-toolbar">
      <div class="mk-viewtoggle">
        <button class="mk-vt" :class="{on:view==='shops'}" @click="setView('shops')"><Icon name="building" :size="14" /> Shops</button>
        <button class="mk-vt" :class="{on:view==='products'}" @click="setView('products')"><Icon name="package" :size="14" /> Products</button>
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
      <div v-if="loading" class="mk-pgrid">
        <div v-for="i in 4" :key="i" class="mk-pcard sk"></div>
      </div>
      <EmptyState v-else-if="!products.length" icon="package" title="No products found" hint="Try a different search or category." />
      <div v-else class="mk-pgrid">
        <RouterLink v-for="p in products" :key="p.id" :to="`/shop/${p.shop_slug}`" class="mk-pcard">
          <div class="mk-pimg" :style="p.image_url ? {backgroundImage:`url(${p.image_url})`} : {background:p.shop_accent}">
            <span v-if="!p.image_url" class="mk-pimg-ph">{{ p.name.slice(0,1) }}</span>
          </div>
          <div class="mk-pbody">
            <div class="mk-pname">{{ p.name }}</div>
            <div class="mk-pshop">{{ p.shop_name }}<Icon v-if="p.verified_delivery" name="check" :size="11" /></div>
            <div class="mk-pfoot">
              <span class="mk-pprice">TZS {{ Number(p.price_tzs).toLocaleString() }}</span>
              <span v-if="p.delivered_count>0" class="mk-pdel">{{ p.delivered_count }} delivered</span>
            </div>
          </div>
        </RouterLink>
      </div>
    </div>

    <div v-else-if="loading" class="mk-grid">
      <div v-for="i in 3" :key="i" class="mk-card sk"></div>
    </div>
    <EmptyState v-else-if="!stores.length" icon="search" title="No shops here yet" :hint="corridor ? `No storefronts delivering to ${corridor} yet.` : 'Be the first business on the marketplace.'" />
    <div v-else class="mk-grid">
      <RouterLink v-for="s in stores" :key="s.id" :to="`/shop/${s.slug}`" class="mk-card" :style="{'--sf': s.accent}">
        <span v-if="s.featured" class="mk-badge feat"><Icon name="star" :size="10" /> Featured</span>
        <div class="mk-card-top">
          <div class="mk-avatar" :style="{background:s.accent}">{{ s.name.slice(0,2).toUpperCase() }}</div>
          <div style="flex:1;min-width:0">
            <div class="mk-name">{{ s.name }}</div>
            <div class="mk-tag">{{ s.tagline }}</div>
          </div>
        </div>
        <div class="mk-meta">
          <span v-if="s.verified_delivery" class="mk-verified"><Icon name="check" :size="13" /> Verified delivery</span>
          <span v-if="s.avg_rating" class="mk-rating"><Icon name="star" :size="13" /> {{ s.avg_rating }} <span class="mk-rc">({{ s.review_count }})</span></span>
          <span v-if="s.delivered_count > 0" class="mk-delivered"><Icon name="truck" :size="12" /> {{ s.delivered_count }} delivered</span>
        </div>
        <div class="mk-foot">
          <span class="mk-prods">{{ s.product_count }} product{{ s.product_count===1?'':'s' }}</span>
          <span v-if="s.delivers_to" class="mk-delivers"><Icon name="pin" :size="12" /> {{ s.delivers_to }}</span>
        </div>
      </RouterLink>
    </div>

    <footer class="mk-cta">
      <h3>Run a business? Sell with delivery built in.</h3>
      <p>Open a storefront, list your products, and every order ships tracked through the platform.</p>
      <RouterLink to="/login" class="btn btn-accent btn-lg">Open a storefront</RouterLink>
    </footer>
  </div>
</template>

<style scoped>
.mk{max-width:1100px;margin:0 auto;padding:0 20px 60px}
.mk-head{display:flex;align-items:center;justify-content:space-between;padding:20px 0}
.mk-logo{text-decoration:none}
.mk-hero{text-align:center;padding:36px 0 30px}
.mk-h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(30px,6vw,46px);font-weight:700;letter-spacing:-.02em;margin-bottom:14px}
.grad{background:linear-gradient(120deg,var(--accent-ink),var(--go-ink));-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.mk-sub{font-size:15px;color:var(--ink-soft);max-width:560px;margin:0 auto 24px;line-height:1.6}
.mk-corridors{display:flex;align-items:center;gap:8px;justify-content:center;flex-wrap:wrap}
.mk-corr-lab{font-size:13px;color:var(--ink-faint);font-weight:500}
.mk-corr{padding:7px 14px;border:1px solid var(--hairline);background:var(--surface);border-radius:20px;font-size:13px;font-weight:600;color:var(--ink-soft);cursor:pointer;transition:.15s;font-family:inherit}
.mk-corr:hover{border-color:var(--accent)}
.mk-corr.on{background:var(--accent);color:#fff;border-color:var(--accent)}
.mk-grid{align-items:stretch;display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px;margin-top:10px}
.mk-card{position:relative;display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:20px;text-decoration:none;transition:box-shadow var(--dur) var(--ease),transform var(--dur-fast) var(--ease);box-shadow:var(--shadow-sm);border-top:3px solid var(--sf,var(--accent))}
.mk-card:hover{box-shadow:var(--shadow-lg);transform:translateY(-3px)}
.mk-card.sk{height:180px;background:linear-gradient(90deg,var(--surface-2) 25%,var(--hairline) 37%,var(--surface-2) 63%);background-size:400% 100%;animation:mksh 1.4s infinite}
@keyframes mksh{0%{background-position:100% 0}100%{background-position:-100% 0}}
.mk-card-top{display:flex;align-items:center;gap:13px;margin-bottom:16px}
.mk-avatar{width:48px;height:48px;border-radius:12px;color:#fff;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:17px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.mk-name{font-weight:700;font-size:16px;color:var(--ink);display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.mk-badge.feat{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.03em;padding:3px 8px;border-radius:8px;background:var(--accent-soft);color:var(--accent-ink);display:inline-flex;align-items:center;gap:3px}
.mk-tag{font-size:13px;color:var(--ink-faint);margin-top:2px}
.mk-meta{display:flex;gap:14px;margin-bottom:14px;flex-wrap:wrap}
.mk-verified{display:inline-flex;align-items:center;gap:5px;font-size:12.5px;font-weight:650;color:var(--go-ink);background:var(--go-soft);padding:4px 10px;border-radius:20px}
.mk-rating{display:inline-flex;align-items:center;gap:4px;font-size:13px;font-weight:600;color:#B5791E}
.mk-rc{color:var(--ink-faint);font-weight:400}
.mk-foot{display:flex;align-items:center;justify-content:space-between;padding-top:14px;border-top:1px solid var(--hairline);font-size:12.5px}
.mk-prods{font-weight:600;color:var(--ink-soft)}
.mk-delivers{display:inline-flex;align-items:center;gap:4px;color:var(--ink-faint)}
.mk-cta{text-align:center;margin-top:50px;padding:40px 24px;background:var(--surface);border:1px solid var(--hairline);border-radius:22px}
.mk-cta h3{font-size:22px;font-weight:700;margin-bottom:8px}
.mk-cta p{font-size:14.5px;color:var(--ink-soft);margin-bottom:22px}

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
.mk-cat{padding:7px 14px;border:1px solid var(--hairline-2);border-radius:var(--r-full);background:var(--surface);font-size:var(--t-sm);font-family:inherit;cursor:pointer;color:var(--ink-soft);font-weight:550;transition:all var(--dur-fast) var(--ease)}
.mk-cat.on{background:var(--accent);border-color:var(--accent);color:#fff}
.mk-cat-n{opacity:.6;font-size:var(--t-xs)}
.mk-viewtoggle{display:flex;gap:4px;background:var(--surface-2);padding:4px;border-radius:var(--r-full)}
.mk-vt{display:inline-flex;align-items:center;gap:6px;padding:6px 14px;border:none;background:none;border-radius:var(--r-full);font-size:var(--t-sm);font-family:inherit;color:var(--ink-soft);cursor:pointer;font-weight:600;transition:all var(--dur-fast) var(--ease)}
.mk-vt.on{background:var(--surface);color:var(--ink);box-shadow:var(--shadow-xs)}
.mk-pgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:16px;max-width:1000px;margin:0 auto;padding:0 4px}
.mk-pcard{display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--hairline);border-radius:12px;overflow:hidden;text-decoration:none;transition:box-shadow var(--dur) var(--ease),transform var(--dur-fast) var(--ease);box-shadow:var(--shadow-sm)}
.mk-pcard:hover{box-shadow:var(--shadow-md);transform:translateY(-2px)}
.mk-pcard.sk{height:280px;background:var(--surface-2);animation:pulse 1.5s ease-in-out infinite}
.mk-pimg{height:150px;background-size:cover;background-position:center;display:flex;align-items:center;justify-content:center}
.mk-pimg-ph{font-family:'Space Grotesk',sans-serif;font-size:40px;font-weight:700;color:rgba(255,255,255,.7)}
.mk-pbody{padding:12px 14px;display:flex;flex-direction:column;gap:4px;flex:1}
.mk-pname{font-weight:650;font-size:var(--t-base);color:var(--ink);line-height:1.3;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.mk-pshop{display:flex;align-items:center;gap:4px;font-size:var(--t-xs);color:var(--ink-faint)}
.mk-pshop :deep(svg){color:var(--go-ink)}
.mk-pfoot{margin-top:auto;padding-top:8px;display:flex;align-items:center;justify-content:space-between;gap:6px}
.mk-pprice{font-weight:700;font-size:var(--t-base);color:var(--ink)}
.mk-pdel{font-size:10px;color:var(--go-ink);font-weight:600;white-space:nowrap}
.mk-head-actions{display:flex;align-items:center;gap:10px}
</style>
