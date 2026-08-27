<script setup>
// Enkiama Cargos brand mark. Uses the real logo assets in /public.
//   variant="mark" → the EC+truck emblem only (topbars, tight spaces)
//   variant="full" → the full lockup incl. ENKIAMA CARGOS wordmark
// height drives sizing; width auto-scales. Falls back to a styled "EC"
// monogram if the image is slow or fails — so it's NEVER blank.
import { computed, ref } from 'vue'
const props = defineProps({
  variant: { type: String, default: 'mark' },   // mark | full
  height: { type: [Number, String], default: 34 },
  light: { type: Boolean, default: false },      // use the light logo for dark headers
})
const base = (import.meta.env.BASE_URL || '/')
const src = computed(() => {
  const stem = props.variant === 'full' ? 'logo-transparent' : 'logo-mark'
  return base + stem + (props.light ? '-light' : '') + '.png'
})
const failed = ref(false)
const h = computed(() => (typeof props.height === 'number' ? props.height + 'px' : props.height))
</script>

<template>
  <img v-if="!failed" :src="src" alt="Enkiama Cargos" class="brandmark"
       :style="{ height: h }" @error="failed = true" />
  <!-- fallback monogram: never renders empty -->
  <span v-else class="brandmark-fallback" :style="{ height: h, width: h, fontSize: `calc(${h} * 0.42)` }">EC</span>
</template>

<style scoped>
.brandmark{width:auto;display:block;object-fit:contain;user-select:none;-webkit-user-drag:none}
.brandmark-fallback{display:inline-flex;align-items:center;justify-content:center;border-radius:8px;
  background:linear-gradient(135deg,#0B6E5D,#312E81);color:#fff;font-family:'Space Grotesk',sans-serif;
  font-weight:700;letter-spacing:-.02em;flex-shrink:0}
</style>
