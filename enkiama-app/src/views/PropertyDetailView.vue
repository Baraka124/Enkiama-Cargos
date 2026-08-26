<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import AppHeader from '../components/AppHeader.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'

const route = useRoute()
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

        <div class="pd-specs">
          <div v-if="listing.size_value" class="pd-spec"><span class="pd-spec-l">Size</span><span class="pd-spec-v">{{ listing.size_value }} {{ listing.size_unit }}</span></div>
          <div class="pd-spec"><span class="pd-spec-l">Electricity</span><span class="pd-spec-v">{{ listing.has_electricity ? 'Available' : 'Not available' }}</span></div>
          <div class="pd-spec"><span class="pd-spec-l">Water</span><span class="pd-spec-v">{{ listing.has_water ? (listing.water_potable ? 'Available · potable' : 'Available') : 'Not available' }}</span></div>
          <div v-if="listing.fair_price_ok" class="pd-spec"><span class="pd-spec-l">Pricing</span><span class="pd-spec-v go">Reviewed · fair</span></div>
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
          <div class="pd-price">{{ fmtPrice(listing) }}</div>
          <div v-if="listing.fair_price_ok" class="pd-fair"><Icon name="check" :size="12" /> Fair price · reviewed by Enkiama</div>
          <button class="btn btn-accent btn-block btn-lg" @click="showContact=true"><Icon name="phone" :size="15" /> Enquire about this property</button>
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
.pd-block h3{font-family:'Space Grotesk',sans-serif;font-size:15px;font-weight:700;color:var(--ink);margin-bottom:7px}
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
</style>
