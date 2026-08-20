<script setup>
import { ref, computed, onMounted, onUnmounted, inject } from 'vue'
import { usePublic } from '../composables/usePublic'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { supabase } from '../lib/supabase'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import BrandMark from '../components/BrandMark.vue'

const router = useRouter()
const toast = inject('toast')
const pub = usePublic()
const { signInEmail, signUpEmail, signUpSender, signUpReceiver, signUpDriver, sendPhoneOtp, verifyPhoneOtp, sendPasswordReset, reloadProfile } = useAuth()

// ── auth state (all logic preserved) ──
const mode = ref('email')            // email | phone
const role = ref('carrier')          // carrier | driver | sender
const email = ref(''); const password = ref('')
const phone = ref(''); const otp = ref(''); const otpSent = ref(false)
const senderName = ref('')
const bizLocation = ref('')
const bizTin = ref('')
const driverName = ref(''); const driverVehicle = ref('')
const busy = ref(false)
const showReset = ref(false)
const signupMode = ref(false)

async function doEmail() {
  if (!email.value || !password.value) { toast('Email and password required', 'warn'); return }
  busy.value = true
  try {
    if (signupMode.value && role.value === 'sender') {
      await signUpSender(email.value, password.value, senderName.value || 'Business', bizLocation.value, bizTin.value)
      toast('Account created — check your email to verify, then sign in', 'ok')
      signupMode.value = false
    } else if (signupMode.value && role.value === 'driver') {
      await signUpDriver(email.value, password.value, driverName.value || 'Driver', phone.value || null, driverVehicle.value || null)
      toast('Account created — check your email to verify, then sign in', 'ok')
      signupMode.value = false
    } else if (signupMode.value && role.value === 'receiver') {
      await signUpReceiver(email.value, password.value, senderName.value || 'Receiver')
      toast('Account created — check your email to verify, then sign in', 'ok')
      signupMode.value = false
    } else if (signupMode.value) {
      await signUpEmail(email.value, password.value)
      toast('Account created — check your email to verify', 'ok')
      signupMode.value = false
    } else {
      await signInEmail(email.value, password.value)
      await reloadProfile(); router.push('/')
    }
  } catch (e) { toast(e.message || 'Something went wrong', 'warn') }
  busy.value = false
}
async function doReset() {
  if (!email.value) { toast('Enter your email first', 'warn'); return }
  busy.value = true
  try { await sendPasswordReset(email.value); toast('Reset link sent — check your inbox', 'ok'); showReset.value = false }
  catch (e) { toast(e.message, 'warn') }
  busy.value = false
}
async function doSendOtp() {
  if (!phone.value) { toast('Enter your phone number', 'warn'); return }
  busy.value = true
  try { await sendPhoneOtp(phone.value); otpSent.value = true; toast('Code sent to your phone', 'ok') }
  catch (e) { toast(e.message || 'Could not send code', 'warn') }
  busy.value = false
}
async function doVerify() {
  busy.value = true
  try {
    await verifyPhoneOtp(phone.value, otp.value)
    // if this is a driver signing up, create their account + connect them
    // to a carrier's waiting record (or stand up an independent driver)
    if (role.value === 'driver') {
      const { useDriver } = await import('../composables/useDriver')
      const { driverSignup } = useDriver()
      try { await driverSignup(driverName.value || 'Driver', driverVehicle.value || null) } catch (e) {}
    }
    await reloadProfile(); router.push('/')
  }
  catch (e) { toast(e.message || 'Wrong code', 'warn') }
  busy.value = false
}
function pickRole(r) {
  role.value = r
  mode.value = 'email'   // all roles use email+password now (phone OTP needs SMS provider)
  signupMode.value = false; showReset.value = false; otpSent.value = false
}

// ── live ledger (kept, drives the proof strip) ──
const parcelsToday = ref(2841)
const onRoad = ref(63)
const settledTZS = ref(48920000)
const carriersLive = ref(0)
const NAMES = ['Grace Mwangi','Peter Otieno','Neema Joseph','Hamisi Bakari','John Mkwawa','Asha Salum','Baraka Omari','Zainab Ali','Juma Hassan','Rehema Said']
const PLACES = ['Mikocheni','Kariakoo','Msasani','Uyole','Kimara','Tabata','Mbezi','Sinza','Ilala','Temeke']
const CARRIERS = [['USIRI','#3E5BD6'],['Sumry','#137A5E'],['Kimoto','#B4472B'],['Enkiama','#4338CA']]
const EVENTS = [['booked','booked'],['collected','collected'],['on road','linehaul'],['delivered','delivered'],['cash collected','cash'],['confirmed','confirmed']]
const feed = ref([])
const stats = ref(null)
async function loadStats() {
  try {
    const { data } = await supabase.rpc('public_platform_stats')
    if (data) { stats.value = data; carriersLive.value = data.active_carriers || 0 }
  } catch (e) {}
}
let timers = []
onMounted(() => {
  // deep-link: /login?role=sender opens the Business tab in signup mode
  try {
    const q = new URLSearchParams(window.location.hash.split('?')[1] || '')
    const qr = q.get('role')
    if (qr && ['carrier','driver','sender','receiver'].includes(qr)) {
      pickRole(qr)
      if (qr === 'sender') signupMode.value = true
    }
  } catch (e) {}
  // surface any auth error captured before boot (expired link, etc.)
  try {
    const notice = sessionStorage.getItem('auth_notice')
    if (notice) { toast(notice, 'warn'); sessionStorage.removeItem('auth_notice') }
  } catch (e) {}
  loadStats()
})
onUnmounted(() => timers.forEach(clearInterval))
const settledStr = computed(() => 'TZS ' + settledTZS.value.toLocaleString())

const roleLabels = { carrier: 'Carrier team', driver: 'Driver', sender: 'Sell on the marketplace — manage your shop', receiver: 'Receiving parcels' }

// ── fleet operator self-application (Phase 3 front door) ──
const showFleet = ref(false)
const fleet = ref({ company:'', contact:'', phone:'', email:'', region:'', note:'' })
const fleetSent = ref(false)
function scrollToAuth() {
  document.querySelector('.lp-auth')?.scrollIntoView({ behavior:'smooth', block:'center' })
}
async function submitFleet() {
  if (!fleet.value.company || !fleet.value.contact || !fleet.value.phone) {
    toast('Company, contact name and phone are required', 'warn'); return
  }
  busy.value = true
  try {
    const { error } = await sendFleetApplication()
    if (error) throw error
    fleetSent.value = true
  } catch (e) { toast(e.message || 'Could not send application', 'warn') }
  busy.value = false
}
async function sendFleetApplication() {
  return pub.applyAsCarrier({
    p_company: fleet.value.company, p_contact: fleet.value.contact,
    p_phone: fleet.value.phone, p_email: fleet.value.email || null,
    p_region: fleet.value.region || null, p_fleet: fleet.value.note || null,
  })
}
</script>

<template>
  <div class="lp">
    <!-- top bar -->
    <header class="lp-top">
      <div class="lp-brand"><BrandMark variant="mark" :height="36" /> <span class="lp-brand-name">Enkiama Cargos</span></div>
      <span v-if="carriersLive" class="lp-live"><span class="lp-dot"></span>{{ carriersLive }} carriers live</span>
    </header>

    <div class="lp-grid">
      <!-- LEFT / TOP: pitch + proof -->
      <section class="lp-pitch">
        <h1 class="lp-h1">One parcel,<br><span class="grad">one truth.</span></h1>
        <p class="lp-sub">The ledger every road-freight carrier runs on — movement and money, tracked end to end, for every hand that touches the cargo.</p>

        <div class="lp-quick">
          <router-link to="/track" class="lp-quick-link"><Icon name="pin" :size="16" /> Track a parcel</router-link>
          <router-link to="/market" class="lp-quick-link"><Icon name="box" :size="16" /> Browse the marketplace</router-link>
          <span class="lp-quick-note">No account needed</span>
        </div>

        <div class="lp-stats" v-if="stats">
          <div class="lp-stat"><div class="lp-sv mono">{{ (stats.total_parcels||0).toLocaleString() }}</div><div class="lp-sl">parcels moved</div></div>
          <div class="lp-stat"><div class="lp-sv mono">{{ stats.active_carriers||0 }}</div><div class="lp-sl">active carriers</div></div>
          <div class="lp-stat"><div class="lp-sv mono">{{ stats.regions||0 }}</div><div class="lp-sl">destinations served</div></div>
        </div>

        <!-- real value proof, not fake activity -->
        <div class="lp-proof" v-if="stats">
          <div class="lp-proof-row"><Icon name="check" :size="15" /><div><b>{{ (stats.delivered||0).toLocaleString() }} parcels delivered</b><span>Every one tracked end to end, cash reconciled</span></div></div>
          <div class="lp-proof-row"><Icon name="truck" :size="15" /><div><b>{{ stats.active_carriers||0 }} carriers on the platform</b><span>Independent fleets, one shared standard</span></div></div>
          <div class="lp-proof-row"><Icon name="box" :size="15" /><div><b>{{ stats.shops||0 }} shops selling with delivery built in</b><span>Order on the marketplace, shipped tracked</span></div></div>
        </div>

      </section>

      <!-- RIGHT / BOTTOM: the actual sign-in, inline (no awkward slide-panel) -->
      <section class="lp-auth">
        <div class="auth-box">
          <div class="auth-head">
            <div class="auth-title">{{ signupMode ? 'Create your account' : 'Sign in' }}</div>
            <div class="auth-subtitle">{{ signupMode ? 'Choose what you\'re here to do' : 'Welcome back — enter your details' }}</div>
          </div>

          <!-- role tabs ONLY matter for creating an account -->
          <div v-if="signupMode" class="auth-role">
            <button v-for="r in ['carrier','driver','sender','receiver']" :key="r" class="role-pill" :class="{on:role===r}" @click="pickRole(r)">
              <Icon :name="r==='carrier'?'building':r==='driver'?'bike':r==='receiver'?'inbox':'box'" :size="15" /> {{ r==='carrier'?'Carrier':r==='driver'?'Driver':r==='receiver'?'Receive':'Business' }}
            </button>
          </div>
          <div v-if="signupMode" class="auth-role-label">{{ roleLabels[role] }}</div>

          <!-- EMAIL flow -->
          <template v-if="mode==='email' || !signupMode">
            <template v-if="showReset">
              <label class="fld">Email<input v-model="email" type="email" inputmode="email" autocomplete="email" placeholder="you@example.com" /></label>
              <p class="auth-note">We'll email you a link to reset your password.</p>
              <button class="auth-btn" :disabled="busy" @click="doReset"><Spinner v-if="busy" :size="16" /><span v-else>Send reset link</span></button>
              <button class="auth-link" @click="showReset=false">← Back to sign in</button>
            </template>
            <template v-else>
              <label v-if="signupMode && role==='receiver'" class="fld">Your name<input v-model="senderName" placeholder="e.g. Grace M." /></label>
              <template v-if="signupMode && role==='sender'">
                <label class="fld">Business name<input v-model="senderName" placeholder="e.g. Amina's Fabrics" /></label>
                <label class="fld">Location<input v-model="bizLocation" placeholder="e.g. Kariakoo, Dar es Salaam" /></label>
                <label class="fld">TIN <span class="fld-opt">optional</span><input v-model="bizTin" placeholder="Tax ID (if you have one)" /></label>
              </template>
              <template v-if="signupMode && role==='driver'">
                <label class="fld">Your name<input v-model="driverName" placeholder="e.g. Juma Hassan" /></label>
                <label class="fld">Phone <span class="fld-opt">links you to your carrier</span><input v-model="phone" type="tel" inputmode="tel" autocomplete="tel" placeholder="+255 7XX XXX XXX" /></label>
                <label class="fld">Vehicle <span class="fld-opt">optional</span><input v-model="driverVehicle" placeholder="e.g. Motorbike T123 ABC" /></label>
              </template>
              <label class="fld">Email<input v-model="email" type="email" inputmode="email" autocomplete="email" placeholder="you@example.com" @keyup.enter="doEmail" /></label>
              <label class="fld">Password<input v-model="password" type="password" :autocomplete="signupMode ? 'new-password' : 'current-password'" placeholder="••••••••" @keyup.enter="doEmail" /></label>
              <button class="auth-btn" :disabled="busy" @click="doEmail">
                <Spinner v-if="busy" :size="16" /><span v-else>{{ signupMode ? 'Create account' : 'Sign in' }}</span>
              </button>
              <div class="auth-links">
                <button class="auth-link" @click="signupMode=!signupMode">{{ signupMode ? 'Have an account? Sign in' : 'New here? Create an account' }}</button>
                <button v-if="!signupMode" class="auth-link" @click="showReset=true">Forgot password?</button>
              </div>
            </template>
          </template>

          <!-- PHONE flow (driver signup only) -->
          <template v-else>
            <template v-if="!otpSent">
              <template v-if="role==='driver'">
                <label class="fld">Your name<input v-model="driverName" placeholder="e.g. Juma Hassan" /></label>
                <label class="fld">Vehicle <span class="fld-opt">optional</span><input v-model="driverVehicle" placeholder="e.g. Motorbike T123 ABC" /></label>
              </template>
              <label class="fld">Phone number<input v-model="phone" type="tel" inputmode="tel" autocomplete="tel" placeholder="+255 7XX XXX XXX" @keyup.enter="doSendOtp" /></label>
              <button class="auth-btn" :disabled="busy" @click="doSendOtp"><Spinner v-if="busy" :size="16" /><span v-else>Send code</span></button>
              <p class="auth-note">We'll text you a one-time code to sign in.</p>
            </template>
            <template v-else>
              <label class="fld">Enter the 6-digit code<input v-model="otp" inputmode="numeric" maxlength="6" autocomplete="one-time-code" placeholder="000000" class="otp-input mono" @keyup.enter="doVerify" /></label>
              <button class="auth-btn" :disabled="busy" @click="doVerify"><Spinner v-if="busy" :size="16" /><span v-else>Verify & sign in</span></button>
              <button class="auth-link" @click="otpSent=false">← Change number</button>
            </template>
          </template>

          <div class="auth-secure"><Icon name="check" :size="12" /> Encrypted &amp; secure · Your data stays private</div>

          <div class="auth-foot">
            <Icon name="box" :size="13" /> Receiving a parcel? Just open the tracking link your sender shared — no account needed.
          </div>
        </div>
        <button class="lp-fleet-link" @click="showFleet=true"><Icon name="truck" :size="14" /> Operate a fleet? Apply to join as a carrier</button>
      </section>
    </div>

    <!-- FLEET OPERATOR APPLICATION -->
    <div v-if="showFleet" class="overlay" v-escape="() => { showFleet=false }" @click.self="showFleet=false">
      <div class="modal" style="max-width:460px">
        <div v-if="fleetSent" class="book-success">
          <div class="book-success-ic"><Icon name="check" :size="30" /></div>
          <div class="book-success-code" style="font-size:20px">Application received</div>
          <div class="book-success-sub">Thanks, {{ fleet.contact }}. The Enkiama Cargos team will review {{ fleet.company }} and reach out on {{ fleet.phone }}.</div>
          <button class="btn btn-accent btn-block" @click="showFleet=false; fleetSent=false">Done</button>
        </div>
        <template v-else>
          <h3>Operate a fleet on Enkiama</h3>
          <p>Run trucks or bajaji? Apply to join the platform — carry parcels for senders across the network, with tracking and cash handled for you.</p>
          <div class="row2">
            <div class="fg"><label>Company name <span class="req">*</span></label><input v-model="fleet.company" placeholder="e.g. Mwanza Movers" /></div>
            <div class="fg"><label>Your name <span class="req">*</span></label><input v-model="fleet.contact" placeholder="Contact person" /></div>
          </div>
          <div class="row2">
            <div class="fg"><label>Phone <span class="req">*</span></label><input v-model="fleet.phone" type="tel" inputmode="tel" placeholder="+255…" /></div>
            <div class="fg"><label>Email <span class="opt">optional</span></label><input v-model="fleet.email" type="email" inputmode="email" placeholder="you@company.co.tz" /></div>
          </div>
          <div class="fg"><label>Where do you operate? <span class="opt">optional</span></label><input v-model="fleet.region" placeholder="e.g. Dar es Salaam ↔ Mwanza" /></div>
          <div class="fg"><label>Tell us about your fleet <span class="opt">optional</span></label><input v-model="fleet.note" placeholder="e.g. 12 trucks, daily northern routes" /></div>
          <div class="confirm-actions">
            <button class="btn btn-ghost" @click="showFleet=false">Cancel</button>
            <button class="btn btn-accent" :disabled="busy" @click="submitFleet"><Spinner v-if="busy" :size="15" /><span v-else>Submit application</span></button>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
.lp{min-height:100vh;position:relative;background:var(--nav);padding:0 0 40px;overflow:hidden}
.lp::before{content:'';position:absolute;inset:0;pointer-events:none;background:
  radial-gradient(900px 600px at 78% -8%, rgba(67,56,202,.35), transparent 60%),
  radial-gradient(700px 500px at 10% 110%, rgba(55,48,217,.18), transparent 55%),
  radial-gradient(500px 400px at 95% 90%, rgba(15,157,88,.1), transparent 60%)}
.lp::after{content:'';position:absolute;inset:0;pointer-events:none;opacity:.4;
  background-image:linear-gradient(rgba(255,255,255,.03) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.03) 1px,transparent 1px);
  background-size:44px 44px;mask-image:radial-gradient(circle at 30% 40%,black,transparent 75%)}
.lp>*{position:relative;z-index:1}
.lp-top{display:flex;align-items:center;justify-content:space-between;padding:22px 24px;max-width:1140px;margin:0 auto}
.lp-brand{display:flex;align-items:center;gap:10px;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:16px;color:#fff}
.lp-brand-name{letter-spacing:-.01em}
.lp-live{display:inline-flex;align-items:center;gap:7px;font-size:12px;font-weight:600;color:#fff;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.12);padding:6px 12px;border-radius:var(--r-full)}
.lp-dot{width:7px;height:7px;border-radius:50%;background:#34D399;box-shadow:0 0 8px #34D399;animation:pl 1.8s infinite}
@keyframes pl{0%{box-shadow:0 0 0 0 rgba(52,211,153,.5)}70%{box-shadow:0 0 0 7px transparent}100%{box-shadow:0 0 0 0 transparent}}

.lp-grid{max-width:1080px;margin:0 auto;padding:32px 24px 60px;display:grid;gap:36px;grid-template-columns:1fr}
@media(min-width:920px){.lp-grid{grid-template-columns:1fr .85fr;gap:64px;align-items:center;padding-top:72px}}

.lp-h1{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:clamp(38px,11vw,64px);line-height:1.02;letter-spacing:-.03em;color:#fff;margin-top:8px}
.grad{background:linear-gradient(100deg,#818CF8,#34D399);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.lp-sub{color:rgba(255,255,255,.62);font-size:16px;line-height:1.65;margin-top:20px;max-width:32em}

.lp-stats{display:flex;gap:32px;margin-top:36px;flex-wrap:wrap;padding-top:28px;border-top:1px solid rgba(255,255,255,.1)}
.lp-sv{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:23px;color:#fff;letter-spacing:-.02em;font-variant-numeric:tabular-nums}
.lp-sv.mono{font-size:18px}
.lp-sl{font-size:12px;color:rgba(255,255,255,.5);margin-top:3px}

.lp-feed{margin-top:28px;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);border-radius:16px;padding:16px;backdrop-filter:blur(8px)}
.lp-feed-hd{margin-bottom:8px}
.lp-feed-list{display:flex;flex-direction:column}
.lp-feed-row{display:flex;align-items:center;gap:10px;padding:9px 0;border-bottom:1px solid rgba(255,255,255,.07);font-size:13px}
.lp-feed-row:last-child{border-bottom:none}
.lp-code{font-weight:700;font-size:12px;flex-shrink:0;width:64px}
.lp-who{color:rgba(255,255,255,.72);flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.lp-ev{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.03em;padding:3px 8px;border-radius:8px;flex-shrink:0}
.ev-booked{background:var(--surface-2);color:var(--ink-soft)}
.ev-collected,.ev-linehaul{background:var(--accent-soft);color:var(--accent-ink)}
.ev-delivered,.ev-confirmed{background:var(--go-soft);color:var(--go-ink)}
.ev-cash{background:var(--owed-soft);color:var(--owed-ink)}
.feed-enter-active{transition:all .5s cubic-bezier(.16,1,.3,1)}
.feed-enter-from{opacity:0;transform:translateY(-10px)}
.feed-leave-active{transition:all .3s;position:absolute;width:100%}
.feed-leave-to{opacity:0}
.feed-move{transition:transform .4s cubic-bezier(.16,1,.3,1)}

.lp-auth{position:relative}
@media(min-width:920px){.lp-auth{position:sticky;top:40px}}
.auth-box{background:linear-gradient(180deg,#FFFFFF,#FCFCFE);border:1px solid rgba(255,255,255,.9);border-radius:22px;padding:30px 28px;
  box-shadow:0 0 0 1px rgba(11,14,20,.04),0 2px 4px rgba(11,14,20,.04),0 12px 32px rgba(11,14,20,.14),0 40px 80px rgba(11,14,20,.16)}
.auth-role{display:flex;gap:6px;background:var(--surface-2);padding:5px;border-radius:12px;margin-bottom:6px}
.role-pill{flex:1;display:flex;align-items:center;justify-content:center;gap:6px;padding:11px 8px;border:none;background:transparent;border-radius:8px;font-family:inherit;font-weight:600;font-size:13px;color:var(--ink-faint);cursor:pointer;transition:.15s}
.role-pill.on{background:var(--surface);color:var(--ink);box-shadow:var(--shadow-sm)}
.auth-role-label{font-size:12px;color:var(--ink-faint);margin:12px 2px 16px;font-weight:500}
.fld{display:block;font-size:12px;font-weight:650;color:var(--ink-soft);margin-bottom:16px;letter-spacing:.01em}
.fld input{width:100%;margin-top:8px;padding:14px 15px;border:1px solid var(--hairline-2);border-radius:12px;font-size:15px;font-family:inherit;background:var(--surface-2);color:var(--ink);transition:border-color .18s ease,box-shadow .18s ease,background .18s ease;box-shadow:inset 0 1px 2px rgba(11,14,20,.03)}
.fld input:focus{outline:none;border-color:var(--accent);background:#fff;box-shadow:0 0 0 4px var(--accent-soft),inset 0 1px 2px rgba(11,14,20,.02)}
.otp-input{letter-spacing:.4em;text-align:center;font-size:22px !important}
.auth-btn{width:100%;padding:15px 24px;border:none;border-radius:14px;background:linear-gradient(180deg,#4B40E0,var(--accent));color:#fff;font-family:inherit;font-weight:650;font-size:15px;letter-spacing:-.01em;cursor:pointer;transition:transform var(--dur-fast) var(--ease),box-shadow var(--dur-fast) var(--ease),filter var(--dur-fast) var(--ease);display:flex;align-items:center;justify-content:center;gap:8px;box-shadow:inset 0 1px 0 rgba(255,255,255,.18),0 1px 2px rgba(45,38,140,.4),0 4px 12px rgba(55,48,217,.32),0 8px 24px rgba(55,48,217,.2)}
.auth-btn:hover:not(:disabled){filter:brightness(1.06);transform:translateY(-1.5px);box-shadow:inset 0 1px 0 rgba(255,255,255,.22),0 2px 4px rgba(45,38,140,.4),0 8px 20px rgba(55,48,217,.42),0 14px 34px rgba(55,48,217,.28)}
.auth-btn:active{transform:translateY(1px) scale(.99)}
.auth-btn:active{transform:translateY(1px) scale(.99)} .auth-btn:disabled{opacity:.6}
.auth-links{display:flex;justify-content:space-between;margin-top:14px;gap:10px}
.auth-link{background:none;border:none;color:var(--accent-ink);font-family:inherit;font-weight:600;font-size:13px;cursor:pointer;padding:4px 0}
.auth-note{font-size:12px;color:var(--ink-faint);margin:12px 2px 0;line-height:1.5}
.auth-foot{margin-top:20px;padding-top:16px;border-top:1px solid var(--hairline);font-size:12px;color:var(--ink-faint);line-height:1.5;display:flex;gap:8px;align-items:flex-start}
.auth-foot svg{flex-shrink:0;margin-top:1px;color:var(--ink-ghost)}

.lp-quick{display:flex;align-items:center;flex-wrap:wrap;gap:16px;margin-top:28px}
.lp-quick-link{display:inline-flex;align-items:center;gap:7px;font-size:14px;font-weight:600;color:#fff;text-decoration:none;padding:10px 18px;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.14);border-radius:var(--r-full);transition:all var(--dur-fast) var(--ease)}
.lp-quick-link:hover{border-color:var(--accent);background:var(--accent-soft)}
.lp-quick-note{font-size:13px;color:rgba(255,255,255,.45)}
.lp-fleet-link{display:flex;align-items:center;justify-content:center;gap:7px;width:100%;margin-top:16px;padding:12px;background:none;border:none;color:rgba(255,255,255,.5);font-size:13px;font-family:inherit;cursor:pointer;border-radius:var(--r);transition:color var(--dur-fast) var(--ease)}
.lp-fleet-link:hover{color:#fff}
.auth-head{margin-bottom:18px}
.auth-title{font-family:"Space Grotesk",sans-serif;font-size:22px;font-weight:700;color:var(--ink);letter-spacing:-.03em}
.auth-subtitle{font-size:13px;color:var(--ink-faint);margin-top:3px}

.auth-secure{display:flex;align-items:center;justify-content:center;gap:6px;font-size:11.5px;color:var(--go-ink);font-weight:600;margin-top:16px;padding-top:14px;border-top:1px solid var(--hairline)}
.auth-secure :deep(svg){color:var(--go)}

.lp-proof{margin-top:28px;display:flex;flex-direction:column;gap:2px;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.1);border-radius:16px;padding:8px;backdrop-filter:blur(8px)}
.lp-proof-row{display:flex;align-items:center;gap:12px;padding:12px 12px}
.lp-proof-row:not(:last-child){border-bottom:1px solid rgba(255,255,255,.06)}
.lp-proof-row :deep(svg){color:#34D399;flex-shrink:0}
.lp-proof-row b{display:block;color:#fff;font-size:14px;font-weight:650;letter-spacing:-.01em}
.lp-proof-row span{display:block;color:rgba(255,255,255,.5);font-size:12.5px;margin-top:2px}
</style>
