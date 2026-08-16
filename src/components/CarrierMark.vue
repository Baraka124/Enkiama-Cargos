<script setup>
// Smart carrier mark: shows the real Enkiama logo when the carrier is Enkiama
// (the platform owner), otherwise the carrier's own colored text badge.
// Keeps every tenant's identity distinct while giving Enkiama its true brand.
import { computed } from 'vue'
import BrandMark from './BrandMark.vue'
const props = defineProps({
  slug: { type: String, default: '' },
  mark: { type: String, default: '' },
  name: { type: String, default: '' },
  accent: { type: String, default: '' },
  size: { type: [Number, String], default: 40 },
})
const isEnkiama = computed(() => (props.slug || '').toLowerCase() === 'enkiama')
const label = computed(() => props.mark || (props.name || '').slice(0,2).toUpperCase())
</script>

<template>
  <span v-if="isEnkiama" class="cm-enkiama" :style="{ width: size+'px', height: size+'px' }">
    <BrandMark variant="mark" :height="Math.round(Number(size)*0.62)" />
  </span>
  <span v-else class="cm-badge" :style="{ width: size+'px', height: size+'px', background: accent || 'var(--accent)', fontSize: (Number(size)*0.36)+'px' }">
    {{ label }}
  </span>
</template>

<style scoped>
.cm-enkiama{display:inline-flex;align-items:center;justify-content:center;border-radius:12px;
  background:#fff;border:1px solid var(--hairline);flex-shrink:0;box-shadow:var(--shadow-sm)}
.cm-badge{display:inline-flex;align-items:center;justify-content:center;border-radius:12px;color:#fff;
  font-family:'Space Grotesk',sans-serif;font-weight:700;flex-shrink:0;box-shadow:var(--shadow-sm)}
</style>
