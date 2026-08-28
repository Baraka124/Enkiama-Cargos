<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import AppHeader from '../components/AppHeader.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'

const route = useRoute()
const router = useRouter()
async function startDeal() {
  try {
    const { data: sess } = await supabase.auth.getSession()
    if (!sess?.session) { router.push('/login'); return }
    const name = sess.session.user?.user_metadata?.name || ''
    const { data: res } = await supabase.rpc('start_property_deal', {
      p_listing_id: listing.value.id, p_buyer_name: name, p_buyer_phone: '', p_note: null })
    if (res?.ok) router.push(`/property-deal/${res.id}`)
  } catch (e) {}
}
const listing = ref(null)
const loading = ref(true)
const activeImg = ref(0)
const showContact = ref(false)

async function load() {
  loading.value = true
  try {
    const { data } = await supabase.rpc('property_detail', { p_id: route.params.id })
    listing.value = data
  } catch (e) { listing.value = null }
  loading.value = false
}
const imgs = computed(() => (listing.value?.images || []).filter(Boolean))
function fmtPrice(l) {
  if (!l?.price_tzs) return 'Price on request'
  const b = l.price_basis === 'per_acre' ? ' /acre' : l.price_basis === 'per_month' ? ' /month' : ''
  return 'TZS ' + Number(l.price_tzs).toLocaleString() + b
}
const kindLabel = computed(() => ({ plot:'Land plot', farm:'Farm', house:'House / building', rental:'Rental' }[listing.value?.kind] || listing.value?.kind))
const basisLabel = computed(() => ({ total:'Total price', per_acre:'Per acre', per_month:'Per month', per_sqm:'Per m²' }[listing.value?.price_basis] || 'Total price'))
function tzs(n) { return n ? 'TZS ' + Math.round(Number(n)).toLocaleString() : '' }
const depositAmount = computed(() => {
  const l = listing.value
  if (!l?.installments_ok || !l.deposit_pct || !l.price_tzs) return 0
  return Math.round(l.price_tzs * l.deposit_pct / 100)
})
const monthlyAmount = computed(() => {
  const l = listing.value
  if (!l?.installments_ok || !l.installment_months || !l.price_tzs) return 0
  const remaining = l.price_tzs - depositAmount.value
  return Math.round(remaining / l.installment_months)
})
onMounted(load)
</script>

<template>
  <AppHeader title="Enkiama Property" subtitle="Land & property" />

  <div v-if="loading" class="pd-load"><Spinner :size="26" /></div>
  <div v-else-if="!listing" class="wrap" style="padding-top:40px">
    <div class="pd-missing"><Icon name="pin" :size="34" /><h2>Listing not found</h2><p>It may have been removed or is awaiting verification.</p>
      <RouterLink to="/property" class="btn btn-accent">Back to properties</RouterLink></div>
  </div>

  <div v-else class="wrap pd-wrap">
    <RouterLink to="/property" class="pd-back"><Icon name="arrow" :size="14" style="transform:rotate(180deg)" /> All properties</RouterLink>

    <div class="pd-grid">
      <!-- LEFT: gallery + detail -->
      <div class="pd-main">
        <div class="pd-gallery">
          <div class="pd-hero-img" :style="imgs[activeImg] ? {backgroundImage:`url(${imgs[activeImg]})`} : {}">
            <span v-if="!imgs.length" class="pd-noimg"><Icon name="pin" :size="40" /></span>
            <span class="pd-kind">{{ kindLabel }}</span>
            <span v-if="listing.status==='verified'" class="pd-verified"><Icon name="shield" :size="12" /> Verified by Enkiama</span>
            <span v-else class="pd-pending">Awaiting verification</span>
          </div>
          <div v-if="imgs.length > 1" class="pd-thumbs">
            <button v-for="(im,i) in imgs" :key="i" class="pd-thumb" :class="{on:i===activeImg}" :style="{backgroundImage:`url(${im})`}" @click="activeImg=i"></button>
          </div>
        </div>

        <h1 class="pd-title">{{ listing.title }}</h1>
        <div class="pd-loc"><Icon name="pin" :size="14" /> {{ listing.location }}<template v-if="listing.region">, {{ listing.region }}</template></div>

        <!-- key facts: the scannable decision-grid a land buyer needs -->
        <div class="pd-facts">
          <div class="pd-fact"><Icon name="pin" :size="15" /><div><span class="pd-fact-l">Type</span><span class="pd-fact-v">{{ kindLabel }}</span></div></div>
          <div v-if="listing.size_value" class="pd-fact"><Icon name="package" :size="15" /><div><span class="pd-fact-l">Size</span><span class="pd-fact-v">{{ listing.size_value }} {{ listing.size_unit }}</span></div></div>
          <div class="pd-fact"><Icon name="star" :size="15" /><div><span class="pd-fact-l">Price basis</span><span class="pd-fact-v">{{ basisLabel }}</span></div></div>
          <div v-if="listing.region" class="pd-fact"><Icon name="globe" :size="15" /><div><span class="pd-fact-l">Region</span><span class="pd-fact-v">{{ listing.region }}</span></div></div>
        </div>

        <!-- what's on the land: services & utilities as scannable tags, not paragraphs -->
        <div class="pd-amenities">
          <span class="pd-am" :class="listing.has_electricity ? 'yes':'no'"><Icon :name="listing.has_electricity?'check':'x'" :size="13" /> Electricity</span>
          <span class="pd-am" :class="listing.has_water ? 'yes':'no'"><Icon :name="listing.has_water?'check':'x'" :size="13" /> Water{{ listing.has_water && listing.water_potable ? ' · potable' : '' }}</span>
          <span class="pd-am" :class="listing.ownership_declared ? 'yes':'no'"><Icon :name="listing.ownership_declared?'check':'x'" :size="13" /> Ownership declared</span>
          <span class="pd-am" :class="listing.status==='verified' ? 'yes':'pending'"><Icon name="shield" :size="13" /> {{ listing.status==='verified' ? 'Enkiama-verified' : 'Awaiting verification' }}</span>
          <span v-if="listing.fair_price_ok" class="pd-am yes"><Icon name="check" :size="13" /> Fair price reviewed</span>
        </div>

        <!-- title / lister clarity — critical for a land purchase -->
        <div class="pd-titlebox">
          <div class="pd-titlebox-row"><span class="pd-tb-l">Listed by</span><span class="pd-tb-v">{{ listing.lister_role==='representative' ? 'Representative on behalf of owner' : 'The owner' }}</span></div>
          <div v-if="listing.lister_role==='representative' && listing.owner_name" class="pd-titlebox-row"><span class="pd-tb-l">Legal owner</span><span class="pd-tb-v">{{ listing.owner_name }}<template v-if="listing.owner_relation"> · {{ listing.owner_relation }}</template></span></div>
        </div>

        <div v-if="listing.description" class="pd-block"><h3>About this property</h3><p>{{ listing.description }}</p></div>
        <div v-if="listing.neighbours" class="pd-block"><h3>Neighbouring area</h3><p>{{ listing.neighbours }}</p></div>
        <div v-if="listing.services_5km" class="pd-block"><h3>Social services within 5&nbsp;km</h3><p>{{ listing.services_5km }}</p></div>

        <div class="pd-disclaimer">
          <Icon name="shield" :size="16" />
          <div>
            <b>Verified listing — but always do your own due diligence.</b>
            <span>Enkiama reviews every listing before publishing. Final purchase remains subject to your own legal verification of title and ownership.
            <template v-if="listing.lister_role==='representative'"> This property is listed by a representative — the final sale and all signatures must come from the legal owner{{ listing.owner_name ? ' (' + listing.owner_name + ')' : '' }}.</template></span>
          </div>
        </div>
      </div>

      <!-- RIGHT: price + enquiry -->
      <div class="pd-side">
        <div class="pd-price-card">
          <div class="pd-price-top">
            <div class="pd-price">{{ fmtPrice(listing) }}</div>
            <span v-if="listing.price_negotiable" class="pd-negot">Negotiable</span>
          </div>
          <div v-if="listing.fair_price_ok" class="pd-fair"><Icon name="check" :size="12" /> Fair price · reviewed by Enkiama</div>

          <!-- installment plan — the barrier-remover -->
          <div v-if="listing.installments_ok" class="pd-plan">
            <div class="pd-plan-head"><Icon name="star" :size="14" /> Payment plan available</div>
            <div class="pd-plan-grid">
              <div v-if="depositAmount" class="pd-plan-item"><span class="pd-plan-l">Deposit</span><span class="pd-plan-v">{{ tzs(depositAmount) }}<small>{{ listing.deposit_pct }}%</small></span></div>
              <div v-if="monthlyAmount" class="pd-plan-item"><span class="pd-plan-l">Then monthly</span><span class="pd-plan-v">{{ tzs(monthlyAmount) }}<small>× {{ listing.installment_months }}</small></span></div>
            </div>
            <div class="pd-plan-note">Terms agreed directly with the seller. Enkiama can hold your deposit in escrow while title is verified.</div>
          </div>

          <button class="btn btn-accent btn-block btn-lg" @click="showContact=true"><Icon name="phone" :size="15" /> Enquire about this property</button>
          <button class="btn btn-ghost btn-block deal-start-btn" @click="startDeal"><Icon name="shield" :size="15" /> Start a protected purchase</button>
          <div v-if="showContact" class="pd-contact">
            <div class="pd-contact-h">Contact for enquiries</div>
            <a v-if="listing.contact_phone" :href="`tel:${listing.contact_phone}`" class="pd-contact-row"><Icon name="phone" :size="14" /> {{ listing.contact_phone }}</a>
            <div v-if="listing.lister_role==='representative'" class="pd-rep-note">
              Listed by a representative ({{ listing.owner_relation }}). Legal owner: <b>{{ listing.owner_name }}</b>.
            </div>
            <p class="pd-contact-warn">Never pay in full before verifying title and meeting the legal owner.</p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.pd-load{display:flex;justify-content:center;padding:80px}
.pd-missing{text-align:center;padding:60px 20px;color:var(--ink-faint)}
.pd-missing svg{color:var(--ink-ghost)}
.pd-missing h2{font-family:'Space Grotesk',sans-serif;font-size:20px;color:var(--ink);margin:14px 0 6px}
.pd-missing p{margin-bottom:18px}
.pd-wrap{padding-top:20px;padding-bottom:60px}
.pd-back{display:inline-flex;align-items:center;gap:6px;font-size:13px;font-weight:600;color:var(--ink-faint);text-decoration:none;margin-bottom:18px}
.pd-back:hover{color:var(--accent-ink)}
.pd-grid{display:grid;grid-template-columns:1fr 340px;gap:28px;align-items:start}
.pd-gallery{margin-bottom:20px}
.pd-hero-img{position:relative;height:360px;border-radius:16px;background:linear-gradient(135deg,var(--accent),var(--accent-ink));background-size:cover;background-position:center;display:flex;align-items:center;justify-content:center;color:rgba(255,255,255,.6);overflow:hidden}
.pd-kind{position:absolute;top:14px;left:14px;background:rgba(20,24,31,.8);color:#fff;font-size:12.5px;font-weight:600;padding:5px 12px;border-radius:8px;backdrop-filter:blur(4px)}
.pd-verified{position:absolute;top:14px;right:14px;display:inline-flex;align-items:center;gap:4px;background:var(--go);color:#fff;font-size:11px;font-weight:700;padding:5px 11px;border-radius:8px}
.pd-pending{position:absolute;top:14px;right:14px;background:var(--warn);color:#fff;font-size:11px;font-weight:700;padding:5px 11px;border-radius:8px}
.pd-thumbs{display:flex;gap:8px;margin-top:10px}
.pd-thumb{width:72px;height:56px;border-radius:10px;background-size:cover;background-position:center;border:2px solid transparent;cursor:pointer;opacity:.65;transition:.15s}
.pd-thumb.on{border-color:var(--accent);opacity:1}
.pd-title{font-family:'Space Grotesk',sans-serif;font-size:24px;font-weight:700;letter-spacing:-.025em;color:var(--ink);margin-bottom:6px}
.pd-loc{display:flex;align-items:center;gap:5px;font-size:14px;color:var(--ink-faint);margin-bottom:20px}
.pd-specs{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:12px;margin-bottom:26px;padding:16px;background:var(--surface-2);border-radius:12px}
.pd-spec{display:flex;flex-direction:column;gap:3px}
.pd-spec-l{font-size:11px;text-transform:uppercase;letter-spacing:.04em;color:var(--ink-faint);font-weight:600}
.pd-spec-v{font-size:14px;font-weight:650;color:var(--ink)}
.pd-spec-v.go{color:var(--go-ink)}
.pd-block{margin-bottom:22px}
.pd-block h3{font-family:'Space Grotesk',sans-serif;font-size:16px;font-weight:700;color:var(--ink);letter-spacing:-.01em;margin-bottom:9px}
.pd-block p{font-size:14px;line-height:1.6;color:var(--ink-soft)}
.pd-disclaimer{display:flex;gap:12px;padding:16px;background:var(--accent-soft);border-radius:12px;margin-top:6px}
.pd-disclaimer svg{color:var(--accent-ink);flex-shrink:0;margin-top:2px}
.pd-disclaimer b{display:block;font-size:13px;color:var(--accent-ink);margin-bottom:4px}
.pd-disclaimer span{font-size:12.5px;line-height:1.55;color:var(--ink-soft)}
.pd-side{position:sticky;top:80px}
.pd-price-card{background:var(--surface);border:1px solid var(--hairline-2);border-radius:16px;padding:22px;box-shadow:var(--shadow-md)}
.pd-price{font-family:'Space Grotesk',sans-serif;font-size:24px;font-weight:700;letter-spacing:-.02em;color:var(--ink);margin-bottom:6px}
.pd-fair{display:inline-flex;align-items:center;gap:4px;font-size:12.5px;font-weight:600;color:var(--go-ink);background:var(--go-soft);padding:4px 10px;border-radius:999px;margin-bottom:16px}
.pd-contact{margin-top:16px;padding-top:16px;border-top:1px solid var(--hairline)}
.pd-contact-h{font-size:12.5px;text-transform:uppercase;letter-spacing:.04em;color:var(--ink-faint);font-weight:600;margin-bottom:10px}
.pd-contact-row{display:flex;align-items:center;gap:8px;font-size:15px;font-weight:650;color:var(--accent-ink);text-decoration:none;padding:10px;background:var(--accent-soft);border-radius:10px;margin-bottom:10px}
.pd-rep-note{font-size:12.5px;color:var(--ink-soft);background:var(--surface-2);padding:10px;border-radius:10px;margin-bottom:10px;line-height:1.5}
.pd-contact-warn{font-size:12.5px;color:var(--owed-ink);line-height:1.5}
@media(max-width:820px){.pd-grid{grid-template-columns:1fr}.pd-side{position:static}}

.pd-facts{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin-bottom:16px}
.pd-fact{display:flex;align-items:center;gap:10px;padding:13px 14px;background:var(--surface-2);border-radius:12px}
.pd-fact svg{color:var(--accent-ink);flex-shrink:0}
.pd-fact-l{display:block;font-size:10.5px;text-transform:uppercase;letter-spacing:.04em;color:var(--ink-faint);font-weight:600}
.pd-fact-v{display:block;font-size:14px;font-weight:700;color:var(--ink);margin-top:1px}
.pd-amenities{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:16px}
.pd-am{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;font-weight:600;padding:7px 12px;border-radius:999px}
.pd-am.yes{background:var(--go-soft);color:var(--go-ink)}
.pd-am.no{background:var(--surface-3);color:var(--ink-faint)}
.pd-am.pending{background:var(--warn-soft);color:var(--warn-ink)}
.pd-titlebox{background:var(--surface-2);border:1px solid var(--hairline);border-radius:12px;padding:14px 16px;margin-bottom:24px}
.pd-titlebox-row{display:flex;justify-content:space-between;gap:12px;padding:5px 0}
.pd-tb-l{font-size:13px;color:var(--ink-faint);font-weight:600}
.pd-tb-v{font-size:13.5px;color:var(--ink);font-weight:650;text-align:right}

.pd-price-top{display:flex;align-items:center;justify-content:space-between;gap:10px}
.pd-negot{font-size:11px;font-weight:700;color:var(--accent-ink);background:var(--accent-soft);padding:4px 10px;border-radius:999px;white-space:nowrap}
.pd-plan{margin:16px 0;border-radius:14px;padding:16px;background:linear-gradient(145deg,var(--accent-soft),var(--go-soft));border:1px solid var(--accent)}
.pd-plan-head{display:flex;align-items:center;gap:7px;font-size:13px;font-weight:700;color:var(--accent-ink);margin-bottom:12px}
.pd-plan-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.pd-plan-item{background:var(--surface);border-radius:11px;padding:11px 13px}
.pd-plan-l{display:block;font-size:11px;text-transform:uppercase;letter-spacing:.03em;color:var(--ink-faint);font-weight:600;margin-bottom:3px}
.pd-plan-v{display:block;font-family:'Space Grotesk',sans-serif;font-size:16px;font-weight:700;color:var(--ink);letter-spacing:-.01em}
.pd-plan-v small{font-size:11px;font-weight:600;color:var(--ink-faint);margin-left:5px}
.pd-plan-note{font-size:11.5px;line-height:1.5;color:var(--ink-soft);margin-top:11px}
</style>
