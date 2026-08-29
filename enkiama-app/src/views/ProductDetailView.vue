<script setup>
// A product's own shareable page — a shop can send this link straight to a buyer.
import { ref, computed, onMounted, inject } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import AppHeader from '../components/AppHeader.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import Avatar from '../components/Avatar.vue'
import TrustBadge from '../components/TrustBadge.vue'
import EmptyState from '../components/EmptyState.vue'

const route = useRoute()
const router = useRouter()
const toast = inject('toast')

const data = ref(null)
const loading = ref(true)
const notFound = ref(false)
const activeImg = ref(0)

async function load() {
  loading.value = true
  try {
    const { data: res } = await supabase.rpc('get_product', { p_shop_slug: route.params.slug, p_product_id: route.params.id })
    if (res?.ok) { data.value = res; activeImg.value = 0; loadConfidence() } else notFound.value = true
  } catch (e) { notFound.value = true }
  loading.value = false
}
const confidence = ref(null)
async function loadConfidence() {
  try {
    const { data: c } = await supabase.rpc('delivery_confidence', { p_storefront_id: data.value.shop.id, p_dest: null })
    if (c?.has_data) confidence.value = c
  } catch (e) {}
}
const p = computed(() => data.value?.product || {})
const shop = computed(() => data.value?.shop || {})
const images = computed(() => {
  const arr = Array.isArray(p.value.images) ? p.value.images.filter(Boolean) : []
  if (p.value.image_url && !arr.includes(p.value.image_url)) arr.unshift(p.value.image_url)
  return arr
})
const discount = computed(() => p.value.compare_at_tzs > p.value.price_tzs
  ? Math.round((1 - p.value.price_tzs / p.value.compare_at_tzs) * 100) : 0)
const soldOut = computed(() => p.value.available === false)
const lowStock = computed(() => p.value.track_stock && p.value.stock_qty > 0 && p.value.stock_qty <= 5)
function tzs(n) { return n ? 'TZS ' + Number(n).toLocaleString() : '' }

// order
const showOrder = ref(false)
const form = ref({ name: '', phone: '', addr: '', qty: 1 })
const ordering = ref(false)
const orderCode = ref('')
const productOptions = computed(() => Array.isArray(p.value.options) ? p.value.options.filter(o => o?.name && o?.choices?.length) : [])
const selectedOpts = ref({})
const variantString = computed(() => productOptions.value.map(o => selectedOpts.value[o.name] ? `${o.name}: ${selectedOpts.value[o.name]}` : null).filter(Boolean).join(', '))
async function placeOrder() {
  if (!form.value.name || !form.value.phone || !form.value.addr) { toast('Fill in your name, phone and address', 'warn'); return }
  // require a choice for each option group
  for (const o of productOptions.value) {
    if (!selectedOpts.value[o.name]) { toast(`Please choose ${o.name.toLowerCase()}`, 'warn'); return }
  }
  ordering.value = true
  try {
    const { data: code, error } = await supabase.rpc('place_order_v2', {
      p_store_slug: route.params.slug, p_product_id: p.value.id,
      p_buyer_name: form.value.name, p_buyer_phone: form.value.phone,
      p_buyer_addr: form.value.addr, p_qty: Number(form.value.qty) || 1,
      p_variant: variantString.value || null })
    if (error) throw error
    orderCode.value = code
  } catch (e) { toast(e.message || 'Could not place order', 'warn') }
  ordering.value = false
}

function shareProduct() {
  const url = window.location.href
  if (navigator.share) { navigator.share({ title: p.value.name, url }).catch(() => {}) }
  else { navigator.clipboard?.writeText(url); toast('Link copied — share it anywhere', 'ok') }
}

onMounted(load)
</script>

<template>
  <AppHeader />
  <div class="wrap pd-wrap">
    <div v-if="loading" class="pd-load"><Spinner :size="26" /></div>
    <EmptyState v-else-if="notFound" icon="package" title="Product not found" hint="It may have been removed or sold." />
    <template v-else>
      <RouterLink :to="`/shop/${shop.slug}`" class="pd-back"><Icon name="arrowLeft" :size="15" /> {{ shop.name }}</RouterLink>

      <div class="pd-grid">
        <!-- gallery -->
        <div class="pd-gallery">
          <div class="pd-main" :class="{soldout: soldOut}" :style="images.length ? {backgroundImage:`url(${images[activeImg]})`} : {background:`linear-gradient(135deg, ${shop.accent||'#0B6E5D'}, ${shop.accent||'#075446'}bb)`}">
            <span v-if="!images.length" class="pd-ph-chip">{{ (p.name||'?').slice(0,1).toUpperCase() }}</span>
            <span v-if="soldOut" class="pd-badge sold">Sold out</span>
            <span v-else-if="lowStock" class="pd-badge low">Only {{ p.stock_qty }} left</span>
            <span v-else-if="discount" class="pd-badge off">{{ discount }}% off</span>
          </div>
          <div v-if="images.length > 1" class="pd-thumbs">
            <button v-for="(img,i) in images" :key="i" class="pd-thumb" :class="{on:i===activeImg}" :style="{backgroundImage:`url(${img})`}" @click="activeImg=i"></button>
          </div>
        </div>

        <!-- info -->
        <div class="pd-info">
          <h1 class="pd-name">{{ p.name }}</h1>
          <div class="pd-price-row">
            <span class="pd-price">{{ tzs(p.price_tzs) }}</span>
            <span v-if="discount" class="pd-was">{{ tzs(p.compare_at_tzs) }}</span>
            <span v-if="discount" class="pd-save">Save {{ tzs(p.compare_at_tzs - p.price_tzs) }} · {{ discount }}%</span>
          </div>
          <div v-if="lowStock && !soldOut" class="pd-urgency"><Icon name="star" :size="13" /> Only {{ p.stock_qty }} left — order soon</div>
          <p v-if="p.description" class="pd-desc">{{ p.description }}</p>

          <div v-for="(opt,oi) in productOptions" :key="oi" class="pd-opt-preview">
            <span class="pd-opt-label">{{ opt.name }}:</span>
            <span v-for="ch in opt.choices" :key="ch" class="pd-opt-chip">{{ ch }}</span>
          </div>

          <RouterLink :to="`/shop/${shop.slug}`" class="pd-shop">
            <Avatar :name="shop.name" :size="38" />
            <div class="pd-shop-id">
              <div class="pd-shop-name">{{ shop.name }} <Icon v-if="shop.verified" name="check" :size="13" class="pd-vf" /></div>
              <TrustBadge v-if="data.shop_rep && data.shop_rep.tier !== 'new'" :rep="data.shop_rep" compact />
              <span v-else class="pd-shop-sub">View shop</span>
            </div>
          </RouterLink>

          <div class="pd-trust"><Icon name="shield" :size="15" /> <div><b>Protected by Enkiama</b><span>Tracked delivery, cash on delivery, and your payment held until it arrives.</span></div></div>

          <div v-if="confidence" class="pd-confidence">
            <div class="pd-conf-row">
              <div v-if="confidence.typical_days" class="pd-conf-stat">
                <Icon name="clock" :size="16" />
                <div><b>~{{ confidence.typical_days }} day{{ confidence.typical_days===1?'':'s' }}</b><span>typical delivery</span></div>
              </div>
              <div v-if="confidence.on_time_pct !== null" class="pd-conf-stat">
                <Icon name="check" :size="16" />
                <div><b>{{ confidence.on_time_pct }}% on-time</b><span>arrival rate</span></div>
              </div>
              <div class="pd-conf-stat">
                <Icon name="package" :size="16" />
                <div><b>{{ confidence.delivered }}</b><span>parcels delivered</span></div>
              </div>
            </div>
          </div>

          <div class="pd-actions">
            <button v-if="!soldOut" class="btn btn-buy btn-lg pd-order" @click="showOrder=true">Order now · {{ tzs(p.price_tzs) }}</button>
            <button v-else class="btn btn-lg" disabled>Sold out</button>
            <button class="btn btn-ghost btn-lg" @click="shareProduct"><Icon name="send" :size="16" /> Share</button>
          </div>
        </div>
      </div>

      <!-- more from shop -->
      <div v-if="data.more?.length" class="pd-more">
        <h2 class="pd-more-h">More from {{ shop.name }}</h2>
        <div class="pd-more-grid">
          <RouterLink v-for="m in data.more" :key="m.id" :to="`/shop/${shop.slug}/product/${m.id}`" class="pd-more-card">
            <div class="pd-more-img" :style="(m.image_url || (m.images&&m.images[0])) ? {backgroundImage:`url(${m.image_url || m.images[0]})`} : {background:`linear-gradient(135deg, ${shop.accent||'#0B6E5D'}, ${shop.accent||'#075446'}bb)`}">
              <span v-if="!(m.image_url || (m.images&&m.images[0]))" class="pd-more-ph">{{ (m.name||'?').slice(0,1) }}</span>
            </div>
            <div class="pd-more-name">{{ m.name }}</div>
            <div class="pd-more-price">{{ tzs(m.price_tzs) }}</div>
          </RouterLink>
        </div>
      </div>
    </template>

    <!-- order modal -->
    <div v-if="showOrder" class="overlay" @click.self="showOrder=false; orderCode=''">
      <div class="modal" style="max-width:440px">
        <template v-if="!orderCode">
          <h3>Order {{ p.name }}</h3>
          <p>Pay {{ tzs(p.price_tzs * (Number(form.qty)||1)) }} on delivery. {{ shop.name }} ships it tracked via Enkiama.</p>
          <div v-for="(opt,oi) in productOptions" :key="oi" class="fg">
            <label>{{ opt.name }}</label>
            <div class="pd-opts">
              <button v-for="ch in opt.choices" :key="ch" type="button" class="pd-opt" :class="{on: selectedOpts[opt.name] === ch}" @click="selectedOpts[opt.name] = ch">{{ ch }}</button>
            </div>
          </div>
          <div class="fg"><label>Your name</label><input v-model="form.name" placeholder="Full name" /></div>
          <div class="row2">
            <div class="fg"><label>Phone</label><input v-model="form.phone" placeholder="+255…" /></div>
            <div class="fg"><label>Quantity</label><input v-model="form.qty" type="number" min="1" /></div>
          </div>
          <div class="fg"><label>Delivery address</label><input v-model="form.addr" placeholder="Where to deliver" /></div>
          <div class="form-actions">
            <button class="btn btn-ghost" @click="showOrder=false">Cancel</button>
            <button class="btn btn-buy" :disabled="ordering" @click="placeOrder"><Spinner v-if="ordering" :size="15" /><span v-else>Place order</span></button>
          </div>
        </template>
        <template v-else>
          <div class="pd-success">
            <div class="pd-success-ic"><Icon name="check" :size="24" /></div>
            <h3>Order placed</h3>
            <p>Your tracking code is <b class="mono">{{ orderCode }}</b>. {{ shop.name }} will ship your {{ p.name }} — tracked all the way, pay on delivery.</p>
            <RouterLink :to="`/track/${orderCode}`" class="btn btn-accent btn-block btn-lg">Track your order</RouterLink>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
.pd-wrap{max-width:1000px}
.pd-load{display:flex;justify-content:center;padding:80px}
.pd-back{display:inline-flex;align-items:center;gap:6px;font-size:13.5px;font-weight:600;color:var(--ink-soft);text-decoration:none;margin-bottom:20px}
.pd-back:hover{color:var(--accent-ink)}
.pd-grid{display:grid;grid-template-columns:1fr 1fr;gap:36px;align-items:start}
@media(max-width:760px){.pd-grid{grid-template-columns:1fr;gap:24px}}

.pd-main{aspect-ratio:1;border-radius:18px;background-size:cover;background-position:center;position:relative;display:flex;align-items:center;justify-content:center;box-shadow:var(--shadow-sm)}
.pd-main.soldout{opacity:.7}
.pd-ph{font-family:'Space Grotesk',sans-serif;font-size:80px;font-weight:700;color:rgba(255,255,255,.9)}
.pd-badge{position:absolute;top:14px;left:14px;font-size:12px;font-weight:700;padding:5px 12px;border-radius:8px;color:#fff}
.pd-badge.off{background:var(--owed)}
.pd-badge.low{background:var(--warn)}
.pd-badge.sold{background:var(--ink)}
.pd-thumbs{display:flex;gap:10px;margin-top:12px}
.pd-thumb{width:64px;height:64px;border-radius:11px;background-size:cover;background-position:center;border:2px solid transparent;cursor:pointer;padding:0}
.pd-thumb.on{border-color:var(--accent)}

.pd-name{font-family:'Space Grotesk',sans-serif;font-size:30px;font-weight:700;letter-spacing:-.02em;line-height:1.15;color:var(--ink);margin-bottom:12px}
.pd-price-row{display:flex;align-items:baseline;gap:12px;margin-bottom:16px}
.pd-price{font-family:'Space Grotesk',sans-serif;font-size:26px;font-weight:700;color:var(--ink);font-variant-numeric:tabular-nums}
.pd-was{font-size:17px;color:var(--ink-faint);text-decoration:line-through}
.pd-desc{font-size:14.5px;line-height:1.65;color:var(--ink-soft);margin-bottom:20px}

.pd-shop{display:flex;align-items:center;gap:12px;padding:14px;background:var(--surface-2);border-radius:13px;text-decoration:none;margin-bottom:16px;transition:background var(--dur) var(--ease)}
.pd-shop:hover{background:var(--surface-3)}
.pd-shop-name{font-weight:650;font-size:14.5px;color:var(--ink);display:flex;align-items:center;gap:5px}
.pd-vf{color:var(--accent-ink)}
.pd-shop-sub{font-size:12.5px;color:var(--ink-faint)}

.pd-trust{display:flex;gap:10px;align-items:flex-start;padding:13px 15px;background:linear-gradient(135deg,var(--accent-soft),var(--go-soft));border:1px solid var(--accent);border-radius:12px;margin-bottom:22px}
.pd-trust svg{color:var(--accent-ink);flex-shrink:0;margin-top:1px}
.pd-trust b{display:block;font-size:13px;color:var(--accent-ink);margin-bottom:2px}
.pd-trust span{font-size:12px;line-height:1.5;color:var(--ink-soft)}

.pd-actions{display:flex;gap:10px}
.pd-order{flex:1}

.pd-more{margin-top:48px}
.pd-more-h{font-family:'Space Grotesk',sans-serif;font-size:20px;font-weight:700;margin-bottom:18px;color:var(--ink)}
.pd-more-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:18px}
.pd-more-card{text-decoration:none;display:block}
.pd-more-img{aspect-ratio:1;border-radius:13px;background-size:cover;background-position:center;display:flex;align-items:center;justify-content:center;margin-bottom:10px;transition:transform var(--dur-fast) var(--ease)}
.pd-more-card:hover .pd-more-img{transform:translateY(-3px)}
.pd-more-ph{font-family:'Space Grotesk',sans-serif;font-size:36px;font-weight:700;color:rgba(255,255,255,.9)}
.pd-more-name{font-weight:600;font-size:14px;color:var(--ink);line-height:1.3}
.pd-more-price{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:14px;color:var(--ink-soft);margin-top:2px}

.pd-success{text-align:center;padding:10px}
.pd-success-ic{width:56px;height:56px;border-radius:50%;background:var(--go-soft);color:var(--go-ink);display:flex;align-items:center;justify-content:center;margin:0 auto 14px}

.pd-opt-preview{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:14px}
.pd-opt-label{font-size:13px;font-weight:650;color:var(--ink)}
.pd-opt-chip{font-size:12.5px;font-weight:600;color:var(--ink-soft);background:var(--surface-2);padding:4px 11px;border-radius:999px;border:1px solid var(--hairline)}
.pd-opts{display:flex;gap:8px;flex-wrap:wrap}
.pd-opt{font-size:13.5px;font-weight:600;padding:8px 16px;border-radius:10px;border:1.5px solid var(--hairline-2);background:var(--surface);color:var(--ink-soft);cursor:pointer;font-family:inherit;transition:.15s}
.pd-opt:hover{border-color:var(--accent)}
.pd-opt.on{background:var(--accent-soft);border-color:var(--accent);color:var(--accent-ink)}

.pd-confidence{margin-bottom:22px}
.pd-conf-row{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
.pd-conf-stat{display:flex;align-items:center;gap:9px;padding:12px 13px;background:var(--surface-2);border-radius:12px}
.pd-conf-stat svg{color:var(--accent-ink);flex-shrink:0}
.pd-conf-stat b{display:block;font-size:14px;font-weight:700;color:var(--ink);font-variant-numeric:tabular-nums;line-height:1.2}
.pd-conf-stat span{font-size:11px;color:var(--ink-faint);line-height:1.3}
@media(max-width:520px){.pd-conf-row{grid-template-columns:1fr}}

.pd-save{font-size:12.5px;font-weight:700;color:#fff;background:var(--owed);padding:3px 10px;border-radius:7px;letter-spacing:.01em}
.pd-urgency{display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600;color:var(--warn-ink);background:var(--warn-soft);padding:6px 12px;border-radius:9px;margin-bottom:14px}
.pd-urgency svg{color:var(--warn-ink)}
.pd-main{position:relative;overflow:hidden}
.pd-main::before{content:"";position:absolute;inset:0;background:radial-gradient(circle at 50% 32%,rgba(255,255,255,.16),transparent 60%);pointer-events:none}
.pd-ph-chip{position:relative;z-index:1;width:88px;height:88px;border-radius:24px;display:flex;align-items:center;justify-content:center;font-family:'Space Grotesk',sans-serif;font-size:40px;font-weight:700;color:#fff;background:rgba(255,255,255,.15);border:2px solid rgba(255,255,255,.28);box-shadow:0 6px 20px rgba(0,0,0,.16),inset 0 1px 0 rgba(255,255,255,.3)}
</style>
