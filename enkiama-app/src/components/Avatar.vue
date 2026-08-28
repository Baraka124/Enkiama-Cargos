<script setup>
import { computed } from 'vue'
const props = defineProps({
  name: { type: String, default: '' },
  size: { type: [String, Number], default: '' },
  accent: { type: String, default: '' },   // override the auto colour (e.g. a shop's brand)
  logo: { type: String, default: '' },      // show an image instead of initials
})
const palette = [
  ['#12A585', '#0B6E5D'],
  ['#C2603A', '#9E4A28'],
  ['#3E6DB0', '#2A4E82'],
  ['#C79A3E', '#946B25'],
  ['#4A8C6A', '#2F6048'],
  ['#4F9B9B', '#356E6E'],
  ['#B5544A', '#8E362E'],
  ['#6E8B3D', '#516A28'],
]
const initials = computed(() => {
  const parts = (props.name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return '?'
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
})
const style = computed(() => {
  const s = props.name || ''
  let h = 0
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0
  let [a, b] = palette[h % palette.length]
  if (props.accent) { a = props.accent; b = `color-mix(in srgb, ${props.accent} 68%, #000)` }
  const out = { '--av-1': a, '--av-2': b }
  if (typeof props.size === 'number' || /^\d+$/.test(props.size)) {
    const px = Number(props.size)
    out.width = px + 'px'; out.height = px + 'px'
    out.fontSize = Math.round(px * 0.4) + 'px'; out.borderRadius = Math.round(px * 0.3) + 'px'
  }
  return out
})
const sizeClass = computed(() => (typeof props.size === 'string' && !/^\d+$/.test(props.size)) ? props.size : '')
</script>
<template>
  <div class="avatar" :class="sizeClass" :style="style">
    <img v-if="logo" :src="logo" alt="" class="avatar-img" />
    <span v-else class="avatar-txt">{{ initials }}</span>
  </div>
</template>

<style scoped>
.avatar{
  width:40px;height:40px;border-radius:12px;flex-shrink:0;
  display:flex;align-items:center;justify-content:center;
  font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:15px;letter-spacing:-.02em;
  color:#fff;position:relative;overflow:hidden;
  background:linear-gradient(140deg, var(--av-1), var(--av-2));
  box-shadow:inset 0 1px 0 rgba(255,255,255,.22), inset 0 -2px 6px rgba(0,0,0,.16), 0 1px 3px rgba(20,24,31,.18);
}
.avatar::before{
  content:'';position:absolute;top:0;left:0;right:0;height:55%;
  background:linear-gradient(180deg, rgba(255,255,255,.16), transparent);
  pointer-events:none;
}
.avatar-txt{position:relative;z-index:1;text-shadow:0 1px 2px rgba(0,0,0,.18)}
.avatar-img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.avatar.sm{width:30px;height:30px;font-size:12px;border-radius:9px}
.avatar.lg{width:56px;height:56px;font-size:21px;border-radius:16px}
</style>
