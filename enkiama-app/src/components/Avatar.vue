<script setup>
import { computed } from 'vue'
const props = defineProps({
  name: { type: String, default: '' },
  size: { type: String, default: '' } // '', 'sm', 'lg'
})
// deterministic hue from the name → each person keeps their own colour
const palette = [
  ['#0E8873', '#0B6E5D'], // teal (brand)
  ['#C2603A', '#A84A28'], // terracotta
  ['#3E6DB0', '#2E5488'], // steel blue
  ['#B58A3C', '#946B25'], // ochre
  ['#7A5AA8', '#5E4287'], // plum
  ['#4A8C6A', '#357050'], // sage
  ['#C24D6B', '#9E3450'], // rose
  ['#5B8C8C', '#3F6E6E'], // slate teal
]
const initials = computed(() => {
  const parts = (props.name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
})
const grad = computed(() => {
  const s = props.name || ''
  let h = 0
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0
  const [a, b] = palette[h % palette.length]
  return { '--av-1': a, '--av-2': b }
})
</script>
<template>
  <div class="avatar" :class="size" :style="grad">{{ initials }}</div>
</template>
