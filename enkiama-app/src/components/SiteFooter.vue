<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import BrandMark from './BrandMark.vue'

const route = useRoute()
const movement = computed(() => ['track','deliveries'].includes(route.name))
</script>

<template>
  <footer class="ef" :class="{'ef--movement':movement}">
    <div class="ef-inner">
      <div class="ef-brand">
        <BrandMark variant="full" :height="28" :light="movement" />
        <p>Commerce, place and movement — made visible.</p>
      </div>

      <nav class="ef-nav" aria-label="Footer navigation">
        <div>
          <span>Explore</span>
          <RouterLink to="/market">Market</RouterLink>
          <RouterLink to="/property">Property</RouterLink>
          <RouterLink to="/track">Track</RouterLink>
        </div>
        <div>
          <span>Build</span>
          <RouterLink to="/join/business">Sell with Enkiama</RouterLink>
          <RouterLink to="/driver/apply">Drive</RouterLink>
          <RouterLink to="/login">Sign in</RouterLink>
        </div>
      </nav>
    </div>
    <div class="ef-bottom">
      <span>Enkiama · Tanzania</span>
      <span>Movement you can verify.</span>
    </div>
  </footer>
</template>

<style scoped>
.ef{margin-top:0;border-top:1px solid var(--world-line);background:color-mix(in srgb,var(--world-surface) 48%,var(--world-canvas));color:var(--world-ink)}
.ef--movement{background:#09120f;border-top-color:var(--world-nav-line);color:var(--world-nav-ink)}
.ef-inner,.ef-bottom{width:min(var(--page-max),calc(100% - (var(--page-gutter) * 2)));margin:0 auto}.ef-inner{display:grid;grid-template-columns:1fr auto;gap:64px;padding:52px 0 44px}.ef-brand{display:flex;flex-direction:column;align-items:flex-start;gap:18px}.ef-brand p{max-width:330px;font:500 14px/1.55 var(--font-body);color:var(--world-ink-soft)}.ef--movement .ef-brand p{color:var(--world-nav-faint)}
.ef-nav{display:grid;grid-template-columns:repeat(2,minmax(150px,1fr));gap:52px}.ef-nav>div{display:flex;flex-direction:column;align-items:flex-start;gap:9px}.ef-nav>div>span{margin-bottom:4px;font:600 9px/1 var(--font-mono);text-transform:uppercase;letter-spacing:.11em;color:var(--world-ink-faint)}.ef-nav a{font:550 13px/1.35 var(--font-display);color:var(--world-ink-soft);text-decoration:none}.ef-nav a:hover{color:var(--world-ink)}.ef--movement .ef-nav a{color:var(--world-nav-faint)}.ef--movement .ef-nav a:hover{color:var(--world-nav-ink)}
.ef-bottom{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:18px 0 22px;border-top:1px solid var(--world-line);font:500 9px/1 var(--font-mono);text-transform:uppercase;letter-spacing:.08em;color:var(--world-ink-faint)}.ef--movement .ef-bottom{border-top-color:var(--world-nav-line);color:var(--world-nav-faint)}
@media(max-width:720px){.ef{margin-top:0}.ef-inner{grid-template-columns:1fr;gap:38px;padding:40px 0 32px}.ef-nav{grid-template-columns:1fr 1fr;gap:24px}.ef-bottom{align-items:flex-start;flex-direction:column;padding-bottom:calc(22px + env(safe-area-inset-bottom))}}
</style>
