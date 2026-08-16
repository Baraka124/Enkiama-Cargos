<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'
import Icon from '../components/Icon.vue'
import BrandMark from '../components/BrandMark.vue'
import EmptyState from '../components/EmptyState.vue'

const stores = ref([])
const loading = ref(true)
const corridor = ref('')
const corridors = ['Mbeya', 'Arusha', 'Mwanza', 'Dodoma', 'Dar es Salaam']

async function load() {
  loading.value = true
  const { data } = await supabase.rpc('browse_storefronts', { p_corridor: corridor.value || null })
  stores.value = data || []
  loading.value = false
}
function filterCorridor(c) { corridor.value = corridor.value === c ? '' : c; load() }
onMounted(load)
</script>

<template>
  <div class="mk">
    <header class="mk-head">
      <RouterLink to="/" class="mk-logo"><BrandMark variant="full" :height="34" /></RouterLink>
      <RouterLink to="/login" class="btn btn-ghost">Sign in</RouterLink>
    </header>

    <section class="mk-hero">
      <h1 class="mk-h1">Shops that <span class="grad">deliver</span>, tracked.</h1>
      <p class="mk-sub">Discover businesses across Tanzania — every order shipped with end-to-end tracked delivery through Enkiama Cargos carriers.</p>
      <div class="mk-corridors">
        <span class="mk-corr-lab">Delivers to:</span>
        <button v-for="c in corridors" :key="c" class="mk-corr" :class="{on:corridor===c}" @click="filterCorridor(c)">{{ c }}</button>
      </div>
    </section>

    <div v-if="loading" class="mk-grid">
      <div v-for="i in 3" :key="i" class="mk-card sk"></div>
    </div>
    <EmptyState v-else-if="!stores.length" icon="search" title="No shops here yet" :hint="corridor ? `No storefronts delivering to ${corridor} yet.` : 'Be the first business on the marketplace.'" />
    <div v-else class="mk-grid">
      <RouterLink v-for="s in stores" :key="s.id" :to="`/shop/${s.slug}`" class="mk-card" :style="{'--sf': s.accent}">
        <div class="mk-card-top">
          <div class="mk-avatar" :style="{background:s.accent}">{{ s.name.slice(0,2).toUpperCase() }}</div>
          <div style="flex:1;min-width:0">
            <div class="mk-name">{{ s.name }}
              <span v-if="s.featured" class="mk-badge feat"><Icon name="star" :size="11" /> Featured</span>
            </div>
            <div class="mk-tag">{{ s.tagline }}</div>
          </div>
        </div>
        <div class="mk-meta">
          <span v-if="s.verified_delivery" class="mk-verified"><Icon name="check" :size="13" /> Verified delivery</span>
          <span v-if="s.avg_rating" class="mk-rating"><Icon name="star" :size="13" /> {{ s.avg_rating }} <span class="mk-rc">({{ s.review_count }})</span></span>
        </div>
        <div class="mk-foot">
          <span class="mk-prods">{{ s.product_count }} product{{ s.product_count===1?'':'s' }}</span>
          <span v-if="s.delivers_to" class="mk-delivers"><Icon name="pin" :size="12" /> {{ s.delivers_to.split(',')[0] }}…</span>
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
.mk-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px;margin-top:10px}
.mk-card{display:block;background:var(--surface);border:1px solid var(--hairline);border-radius:18px;padding:20px;text-decoration:none;transition:.18s;box-shadow:var(--shadow-sm);border-top:3px solid var(--sf,var(--accent))}
.mk-card:hover{box-shadow:var(--shadow-lg);transform:translateY(-3px)}
.mk-card.sk{height:180px;background:linear-gradient(90deg,var(--surface-2) 25%,var(--hairline) 37%,var(--surface-2) 63%);background-size:400% 100%;animation:mksh 1.4s infinite}
@keyframes mksh{0%{background-position:100% 0}100%{background-position:-100% 0}}
.mk-card-top{display:flex;align-items:center;gap:13px;margin-bottom:16px}
.mk-avatar{width:48px;height:48px;border-radius:13px;color:#fff;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:17px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.mk-name{font-weight:700;font-size:16px;color:var(--ink);display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.mk-badge.feat{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.03em;padding:3px 8px;border-radius:6px;background:linear-gradient(120deg,#F5D67E,#E8A33D);color:#5A3D0A;display:inline-flex;align-items:center;gap:3px}
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
</style>
