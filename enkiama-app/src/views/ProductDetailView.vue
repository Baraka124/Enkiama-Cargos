<script setup>
// ENKIAMA MARKET V8 — product experience + quiet stepped checkout.
// Commerce contracts remain unchanged: get_product, delivery_confidence, product_reviews, place_order_v2.
import { ref, computed, onMounted, inject, watch, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { usePublic } from '../composables/usePublic'
import AppHeader from '../components/AppHeader.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import Avatar from '../components/Avatar.vue'
import TrustBadge from '../components/TrustBadge.vue'
import EmptyState from '../components/EmptyState.vue'
import { viewName, signalMotionReady } from '../lib/motion'

const route = useRoute()
const toast = inject('toast')
const pub = usePublic()

const data = ref(null)
const loading = ref(true)
const notFound = ref(false)
const activeImg = ref(0)
const galleryOpen = ref(false)
const confidence = ref(null)
const reviews = ref({ avg: 0, count: 0, reviews: [] })

const p = computed(() => data.value?.product || {})
const shop = computed(() => data.value?.shop || {})
const shopRep = computed(() => data.value?.shop_rep || null)

const images = computed(() => {
  const valid = (u) => {
    const s = String(u || '').trim()
    return s && s !== 'null' && s.startsWith('http')
  }
  const arr = (Array.isArray(p.value.images) ? p.value.images : []).filter(valid)
  if (valid(p.value.image_url) && !arr.includes(p.value.image_url)) arr.unshift(p.value.image_url)
  return arr
})

const discount = computed(() => p.value.compare_at_tzs > p.value.price_tzs
  ? Math.round((1 - p.value.price_tzs / p.value.compare_at_tzs) * 100) : 0)
const soldOut = computed(() => p.value.available === false || (p.value.track_stock && p.value.stock_qty !== null && p.value.stock_qty !== undefined && Number(p.value.stock_qty) <= 0))
const lowStock = computed(() => p.value.track_stock && p.value.stock_qty > 0 && p.value.stock_qty <= 5)
const productOptions = computed(() => Array.isArray(p.value.options) ? p.value.options.filter(o => o?.name && o?.choices?.length) : [])
const selectedOpts = ref({})
const variantString = computed(() => productOptions.value
  .map(o => selectedOpts.value[o.name] ? `${o.name}: ${selectedOpts.value[o.name]}` : null)
  .filter(Boolean).join(', '))
const allOptionsChosen = computed(() => productOptions.value.every(o => selectedOpts.value[o.name]))
const shopPlace = computed(() => shop.value.region || shop.value.city || 'Tanzania')
const orderTotal = computed(() => (Number(p.value.price_tzs) || 0) * (Number(form.value.qty) || 1))
const reviewItems = computed(() => Array.isArray(reviews.value?.reviews) ? reviews.value.reviews : [])

function tzs(n) { return n || n === 0 ? 'TZS ' + Number(n).toLocaleString() : '' }

async function loadConfidence() {
  confidence.value = null
  if (!data.value?.shop?.id) return
  try {
    const { data: c } = await supabase.rpc('delivery_confidence', { p_storefront_id: data.value.shop.id, p_dest: null })
    if (c?.has_data) confidence.value = c
  } catch (e) {}
}

async function loadReviews() {
  reviews.value = { avg: 0, count: 0, reviews: [] }
  if (!p.value?.id) return
  try {
    const { data: r } = await pub.productReviews(p.value.id)
    if (r) reviews.value = r
  } catch (e) {}
}

async function load() {
  loading.value = true
  notFound.value = false
  data.value = null
  activeImg.value = 0
  galleryOpen.value = false
  confidence.value = null
  reviews.value = { avg: 0, count: 0, reviews: [] }
  selectedOpts.value = {}
  showOrder.value = false
  orderCode.value = ''
  checkoutStep.value = 1
  checkoutError.value = ''
  try {
    const { data: res, error } = await supabase.rpc('get_product', {
      p_shop_slug: route.params.slug,
      p_product_id: route.params.id,
    })
    if (error) throw error
    if (res?.ok) {
      data.value = res
      await Promise.allSettled([loadConfidence(), loadReviews()])
    } else {
      notFound.value = true
    }
  } catch (e) {
    notFound.value = true
  }
  loading.value = false
  await nextTick()
  signalMotionReady()
}

function chooseOption(name, choice) {
  selectedOpts.value = { ...selectedOpts.value, [name]: choice }
}

function openOrder() {
  if (soldOut.value) return
  checkoutStep.value = 1
  checkoutError.value = ''
  showOrder.value = true
}

function closeOrder() {
  if (ordering.value) return
  showOrder.value = false
  orderCode.value = ''
  checkoutStep.value = 1
  checkoutError.value = ''
}

function nextImage(dir = 1) {
  if (images.value.length < 2) return
  activeImg.value = (activeImg.value + dir + images.value.length) % images.value.length
}

// checkout / order — V8 keeps the RPC contract untouched and makes the interaction progressive.
const showOrder = ref(false)
const form = ref({ name: '', phone: '', addr: '', qty: 1 })
const ordering = ref(false)
const orderCode = ref('')
const checkoutStep = ref(1)
const checkoutError = ref('')
const checkoutSteps = [
  { id: 1, label: 'Choose' },
  { id: 2, label: 'Who' },
  { id: 3, label: 'Where' },
  { id: 4, label: 'Confirm' },
]
const maxQty = computed(() => p.value.track_stock && Number(p.value.stock_qty) > 0 ? Number(p.value.stock_qty) : null)
const cleanPhoneDigits = computed(() => String(form.value.phone || '').replace(/\D/g, ''))

function normalizeQty() {
  let q = Math.max(1, Math.floor(Number(form.value.qty) || 1))
  if (maxQty.value) q = Math.min(q, maxQty.value)
  form.value.qty = q
}

function validateCheckoutStep(step) {
  checkoutError.value = ''
  if (step === 1) {
    for (const o of productOptions.value) {
      if (!selectedOpts.value[o.name]) {
        checkoutError.value = `Choose ${o.name.toLowerCase()} before continuing.`
        return false
      }
    }
    normalizeQty()
    if (Number(form.value.qty) < 1) {
      checkoutError.value = 'Quantity must be at least 1.'
      return false
    }
  }
  if (step === 2) {
    if (String(form.value.name || '').trim().length < 2) {
      checkoutError.value = 'Enter the name of the person receiving this order.'
      return false
    }
    if (cleanPhoneDigits.value.length < 7) {
      checkoutError.value = 'Enter a phone number we can use for delivery.'
      return false
    }
  }
  if (step === 3 && String(form.value.addr || '').trim().length < 5) {
    checkoutError.value = 'Add a clear delivery address or meeting point.'
    return false
  }
  return true
}

function checkoutNext() {
  if (!validateCheckoutStep(checkoutStep.value)) return
  checkoutStep.value = Math.min(4, checkoutStep.value + 1)
}

function checkoutBack() {
  checkoutError.value = ''
  checkoutStep.value = Math.max(1, checkoutStep.value - 1)
}

function goCheckoutStep(step) {
  if (step >= checkoutStep.value) return
  checkoutError.value = ''
  checkoutStep.value = step
}

async function placeOrder() {
  for (const step of [1, 2, 3]) {
    if (!validateCheckoutStep(step)) {
      checkoutStep.value = step
      return
    }
  }
  checkoutError.value = ''
  ordering.value = true
  try {
    const { data: code, error } = await supabase.rpc('place_order_v2', {
      p_store_slug: route.params.slug,
      p_product_id: p.value.id,
      p_buyer_name: form.value.name.trim(),
      p_buyer_phone: form.value.phone.trim(),
      p_buyer_addr: form.value.addr.trim(),
      p_qty: Number(form.value.qty) || 1,
      p_variant: variantString.value || null,
    })
    if (error) throw error
    orderCode.value = code
  } catch (e) {
    checkoutError.value = e.message || 'Could not place this order. Please try again.'
    toast(checkoutError.value, 'warn')
  }
  ordering.value = false
}

function shareProduct() {
  const url = window.location.href
  if (navigator.share) {
    navigator.share({ title: p.value.name, text: `${p.value.name} from ${shop.value.name} on Enkiama Market`, url }).catch(() => {})
  } else {
    navigator.clipboard?.writeText(url)
    toast('Link copied — share it anywhere', 'ok')
  }
}

onMounted(load)
watch(() => route.params.id, (newId, oldId) => {
  if (newId && newId !== oldId) {
    window.scrollTo({ top: 0, behavior: 'smooth' })
    load()
  }
})
</script>

<template>
  <AppHeader />

  <main class="pd-page">
    <div v-if="loading" class="pd-load"><Spinner :size="26" /></div>

    <div v-else-if="notFound" class="pd-state">
      <EmptyState icon="package" title="Product not found" hint="It may have been removed or sold." />
      <RouterLink to="/market" class="pd-state-link"><Icon name="arrow" :size="15" style="transform:rotate(180deg)" /> Return to Market</RouterLink>
    </div>

    <template v-else>
      <!-- 01 / OBJECT — expressive, quiet, product-first -->
      <section class="pd-object">
        <div class="pd-object-top">
          <RouterLink :to="`/shop/${shop.slug}`" class="pd-back">
            <Icon name="arrow" :size="14" style="transform:rotate(180deg)" />
            <span>{{ shop.name }}</span>
          </RouterLink>
          <div class="pd-index"><span>01</span><span>Object / Market</span></div>
        </div>

        <div class="pd-object-grid">
          <div class="pd-gallery-col">
            <div class="pd-gallery-frame" :class="{soldout: soldOut}" :style="{viewTransitionName:activeImg===0 ? viewName('product', p.id) : 'none'}">
              <button
                v-if="images.length"
                class="pd-main"
                data-cursor="Open"
                :style="{backgroundImage:`url(${images[activeImg]})`}"
                type="button"
                aria-label="Open product image"
                @click="galleryOpen=true"
              >
                <span class="pd-image-index">{{ String(activeImg + 1).padStart(2,'0') }} / {{ String(images.length).padStart(2,'0') }}</span>
                <span class="pd-image-open">View image ↗</span>
              </button>
              <div
                v-else
                class="pd-main pd-main-placeholder"
                :style="{background:`linear-gradient(145deg, ${shop.accent||'#0B6E5D'}, ${shop.accent||'#075446'}cc)`}"
              >
                <span class="pd-ph-chip">{{ (p.name||'?').slice(0,1).toUpperCase() }}</span>
              </div>

              <span v-if="soldOut" class="pd-status sold">Sold out</span>
              <span v-else-if="lowStock" class="pd-status low">{{ p.stock_qty }} remaining</span>
              <span v-else-if="discount" class="pd-status offer">−{{ discount }}%</span>
            </div>

            <div v-if="images.length > 1" class="pd-thumbs" aria-label="Product gallery">
              <button
                v-for="(img,i) in images"
                :key="i"
                class="pd-thumb"
                :class="{on:i===activeImg}"
                :style="{backgroundImage:`url(${img})`}"
                type="button"
                :aria-label="`View image ${i+1}`"
                @click="activeImg=i"
              ><span>{{ String(i + 1).padStart(2,'0') }}</span></button>
            </div>
          </div>

          <aside class="pd-info">
            <div class="pd-eyebrow">
              <span>{{ p.category || 'Market object' }}</span>
              <span>{{ shopPlace }}</span>
            </div>

            <h1 class="pd-name">{{ p.name }}</h1>

            <div class="pd-price-block">
              <div class="pd-price-row">
                <span class="pd-price">{{ tzs(p.price_tzs) }}</span>
                <span v-if="discount" class="pd-was">{{ tzs(p.compare_at_tzs) }}</span>
              </div>
              <div v-if="discount" class="pd-saving">You save {{ tzs(p.compare_at_tzs - p.price_tzs) }}</div>
            </div>

            <p v-if="p.description" class="pd-desc">{{ p.description }}</p>

            <div v-if="productOptions.length" class="pd-options">
              <div v-for="(opt,oi) in productOptions" :key="oi" class="pd-option-group">
                <div class="pd-option-head">
                  <span>{{ opt.name }}</span>
                  <span>{{ selectedOpts[opt.name] || 'Select' }}</span>
                </div>
                <div class="pd-option-list">
                  <button
                    v-for="ch in opt.choices"
                    :key="ch"
                    type="button"
                    class="pd-option"
                    :class="{on: selectedOpts[opt.name] === ch}"
                    @click="chooseOption(opt.name, ch)"
                  >{{ ch }}</button>
                </div>
              </div>
            </div>

            <div v-if="lowStock && !soldOut" class="pd-availability"><span></span> Only {{ p.stock_qty }} left in stock</div>
            <div v-else-if="!soldOut" class="pd-availability"><span></span> Available to order</div>

            <div class="pd-actions">
              <button v-if="!soldOut" class="pd-buy" type="button" @click="openOrder">
                <span>Order now</span>
                <span>{{ tzs(p.price_tzs) }} ↗</span>
              </button>
              <button v-else class="pd-buy pd-buy-disabled" type="button" disabled><span>Sold out</span><span>Unavailable</span></button>
              <button class="pd-share" type="button" @click="shareProduct"><Icon name="send" :size="15" /> Share</button>
            </div>

            <div class="pd-protection">
              <div class="pd-protection-mark"><Icon name="shield" :size="17" /></div>
              <div>
                <b>Protected by Enkiama</b>
                <p>Tracked delivery and cash on delivery. Follow the parcel from handoff to arrival.</p>
              </div>
            </div>

            <RouterLink :to="`/shop/${shop.slug}`" class="pd-maker-mini">
              <Avatar :name="shop.name" :accent="shop.accent" :logo="shop.logo_url" :size="38" />
              <div class="pd-maker-mini-copy">
                <span>Sold by</span>
                <strong>{{ shop.name }} <Icon v-if="shop.verified" name="check" :size="12" /></strong>
              </div>
              <span class="pd-maker-mini-arrow">↗</span>
            </RouterLink>
          </aside>
        </div>
      </section>

      <!-- 02 / MOVEMENT — delivery is part of the product experience -->
      <section v-reveal class="pd-movement">
        <div class="pd-movement-inner">
          <div class="pd-section-index"><span>02</span><span>Movement</span></div>
          <div class="pd-movement-head">
            <h2>From {{ shopPlace }}<br>to your door.</h2>
            <p>Once ordered, this object enters Enkiama's tracked delivery flow. The operational layer stays quiet until you need it.</p>
          </div>

          <div class="pd-route" aria-label="Delivery journey">
            <div class="pd-route-node on">
              <span class="pd-route-dot"></span>
              <strong>{{ shop.name }}</strong>
              <small>Seller handoff</small>
            </div>
            <div class="pd-route-line"><span></span></div>
            <div class="pd-route-node on">
              <span class="pd-route-dot"></span>
              <strong>Enkiama</strong>
              <small>Tracked movement</small>
            </div>
            <div class="pd-route-line"><span></span></div>
            <div class="pd-route-node">
              <span class="pd-route-dot"></span>
              <strong>You</strong>
              <small>Arrival &amp; receipt</small>
            </div>
          </div>

          <div class="pd-confidence-ledger">
            <div class="pd-ledger-stat">
              <span>Typical movement</span>
              <strong v-if="confidence?.typical_days">~{{ confidence.typical_days }} day{{ confidence.typical_days===1?'':'s' }}</strong>
              <strong v-else>Tracked</strong>
            </div>
            <div class="pd-ledger-stat">
              <span>On-time history</span>
              <strong v-if="confidence?.on_time_pct !== null && confidence?.on_time_pct !== undefined">{{ confidence.on_time_pct }}%</strong>
              <strong v-else>Live status</strong>
            </div>
            <div class="pd-ledger-stat">
              <span>Delivered by this shop</span>
              <strong v-if="confidence?.delivered !== undefined">{{ confidence.delivered }}</strong>
              <strong v-else>—</strong>
            </div>
          </div>
        </div>
      </section>

      <!-- 03 / PROVENANCE — business identity instead of badge clutter -->
      <section v-reveal class="pd-provenance">
        <div class="pd-section-index"><span>03</span><span>Provenance</span></div>
        <div class="pd-provenance-grid">
          <div class="pd-maker-lockup">
            <Avatar :name="shop.name" :accent="shop.accent" :logo="shop.logo_url" :size="70" />
            <div>
              <p>Made available by</p>
              <h2>{{ shop.name }}</h2>
              <span v-if="shop.region"><Icon name="pin" :size="13" /> {{ shop.region }}</span>
            </div>
          </div>

          <div class="pd-maker-story">
            <p v-if="shop.about">{{ shop.about }}</p>
            <p v-else-if="shop.tagline">{{ shop.tagline }}</p>
            <p v-else>This product is listed by {{ shop.name }} and moves through Enkiama's tracked marketplace network.</p>

            <div class="pd-maker-facts">
              <div v-if="shop.verified || shop.verified_delivery"><span>Identity</span><strong>Verified</strong></div>
              <div v-if="shop.since_year"><span>Trading since</span><strong>{{ shop.since_year }}</strong></div>
              <div v-if="shop.ships_what"><span>Usually ships</span><strong>{{ shop.ships_what }}</strong></div>
              <div v-if="shopRep && shopRep.tier !== 'new'" class="pd-rep"><span>Marketplace record</span><TrustBadge :rep="shopRep" compact /></div>
            </div>

            <RouterLink :to="`/shop/${shop.slug}`" class="pd-text-link">Visit {{ shop.name }} <span>↗</span></RouterLink>
          </div>
        </div>
      </section>

      <!-- 04 / EXPERIENCE — reviews if the product has them -->
      <section v-if="reviews.count" v-reveal class="pd-reviews-section">
        <div class="pd-section-index"><span>04</span><span>Experience</span></div>
        <div class="pd-reviews-grid">
          <div class="pd-review-score">
            <span class="pd-review-number">{{ reviews.avg }}</span>
            <div class="pd-stars"><Icon v-for="n in 5" :key="n" name="star" :size="15" :class="{on:n <= Math.round(reviews.avg)}" /></div>
            <p>{{ reviews.count }} product review{{ reviews.count===1?'':'s' }}</p>
          </div>
          <div class="pd-review-list">
            <article v-for="(r,i) in reviewItems.slice(0,4)" :key="i" class="pd-review">
              <div class="pd-review-meta">
                <span><Icon v-for="n in 5" :key="n" name="star" :size="11" :class="{on:n <= r.rating}" /></span>
                <small>{{ r.name || 'Buyer' }}</small>
              </div>
              <p v-if="r.comment">“{{ r.comment }}”</p>
            </article>
          </div>
        </div>
      </section>

      <!-- final collection — return to discovery -->
      <section v-if="data.more?.length" v-reveal class="pd-more">
        <div class="pd-more-head">
          <div class="pd-section-index"><span>{{ reviews.count ? '05' : '04' }}</span><span>Continue</span></div>
          <div>
            <h2>More from {{ shop.name }}</h2>
            <RouterLink :to="`/shop/${shop.slug}`" class="pd-text-link">View the whole shop <span>↗</span></RouterLink>
          </div>
        </div>

        <div class="pd-more-grid">
          <RouterLink v-for="(m,mi) in data.more" :key="m.id" :to="`/shop/${shop.slug}/product/${m.id}`" class="pd-more-card" data-cursor="View">
            <div class="pd-more-img" :style="Object.assign({}, (m.image_url || (m.images&&m.images[0])) ? {backgroundImage:`url(${m.image_url || m.images[0]})`} : {background:`linear-gradient(145deg, ${shop.accent||'#0B6E5D'}, ${shop.accent||'#075446'}cc)`}, {viewTransitionName:m.id===p.id ? 'none' : viewName('product',m.id)})">
              <span class="pd-more-index">{{ String(mi + 1).padStart(2,'0') }}</span>
              <span v-if="!(m.image_url || (m.images&&m.images[0]))" class="pd-more-ph">{{ (m.name||'?').slice(0,1) }}</span>
              <span class="pd-more-open">↗</span>
            </div>
            <div class="pd-more-copy"><span>{{ m.name }}</span><strong>{{ tzs(m.price_tzs) }}</strong></div>
          </RouterLink>
        </div>
      </section>
    </template>
  </main>

  <!-- full-screen image viewing stays entirely presentation-only -->
  <div v-if="galleryOpen && images.length" class="pd-lightbox" @click.self="galleryOpen=false">
    <button class="pd-lightbox-close" type="button" aria-label="Close image" @click="galleryOpen=false"><Icon name="plus" :size="20" style="transform:rotate(45deg)" /></button>
    <button v-if="images.length > 1" class="pd-lightbox-nav prev" type="button" aria-label="Previous image" @click="nextImage(-1)"><Icon name="arrow" :size="20" style="transform:rotate(180deg)" /></button>
    <img :src="images[activeImg]" :alt="p.name" />
    <button v-if="images.length > 1" class="pd-lightbox-nav next" type="button" aria-label="Next image" @click="nextImage(1)"><Icon name="arrow" :size="20" /></button>
    <span class="pd-lightbox-count">{{ String(activeImg + 1).padStart(2,'0') }} / {{ String(images.length).padStart(2,'0') }}</span>
  </div>

  <!-- CHECKOUT — V8: choose → identity → destination → confirm → movement -->
  <div v-if="showOrder" v-escape="closeOrder" class="overlay pd-order-overlay" @click.self="closeOrder">
    <div class="pd-order-sheet" role="dialog" aria-modal="true" :aria-label="orderCode ? 'Order confirmed' : `Order ${p.name}`">
      <button class="pd-order-close" type="button" aria-label="Close order" :disabled="ordering" @click="closeOrder">
        <Icon name="plus" :size="18" style="transform:rotate(45deg)" />
      </button>

      <template v-if="!orderCode">
        <aside class="pd-order-summary">
          <div class="pd-order-image" :style="images.length ? {backgroundImage:`url(${images[0]})`} : {background:`linear-gradient(145deg, ${shop.accent||'#0B6E5D'}, ${shop.accent||'#075446'}cc)`}"></div>
          <div class="pd-order-summary-copy">
            <span>Order / {{ shop.name }}</span>
            <h3>{{ p.name }}</h3>
            <strong>{{ tzs(p.price_tzs) }}</strong>
            <p>Cash on delivery. No card details are collected here. Once confirmed, the order enters Enkiama's tracked movement flow.</p>
          </div>

          <div class="pd-order-side-facts">
            <div><span>Quantity</span><strong>{{ form.qty }}</strong></div>
            <div v-if="variantString"><span>Selection</span><strong>{{ variantString }}</strong></div>
            <div><span>Payment</span><strong>On delivery</strong></div>
          </div>

          <div class="pd-order-route-mini">
            <span class="on"></span><i></i><span class="on"></span><i></i><span></span>
            <small>{{ shopPlace }}</small><small>Enkiama</small><small>You</small>
          </div>
        </aside>

        <section class="pd-order-flow">
          <div class="pd-checkout-head">
            <div>
              <span class="pd-order-kicker">Checkout</span>
              <h3>{{ checkoutStep === 1 ? 'Choose your object.' : checkoutStep === 2 ? 'Who receives it?' : checkoutStep === 3 ? 'Where should it arrive?' : 'Check it once.' }}</h3>
            </div>
            <span class="pd-checkout-count">0{{ checkoutStep }} / 04</span>
          </div>

          <nav class="pd-stepper" aria-label="Checkout progress">
            <button
              v-for="step in checkoutSteps"
              :key="step.id"
              type="button"
              :class="{on:checkoutStep===step.id, done:checkoutStep>step.id}"
              :disabled="step.id >= checkoutStep"
              @click="goCheckoutStep(step.id)"
            >
              <span>0{{ step.id }}</span>
              <strong>{{ step.label }}</strong>
            </button>
          </nav>

          <div class="pd-mobile-order-snapshot">
            <div>
              <span>{{ p.name }}</span>
              <small>{{ shop.name }}</small>
            </div>
            <strong>{{ tzs(orderTotal) }}</strong>
          </div>

          <div class="pd-step-stage">
            <div v-if="checkoutStep === 1" class="pd-step-panel">
              <div v-if="productOptions.length" class="pd-checkout-options">
                <div v-for="(opt,oi) in productOptions" :key="oi" class="pd-sheet-field">
                  <div class="pd-field-head"><label>{{ opt.name }}</label><span>{{ selectedOpts[opt.name] || 'Required' }}</span></div>
                  <div class="pd-sheet-options">
                    <button v-for="ch in opt.choices" :key="ch" type="button" :class="{on:selectedOpts[opt.name] === ch}" @click="chooseOption(opt.name,ch); checkoutError=''">{{ ch }}</button>
                  </div>
                </div>
              </div>
              <div v-else class="pd-no-variants">
                <span class="pd-no-variants-mark"><Icon name="check" :size="15" /></span>
                <div><strong>One configuration</strong><p>This object does not require a size or variant selection.</p></div>
              </div>

              <div class="pd-quantity-control">
                <div><label>Quantity</label><small v-if="maxQty">{{ maxQty }} available</small></div>
                <div class="pd-qty-stepper">
                  <button type="button" aria-label="Decrease quantity" @click="form.qty=Math.max(1, Number(form.qty||1)-1); checkoutError=''">−</button>
                  <input v-model.number="form.qty" type="number" min="1" :max="maxQty || undefined" inputmode="numeric" @blur="normalizeQty" />
                  <button type="button" aria-label="Increase quantity" @click="form.qty=maxQty ? Math.min(maxQty, Number(form.qty||1)+1) : Number(form.qty||1)+1; checkoutError=''">+</button>
                </div>
              </div>
            </div>

            <div v-else-if="checkoutStep === 2" class="pd-step-panel">
              <div class="pd-step-intro"><p>Use the details of the person who should receive the parcel. The phone number is operational: it may be used during delivery.</p></div>
              <div class="pd-sheet-field">
                <label>Receiver name</label>
                <input v-model="form.name" autocomplete="name" placeholder="Full name" @input="checkoutError=''" />
              </div>
              <div class="pd-sheet-field">
                <label>Phone</label>
                <input v-model="form.phone" autocomplete="tel" inputmode="tel" placeholder="+255…" @input="checkoutError=''" />
                <small class="pd-field-note">Include the country code when possible.</small>
              </div>
            </div>

            <div v-else-if="checkoutStep === 3" class="pd-step-panel">
              <div class="pd-step-intro"><p>Give the clearest practical destination you can: street, building, neighbourhood, landmark or agreed meeting point.</p></div>
              <div class="pd-sheet-field">
                <label>Delivery address / meeting point</label>
                <textarea v-model="form.addr" rows="4" placeholder="Where should it arrive?" @input="checkoutError=''" />
              </div>
              <div class="pd-destination-route">
                <div><span></span><strong>{{ shopPlace }}</strong><small>Seller</small></div>
                <i></i>
                <div><span></span><strong>{{ form.addr || 'Your destination' }}</strong><small>Receiver</small></div>
              </div>
            </div>

            <div v-else class="pd-step-panel pd-confirm-panel">
              <div class="pd-confirm-row"><span>Object</span><strong>{{ p.name }}</strong></div>
              <div v-if="variantString" class="pd-confirm-row"><span>Selection</span><strong>{{ variantString }}</strong></div>
              <div class="pd-confirm-row"><span>Quantity</span><strong>{{ form.qty }}</strong></div>
              <button class="pd-confirm-row pd-confirm-edit" type="button" @click="goCheckoutStep(2)"><span>Receiver</span><strong>{{ form.name }} · {{ form.phone }}</strong><em>Edit</em></button>
              <button class="pd-confirm-row pd-confirm-edit" type="button" @click="goCheckoutStep(3)"><span>Destination</span><strong>{{ form.addr }}</strong><em>Edit</em></button>

              <div class="pd-payment-contract">
                <div class="pd-payment-mark"><Icon name="shield" :size="17" /></div>
                <div><span>Payment</span><strong>Cash on delivery</strong><p>No online payment details are requested in this checkout. Pay when the order reaches you.</p></div>
              </div>

              <div class="pd-final-total">
                <span>Total due on delivery</span>
                <strong>{{ tzs(orderTotal) }}</strong>
              </div>
            </div>
          </div>

          <div v-if="checkoutError" class="pd-checkout-error" role="alert"><span>!</span>{{ checkoutError }}</div>

          <footer class="pd-checkout-actions">
            <button v-if="checkoutStep > 1" class="pd-checkout-back" type="button" :disabled="ordering" @click="checkoutBack">← Back</button>
            <span v-else class="pd-checkout-security"><Icon name="shield" :size="13" /> Tracked by Enkiama</span>

            <button v-if="checkoutStep < 4" class="pd-checkout-next" type="button" @click="checkoutNext">
              <span>Continue</span><span>0{{ checkoutStep + 1 }} ↗</span>
            </button>
            <button v-else class="pd-checkout-next pd-place-order" :disabled="ordering" type="button" @click="placeOrder">
              <Spinner v-if="ordering" :size="15" />
              <template v-else><span>Confirm order</span><span>{{ tzs(orderTotal) }} ↗</span></template>
            </button>
          </footer>
        </section>
      </template>

      <div v-else class="pd-success">
        <div class="pd-success-mark"><Icon name="check" :size="23" /></div>
        <div class="pd-success-kicker">Order confirmed</div>
        <h3>Your object<br>becomes movement.</h3>
        <p>{{ shop.name }} can now prepare your {{ p.name }}. From here, Enkiama's movement layer takes over: handoff, transit, arrival and receipt remain visible through one tracking code.</p>

        <div class="pd-success-journey">
          <div class="on"><span></span><strong>Order</strong><small>Confirmed</small></div><i></i>
          <div><span></span><strong>Seller</strong><small>Preparing</small></div><i></i>
          <div><span></span><strong>Movement</strong><small>Next</small></div>
        </div>

        <div class="pd-success-code"><span>Tracking code</span><strong class="mono" :style="{viewTransitionName:viewName('parcel', orderCode)}">{{ orderCode }}</strong></div>
        <RouterLink :to="`/track/${orderCode}`" class="pd-success-track" data-cursor="Track">Enter Movement <span>↗</span></RouterLink>
        <button class="pd-success-close" type="button" @click="closeOrder">Continue shopping</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* ────────────────────────────────────────────────────────────────
   ENKIAMA MARKET V8 / PRODUCT + CHECKOUT
   expressive object → quiet commitment → movement
   ──────────────────────────────────────────────────────────────── */
.pd-page{background:#f7f7f3;color:var(--ink);min-height:100vh;padding-bottom:120px}
.pd-load{min-height:68vh;display:grid;place-items:center}
.pd-state{max-width:1180px;margin:0 auto;padding:80px 24px;text-align:center}
.pd-state-link{display:inline-flex;align-items:center;gap:7px;margin-top:18px;font-size:13px;font-weight:650;color:var(--ink)}

.pd-object{max-width:1380px;margin:0 auto;padding:28px 44px 112px}
.pd-object-top{display:flex;justify-content:space-between;align-items:center;margin-bottom:34px}
.pd-back{display:inline-flex;align-items:center;gap:8px;font-size:12px;font-weight:650;letter-spacing:.02em;color:var(--ink-soft);text-decoration:none}
.pd-back:hover{color:var(--ink)}
.pd-index,.pd-section-index{display:flex;align-items:center;gap:11px;font-family:'Spline Sans Mono',monospace;font-size:10.5px;letter-spacing:.08em;text-transform:uppercase;color:#8b8b82}
.pd-index span:first-child,.pd-section-index span:first-child{color:var(--ink)}
.pd-object-grid{display:grid;grid-template-columns:minmax(0,1.28fr) minmax(360px,.72fr);gap:clamp(44px,6vw,92px);align-items:start}

.pd-gallery-col{min-width:0}
.pd-gallery-frame{position:relative;background:#ecece7;overflow:hidden;min-height:0}
.pd-gallery-frame.soldout{filter:saturate(.45)}
.pd-main{border:0;width:100%;aspect-ratio:1.03/1;background-size:cover;background-position:center;position:relative;cursor:zoom-in;display:block;overflow:hidden;transition:transform .65s var(--ease),filter .3s ease}
.pd-main::after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(10,12,14,.04),transparent 35%,rgba(10,12,14,.15));pointer-events:none}
.pd-main:hover{transform:scale(1.008)}
.pd-main-placeholder{display:grid;place-items:center;cursor:default}
.pd-main-placeholder::after{background:radial-gradient(circle at 50% 35%,rgba(255,255,255,.18),transparent 55%)}
.pd-ph-chip{position:relative;z-index:1;width:116px;height:116px;border-radius:50%;display:grid;place-items:center;font-family:'Space Grotesk',sans-serif;font-size:46px;font-weight:600;color:#fff;border:1px solid rgba(255,255,255,.4);background:rgba(255,255,255,.12);backdrop-filter:blur(8px)}
.pd-image-index,.pd-image-open{position:absolute;z-index:2;bottom:18px;font-family:'Spline Sans Mono',monospace;font-size:10px;text-transform:uppercase;letter-spacing:.08em;color:#fff;text-shadow:0 1px 8px rgba(0,0,0,.3)}
.pd-image-index{left:18px}.pd-image-open{right:18px}
.pd-status{position:absolute;z-index:3;top:18px;left:18px;padding:7px 10px;background:rgba(247,247,243,.92);backdrop-filter:blur(8px);font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--ink)}
.pd-status.low{background:#f4ead6;color:#77480a}.pd-status.sold{background:#171a1f;color:#fff}.pd-status.offer{background:#171a1f;color:#fff}
.pd-thumbs{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:8px;margin-top:8px}
.pd-thumb{position:relative;aspect-ratio:1;border:0;background-size:cover;background-position:center;opacity:.5;cursor:pointer;transition:opacity .2s ease,transform .25s var(--ease);padding:0}
.pd-thumb:hover{opacity:.82}.pd-thumb.on{opacity:1}
.pd-thumb.on::after{content:"";position:absolute;inset:0;border:1px solid var(--ink)}
.pd-thumb span{position:absolute;bottom:5px;left:6px;color:#fff;font-family:'Spline Sans Mono',monospace;font-size:9px;text-shadow:0 1px 5px #000}

.pd-info{position:sticky;top:96px;padding-top:6px}
.pd-eyebrow{display:flex;justify-content:space-between;gap:12px;padding-bottom:13px;border-bottom:1px solid #d9d9d1;font-family:'Spline Sans Mono',monospace;font-size:10px;text-transform:uppercase;letter-spacing:.08em;color:#77786f}
.pd-name{font-family:'Space Grotesk',sans-serif;font-size:clamp(42px,4.2vw,68px);line-height:.96;letter-spacing:-.055em;font-weight:600;margin:30px 0 28px;max-width:11ch;text-wrap:balance}
.pd-price-block{padding:0 0 24px;border-bottom:1px solid #d9d9d1}
.pd-price-row{display:flex;align-items:baseline;gap:12px;flex-wrap:wrap}
.pd-price{font-family:'Space Grotesk',sans-serif;font-size:22px;font-weight:600;font-variant-numeric:tabular-nums;letter-spacing:-.025em}
.pd-was{font-size:13px;color:#99998f;text-decoration:line-through}
.pd-saving{font-size:11px;color:var(--accent-ink);margin-top:5px;font-weight:650}
.pd-desc{font-size:15px;line-height:1.8;color:#53554f;max-width:47ch;padding:25px 0 2px}
.pd-options{margin-top:23px;border-top:1px solid #d9d9d1}
.pd-option-group{padding:17px 0;border-bottom:1px solid #d9d9d1}
.pd-option-head{display:flex;justify-content:space-between;align-items:center;font-size:11px;text-transform:uppercase;letter-spacing:.06em;font-weight:700;margin-bottom:12px}
.pd-option-head span:last-child{color:#8d8e85;font-weight:500}
.pd-option-list{display:flex;gap:7px;flex-wrap:wrap}
.pd-option{border:1px solid #d5d5cc;background:transparent;color:#555750;padding:8px 12px;font:600 12px 'Inter',sans-serif;cursor:pointer;border-radius:0}
.pd-option:hover{border-color:#93958c;color:var(--ink)}
.pd-option.on{background:var(--ink);border-color:var(--ink);color:#fff}
.pd-availability{display:flex;align-items:center;gap:8px;margin:18px 0 17px;font-size:11px;font-weight:650;color:#62645e}
.pd-availability span{width:6px;height:6px;border-radius:50%;background:var(--accent);box-shadow:0 0 0 4px rgba(11,110,93,.08)}
.pd-actions{display:grid;grid-template-columns:1fr auto;gap:8px}
.pd-buy{min-height:58px;border:0;background:var(--ink);color:#fff;padding:0 18px;display:flex;justify-content:space-between;align-items:center;font:650 13px 'Inter',sans-serif;cursor:pointer;border-radius:0}
.pd-buy:hover{background:#272b31}
.pd-buy span:last-child{font-family:'Spline Sans Mono',monospace;font-size:10px;letter-spacing:.03em;color:#d7d9d8}
.pd-buy-disabled{opacity:.48;cursor:not-allowed}
.pd-share{width:58px;border:1px solid #cbccc5;background:transparent;color:var(--ink);display:grid;place-items:center;font-size:0;border-radius:0;cursor:pointer}
.pd-share:hover{background:#eeeee9}
.pd-protection{display:grid;grid-template-columns:34px 1fr;gap:11px;padding:22px 0;border-bottom:1px solid #d9d9d1}
.pd-protection-mark{width:30px;height:30px;border:1px solid #c8cbc4;display:grid;place-items:center;color:var(--accent-ink)}
.pd-protection b{display:block;font-size:12px;margin-bottom:4px}.pd-protection p{font-size:11.5px;line-height:1.55;color:#777970}
.pd-maker-mini{display:grid;grid-template-columns:auto 1fr auto;align-items:center;gap:11px;padding:18px 0;color:var(--ink);text-decoration:none}
.pd-maker-mini-copy{display:flex;flex-direction:column;gap:2px}.pd-maker-mini-copy>span{font-size:10px;text-transform:uppercase;letter-spacing:.08em;color:#8a8b83}.pd-maker-mini-copy strong{display:flex;align-items:center;gap:4px;font-size:13px}.pd-maker-mini-arrow{font-size:16px;color:#777970;transition:transform .25s var(--ease)}
.pd-maker-mini:hover .pd-maker-mini-arrow{transform:translate(3px,-3px)}

/* movement chapter */
.pd-movement{background:#15181d;color:#f1f2ee;padding:106px 44px 96px}
.pd-movement-inner{max-width:1280px;margin:0 auto}
.pd-movement .pd-section-index{color:#767d82}.pd-movement .pd-section-index span:first-child{color:#f1f2ee}
.pd-movement-head{display:grid;grid-template-columns:1.25fr .75fr;gap:80px;align-items:end;margin:42px 0 80px}
.pd-movement-head h2{color:#f1f2ee;font-size:clamp(42px,6vw,78px);font-weight:500;line-height:.98;letter-spacing:-.055em}
.pd-movement-head p{color:#969da3;font-size:14px;line-height:1.75;max-width:42ch;padding-bottom:6px}
.pd-route{display:grid;grid-template-columns:auto minmax(70px,1fr) auto minmax(70px,1fr) auto;align-items:start;margin:0 0 66px}
.pd-route-node{display:grid;grid-template-rows:auto auto auto;gap:5px;min-width:130px}
.pd-route-dot{width:9px;height:9px;border:1px solid #697178;border-radius:50%;margin-bottom:11px;background:#15181d;position:relative;z-index:2}.pd-route-node.on .pd-route-dot{background:#d8eee8;border-color:#d8eee8;box-shadow:0 0 0 5px rgba(216,238,232,.06)}
.pd-route-node strong{font:600 13px 'Space Grotesk',sans-serif;color:#f1f2ee}.pd-route-node small{font-size:10.5px;color:#747c82}
.pd-route-line{height:1px;background:#3a4147;margin-top:4px;position:relative}.pd-route-line span{display:block;width:58%;height:1px;background:#91aaa3}
.pd-confidence-ledger{border-top:1px solid #343b41;display:grid;grid-template-columns:repeat(3,1fr)}
.pd-ledger-stat{padding:24px 24px 0 0;min-height:100px;border-right:1px solid #343b41}.pd-ledger-stat:last-child{border-right:0;padding-left:24px}.pd-ledger-stat:nth-child(2){padding-left:24px}
.pd-ledger-stat span{display:block;font-size:9.5px;text-transform:uppercase;letter-spacing:.09em;color:#687178;margin-bottom:11px}.pd-ledger-stat strong{font:500 clamp(24px,3vw,38px) 'Space Grotesk',sans-serif;color:#f1f2ee;letter-spacing:-.04em}

/* provenance */
.pd-provenance,.pd-reviews-section,.pd-more{max-width:1280px;margin:0 auto;padding:106px 44px 0}
.pd-provenance-grid{display:grid;grid-template-columns:.82fr 1.18fr;gap:clamp(60px,9vw,150px);margin-top:44px;border-top:1px solid #d9d9d1;padding-top:38px}
.pd-maker-lockup{display:flex;align-items:center;gap:18px;align-self:start}.pd-maker-lockup p{font-size:10px;text-transform:uppercase;letter-spacing:.08em;color:#898a82;margin-bottom:5px}.pd-maker-lockup h2{font-size:clamp(28px,3vw,42px);font-weight:600;letter-spacing:-.04em}.pd-maker-lockup span{display:flex;align-items:center;gap:5px;font-size:11px;color:#777970;margin-top:6px}
.pd-maker-story>p{font-family:'Space Grotesk',sans-serif;font-size:clamp(20px,2.4vw,30px);line-height:1.35;letter-spacing:-.025em;color:#333630;max-width:31ch}
.pd-maker-facts{margin-top:38px;border-top:1px solid #d9d9d1}.pd-maker-facts>div{display:grid;grid-template-columns:150px 1fr;gap:15px;padding:13px 0;border-bottom:1px solid #d9d9d1;align-items:center}.pd-maker-facts span{font-size:10px;text-transform:uppercase;letter-spacing:.07em;color:#87887f}.pd-maker-facts strong{font-size:12px;font-weight:650}.pd-text-link{display:inline-flex;gap:18px;align-items:center;margin-top:28px;color:var(--ink);font-size:12px;font-weight:700;text-decoration:none;border-bottom:1px solid var(--ink);padding-bottom:5px}.pd-text-link span{transition:transform .2s var(--ease)}.pd-text-link:hover span{transform:translate(3px,-3px)}

/* review chapter */
.pd-reviews-grid{display:grid;grid-template-columns:.55fr 1.45fr;gap:80px;margin-top:44px;border-top:1px solid #d9d9d1;padding-top:38px}.pd-review-number{font:500 clamp(58px,8vw,104px) 'Space Grotesk',sans-serif;line-height:.8;letter-spacing:-.065em}.pd-stars{display:flex;gap:3px;margin:20px 0 8px;color:#c8c9c1}.pd-stars .on,.pd-review-meta span .on{color:var(--ink);fill:var(--ink)}.pd-review-score p{font-size:11px;color:#85867d}.pd-review-list{border-top:1px solid #d9d9d1}.pd-review{padding:20px 0;border-bottom:1px solid #d9d9d1}.pd-review-meta{display:flex;justify-content:space-between;align-items:center;margin-bottom:11px}.pd-review-meta span{display:flex;gap:2px;color:#c7c8c0}.pd-review-meta small{font-size:10px;text-transform:uppercase;letter-spacing:.06em;color:#8b8c84}.pd-review p{font-family:'Space Grotesk',sans-serif;font-size:18px;line-height:1.5;max-width:50ch;color:#40423c}

/* continue collection */
.pd-more{padding-bottom:0}.pd-more-head{display:grid;grid-template-columns:.55fr 1.45fr;gap:80px;align-items:start}.pd-more-head h2{font-size:clamp(34px,4.8vw,62px);font-weight:500;letter-spacing:-.05em;line-height:1}.pd-more-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-top:46px}.pd-more-card{color:var(--ink);text-decoration:none}.pd-more-img{aspect-ratio:.9;position:relative;background-size:cover;background-position:center;display:grid;place-items:center;overflow:hidden}.pd-more-img::after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(0,0,0,.04),transparent 65%,rgba(0,0,0,.18))}.pd-more-index,.pd-more-open{position:absolute;z-index:2;color:#fff;font-family:'Spline Sans Mono',monospace;font-size:10px;text-shadow:0 1px 6px rgba(0,0,0,.35)}.pd-more-index{top:13px;left:13px}.pd-more-open{right:13px;bottom:13px;font-size:17px;transition:transform .25s var(--ease)}.pd-more-card:hover .pd-more-open{transform:translate(3px,-3px)}.pd-more-ph{font:600 48px 'Space Grotesk',sans-serif;color:#fff;position:relative;z-index:1}.pd-more-copy{display:flex;justify-content:space-between;gap:10px;padding-top:11px}.pd-more-copy span{font-size:13px;font-weight:600}.pd-more-copy strong{font:600 11px 'Space Grotesk',sans-serif;white-space:nowrap}

/* immersive gallery */
.pd-lightbox{position:fixed;inset:0;z-index:2200;background:rgba(10,12,14,.97);display:grid;place-items:center;padding:50px}.pd-lightbox img{max-width:min(88vw,1400px);max-height:88vh;object-fit:contain;box-shadow:0 22px 90px rgba(0,0,0,.34)}.pd-lightbox-close,.pd-lightbox-nav{position:absolute;border:1px solid rgba(255,255,255,.2);background:rgba(20,23,27,.4);color:#fff;width:44px;height:44px;display:grid;place-items:center;cursor:pointer;border-radius:0}.pd-lightbox-close{right:24px;top:24px}.pd-lightbox-nav{top:50%;transform:translateY(-50%)}.pd-lightbox-nav.prev{left:24px}.pd-lightbox-nav.next{right:24px}.pd-lightbox-count{position:absolute;bottom:24px;color:#fff;font:10px 'Spline Sans Mono',monospace;letter-spacing:.08em}

/* checkout / conversion — V8: progressively quieter as commitment increases */
.pd-order-overlay{background:rgba(15,18,21,.62);backdrop-filter:blur(12px);padding:22px}
.pd-order-sheet{position:relative;width:min(1120px,100%);max-height:94vh;overflow:auto;background:#f7f7f3;display:grid;grid-template-columns:.78fr 1.22fr;box-shadow:0 35px 110px rgba(0,0,0,.3)}
.pd-order-close{position:absolute;z-index:7;right:16px;top:16px;width:38px;height:38px;border:1px solid #cdcec6;background:#f7f7f3;display:grid;place-items:center;cursor:pointer;border-radius:0}.pd-order-close:disabled{opacity:.45;cursor:not-allowed}
.pd-order-summary{background:#171a1f;color:#f2f2ee;padding:30px;display:flex;flex-direction:column;min-height:660px}.pd-order-image{aspect-ratio:1.18;background-size:cover;background-position:center;margin-bottom:30px}.pd-order-summary-copy>span,.pd-order-kicker{display:block;font:9.5px 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.09em;color:#7e858a}.pd-order-summary-copy h3{color:#f2f2ee;font-size:32px;font-weight:500;margin:12px 0 8px;line-height:1.05}.pd-order-summary-copy strong{font:500 18px 'Space Grotesk',sans-serif}.pd-order-summary-copy p{font-size:12px;line-height:1.65;color:#92999e;margin-top:17px;max-width:38ch}.pd-order-side-facts{margin-top:28px;border-top:1px solid #343b41}.pd-order-side-facts>div{display:grid;grid-template-columns:90px 1fr;gap:12px;padding:11px 0;border-bottom:1px solid #343b41}.pd-order-side-facts span{font-size:8.5px;text-transform:uppercase;letter-spacing:.07em;color:#6f777d}.pd-order-side-facts strong{font-size:11px;color:#d9dcda;font-weight:600;text-align:right;overflow-wrap:anywhere}.pd-order-route-mini{display:grid;grid-template-columns:8px 1fr 8px 1fr 8px;align-items:center;row-gap:9px;margin-top:auto;padding-top:34px}.pd-order-route-mini>span{width:8px;height:8px;border:1px solid #596168;border-radius:50%}.pd-order-route-mini>span.on{background:#d8eee8;border-color:#d8eee8}.pd-order-route-mini>i{height:1px;background:#3c444a}.pd-order-route-mini>small{font-size:8.5px;color:#6f777d;text-transform:uppercase;letter-spacing:.06em;white-space:nowrap}.pd-order-route-mini>small:nth-of-type(1){grid-column:1/2}.pd-order-route-mini>small:nth-of-type(2){grid-column:3/4}.pd-order-route-mini>small:nth-of-type(3){grid-column:5/6;text-align:right}
.pd-order-flow{padding:44px 48px 30px;min-height:660px;display:flex;flex-direction:column}.pd-checkout-head{display:flex;align-items:flex-start;justify-content:space-between;gap:30px;padding-right:34px}.pd-order-kicker{color:#888980;margin-bottom:10px}.pd-checkout-head h3{font:500 clamp(30px,3.2vw,45px) 'Space Grotesk',sans-serif;letter-spacing:-.045em;line-height:1.02;max-width:12ch}.pd-checkout-count{font:9.5px 'Spline Sans Mono',monospace;color:#909188;letter-spacing:.08em;padding-top:3px}
.pd-stepper{display:grid;grid-template-columns:repeat(4,1fr);border-top:1px solid #d2d3cb;border-bottom:1px solid #d2d3cb;margin:30px 0 0}.pd-stepper button{border:0;border-right:1px solid #d2d3cb;background:transparent;text-align:left;padding:11px 9px 12px 0;cursor:pointer;color:#9a9b93}.pd-stepper button+button{padding-left:10px}.pd-stepper button:last-child{border-right:0}.pd-stepper button:disabled{cursor:default}.pd-stepper button span{display:block;font:8.5px 'Spline Sans Mono',monospace;margin-bottom:3px}.pd-stepper button strong{font-size:10px;text-transform:uppercase;letter-spacing:.06em}.pd-stepper button.on{color:var(--ink)}.pd-stepper button.done{color:#5f6964}.pd-stepper button.done span::after{content:'  ✓';font-family:Inter,sans-serif}
.pd-mobile-order-snapshot{display:none}.pd-step-stage{flex:1;padding:34px 0 22px}.pd-step-panel{animation:pdStepIn .28s var(--ease) both}.pd-step-intro{padding-bottom:24px;margin-bottom:20px;border-bottom:1px solid #ddded7}.pd-step-intro p{font-size:13px;line-height:1.7;color:#73756d;max-width:48ch}.pd-sheet-field{margin-bottom:21px}.pd-field-head{display:flex;justify-content:space-between;gap:14px;align-items:center;margin-bottom:9px}.pd-sheet-field label,.pd-quantity-control label{display:block;font-size:10px;text-transform:uppercase;letter-spacing:.07em;font-weight:700;color:#65675f}.pd-field-head>span{font:9px 'Spline Sans Mono',monospace;color:#898b82}.pd-sheet-field input,.pd-sheet-field textarea{width:100%;border:0;border-bottom:1px solid #bebfb7;background:transparent;border-radius:0;padding:12px 1px;font:500 15px 'Inter',sans-serif;color:var(--ink);box-shadow:none;resize:vertical}.pd-sheet-field textarea{min-height:92px;line-height:1.55}.pd-sheet-field input:focus,.pd-sheet-field textarea:focus{outline:none;border-bottom-color:var(--ink);box-shadow:none}.pd-field-note{display:block;margin-top:7px;font-size:10.5px;color:#8b8d84}.pd-sheet-options{display:flex;gap:7px;flex-wrap:wrap}.pd-sheet-options button{border:1px solid #c9cac2;background:transparent;padding:10px 13px;font:600 12px 'Inter',sans-serif;cursor:pointer;border-radius:0}.pd-sheet-options button.on{background:var(--ink);border-color:var(--ink);color:#fff}.pd-no-variants{display:grid;grid-template-columns:30px 1fr;gap:11px;padding:18px 0 25px;border-bottom:1px solid #dadbd3}.pd-no-variants-mark{width:26px;height:26px;display:grid;place-items:center;border:1px solid #bfc2b9;color:var(--accent-ink)}.pd-no-variants strong{display:block;font-size:12px;margin-bottom:3px}.pd-no-variants p{font-size:11.5px;color:#80827a;line-height:1.5}.pd-quantity-control{display:flex;justify-content:space-between;align-items:end;gap:20px;margin-top:25px;padding-top:19px;border-top:1px solid #dadbd3}.pd-quantity-control small{display:block;margin-top:5px;font-size:10px;color:#8a8c83}.pd-qty-stepper{display:grid;grid-template-columns:38px 56px 38px;height:40px;border:1px solid #c7c8c0}.pd-qty-stepper button{border:0;background:transparent;font-size:18px;cursor:pointer;color:#53564f}.pd-qty-stepper input{min-width:0;width:56px;border:0;border-left:1px solid #d3d4cc;border-right:1px solid #d3d4cc;background:transparent;text-align:center;font:600 13px 'Space Grotesk',sans-serif;-moz-appearance:textfield}.pd-qty-stepper input::-webkit-inner-spin-button,.pd-qty-stepper input::-webkit-outer-spin-button{-webkit-appearance:none;margin:0}.pd-destination-route{display:grid;grid-template-columns:minmax(0,1fr) 70px minmax(0,1fr);align-items:start;margin-top:34px}.pd-destination-route>div{display:grid;grid-template-columns:11px 1fr;column-gap:9px;align-items:start}.pd-destination-route>div span{width:8px;height:8px;border-radius:50%;background:var(--ink);margin-top:4px}.pd-destination-route strong{font-size:11px;line-height:1.35;overflow-wrap:anywhere}.pd-destination-route small{grid-column:2;font-size:9px;text-transform:uppercase;letter-spacing:.06em;color:#93958d;margin-top:3px}.pd-destination-route>i{height:1px;background:#c9cac2;margin-top:8px}
.pd-confirm-panel{border-top:1px solid #d5d6ce}.pd-confirm-row{display:grid;grid-template-columns:115px 1fr;gap:18px;width:100%;padding:13px 0;border:0;border-bottom:1px solid #d5d6ce;background:transparent;text-align:left;color:var(--ink)}.pd-confirm-row>span{font-size:9.5px;text-transform:uppercase;letter-spacing:.06em;color:#85877e}.pd-confirm-row>strong{font-size:12px;line-height:1.45;font-weight:650;overflow-wrap:anywhere}.pd-confirm-edit{grid-template-columns:115px 1fr auto;cursor:pointer}.pd-confirm-edit em{font-style:normal;font-size:9px;text-transform:uppercase;letter-spacing:.06em;color:#73766e;border-bottom:1px solid #73766e;padding-bottom:2px}.pd-payment-contract{display:grid;grid-template-columns:36px 1fr;gap:12px;margin-top:28px;padding:18px;background:#eeeeE8}.pd-payment-mark{width:32px;height:32px;display:grid;place-items:center;border:1px solid #c5c7be;color:var(--accent-ink)}.pd-payment-contract span{display:block;font-size:9px;text-transform:uppercase;letter-spacing:.07em;color:#85877e}.pd-payment-contract strong{display:block;font-size:13px;margin:3px 0}.pd-payment-contract p{font-size:11px;line-height:1.55;color:#76786f;max-width:44ch}.pd-final-total{display:flex;justify-content:space-between;align-items:baseline;padding:20px 0 0}.pd-final-total span{font-size:10px;text-transform:uppercase;letter-spacing:.07em;color:#777970}.pd-final-total strong{font:600 20px 'Space Grotesk',sans-serif}
.pd-checkout-error{display:flex;align-items:flex-start;gap:9px;padding:10px 12px;border-top:1px solid #b86a5e;border-bottom:1px solid #b86a5e;color:#8d463b;font-size:11px;line-height:1.45;margin-bottom:14px}.pd-checkout-error span{display:grid;place-items:center;width:16px;height:16px;border:1px solid currentColor;border-radius:50%;font-size:9px;flex:0 0 auto}.pd-checkout-actions{display:flex;align-items:center;justify-content:space-between;gap:18px;border-top:1px solid #d0d1c9;padding-top:17px}.pd-checkout-back{border:0;background:transparent;padding:10px 0;font-size:11px;font-weight:650;color:#6b6e66;cursor:pointer}.pd-checkout-security{display:flex;align-items:center;gap:6px;font-size:10px;color:#85877e}.pd-checkout-next{min-width:220px;min-height:52px;background:var(--ink);color:#fff;border:0;padding:0 15px;display:flex;align-items:center;justify-content:space-between;gap:28px;font:650 12px 'Inter',sans-serif;cursor:pointer;border-radius:0}.pd-checkout-next>span:last-child{font:9px 'Spline Sans Mono',monospace;text-transform:uppercase;color:#c5c8c7}.pd-checkout-next:disabled{opacity:.55;cursor:not-allowed}.pd-place-order{min-width:250px}
.pd-success{grid-column:1/-1;min-height:650px;padding:70px 80px;display:flex;flex-direction:column;align-items:flex-start;justify-content:center;max-width:820px;margin:auto}.pd-success-mark{width:46px;height:46px;border:1px solid #bfc1b8;display:grid;place-items:center;color:var(--accent-ink);margin-bottom:32px}.pd-success-kicker{font:10px 'Spline Sans Mono',monospace;text-transform:uppercase;letter-spacing:.09em;color:#81837b}.pd-success h3{font-size:clamp(42px,6vw,74px);font-weight:500;letter-spacing:-.055em;line-height:.92;margin:14px 0 20px}.pd-success>p{font-size:14px;line-height:1.75;color:#676960;max-width:55ch}.pd-success-journey{width:100%;display:grid;grid-template-columns:auto minmax(40px,1fr) auto minmax(40px,1fr) auto;align-items:start;margin:36px 0 24px}.pd-success-journey>div{display:grid;grid-template-rows:auto auto auto;gap:3px}.pd-success-journey>div>span{width:9px;height:9px;border:1px solid #9c9f96;border-radius:50%;margin-bottom:6px}.pd-success-journey>div.on>span{background:var(--ink);border-color:var(--ink)}.pd-success-journey strong{font-size:11px}.pd-success-journey small{font-size:9px;text-transform:uppercase;letter-spacing:.05em;color:#95978e}.pd-success-journey>i{height:1px;background:#cdd0c7;margin-top:4px}.pd-success-code{width:100%;display:flex;justify-content:space-between;align-items:center;border-top:1px solid #d1d2ca;border-bottom:1px solid #d1d2ca;padding:17px 0;margin:8px 0 26px}.pd-success-code span{font-size:10px;text-transform:uppercase;letter-spacing:.07em;color:#7b7d74}.pd-success-code strong{font-size:14px}.pd-success-track{background:var(--ink);color:#fff;min-width:290px;padding:17px 18px;display:flex;justify-content:space-between;gap:30px;font-size:12px;font-weight:700;text-decoration:none}.pd-success-close{margin-top:14px;border:0;background:transparent;padding:8px 0;font-size:10.5px;font-weight:650;color:#75786f;cursor:pointer;border-bottom:1px solid #9b9d95}
@keyframes pdStepIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
@media(max-width:980px){
  .pd-object{padding-left:24px;padding-right:24px}.pd-object-grid{grid-template-columns:1fr;gap:42px}.pd-info{position:static;max-width:680px}.pd-name{max-width:14ch}.pd-movement{padding-left:24px;padding-right:24px}.pd-movement-head{grid-template-columns:1fr;gap:24px;margin-bottom:56px}.pd-provenance,.pd-reviews-section,.pd-more{padding-left:24px;padding-right:24px}.pd-provenance-grid{grid-template-columns:1fr;gap:48px}.pd-order-sheet{grid-template-columns:1fr}.pd-order-summary{min-height:auto}.pd-order-route-mini{margin-top:34px}.pd-order-form{padding:38px 30px}
}

@media(max-width:720px){
  .pd-page{padding-bottom:80px}.pd-object{padding:18px 16px 72px}.pd-object-top{margin-bottom:19px}.pd-index{display:none}.pd-object-grid{gap:32px}.pd-main{aspect-ratio:.94}.pd-status{top:10px;left:10px}.pd-image-index,.pd-image-open{bottom:11px}.pd-image-index{left:11px}.pd-image-open{right:11px}.pd-thumbs{grid-template-columns:repeat(4,1fr)}.pd-name{font-size:clamp(38px,13vw,58px);margin:24px 0 22px}.pd-desc{font-size:14px;line-height:1.7}.pd-actions{grid-template-columns:1fr 52px}.pd-buy{min-height:54px}.pd-share{width:52px}.pd-movement{padding:74px 16px 70px}.pd-movement-head{margin:32px 0 50px}.pd-movement-head h2{font-size:clamp(39px,13vw,60px)}.pd-route{grid-template-columns:1fr;gap:0;margin-bottom:48px}.pd-route-node{grid-template-columns:22px 1fr;grid-template-rows:auto auto;min-width:0;padding:0 0 28px}.pd-route-node .pd-route-dot{grid-row:1/3;margin:4px 0 0}.pd-route-node strong{grid-column:2}.pd-route-node small{grid-column:2}.pd-route-line{width:1px;height:32px;margin:-25px 0 4px 4px;background:#3a4147}.pd-route-line span{width:1px;height:70%;background:#91aaa3}.pd-confidence-ledger{grid-template-columns:1fr}.pd-ledger-stat,.pd-ledger-stat:nth-child(2),.pd-ledger-stat:last-child{border-right:0;border-bottom:1px solid #343b41;padding:18px 0;min-height:0}.pd-ledger-stat:last-child{border-bottom:0}.pd-provenance,.pd-reviews-section,.pd-more{padding:74px 16px 0}.pd-provenance-grid,.pd-reviews-grid{margin-top:31px;padding-top:26px}.pd-maker-lockup{align-items:flex-start}.pd-maker-story>p{font-size:22px}.pd-maker-facts>div{grid-template-columns:120px 1fr}.pd-reviews-grid{grid-template-columns:1fr;gap:35px}.pd-more-head{grid-template-columns:1fr;gap:24px}.pd-more-grid{grid-template-columns:1fr 1fr;gap:7px}.pd-more-copy{display:block}.pd-more-copy span,.pd-more-copy strong{display:block}.pd-more-copy strong{margin-top:3px;color:#6f7169}.pd-lightbox{padding:42px 12px}.pd-lightbox-nav{width:38px;height:38px}.pd-lightbox-nav.prev{left:8px}.pd-lightbox-nav.next{right:8px}.pd-lightbox-close{right:9px;top:9px}.pd-order-overlay{padding:0;align-items:flex-end}.pd-order-sheet{width:100%;max-height:96vh}.pd-order-summary{padding:22px;display:none}.pd-order-form{padding:52px 20px 24px}.pd-sheet-row{grid-template-columns:1fr 90px;gap:14px}.pd-success{padding:60px 24px;min-height:70vh}.pd-success h3{font-size:52px}.pd-success-track{width:100%}
}

@media(max-width:430px){.pd-more-grid{grid-template-columns:1fr}.pd-thumbs{grid-template-columns:repeat(3,1fr)}}

@media(max-width:980px){
  .pd-order-sheet{grid-template-columns:1fr}.pd-order-summary{display:none}.pd-order-flow{min-height:640px;padding:44px 34px 28px}.pd-mobile-order-snapshot{display:flex;justify-content:space-between;gap:18px;align-items:center;padding:13px 0;border-bottom:1px solid #d7d8d0}.pd-mobile-order-snapshot span{display:block;font-size:12px;font-weight:650}.pd-mobile-order-snapshot small{display:block;font-size:9.5px;color:#888a82;margin-top:2px}.pd-mobile-order-snapshot strong{font:600 13px 'Space Grotesk',sans-serif;white-space:nowrap}
}
@media(max-width:720px){
  .pd-order-overlay{padding:0;align-items:flex-end}.pd-order-sheet{width:100%;max-height:100dvh;min-height:min(92dvh,760px);box-shadow:none}.pd-order-flow{min-height:min(92dvh,760px);padding:46px 18px 18px}.pd-order-close{right:10px;top:10px}.pd-checkout-head{padding-right:34px}.pd-checkout-head h3{font-size:34px}.pd-stepper{margin-top:22px}.pd-stepper button{padding:9px 4px}.pd-stepper button+button{padding-left:7px}.pd-stepper button span{font-size:7.5px}.pd-stepper button strong{font-size:8.5px}.pd-step-stage{padding:26px 0 18px}.pd-sheet-options button{padding:10px 12px}.pd-destination-route{grid-template-columns:1fr;gap:12px}.pd-destination-route>i{width:1px;height:24px;margin:0 0 0 4px}.pd-confirm-row{grid-template-columns:92px 1fr}.pd-confirm-edit{grid-template-columns:92px 1fr auto}.pd-checkout-actions{position:sticky;bottom:-18px;background:#f7f7f3;padding:14px 0 18px;z-index:4}.pd-checkout-next{min-width:178px;min-height:52px}.pd-place-order{min-width:190px}.pd-success{padding:54px 22px;min-height:92dvh}.pd-success h3{font-size:50px}.pd-success-track{width:100%;min-width:0}.pd-success-journey{grid-template-columns:auto 1fr auto 1fr auto}
}
@media(max-width:430px){
  .pd-checkout-security{font-size:0}.pd-checkout-security svg{display:block}.pd-checkout-next{min-width:166px}.pd-confirm-row,.pd-confirm-edit{grid-template-columns:82px 1fr}.pd-confirm-edit em{grid-column:2;margin-top:4px;justify-self:start}.pd-payment-contract{padding:14px}.pd-success-code{align-items:flex-start;gap:14px;flex-direction:column}
}
@media(prefers-reduced-motion:reduce){.pd-main,.pd-maker-mini-arrow,.pd-more-open,.pd-text-link span{transition:none!important}.pd-step-panel{animation:none!important}}

/* PHASE 9 — OBJECT + CHECKOUT / thumb-reachable, edge-to-edge, thumb-safe */
@media(max-width:720px){
  .pd-gallery-frame{margin-left:-16px;margin-right:-16px}
  .pd-main{aspect-ratio:1/1.08}
  .pd-thumbs{overflow-x:auto;grid-template-columns:none!important;display:flex;scroll-snap-type:x proximity;scrollbar-width:none;padding-bottom:5px}
  .pd-thumbs::-webkit-scrollbar{display:none}.pd-thumb{flex:0 0 74px;scroll-snap-align:start}
  .pd-actions{position:sticky;bottom:calc(8px + env(safe-area-inset-bottom));z-index:18;background:rgba(247,247,243,.88);backdrop-filter:blur(16px);padding:7px;margin:18px -7px 0;box-shadow:0 12px 34px rgba(20,24,31,.12)}
  .pd-buy{min-height:56px}.pd-share{min-height:56px}
  .pd-sheet-field input,.pd-sheet-field textarea{font-size:16px}
  .pd-order-sheet{border-radius:18px 18px 0 0;overflow:hidden;overscroll-behavior:contain}
  .pd-order-flow{max-height:100dvh;overflow-y:auto;padding-bottom:0}
  .pd-checkout-actions{bottom:0;margin-top:auto;padding:14px 0 calc(14px + env(safe-area-inset-bottom));background:linear-gradient(to top,#f7f7f3 78%,rgba(247,247,243,.92))}
  .pd-checkout-next,.pd-place-order{min-height:54px}
  .pd-lightbox{padding-top:calc(58px + env(safe-area-inset-top));padding-bottom:calc(66px + env(safe-area-inset-bottom))}
}
@media(max-width:430px){
  .pd-object{padding-left:14px;padding-right:14px}.pd-gallery-frame{margin-left:-14px;margin-right:-14px}
  .pd-name{font-size:42px;line-height:.94}
  .pd-maker-facts>div{grid-template-columns:100px 1fr}
  .pd-more-grid{grid-template-columns:1fr 1fr;gap:8px}
  .pd-more-copy span{font-size:10.5px}.pd-more-copy strong{font-size:10.5px}
  .pd-order-flow{padding-left:16px;padding-right:16px}.pd-checkout-head h3{font-size:31px}
  .pd-stepper{overflow-x:auto;scrollbar-width:none}.pd-stepper::-webkit-scrollbar{display:none}.pd-stepper button{min-width:72px;flex:1 0 72px}
  .pd-checkout-actions{gap:10px}.pd-checkout-next,.pd-place-order{min-width:0;flex:1}
}
</style>
