<script setup>
import { computed, ref, watch } from 'vue'
import { validMediaUrl } from '../lib/media'

const emit = defineEmits(['load', 'error'])
const props = defineProps({
  src: { type: String, default: '' },
  alt: { type: String, default: '' },
  ratio: { type: String, default: 'auto' },
  fit: { type: String, default: 'cover' },
  position: { type: String, default: 'center' },
  tone: { type: String, default: 'neutral' },
  eager: { type: Boolean, default: false },
  fallbackTitle: { type: String, default: 'Image not supplied' },
  fallbackNote: { type: String, default: '' },
  transitionName: { type: String, default: '' },
})

const loaded = ref(false)
const failed = ref(false)
const source = computed(() => validMediaUrl(props.src) ? String(props.src).trim() : '')
const style = computed(() => ({
  ...(props.ratio !== 'auto' ? { aspectRatio: props.ratio } : {}),
  '--en-media-fit': props.fit,
  '--en-media-position': props.position,
  ...(props.transitionName ? { viewTransitionName: props.transitionName } : {}),
}))

watch(() => props.src, () => { loaded.value = false; failed.value = false })
function onLoad() { loaded.value = true; failed.value = false; emit('load') }
function onError() { loaded.value = false; failed.value = true; emit('error') }
</script>

<template>
  <div class="en-media-frame" :class="[`tone-${tone}`, { loaded, failed, empty: !source }]" :style="style">
    <img
      v-if="source && !failed"
      :src="source"
      :alt="alt"
      :loading="eager ? 'eager' : 'lazy'"
      decoding="async"
      :fetchpriority="eager ? 'high' : 'auto'"
      @load="onLoad"
      @error="onError"
    />
    <div v-if="source && !loaded && !failed" class="en-media-skeleton" aria-hidden="true"></div>
    <div v-if="!source || failed" class="en-media-fallback" role="img" :aria-label="alt || fallbackTitle">
      <div class="en-media-fallback-mark" aria-hidden="true"><span></span><span></span><span></span></div>
      <strong>{{ failed ? (fallbackTitle || 'Image unavailable') : fallbackTitle }}</strong>
      <small v-if="fallbackNote">{{ fallbackNote }}</small>
    </div>
    <slot />
  </div>
</template>

<style scoped>
.en-media-frame{position:relative;width:100%;height:100%;overflow:hidden;background:#e9e5dc;color:#4d514d;isolation:isolate}
.en-media-frame>img{position:absolute;inset:0;width:100%;height:100%;object-fit:var(--en-media-fit);object-position:var(--en-media-position);display:block;opacity:0;transition:opacity .34s ease,transform .65s cubic-bezier(.2,.75,.2,1)}
.en-media-frame.loaded>img{opacity:1}
.en-media-skeleton{position:absolute;inset:0;background:linear-gradient(105deg,rgba(255,255,255,.08) 20%,rgba(255,255,255,.58) 38%,rgba(255,255,255,.08) 56%),linear-gradient(145deg,#ddd8cf,#eeeae3);background-size:220% 100%,100% 100%;animation:enMediaLoad 1.25s linear infinite}
.en-media-fallback{position:absolute;inset:0;display:flex;flex-direction:column;justify-content:flex-end;gap:5px;padding:18px;background:linear-gradient(145deg,#e7e2d9,#d9d3c8);color:#746f66}
.en-media-fallback::before{content:"";position:absolute;inset:0;opacity:.42;background:repeating-radial-gradient(ellipse at 80% 18%,transparent 0 30px,rgba(82,77,68,.12) 31px 32px,transparent 33px 48px)}
.en-media-fallback>*{position:relative;z-index:1}.en-media-fallback strong{font:600 9px/1.2 'Space Grotesk',sans-serif;text-transform:uppercase;letter-spacing:.1em}.en-media-fallback small{font-size:9px;line-height:1.45;max-width:28ch;opacity:.72}.en-media-fallback-mark{position:absolute!important;inset:18px 18px auto auto;width:42px;height:42px}.en-media-fallback-mark span{position:absolute;border:1px solid currentColor;border-radius:50%;opacity:.18}.en-media-fallback-mark span:nth-child(1){inset:0}.en-media-fallback-mark span:nth-child(2){inset:7px}.en-media-fallback-mark span:nth-child(3){inset:14px}
.tone-object{background:#ebe8e0}.tone-object .en-media-fallback{background:linear-gradient(145deg,#efede7,#dfd9cf);color:#777168}.tone-place{background:#ded7ca}.tone-place .en-media-fallback{background:linear-gradient(145deg,#ddd5c7,#c9c1b2);color:#5d6259}.tone-business{background:#e7ddd0}.tone-business .en-media-fallback{background:linear-gradient(145deg,#eadfd2,#d3c4b3);color:#75695c}.tone-night{background:#111b18}.tone-night .en-media-fallback{background:linear-gradient(145deg,#16231f,#0d1512);color:#b7d3ca}.tone-neutral{background:#e7e3da}
@keyframes enMediaLoad{to{background-position:-220% 0,0 0}}
@media(prefers-reduced-motion:reduce){.en-media-frame>img{transition:none}.en-media-skeleton{animation:none}}
</style>
