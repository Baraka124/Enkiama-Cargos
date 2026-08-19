<script setup>
// Shared premium header — one consistent, branded top bar for every screen.
// Left: brand/context. Right: a built-in Marketplace link + slot for actions.
import BrandMark from './BrandMark.vue'
import CarrierMark from './CarrierMark.vue'
import Icon from './Icon.vue'
defineProps({
  title: { type: String, default: 'Enkiama Cargos' },
  subtitle: { type: String, default: '' },
  carrier: { type: Object, default: null },   // when set, shows CarrierMark
  live: { type: Boolean, default: false },
  market: { type: Boolean, default: true },   // show the Marketplace link (default on)
})
</script>

<template>
  <header class="ah">
    <div class="ah-inner">
      <div class="ah-brand">
        <CarrierMark v-if="carrier" :slug="carrier.slug" :mark="carrier.mark" :name="carrier.name" :accent="carrier.accent" :size="38" />
        <BrandMark v-else variant="mark" :height="34" />
        <div class="ah-id">
          <div class="ah-title">{{ title }}</div>
          <div v-if="subtitle" class="ah-sub">{{ subtitle }}</div>
        </div>
        <span v-if="live" class="ah-live"><span class="ah-live-dot"></span>Live</span>
      </div>
      <div class="ah-actions">
        <RouterLink v-if="market" to="/market" class="btn btn-ghost ah-market"><Icon name="box" :size="15" /> <span class="ah-market-t">Marketplace</span></RouterLink>
        <slot />
      </div>
    </div>
  </header>
</template>

<style scoped>
.ah{position:sticky;top:0;z-index:50;background:var(--nav);box-shadow:0 1px 0 var(--nav-line),var(--shadow-sm);border-bottom:none}
.ah-inner{max-width:1180px;margin:0 auto;padding:var(--s3) var(--s6);display:flex;align-items:center;gap:var(--s4)}
.ah-brand{display:flex;align-items:center;gap:var(--s3);min-width:0}
.ah-id{min-width:0}
.ah-title{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:var(--t-lg);color:var(--nav-ink);line-height:1.1;letter-spacing:-.02em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ah-sub{font-size:var(--t-xs);color:var(--nav-faint);text-transform:uppercase;letter-spacing:.03em;font-weight:500;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ah-live{display:inline-flex;align-items:center;gap:5px;font-size:var(--t-xs);font-weight:600;color:var(--go-ink);background:var(--go-soft);padding:4px 10px;border-radius:var(--r-full);margin-left:var(--s2)}
.ah-live-dot{width:6px;height:6px;border-radius:50%;background:var(--go);animation:ahPulse 2s var(--ease) infinite}
@keyframes ahPulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.5;transform:scale(.8)}}
.ah-actions{margin-left:auto;display:flex;align-items:center;gap:var(--s2);flex-shrink:0}
@media(max-width:640px){
  .ah-inner{padding:var(--s3) var(--s4)}
  .ah-sub{display:none}
  .ah-market-t{display:none}
}

.ah .btn-ghost{background:var(--nav-soft);border-color:var(--nav-line);color:var(--nav-ink)}
.ah .btn-ghost:hover{background:#20262F;border-color:#333B49;color:#fff}
.ah-market{background:var(--nav-soft);border-color:var(--nav-line);color:var(--nav-ink)}
</style>
