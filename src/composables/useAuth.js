import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'

// ── Shared reactive auth state (module-level singleton) ────────────
const session = ref(null)
const profile = ref(null)
const carrier = ref(null)
const isPlatformAdmin = ref(false)
const hat = ref('platform')
const loading = ref(true)
let initialized = false

const emailVerified = computed(() => {
  const u = session.value?.user
  if (!u) return false
  // email accounts: confirmed_at set once verified; phone accounts: n/a
  return !!(u.email_confirmed_at || u.confirmed_at) || !!u.phone
})

async function loadProfile() {
  if (!session.value?.user) {
    profile.value = null; carrier.value = null; isPlatformAdmin.value = false; return
  }
  const uid = session.value.user.id
  const { data: pa } = await supabase.from('platform_admin').select('user_id').eq('user_id', uid).maybeSingle()
  isPlatformAdmin.value = !!pa
  const { data: prof } = await supabase.from('profile').select('*').eq('user_id', uid).maybeSingle()
  profile.value = prof || null
  if (prof?.carrier_id) {
    const { data: car } = await supabase.from('carrier').select('*').eq('id', prof.carrier_id).maybeSingle()
    carrier.value = car || null
  } else { carrier.value = null }
  hat.value = isPlatformAdmin.value ? 'platform' : 'carrier'
}

async function init() {
  if (initialized) return
  initialized = true
  const { data } = await supabase.auth.getSession()
  session.value = data.session
  await loadProfile()
  loading.value = false
  supabase.auth.onAuthStateChange(async (event, newSession) => {
    session.value = newSession
    // session expired or signed out elsewhere → clear cleanly
    if (event === 'SIGNED_OUT' || !newSession) {
      profile.value = null; carrier.value = null; isPlatformAdmin.value = false
    } else {
      await loadProfile()
    }
  })
}

// ── Sign-in / sign-up ──────────────────────────────────────────────
async function signInEmail(email, password) {
  const { error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw humanizeAuthError(error)
}
async function signUpEmail(email, password, meta = {}) {
  const { error } = await supabase.auth.signUp({
    email, password,
    options: { data: meta, emailRedirectTo: `${window.location.origin}/#/login` },
  })
  if (error) throw humanizeAuthError(error)
}
async function signUpSender(email, password, name) {
  // atomic: the v11 trigger creates the sender profile from metadata
  return signUpEmail(email, password, { intent: 'sender', name })
}
async function sendPhoneOtp(phone) {
  const { error } = await supabase.auth.signInWithOtp({ phone })
  if (error) throw humanizeAuthError(error)
}
async function verifyPhoneOtp(phone, token) {
  const { error } = await supabase.auth.verifyOtp({ phone, token, type: 'sms' })
  if (error) throw humanizeAuthError(error)
}

// ── Password reset + change ────────────────────────────────────────
async function sendPasswordReset(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${window.location.origin}/#/reset`,
  })
  if (error) throw humanizeAuthError(error)
}
async function updatePassword(newPassword) {
  const { error } = await supabase.auth.updateUser({ password: newPassword })
  if (error) throw humanizeAuthError(error)
}
async function resendVerification(email) {
  const { error } = await supabase.auth.resend({ type: 'signup', email,
    options: { emailRedirectTo: `${window.location.origin}/#/login` } })
  if (error) throw humanizeAuthError(error)
}

// ── Profile self-management ────────────────────────────────────────
async function updateMyProfile(name, phone) {
  const { error } = await supabase.rpc('update_my_profile', { p_name: name, p_phone: phone })
  if (error) throw error
  await loadProfile()
}

// ── Sessions ───────────────────────────────────────────────────────
async function signOut() {
  await supabase.auth.signOut()
  session.value = null; profile.value = null; carrier.value = null; isPlatformAdmin.value = false
}
async function signOutEverywhere() {
  await supabase.auth.signOut({ scope: 'global' })
  session.value = null; profile.value = null; carrier.value = null; isPlatformAdmin.value = false
}

function setHat(h) { hat.value = h }

// friendlier auth error messages
function humanizeAuthError(error) {
  const m = (error?.message || '').toLowerCase()
  if (m.includes('invalid login')) return new Error('Wrong email or password')
  if (m.includes('email not confirmed')) return new Error('Please verify your email first — check your inbox')
  if (m.includes('rate limit') || m.includes('too many')) return new Error('Too many attempts — wait a minute and try again')
  if (m.includes('already registered')) return new Error('That email already has an account — sign in instead')
  if (m.includes('weak') || m.includes('at least')) return new Error('Password too weak — use at least 8 characters')
  return new Error(error?.message || 'Something went wrong')
}

export function useAuth() {
  return {
    session, profile, carrier, loading, isPlatformAdmin, hat, emailVerified,
    isAuthed: computed(() => !!session.value),
    role: computed(() => profile.value?.role || null),
    homeRoute: computed(() => {
      if (isPlatformAdmin.value && hat.value === 'platform') return '/platform'
      const r = profile.value?.role
      if (r === 'driver') return '/driver'
      if (r === 'sender') return '/send'
      if (r === 'carrier_admin' || r === 'dispatch') return '/dispatch'
      return null
    }),
    init, signInEmail, signUpEmail, signUpSender, sendPhoneOtp, verifyPhoneOtp,
    sendPasswordReset, updatePassword, resendVerification, updateMyProfile,
    signOut, signOutEverywhere, reloadProfile: loadProfile, setHat,
  }
}
