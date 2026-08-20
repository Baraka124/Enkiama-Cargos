<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRoute } from 'vue-router'
import { usePublic } from '../composables/usePublic'
import Icon from '../components/Icon.vue'
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
}
function tzs(n) { return n ? 'TZS ' + Number(n).toLocaleString() : '' }

// ── order → auto-booking ──
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
function openOrder(p) { orderProduct.value = p; orderCode.value = ''; pvActive.value = 0; pvZoom.value = false; orderForm.value = { name:'', phone:'', addr:'', qty:1 } }

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
    <div class="sf-banner">
      <RouterLink to="/market" class="sf-back"><Icon name="arrow" :size="16" style="transform:rotate(180deg)" /> Marketplace</RouterLink>
      <div class="sf-id">
        <div class="sf-avatar" :style="{background:store.accent}">{{ store.name.slice(0,2).toUpperCase() }}</div>
        <div>
          <h1 class="sf-name">{{ store.name }}
            <span v-if="store.verified_delivery" class="sf-verified"><Icon name="check" :size="14" /> Verified delivery</span>
          </h1>
          <p class="sf-tag">{{ store.tagline }}</p>
          <div class="sf-meta">
            <span v-if="data.avg_rating" class="sf-rating"><Icon name="star" :size="14" /> {{ data.avg_rating }} <span class="sf-rc">· {{ data.review_count }} reviews</span></span>
            <span v-if="store.region" class="sf-region"><Icon name="pin" :size="13" /> {{ store.region }}</span>
          </div>
        </div>
      </div>
    </div>

    <div class="sf-body">
      <div class="sf-main">
        <p v-if="store.about" class="sf-about">{{ store.about }}</p>
        <div v-if="store.ships_what" class="sf-ships"><Icon name="package" :size="14" /> Usually ships: {{ store.ships_what }}<span v-if="store.since_year"> · since {{ store.since_year }}</span></div>
        <div v-if="store.delivers_to" class="sf-delivers"><Icon name="truck" :size="15" /> Delivers to {{ store.delivers_to }} — tracked via Enkiama Cargos</div>

        <h2 class="sf-h2">Products</h2>
        <EmptyState v-if="!products.length" icon="package" title="No products listed yet" />
        <template v-else>
          <div v-for="(g,gi) in grouped" :key="gi" class="sf-section">
            <h3 v-if="g.name" class="sf-section-h">{{ g.name }}</h3>
            <div class="sf-products">
              <div v-for="p in g.items" :key="p.id" class="sf-prod">
                <div v-if="p.image_url" class="sf-prod-img" :style="{backgroundImage:`url(${p.image_url})`}"></div>
                <div v-else class="sf-prod-img sf-prod-noimg"><Icon name="box" :size="22" /></div>
                <div style="flex:1;min-width:0">
                  <div class="sf-prod-name">{{ p.name }}</div>
                  <div v-if="p.description" class="sf-prod-desc">{{ p.description }}</div>
                </div>
                <div class="sf-prod-price">{{ tzs(p.price_tzs) }}<span v-if="p.compare_at_tzs > p.price_tzs" class="sf-prod-was">{{ tzs(p.compare_at_tzs) }}</span></div>
                <button class="btn btn-buy sf-order" @click="openOrder(p)">Order now</button>
              </div>
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
.sf{max-width:1000px;margin:0 auto;padding:0 20px 50px}
.sf-banner{padding:22px 0 26px;border-bottom:1px solid var(--hairline);margin-bottom:26px}
.sf-back{display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600;color:var(--ink-faint);text-decoration:none;margin-bottom:20px}
.sf-back:hover{color:var(--accent-ink)}
.sf-id{display:flex;gap:16px;align-items:flex-start}
.sf-avatar{width:64px;height:64px;border-radius:17px;color:#fff;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:22px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.sf-name{font-family:'Space Grotesk',sans-serif;font-size:24px;font-weight:700;display:flex;align-items:center;gap:10px;flex-wrap:wrap}
.sf-verified{font-size:12px;font-weight:650;color:var(--go-ink);background:var(--go-soft);padding:4px 10px;border-radius:20px;display:inline-flex;align-items:center;gap:4px}
.sf-tag{font-size:14px;color:var(--ink-soft);margin-top:3px}
.sf-meta{display:flex;gap:16px;margin-top:8px;flex-wrap:wrap}
.sf-rating{display:inline-flex;align-items:center;gap:4px;font-size:13px;font-weight:600;color:#B5791E}
.sf-rc{color:var(--ink-faint);font-weight:400}
.sf-region{display:inline-flex;align-items:center;gap:4px;font-size:13px;color:var(--ink-faint)}
.sf-body{display:grid;grid-template-columns:1fr 300px;gap:28px}
@media(max-width:800px){.sf-body{grid-template-columns:1fr}}
.sf-about{font-size:14px;color:var(--ink-soft);line-height:1.65;margin-bottom:16px}
.sf-delivers{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--go-ink);background:var(--go-soft);padding:11px 14px;border-radius:12px;margin-bottom:24px}
.sf-h2{font-size:18px;font-weight:700;margin:24px 0 14px}
.sf-prod-img{width:56px;height:56px;border-radius:12px;background-size:cover;background-position:center;flex-shrink:0;border:1px solid var(--hairline)}
.sf-ships{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--ink-soft);margin-bottom:12px;flex-wrap:wrap}
.sf-products{display:flex;flex-direction:column;gap:10px}
.sf-prod{display:flex;align-items:center;gap:14px;background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:14px 16px}
.sf-prod-name{font-weight:650;font-size:14px;color:var(--ink)}
.sf-prod-desc{font-size:12px;color:var(--ink-faint);margin-top:2px}
.sf-prod-price{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:15px;color:var(--ink);white-space:nowrap}
.sf-order{padding:8px 16px !important;font-size:13px}
.sf-reviews{display:flex;flex-direction:column;gap:10px}
.sf-review{background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:14px 16px}
.sf-stars{display:flex;gap:2px;color:#F59E0B;margin-bottom:6px}
.sf-rev-text{font-size:13px;color:var(--ink-soft);font-style:italic}
.sf-aside{position:sticky;top:20px;align-self:start}
.sf-order-card{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:24px;text-align:center;box-shadow:var(--shadow-sm)}
.sf-trust{width:48px;height:48px;border-radius:12px;background:var(--go-soft);color:var(--go-ink);display:flex;align-items:center;justify-content:center;margin:0 auto 14px}
.sf-trust-h{font-weight:700;font-size:16px;margin-bottom:8px}
.sf-trust-p{font-size:13px;color:var(--ink-soft);line-height:1.55;margin-bottom:18px}
.sf-order-card .btn{margin-bottom:10px}
.sf-foot{text-align:center;margin-top:50px;padding-top:30px;border-top:1px solid var(--hairline)}
.sf-foot p{font-size:12px;color:var(--ink-faint);margin-top:10px}
.sf-loading{text-align:center;padding:80px 20px;color:var(--ink-faint)}
.sf-order-total{font-size:14px;color:var(--ink-soft);margin:14px 0;padding:12px;background:var(--surface-2);border-radius:12px;text-align:center}
.sf-order-total strong{color:var(--owed-ink);font-family:'Space Grotesk',sans-serif}
.sf-prod-noimg{display:flex;align-items:center;justify-content:center;background:var(--surface-2);color:var(--ink-ghost)}

/* ═══ IMMERSIVE PRODUCT VIEW — Amazon-style gallery + detail ═══ */
.pv-modal{max-width:820px;padding:0;overflow:hidden}
.pv{display:grid;grid-template-columns:1fr 1fr;position:relative}
.pv-x{position:absolute;top:12px;right:12px;z-index:5;width:34px;height:34px;border-radius:50%;background:rgba(255,255,255,.9);border:1px solid var(--hairline);display:flex;align-items:center;justify-content:center;cursor:pointer;color:var(--ink-soft);backdrop-filter:blur(4px)}
.pv-x:hover{background:#fff;color:var(--ink)}
.pv-gallery{background:var(--surface-2);padding:20px;display:flex;flex-direction:column;gap:12px}
.pv-main{position:relative;aspect-ratio:1;border-radius:14px;background-size:cover;background-position:center;background-color:var(--surface-3);cursor:zoom-in;overflow:hidden;transition:background-size .3s ease;box-shadow:inset 0 0 0 1px rgba(0,0,0,.04)}
.pv-main.zoomed{background-size:180%;cursor:zoom-out}
.pv-noimg{width:100%;height:100%;display:flex;align-items:center;justify-content:center;color:var(--ink-ghost)}
.pv-zoomhint{position:absolute;bottom:10px;left:10px;display:flex;align-items:center;gap:5px;font-size:11px;font-weight:600;color:#fff;background:rgba(0,0,0,.55);padding:5px 10px;border-radius:999px;backdrop-filter:blur(4px)}
.pv-thumbs{display:flex;gap:8px;flex-wrap:wrap}
.pv-thumb{width:56px;height:56px;border-radius:10px;background-size:cover;background-position:center;background-color:var(--surface-3);border:2px solid transparent;cursor:pointer;transition:border-color .15s ease,transform .15s ease;padding:0}
.pv-thumb:hover{transform:translateY(-2px)}
.pv-thumb.on{border-color:var(--accent)}
.pv-detail{padding:28px 26px;display:flex;flex-direction:column}
.pv-cat{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;color:var(--accent-ink);margin-bottom:8px}
.pv-name{font-family:"Space Grotesk",sans-serif;font-size:24px;font-weight:700;letter-spacing:-.02em;color:var(--ink);line-height:1.15;margin-bottom:10px}
.pv-price{font-family:"Space Grotesk",sans-serif;font-size:26px;font-weight:700;color:var(--ink);font-variant-numeric:tabular-nums;margin-bottom:12px}
.pv-desc{font-size:14px;color:var(--ink-soft);line-height:1.6;margin-bottom:14px}
.pv-trust{display:flex;align-items:center;gap:7px;font-size:12.5px;color:var(--go-ink);font-weight:600;padding:10px 12px;background:var(--go-soft);border-radius:10px;margin-bottom:18px}
.pv-form{margin-top:auto}
.pv-total{display:flex;align-items:center;justify-content:space-between;padding:12px 0;margin:6px 0 14px;border-top:1px solid var(--hairline);font-size:14px;color:var(--ink-soft)}
.pv-total strong{font-family:"Space Grotesk",sans-serif;font-size:20px;color:var(--ink);font-variant-numeric:tabular-nums}
@media(max-width:680px){.pv{grid-template-columns:1fr}.pv-gallery{padding:16px}.pv-detail{padding:20px}}

.pv-price-row{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;margin-bottom:8px}
.pv-compare{font-size:16px;color:var(--ink-faint);text-decoration:line-through;font-variant-numeric:tabular-nums}
.pv-off{font-size:12px;font-weight:700;color:#fff;background:var(--owed);padding:3px 8px;border-radius:6px}
.pv-deliv{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;font-weight:600;padding:6px 11px;border-radius:8px;margin-bottom:14px}
.pv-deliv.inc{background:var(--go-soft);color:var(--go-ink)}
.pv-deliv.sep{background:var(--surface-2);color:var(--ink-soft)}
.sf-prod-was{font-size:12px;color:var(--ink-faint);text-decoration:line-through;font-weight:500;margin-left:7px}
</style>
