<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { prefersReducedMotion } from '../lib/motion'

const enabled = ref(false)
const visible = ref(false)
const pressed = ref(false)
const label = ref('')
const x = ref(-100)
const y = ref(-100)
let frame = 0
let nx = -100
let ny = -100

function render() {
  frame = 0
  x.value = nx
  y.value = ny
}
function move(e) {
  nx = e.clientX
  ny = e.clientY
  if (!frame) frame = requestAnimationFrame(render)

  const target = e.target?.closest?.('[data-cursor]')
  if (!target) {
    visible.value = false
    label.value = ''
    return
  }
  const next = (target.getAttribute('data-cursor') || '').trim()
  if (!next) {
    visible.value = false
    return
  }
  label.value = next.slice(0, 12).toUpperCase()
  visible.value = true
}
function down() { pressed.value = true }
function up() { pressed.value = false }
function leave() { visible.value = false }

onMounted(() => {
  enabled.value = !!window.matchMedia?.('(pointer:fine)').matches && !prefersReducedMotion()
  if (!enabled.value) return
  window.addEventListener('pointermove', move, { passive:true })
  window.addEventListener('pointerdown', down, { passive:true })
  window.addEventListener('pointerup', up, { passive:true })
  document.documentElement.addEventListener('mouseleave', leave)
})

onUnmounted(() => {
  if (frame) cancelAnimationFrame(frame)
  window.removeEventListener('pointermove', move)
  window.removeEventListener('pointerdown', down)
  window.removeEventListener('pointerup', up)
  document.documentElement.removeEventListener('mouseleave', leave)
})
</script>

<template>
  <div
    v-if="enabled"
    class="en-motion-cursor"
    :class="{ visible, pressed }"
    :style="{ transform:`translate3d(${x}px, ${y}px, 0)` }"
    aria-hidden="true"
  ><span>{{ label }}</span></div>
</template>
