<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { usePublic } from '../composables/usePublic'
import Icon from '../components/Icon.vue'
import AppHeader from '../components/AppHeader.vue'
import TrustBadge from '../components/TrustBadge.vue'
import { supabase } from '../lib/supabase'
import BrandMark from '../components/BrandMark.vue'
import EmptyState from '../components/EmptyState.vue'
import Spinner from '../components/Spinner.vue'

const route = useRoute()
const data = ref(null)
const loading = ref(true)
const pub = usePublic()

const store = computed(() => data.value?.store)
const products = computed(() => data.value?.products || [])
const reviews = computed(() => data.value?.reviews || [])
const sections = computed(() => data.value?.sections || [])
// group products by section for a curated shop layout
const grouped = computed(() => {
  const secs = sections.value
  const byId = {}
  secs.forEach(s => { byId[s.id] = { name: s.name, items: [] } })
  const noSection = []
  products.value.forEach(p => {
    if (p.section_id && byId[p.section_id]) byId[p.section_id].items.push(p)
    else noSection.push(p)
  })
  const out = secs.filter(s => byId[s.id].items.length).map(s => byId[s.id])
  if (noSection.length) out.push({ name: secs.length ? 'More' : '', items: noSection })
  return out
})

async function load() {
  loading.value = true
  const { data: res } = await pub.getStorefront(route.params.slug)
  data.value = res
  loading.value = false
  if (res?.store?.id) {
    try { const { data: r } = await supabase.rpc('shop_reputation', { p_storefront_id: res.store.id }); shopRep.value = r } catch (e) {}
  }
}
function tzs(n) { return n ? 'TZS ' + Number(n).toLocaleString() : '' }
function galleryImg(p) {
  if (Array.isArray(p.images) && p.images.length) return p.images[0]
  return p.image_url || ''
}

// ── order → auto-booking ──
const shopRep = ref(null)
const orderProduct = ref(null)
const orderForm = ref({ name: '', phone: '', addr: '', qty: 1 })
const ordering = ref(false)
const orderCode = ref('')
const pvActive = ref(0)
const pvZoom = ref(false)
const pvImages = computed(() => {
  const p = orderProduct.value
  if (!p) return []
  if (Array.isArray(p.images) && p.images.length) return p.images.filter(Boolean)
  return p.image_url ? [p.image_url] : []
})
const orderTotal = computed(() => {
  const p = orderProduct.value; if (!p) return 0
  const base = (p.price_tzs||0) * (orderForm.value.qty||1)
  const deliv = (!p.delivery_included && p.delivery_fee_tzs) ? Number(p.delivery_fee_tzs) : 0
  return base + deliv
})
const pvReviews = ref({ avg: 0, count: 0, reviews: [] })
async function openOrder(p) {
  orderProduct.value = p; orderCode.value = ''; pvActive.value = 0; pvZoom.value = false
  orderForm.value = { name:'', phone:'', addr:'', qty:1 }
  pvReviews.value = { avg: 0, count: 0, reviews: [] }
  try { const { data } = await pub.productReviews(p.id); if (data) pvReviews.value = data } catch (e) {}
}

function shareShop() {
  const url = window.location.href
  const text = `Check out ${store.value?.name} on Enkiama Cargos — order with tracked delivery: ${url}`
  // native share sheet on mobile surfaces WhatsApp directly
  if (navigator.share) {
    navigator.share({ title: store.value?.name, text, url }).catch(() => {})
  } else {
    // desktop fallback: open WhatsApp web with the message prefilled
    window.open(`https://wa.me/?text=${encodeURIComponent(text)}`, '_blank')
  }
}
async function placeOrder() {
  if (!orderForm.value.name || !orderForm.value.phone || !orderForm.value.addr) return
  ordering.value = true
  try {
    const { data: code, error } = await pub.placeOrder({
      p_store_slug: route.params.slug, p_product_id: orderProduct.value.id,
      p_buyer_name: orderForm.value.name, p_buyer_phone: orderForm.value.phone,
      p_buyer_addr: orderForm.value.addr, p_qty: Number(orderForm.value.qty) || 1,
    })
    if (error) throw error
    orderCode.value = code
  } catch (e) { alert(e.message || 'Could not place order') }
  ordering.value = false
}
onMounted(load)
</script>

<template>
  <div class="sf" v-if="!loading && store" :style="{'--sf': store.accent}">
    <AppHeader :title="store.name" subtitle="Storefront" :market="true" />

    <div class="sf-hero">
      <div class="sf-hero-inner">
        <RouterLink to="/market" class="sf-back"><Icon name="arrow" :size="15" style="transform:rotate(180deg)" /> All shops &amp; products</RouterLink>
        <div class="sf-id">
          <div class="sf-avatar" :style="{background:`linear-gradient(140deg, ${store.accent}, ${store.accent}bb)`}">{{ store.name.slice(0,2).toUpperCase() }}</div>
          <div class="sf-id-txt">
            <h1 class="sf-name">{{ store.name }}</h1>
            <p v-if="store.tagline" class="sf-tag">{{ store.tagline }}</p>
            <div class="sf-meta">
              <TrustBadge v-if="shopRep && shopRep.tier !== 'new'" :rep="shopRep" />
              <span v-if="store.verified_delivery" class="sf-verified"><Icon name="shield" :size="13" /> Verified delivery</span>
              <span v-if="data.avg_rating" class="sf-rating"><Icon name="star" :size="13" /> {{ data.avg_rating }} <span class="sf-rc">· {{ data.review_count }} reviews</span></span>
              <span v-if="store.region" class="sf-region"><Icon name="pin" :size="12" /> {{ store.region }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="sf-body">
      <div class="sf-intro-row">
        <div class="sf-intro">
          <p v-if="store.about" class="sf-about">{{ store.about }}</p>
          <div v-if="store.ships_what" class="sf-ships"><Icon name="package" :size="14" /> Usually ships: {{ store.ships_what }}<span v-if="store.since_year"> · since {{ store.since_year }}</span></div>
          <div v-if="store.delivers_to" class="sf-delivers"><Icon name="truck" :size="15" /> Delivers to {{ store.delivers_to }} — tracked via Enkiama Cargos</div>
        </div>
        <aside class="sf-aside">
          <div class="sf-order-card">
            <div class="sf-trust"><Icon name="check" :size="18" /></div>
            <div class="sf-trust-h">Every order tracked</div>
            <p class="sf-trust-p">Orders from {{ store.name }} ship through platform carriers with end-to-end tracking and cash-on-delivery — you see every step.</p>
            <a v-if="store.phone" :href="`tel:${store.phone}`" class="btn btn-accent btn-block btn-lg"><Icon name="phone" :size="16" /> Contact shop</a>
            <button class="btn btn-ghost btn-block sf-share" @click="shareShop"><Icon name="box" :size="15" /> Share this shop</button>
            <RouterLink to="/track" class="btn btn-ghost btn-block">Track an order</RouterLink>
          </div>
        </aside>
      </div>

      <div class="sf-products-wrap">
        <h2 class="sf-h2">Products</h2>
        <EmptyState v-if="!products.length" icon="package" title="No products listed yet" />
        <template v-else>
          <div v-for="(g,gi) in grouped" :key="gi" class="sf-section">
            <h3 v-if="g.name && g.name !== 'More'" class="sf-section-h">{{ g.name }}</h3>
            <div class="sf-products">
              <component :is="p.available === false ? 'div' : 'RouterLink'" v-for="p in g.items" :key="p.id" :to="p.available === false ? undefined : `/shop/${store.slug}/product/${p.id}`" class="sf-prod" :class="{soldout: p.available === false}">
                <div class="sf-prod-img">
                  <img v-if="galleryImg(p)" :src="galleryImg(p)" :alt="p.name" class="sf-prod-img-el" loading="lazy" />
                  <div v-else class="sf-prod-ph" :style="{background:`linear-gradient(150deg, ${store.accent||'#0B6E5D'}, ${store.accent||'#075446'})`}"><span class="sf-ph-chip">{{ p.name.slice(0,1).toUpperCase() }}</span></div>
                  <span v-if="p.available === false" class="sf-prod-soldout">Sold out</span>
                  <span v-else-if="p.track_stock && p.stock_qty <= 5 && p.stock_qty > 0" class="sf-prod-low">Only {{ p.stock_qty }} left</span>
                  <span v-else-if="p.compare_at_tzs > p.price_tzs" class="sf-prod-off">-{{ Math.round((1 - p.price_tzs/p.compare_at_tzs)*100) }}%</span>
                </div>
                <div class="sf-prod-body">
                  <div class="sf-prod-price-row">
                    <span class="sf-prod-price">{{ tzs(p.price_tzs) }}</span>
                    <span v-if="p.compare_at_tzs > p.price_tzs" class="sf-prod-was">{{ tzs(p.compare_at_tzs) }}</span>
                  </div>
                  <div class="sf-prod-name">{{ p.name }}</div>
                  <span v-if="p.available === false" class="sf-prod-cta soldtxt">Unavailable</span>
                  <span v-else class="sf-prod-cta">Order now <Icon name="arrowRight" :size="12" /></span>
                </div>
              </component>
            </div>
          </div>
        </template>

        <template v-if="reviews.length">
          <h2 class="sf-h2">Delivery reviews</h2>
          <div class="sf-reviews">
            <div v-for="(r,i) in reviews" :key="i" class="sf-review">
              <div class="sf-stars"><Icon v-for="n in r.rating" :key="n" name="star" :size="13" /></div>
              <p v-if="r.comment" class="sf-rev-text">"{{ r.comment }}"</p>
            </div>
          </div>
        </template>
      </div>
    </div>

    <footer class="sf-foot"><BrandMark variant="full" :height="36" /><p>Powered by Enkiama Cargos · One parcel, one truth.</p></footer>

    <!-- ORDER MODAL -->
    <div v-if="orderProduct" class="overlay" v-escape="() => { orderProduct=null }" @click.self="orderProduct=null">
      <div class="modal pv-modal">
        <div v-if="orderCode" class="book-success">
          <div class="book-success-ic"><Icon name="check" :size="30" /></div>
          <div class="book-success-code">{{ orderCode }}</div>
          <div class="book-success-sub">Order placed! {{ store.name }} will ship your {{ orderProduct.name }} via {{ store.name }}'s carrier — tracked all the way. Pay {{ tzs(orderProduct.price_tzs * orderForm.qty) }} on delivery.</div>
          <RouterLink :to="`/track/${orderCode}`" class="btn btn-accent btn-block btn-lg"><Icon name="pin" :size="16" /> Track my order</RouterLink>
          <button class="btn btn-ghost btn-block" @click="orderProduct=null">Done</button>
        </div>
        <div v-else class="pv">
          <button class="pv-x" @click="orderProduct=null"><Icon name="plus" :size="18" style="transform:rotate(45deg)" /></button>

          <!-- LEFT: immersive image gallery -->
          <div class="pv-gallery">
            <div class="pv-main" :class="{zoomed:pvZoom}" @click="pvZoom=!pvZoom"
                 :style="pvImages.length ? {backgroundImage:`url(${pvImages[pvActive]})`} : {}">
              <div v-if="!pvImages.length" class="pv-noimg"><Icon name="box" :size="48" /></div>
              <span v-if="pvImages.length" class="pv-zoomhint"><Icon name="search" :size="13" /> {{ pvZoom ? 'Click to zoom out' : 'Click to zoom' }}</span>
            </div>
            <div v-if="pvImages.length > 1" class="pv-thumbs">
              <button v-for="(img,i) in pvImages" :key="i" class="pv-thumb" :class="{on:i===pvActive}"
                      :style="{backgroundImage:`url(${img})`}" @click="pvActive=i; pvZoom=false"></button>
            </div>
          </div>

          <!-- RIGHT: details + order -->
          <div class="pv-detail">
            <div class="pv-cat" v-if="orderProduct.category">{{ orderProduct.category }}</div>
            <h2 class="pv-name">{{ orderProduct.name }}</h2>
            <div class="pv-price-row">
              <div class="pv-price">{{ tzs(orderProduct.price_tzs) }}</div>
              <template v-if="orderProduct.compare_at_tzs > orderProduct.price_tzs">
                <div class="pv-compare">{{ tzs(orderProduct.compare_at_tzs) }}</div>
                <div class="pv-off">{{ Math.round((1 - orderProduct.price_tzs/orderProduct.compare_at_tzs)*100) }}% off</div>
              </template>
            </div>
            <div class="pv-deliv" :class="orderProduct.delivery_included ? 'inc' : 'sep'">
              <Icon name="truck" :size="13" />
              <span v-if="orderProduct.delivery_included">Delivery included in price</span>
              <span v-else-if="orderProduct.delivery_fee_tzs">+ {{ tzs(orderProduct.delivery_fee_tzs) }} delivery</span>
              <span v-else>Delivery charged separately (carrier quote)</span>
            </div>
            <p v-if="orderProduct.description" class="pv-desc">{{ orderProduct.description }}</p>
            <div class="pv-trust"><Icon name="check" :size="14" /> Ships tracked via {{ store.name }}'s carrier · Cash on delivery</div>
            <div class="pv-escrow"><Icon name="shield" :size="15" /> <div><b>Protected by Enkiama</b><span>Your payment is held until you confirm the parcel arrived. If it doesn't, you're refunded.</span></div></div>

            <div v-if="pvReviews.count" class="pv-reviews">
              <div class="pv-reviews-h">
                <span class="pv-reviews-stars"><Icon v-for="n in 5" :key="n" name="star" :size="13" :class="{on: n <= Math.round(pvReviews.avg)}" /></span>
                <b>{{ pvReviews.avg }}</b> <span class="pv-reviews-c">· {{ pvReviews.count }} for this product</span>
              </div>
              <div v-for="(r,i) in pvReviews.reviews.slice(0,3)" :key="i" class="pv-review">
                <span class="pv-review-stars"><Icon v-for="n in 5" :key="n" name="star" :size="10" :class="{on: n <= r.rating}" /></span>
                <span class="pv-review-txt">"{{ r.comment }}"<template v-if="r.name"> — {{ r.name }}</template></span>
              </div>
            </div>

            <div class="pv-form">
              <div class="fg"><label>Your name <span class="req">*</span></label><input v-model="orderForm.name" placeholder="Full name" /></div>
              <div class="row2">
                <div class="fg"><label>Phone <span class="req">*</span></label><input v-model="orderForm.phone" type="tel" inputmode="tel" placeholder="+255…" /></div>
                <div class="fg"><label>Quantity</label><input v-model="orderForm.qty" type="number" inputmode="numeric" min="1" /></div>
              </div>
              <div class="fg"><label>Delivery address <span class="req">*</span></label><input v-model="orderForm.addr" placeholder="Where to deliver" /></div>
              <div class="pv-total"><span>Total on delivery</span><strong>{{ tzs(orderTotal) }}</strong></div>
              <button class="btn btn-buy btn-block btn-lg" :disabled="ordering" @click="placeOrder"><Spinner v-if="ordering" :size="16" /><span v-else>Place order</span></button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div v-else-if="loading" class="sf-loading"><p>Loading shop…</p></div>
  <EmptyState v-else icon="search" title="Shop not found" hint="This storefront doesn't exist or was removed." />
</template>

<style scoped>
.sf{margin:0;padding:0}
.sf-banner{padding:22px 0 26px;border-bottom:1px solid var(--hairline);margin-bottom:26px}
.sf-back{display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600;color:var(--ink-faint);text-decoration:none;margin-bottom:20px}
.sf-back:hover{color:var(--accent-ink)}
.sf-id{display:flex;gap:16px;align-items:flex-start}
.sf-avatar{width:64px;height:64px;border-radius:16px;color:#fff;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:20px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.sf-name{font-family:'Space Grotesk',sans-serif;font-size:24px;font-weight:700;display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.sf-verified{font-size:12.5px;font-weight:650;color:var(--go-ink);background:var(--go-soft);padding:4px 10px;border-radius:18px;display:inline-flex;align-items:center;gap:4px}
.sf-tag{font-size:14px;color:var(--ink-soft);margin-top:3px}
.sf-meta{display:flex;gap:16px;margin-top:8px;flex-wrap:wrap}
.sf-rating{display:inline-flex;align-items:center;gap:4px;font-size:13px;font-weight:600;color:#B5791E}
.sf-rc{color:var(--ink-faint);font-weight:400}
.sf-region{display:inline-flex;align-items:center;gap:4px;font-size:13px;color:var(--ink-faint)}

.sf-body{display:grid;grid-template-columns:1fr 300px;gap:32px;max-width:1040px;margin:0 auto;padding:28px 24px 60px;align-items:start}
@media(max-width:800px){.sf-body{grid-template-columns:1fr}}
.sf-intro-row{display:contents}
.sf-intro{grid-column:1}
.sf-aside{grid-column:2;grid-row:1 / span 3;position:sticky;top:20px}
.sf-products-wrap{grid-column:1;display:block}
@media(max-width:800px){.sf-aside{grid-column:1;grid-row:auto;position:static}.sf-products-wrap{grid-column:1}}
.sf-about{font-size:14px;color:var(--ink-soft);line-height:1.65;margin-bottom:16px}
.sf-delivers{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--go-ink);background:var(--go-soft);padding:11px 14px;border-radius:12px;margin-bottom:24px}
.sf-h2{font-size:18px;font-weight:700;margin:24px 0 14px}
.sf-ships{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--ink-soft);margin-bottom:12px;flex-wrap:wrap}
.sf-products{display:grid;grid-template-columns:repeat(auto-fill,minmax(158px,1fr));gap:12px}
.sf-prod{display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--hairline);border-radius:14px;overflow:hidden;padding:0;text-align:left;font-family:inherit;cursor:pointer;box-shadow:var(--shadow-sm);transition:box-shadow var(--dur) var(--ease),transform var(--dur-fast) var(--ease)}
.sf-prod:hover{box-shadow:var(--shadow-md);transform:translateY(-3px)}
.sf-prod-img{position:relative;aspect-ratio:1/1;background:var(--surface-2);display:flex;align-items:center;justify-content:center;overflow:hidden}
.sf-prod-img-el{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.sf-prod-ph{position:absolute;inset:0;display:flex;align-items:center;justify-content:center}
.sf-prod-ph::before{content:'';position:absolute;inset:0;background:radial-gradient(circle at 50% 35%,rgba(255,255,255,.2),transparent 60%)}
.sf-prod-ph::after{content:'';position:absolute;inset:0;opacity:.4;background-image:radial-gradient(rgba(255,255,255,.16) 1px,transparent 1px);background-size:13px 13px}
.sf-ph-chip{position:relative;z-index:1;width:52px;height:52px;border-radius:15px;display:flex;align-items:center;justify-content:center;font-family:'Space Grotesk',sans-serif;font-size:22px;font-weight:700;color:#fff;background:rgba(255,255,255,.15);border:1.5px solid rgba(255,255,255,.28);box-shadow:0 3px 10px rgba(0,0,0,.15),inset 0 1px 0 rgba(255,255,255,.3)}
.sf-prod-off{position:absolute;top:7px;left:7px;background:var(--owed);color:#fff;font-size:11px;font-weight:800;padding:3px 7px;border-radius:6px;box-shadow:0 2px 6px rgba(214,59,42,.35)}
.sf-prod-body{padding:10px 11px 11px;display:flex;flex-direction:column;gap:5px;flex:1}
.sf-prod-price-row{display:flex;align-items:baseline;gap:7px;flex-wrap:wrap}
.sf-prod-name{font-size:13px;font-weight:500;color:var(--ink-soft);line-height:1.35;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;min-height:35px}
.sf-prod-desc{font-size:12.5px;color:var(--ink-faint);margin-top:3px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.sf-prod-foot{display:flex;align-items:center;justify-content:space-between;margin-top:12px}
.sf-prod-price{font-family:'Space Grotesk',sans-serif;font-weight:800;font-size:16px;color:var(--owed-ink);letter-spacing:-.02em;font-variant-numeric:tabular-nums;line-height:1}
.sf-prod-was{font-size:11px;color:var(--ink-ghost);text-decoration:line-through;font-weight:400}
.sf-prod-cta{display:inline-flex;align-items:center;gap:3px;font-size:12px;font-weight:700;color:var(--buy-ink);margin-top:auto;padding-top:7px;border-top:1px solid var(--hairline)}
.sf-reviews{display:flex;flex-direction:column;gap:10px}
.sf-review{background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:14px 16px}
.sf-stars{display:flex;gap:2px;color:#F59E0B;margin-bottom:6px}
.sf-rev-text{font-size:13px;color:var(--ink-soft);font-style:italic}

.sf-order-card{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:24px;text-align:center;box-shadow:var(--shadow-sm)}
.sf-trust{width:48px;height:48px;border-radius:12px;background:var(--go-soft);color:var(--go-ink);display:flex;align-items:center;justify-content:center;margin:0 auto 14px}
.sf-trust-h{font-weight:700;font-size:16px;margin-bottom:8px}
.sf-trust-p{font-size:13px;color:var(--ink-soft);line-height:1.55;margin-bottom:18px}
.sf-order-card .btn{margin-bottom:10px}
.sf-foot{text-align:center;margin-top:50px;padding-top:30px;border-top:1px solid var(--hairline)}
.sf-foot p{font-size:12.5px;color:var(--ink-faint);margin-top:10px}
.sf-loading{text-align:center;padding:80px 20px;color:var(--ink-faint)}
.sf-order-total{font-size:14px;color:var(--ink-soft);margin:14px 0;padding:12px;background:var(--surface-2);border-radius:12px;text-align:center}
.sf-order-total strong{color:var(--owed-ink);font-family:'Space Grotesk',sans-serif}
.sf-prod-noimg{display:flex;align-items:center;justify-content:center;background:var(--surface-2);color:var(--ink-ghost)}

/* ═══ IMMERSIVE PRODUCT VIEW — Amazon-style gallery + detail ═══ */
.pv-modal{max-width:820px;padding:0;overflow:hidden;max-height:92vh;display:flex}
.pv{display:grid;grid-template-columns:1fr 1fr;position:relative;max-height:92vh;width:100%}
.pv-x{position:absolute;top:12px;right:12px;z-index:5;width:34px;height:34px;border-radius:50%;background:rgba(255,255,255,.9);border:1px solid var(--hairline);display:flex;align-items:center;justify-content:center;cursor:pointer;color:var(--ink-soft);backdrop-filter:blur(4px)}
.pv-x:hover{background:#fff;color:var(--ink)}
.pv-gallery{background:var(--surface-2);padding:20px;display:flex;flex-direction:column;gap:12px;overflow-y:auto}
.pv-main{position:relative;aspect-ratio:1;border-radius:14px;background-size:cover;background-position:center;background-color:var(--surface-3);cursor:zoom-in;overflow:hidden;transition:background-size .3s ease;box-shadow:inset 0 0 0 1px rgba(0,0,0,.04)}
.pv-main.zoomed{background-size:180%;cursor:zoom-out}
.pv-noimg{width:100%;height:100%;display:flex;align-items:center;justify-content:center;color:var(--ink-ghost)}
.pv-zoomhint{position:absolute;bottom:10px;left:10px;display:flex;align-items:center;gap:5px;font-size:11px;font-weight:600;color:#fff;background:rgba(0,0,0,.55);padding:5px 10px;border-radius:999px;backdrop-filter:blur(4px)}
.pv-thumbs{display:flex;gap:8px;flex-wrap:wrap}
.pv-thumb{width:56px;height:56px;border-radius:10px;background-size:cover;background-position:center;background-color:var(--surface-3);border:2px solid transparent;cursor:pointer;transition:border-color .15s ease,transform .15s ease;padding:0}
.pv-thumb:hover{transform:translateY(-2px)}
.pv-thumb.on{border-color:var(--accent)}
.pv-detail{padding:28px 26px;display:flex;flex-direction:column;overflow-y:auto}
.pv-cat{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;color:var(--accent-ink);margin-bottom:8px}
.pv-name{font-family:"Space Grotesk",sans-serif;font-size:24px;font-weight:700;letter-spacing:-.02em;color:var(--ink);line-height:1.15;margin-bottom:10px}
.pv-price{font-family:"Space Grotesk",sans-serif;font-size:24px;font-weight:700;color:var(--ink);font-variant-numeric:tabular-nums;margin-bottom:12px}
.pv-desc{font-size:14px;color:var(--ink-soft);line-height:1.6;margin-bottom:14px}
.pv-trust{display:flex;align-items:center;gap:7px;font-size:12.5px;color:var(--go-ink);font-weight:600;padding:10px 12px;background:var(--go-soft);border-radius:10px;margin-bottom:18px}
.pv-form{margin-top:auto}
.pv-total{display:flex;align-items:center;justify-content:space-between;padding:12px 0;margin:6px 0 14px;border-top:1px solid var(--hairline);font-size:14px;color:var(--ink-soft)}
.pv-total strong{font-family:"Space Grotesk",sans-serif;font-size:20px;color:var(--ink);font-variant-numeric:tabular-nums}
@media(max-width:680px){.pv-modal{max-height:94vh}.pv{grid-template-columns:1fr;max-height:94vh;overflow-y:auto}.pv-gallery{padding:16px;overflow-y:visible}.pv-detail{padding:20px;overflow-y:visible}}

.pv-price-row{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;margin-bottom:8px}
.pv-compare{font-size:16px;color:var(--ink-faint);text-decoration:line-through;font-variant-numeric:tabular-nums}
.pv-off{font-size:12.5px;font-weight:700;color:#fff;background:var(--owed);padding:3px 8px;border-radius:6px}
.pv-deliv{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;font-weight:600;padding:6px 11px;border-radius:8px;margin-bottom:14px}
.pv-deliv.inc{background:var(--go-soft);color:var(--go-ink)}
.pv-deliv.sep{background:var(--surface-2);color:var(--ink-soft)}
.sf-prod-was{font-size:12.5px;color:var(--ink-faint);text-decoration:line-through;font-weight:500;margin-left:7px}

.pv-reviews{margin-bottom:18px;padding:14px;background:var(--surface-2);border-radius:10px}
.pv-reviews-h{display:flex;align-items:center;gap:6px;font-size:13px;color:var(--ink-soft);margin-bottom:10px}
.pv-reviews-h b{color:var(--ink);font-size:14px}
.pv-reviews-stars{display:inline-flex;gap:1px}
.pv-reviews-stars svg,.pv-review-stars svg{color:var(--hairline-2)}
.pv-reviews-stars svg.on,.pv-review-stars svg.on{color:#E0A82E}
.pv-reviews-c{color:var(--ink-faint)}
.pv-review{display:flex;flex-direction:column;gap:3px;padding:8px 0;border-top:1px solid var(--hairline)}
.pv-review-stars{display:inline-flex;gap:1px}
.pv-review-txt{font-size:12.5px;color:var(--ink-soft);font-style:italic;line-height:1.45}

/* storefront hero — proper header frame */
.sf-hero{background:linear-gradient(160deg, color-mix(in srgb, var(--sf) 14%, var(--surface)), var(--surface));border-bottom:1px solid var(--hairline)}
.sf-hero-inner{max-width:1040px;margin:0 auto;padding:24px 24px 30px}
.sf-back{display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600;color:var(--ink-faint);text-decoration:none;margin-bottom:18px}
.sf-back:hover{color:var(--accent-ink)}
.sf-id{display:flex;align-items:center;gap:16px}
.sf-avatar{width:72px;height:72px;border-radius:18px;color:#fff;display:flex;align-items:center;justify-content:center;font-family:"Space Grotesk",sans-serif;font-weight:700;font-size:24px;letter-spacing:-.02em;flex-shrink:0;box-shadow:inset 0 1px 0 rgba(255,255,255,.2),0 4px 14px rgba(20,24,31,.14)}
.sf-id-txt{min-width:0}
.sf-name{font-family:"Space Grotesk",sans-serif;font-size:clamp(24px,3vw,32px);font-weight:700;letter-spacing:-.03em;color:var(--ink);line-height:1.1}
.sf-tag{font-size:14px;color:var(--ink-soft);margin-top:5px}
.sf-meta{display:flex;align-items:center;gap:14px;flex-wrap:wrap;margin-top:12px}
.sf-verified{display:inline-flex;align-items:center;gap:5px;font-size:12.5px;font-weight:600;color:var(--go-ink);background:var(--go-soft);padding:5px 11px;border-radius:999px}
.sf-verified svg{color:var(--go)}
.sf-rating{display:inline-flex;align-items:center;gap:5px;font-size:13px;font-weight:600;color:var(--ink)}
.sf-rating svg{color:#E0A82E}
.sf-rc{color:var(--ink-faint);font-weight:400}
.sf-region{display:inline-flex;align-items:center;gap:4px;font-size:13px;color:var(--ink-faint)}
.sf-body{}
.sf-h2{font-family:"Space Grotesk",sans-serif;font-size:20px;font-weight:700;letter-spacing:-.02em;color:var(--ink);margin-bottom:16px}

.pv-escrow{display:flex;gap:10px;align-items:flex-start;padding:12px 14px;background:linear-gradient(135deg,var(--accent-soft),var(--go-soft));border:1px solid var(--accent);border-radius:11px;margin-bottom:18px}
.pv-escrow svg{color:var(--accent-ink);flex-shrink:0;margin-top:1px}
.pv-escrow b{display:block;font-size:13px;color:var(--accent-ink);margin-bottom:2px}
.pv-escrow span{font-size:12px;line-height:1.5;color:var(--ink-soft)}

.sf-prod.soldout{opacity:.65;cursor:default}
.sf-prod.soldout .sf-prod-cta{visibility:hidden}
.sf-prod-soldout{position:absolute;top:7px;left:7px;background:rgba(20,24,31,.78);color:#fff;font-size:10px;font-weight:700;padding:3px 8px;border-radius:6px;text-transform:uppercase;letter-spacing:.03em}

.sf-prod-low{position:absolute;top:7px;left:7px;background:var(--warn);color:#fff;font-size:10px;font-weight:700;padding:3px 8px;border-radius:6px;letter-spacing:.02em}
</style>
