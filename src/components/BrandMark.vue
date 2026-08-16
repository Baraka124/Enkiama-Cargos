<script setup>
// Enkiama Cargos brand mark. Uses the real logo assets in /public.
//   variant="mark" → the EC+truck emblem only (topbars, tight spaces)
//   variant="full" → the full lockup incl. ENKIAMA CARGOS wordmark (login, tracking)
// height drives sizing; width auto-scales to preserve aspect ratio.
import { computed } from 'vue'
const props = defineProps({
  variant: { type: String, default: 'mark' },   // mark | full
  height: { type: [Number, String], default: 34 },
})
const base = (import.meta.env.BASE_URL || '/')
const src = computed(() => base + (props.variant === 'full' ? 'logo-transparent.png' : 'logo-mark.png'))
</script>

<template>
  <img :src="src" alt="Enkiama Cargos" class="brandmark"
       :style="{ height: (typeof height==='number' ? height+'px' : height) }" />
</template>

<style scoped>
.brandmark{width:auto;display:block;object-fit:contain;user-select:none;-webkit-user-drag:none}
</style>
