<script setup>
// Shared premium header — one consistent, branded top bar for every screen.
// Left: brand/context. Right: slot for actions. Optional live pulse.
import BrandMark from './BrandMark.vue'
import CarrierMark from './CarrierMark.vue'
defineProps({
  title: { type: String, default: 'Enkiama Cargos' },
  subtitle: { type: String, default: '' },
  carrier: { type: Object, default: null },   // when set, shows CarrierMark
  live: { type: Boolean, default: false },
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
      <div class="ah-actions"><slot /></div>
    </div>
  </header>
</template>

<style scoped>
.ah{position:sticky;top:0;z-index:50;background:color-mix(in srgb, var(--paper) 85%, transparent);backdrop-filter:saturate(180%) blur(12px);border-bottom:1px solid var(--hairline)}
.ah-inner{max-width:1180px;margin:0 auto;padding:var(--s3) var(--s6);display:flex;align-items:center;gap:var(--s4)}
.ah-brand{display:flex;align-items:center;gap:var(--s3);min-width:0}
.ah-id{min-width:0}
.ah-title{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:var(--t-lg);color:var(--ink);line-height:1.1;letter-spacing:-.02em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ah-sub{font-size:var(--t-xs);color:var(--ink-faint);text-transform:uppercase;letter-spacing:.03em;font-weight:500;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ah-live{display:inline-flex;align-items:center;gap:5px;font-size:var(--t-xs);font-weight:600;color:var(--go-ink);background:var(--go-soft);padding:4px 10px;border-radius:var(--r-full);margin-left:var(--s2)}
.ah-live-dot{width:6px;height:6px;border-radius:50%;background:var(--go);animation:ahPulse 2s var(--ease) infinite}
@keyframes ahPulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.5;transform:scale(.8)}}
.ah-actions{margin-left:auto;display:flex;align-items:center;gap:var(--s2);flex-shrink:0}
@media(max-width:640px){
  .ah-inner{padding:var(--s3) var(--s4)}
  .ah-sub{display:none}
}
</style>
