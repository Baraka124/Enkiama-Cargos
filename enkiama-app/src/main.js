import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import './style.css'

// Supabase sometimes redirects back with an error hash, e.g.
//   #/error=access_denied&error_code=otp_expired&error_description=...
// or #error=... (expired reset/verify links). Left unhandled, the router
// can't match it and the app renders blank. Detect it, stash a friendly
// message, and clean the URL to /#/login before the app mounts.
;(function handleAuthErrorHash() {
  const h = window.location.hash || ''
  if (h.includes('error_code=') || h.includes('error=access_denied') || h.includes('otp_expired')) {
    let msg = 'That link is invalid or has expired — please sign in again.'
    const m = h.match(/error_description=([^&]+)/)
    if (m) { try { msg = decodeURIComponent(m[1].replace(/\+/g, ' ')) } catch (e) {} }
    try { sessionStorage.setItem('auth_notice', msg) } catch (e) {}
    window.location.replace(window.location.pathname + '#/login')
  }
  // Also handle a successful recovery link: #access_token=...&type=recovery
  if (h.includes('type=recovery') && h.includes('access_token=')) {
    window.location.replace(window.location.pathname + '#/reset' + h.substring(h.indexOf('&')))
  }
})()

const app = createApp(App)

// v-escape: call the bound handler when Escape is pressed while the element
// is in the DOM. Lets any modal close on Esc (accessibility + expected feel)
// without each view wiring its own key listener.
app.directive('escape', {
  mounted(el, binding) {
    el._escHandler = (e) => { if (e.key === 'Escape') binding.value?.(e) }
    document.addEventListener('keydown', el._escHandler)
  },
  unmounted(el) {
    if (el._escHandler) document.removeEventListener('keydown', el._escHandler)
  },
})

// v-click-outside: call the handler when a click lands outside the element.
// Used for dropdown menus (account menu, etc.) so they close naturally.
app.directive('click-outside', {
  mounted(el, binding) {
    el._outsideHandler = (e) => { if (!el.contains(e.target)) binding.value?.(e) }
    // defer so the opening click itself doesn't immediately close it
    setTimeout(() => document.addEventListener('click', el._outsideHandler), 0)
  },
  unmounted(el) {
    if (el._outsideHandler) document.removeEventListener('click', el._outsideHandler)
  },
})

app.use(router).mount('#app')
