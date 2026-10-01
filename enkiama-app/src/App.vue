<script setup>
import { watchEffect, provide, ref, onMounted, onUnmounted, computed } from 'vue'
import { useAuth } from './composables/useAuth'
import Icon from './components/Icon.vue'
import MotionCursor from './components/MotionCursor.vue'
import { useRouter } from 'vue-router'
import { supportsViewTransitions } from './lib/motion'

const { carrier } = useAuth()
const router = useRouter()
const routeName = computed(() => router.currentRoute.value?.name || 'page')
const routeAnnouncement = computed(() => ({
  home:'Enkiama home', login:'Sign in', market:'Market', product:'Product', shop:'Business', property:'Property', 'property-detail':'Property detail', track:'Track a parcel', deliveries:'My movement', account:'Account', dispatch:'Dispatch', driver:'Driver workspace', send:'Sender workspace', platform:'Platform', 'not-found':'Page not found'
}[routeName.value] || 'Enkiama') + ' loaded')
function focusMain() {
  requestAnimationFrame(() => {
    const target = document.querySelector('main,[role="main"],h1') || document.getElementById('app')
    if (!target) return
    if (!target.hasAttribute('tabindex')) target.setAttribute('tabindex', '-1')
    target.focus({ preventScroll: true })
    target.scrollIntoView({ block: 'start', behavior: 'auto' })
  })
}
const routeBusy = ref(false)
const nativeViewTransitions = supportsViewTransitions()
let removeMotionBefore = null
let removeMotionAfter = null

// #20 — network status: crucial on spotty Tanzanian mobile data
const online = ref(navigator.onLine)
function goOnline() { online.value = true }
function goOffline() { online.value = false }
onMounted(() => {
  window.addEventListener('online', goOnline)
  window.addEventListener('offline', goOffline)
  removeMotionBefore = router.beforeEach((to, from) => {
    if (to.fullPath !== from.fullPath) routeBusy.value = true
    return true
  })
  removeMotionAfter = router.afterEach(() => {
    requestAnimationFrame(() => { routeBusy.value = false })
  })
})
onUnmounted(() => {
  window.removeEventListener('online', goOnline)
  window.removeEventListener('offline', goOffline)
  removeMotionBefore?.()
  removeMotionAfter?.()
})

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
  // coerce to a readable string — never render an empty object or blank
  let text = typeof msg === 'string' ? msg : (msg?.message || '')
  if (!text || !String(text).trim()) text = 'Something went wrong'
  const id = Date.now() + Math.random()
  toasts.value.push({ id, msg: String(text), type })
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
  <button class="skip-link" type="button" @click="focusMain">Skip to main content</button>
  <div class="sr-only" aria-live="polite" aria-atomic="true">{{ routeAnnouncement }}</div>

  <transition name="en-route-signal">
    <div v-if="routeBusy" class="en-route-signal" role="progressbar" aria-label="Loading page" aria-valuetext="Loading"><i aria-hidden="true"></i></div>
  </transition>

  <router-view v-slot="{ Component, route }">
    <component v-if="nativeViewTransitions" :is="Component" :key="route.fullPath" />
    <transition v-else name="en-page" mode="out-in">
      <component :is="Component" :key="route.fullPath" />
    </transition>
  </router-view>

  <MotionCursor />

  <transition name="offline-slide">
    <div v-if="!online" class="offline-banner" role="status" aria-live="polite">
      <Icon name="alert" :size="15" aria-hidden="true" /><span><strong>Offline</strong> · Live data and actions may be unavailable until you reconnect.</span>
    </div>
  </transition>
  <div class="toasts" aria-live="polite" aria-relevant="additions text">
    <div v-for="t in toasts" :key="t.id" class="toast" :class="t.type" :role="t.type === 'warn' ? 'alert' : 'status'">
      <Icon :name="t.type === 'ok' ? 'check' : t.type === 'warn' ? 'alert' : 'inbox'" :size="16" aria-hidden="true" />
      <span>{{ t.msg }}</span>
    </div>
  </div>
</template>
