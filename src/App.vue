<script setup>
import { watchEffect, provide, ref } from 'vue'
import { useAuth } from './composables/useAuth'
import Icon from './components/Icon.vue'

const { carrier } = useAuth()

// apply the signed-in carrier's accent to the whole app (white-label)
watchEffect(() => {
  const c = carrier.value
  if (c?.accent) {
    const hex = c.accent
    const n = parseInt(hex.slice(1), 16)
    const hi = '#' + (((Math.min(255,(n>>16)+22))<<16)+((Math.min(255,((n>>8)&255)+22))<<8)+Math.min(255,(n&255)+22)).toString(16).padStart(6,'0')
    const tint = `rgba(${n>>16},${(n>>8)&255},${n&255},.14)`
    document.documentElement.style.setProperty('--accent', hex)
    document.documentElement.style.setProperty('--accent-hi', hi)
    document.documentElement.style.setProperty('--accent-tint', tint)
  }
})

// simple global toast
const toasts = ref([])
function toast(msg, type = 'info') {
  const id = Date.now() + Math.random()
  toasts.value.push({ id, msg, type })
  setTimeout(() => { toasts.value = toasts.value.filter(t => t.id !== id) }, 3600)
}
provide('toast', toast)

// #20 dark mode toggle (global, provided to any view)
const theme = ref('light')
function toggleTheme() {
  theme.value = theme.value === 'light' ? 'dark' : 'light'
  document.documentElement.setAttribute('data-theme', theme.value)
}
provide('theme', theme)
provide('toggleTheme', toggleTheme)
</script>

<template>
  <router-view v-slot="{ Component }">
    <transition name="view-fade" mode="out-in">
      <component :is="Component" />
    </transition>
  </router-view>
  <div class="toasts">
    <div v-for="t in toasts" :key="t.id" class="toast" :class="t.type">
      <Icon :name="t.type === 'ok' ? 'check' : t.type === 'warn' ? 'alert' : 'inbox'" :size="16" />
      <span>{{ t.msg }}</span>
    </div>
  </div>
</template>
