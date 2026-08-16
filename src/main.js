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

createApp(App).use(router).mount('#app')
