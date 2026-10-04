<script setup>
import { ref, computed, onMounted, onUnmounted, inject } from 'vue'
import { usePublic } from '../composables/usePublic'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { supabase } from '../lib/supabase'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import AppHeader from '../components/AppHeader.vue'

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
const CARRIERS = [['USIRI','#3E5BD6'],['Sumry','#137A5E'],['Kimoto','#B4472B'],['Enkiama','#0B6E5D']]
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
    <AppHeader title="Access" subtitle="Sign in or create an account" :auth="false" />

    <div class="lp-grid">
      <!-- LEFT / TOP: pitch + proof -->
      <section class="lp-pitch">
        <h1 class="lp-h1">One system,<br><span class="grad">clear records.</span></h1>
        <p class="lp-sub">Commerce, property and movement in one operating system — with identity, context and custody kept close to every decision.</p>

        <div class="lp-quick">
          <router-link to="/track" class="lp-quick-link"><Icon name="pin" :size="16" /> Track a parcel</router-link>
          <router-link to="/market" class="lp-quick-link"><Icon name="box" :size="16" /> Browse the market</router-link>
          <router-link to="/property" class="lp-quick-link"><Icon name="pin" :size="16" /> Explore property</router-link>
          <span class="lp-quick-note">No account needed</span>
        </div>

        <div class="lp-stats" v-if="stats">
          <div class="lp-stat"><div class="lp-sv mono">{{ (stats.total_parcels||0).toLocaleString() }}</div><div class="lp-sl">movements recorded</div></div>
          <div class="lp-stat"><div class="lp-sv mono">{{ stats.active_carriers||0 }}</div><div class="lp-sl">active carriers</div></div>
          <div class="lp-stat"><div class="lp-sv mono">{{ stats.regions||0 }}</div><div class="lp-sl">regions served</div></div>
        </div>

        <!-- real value proof, not fake activity -->
        <div class="lp-proof" v-if="stats">
          <div class="lp-proof-row"><Icon name="check" :size="15" /><div><b>{{ (stats.delivered||0).toLocaleString() }} deliveries completed</b><span>Movement recorded end to end, including reconciliation where applicable</span></div></div>
          <div class="lp-proof-row"><Icon name="truck" :size="15" /><div><b>{{ stats.active_carriers||0 }} carriers active</b><span>Independent operators working through one movement standard</span></div></div>
          <div class="lp-proof-row"><Icon name="box" :size="15" /><div><b>{{ stats.shops||0 }} shops in the market</b><span>Products and delivery remain connected to the same transaction record</span></div></div>
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
.lp{min-height:100svh;background:var(--world-canvas);color:var(--world-ink);padding-bottom:56px;position:relative;overflow:hidden}
.lp::before{content:"";position:absolute;inset:0;pointer-events:none;background:radial-gradient(900px 460px at 12% 2%,color-mix(in srgb,var(--world-accent-soft) 58%,transparent),transparent 68%),linear-gradient(90deg,transparent 49.92%,var(--world-line) 50%,transparent 50.08%);opacity:.7}
.lp>*{position:relative;z-index:1}
.lp-grid{width:min(1120px,calc(100% - 48px));margin:0 auto;padding:72px 0 64px;display:grid;grid-template-columns:minmax(0,1fr) minmax(360px,440px);gap:clamp(56px,8vw,120px);align-items:start}
.lp-pitch{padding-top:34px;max-width:610px}.lp-h1{font:550 clamp(48px,6vw,78px)/.93 var(--font-display);letter-spacing:-.065em;color:var(--world-ink);max-width:8.8ch}.grad{font-family:var(--font-editorial);font-style:italic;font-weight:500;color:var(--world-highlight)}
.lp-sub{font-size:15px;line-height:1.72;color:var(--world-ink-soft);margin-top:24px;max-width:42ch}
.lp-quick{display:flex;align-items:center;flex-wrap:wrap;gap:20px;margin-top:30px;padding-top:18px;border-top:1px solid var(--world-line)}
.lp-quick-link{display:inline-flex;align-items:center;gap:7px;font-size:12px;font-weight:650;color:var(--world-ink);text-decoration:none;padding:5px 0;border-bottom:1px solid var(--world-line-strong)}.lp-quick-link:hover{border-color:var(--world-ink)}.lp-quick-note{font-size:10px;color:var(--world-ink-faint);font-family:var(--font-mono);text-transform:uppercase;letter-spacing:.05em}
.lp-stats{display:grid;grid-template-columns:repeat(3,1fr);gap:0;margin-top:42px;border-block:1px solid var(--world-line)}.lp-stat{padding:16px 18px 16px 0}.lp-stat+.lp-stat{border-left:1px solid var(--world-line);padding-left:18px}.lp-sv{font:600 18px/1 var(--font-display);color:var(--world-ink);font-variant-numeric:tabular-nums}.lp-sv.mono{font-size:15px}.lp-sl{font-size:10px;color:var(--world-ink-faint);margin-top:6px;text-transform:uppercase;letter-spacing:.04em}
.lp-proof{margin-top:26px;border-top:1px solid var(--world-line)}.lp-proof-row{display:grid;grid-template-columns:20px 1fr;gap:11px;padding:14px 0;border-bottom:1px solid var(--world-line)}.lp-proof-row :deep(svg){color:var(--world-accent);margin-top:2px}.lp-proof-row b{display:block;color:var(--world-ink);font-size:12.5px;font-weight:650}.lp-proof-row span{display:block;color:var(--world-ink-faint);font-size:11.5px;margin-top:2px;line-height:1.45}
.lp-auth{position:sticky;top:96px}.auth-box{background:color-mix(in srgb,var(--world-surface) 94%,#fff);border:1px solid var(--world-line);border-radius:10px;padding:28px;box-shadow:0 24px 70px rgba(25,28,24,.08)}
.auth-head{margin-bottom:22px;padding-bottom:18px;border-bottom:1px solid var(--world-line)}.auth-title{font:600 22px/1.08 var(--font-display);color:var(--world-ink);letter-spacing:-.035em}.auth-subtitle{font-size:12px;color:var(--world-ink-faint);margin-top:6px}
.auth-role{display:grid;grid-template-columns:repeat(4,1fr);border:1px solid var(--world-line);border-radius:6px;overflow:hidden;margin-bottom:7px;background:transparent}.role-pill{display:flex;align-items:center;justify-content:center;gap:5px;min-height:42px;padding:8px 5px;border:0;border-right:1px solid var(--world-line);background:transparent;color:var(--world-ink-faint);font:600 10.5px var(--font-body);cursor:pointer}.role-pill:last-child{border-right:0}.role-pill.on{background:var(--world-ink);color:var(--world-surface)}.auth-role-label{font-size:11px;color:var(--world-ink-faint);margin:9px 1px 18px}
.fld{display:block;font:600 10px/1.2 var(--font-mono);letter-spacing:.065em;text-transform:uppercase;color:var(--world-ink-faint);margin-bottom:17px}.fld-opt{font-family:var(--font-body);text-transform:none;letter-spacing:0;font-weight:500}.fld input{width:100%;margin-top:7px;min-height:46px;padding:11px 12px;border:1px solid var(--util-line);border-radius:6px;background:var(--util-surface);color:var(--world-ink);font:500 14px var(--font-body);box-shadow:none}.fld input:focus{outline:none;border-color:var(--world-accent);box-shadow:0 0 0 3px var(--util-focus);background:var(--world-surface)}.otp-input{letter-spacing:.35em;text-align:center;font-size:18px!important}
.auth-btn{width:100%;min-height:48px;border:1px solid var(--world-ink);border-radius:6px;background:var(--world-ink);color:var(--world-surface);font:650 13px var(--font-body);cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;box-shadow:none}.auth-btn:hover:not(:disabled){background:color-mix(in srgb,var(--world-ink) 90%,var(--world-accent));transform:none}.auth-btn:disabled{opacity:.55}
.auth-links{display:flex;justify-content:space-between;align-items:center;margin-top:13px;gap:12px}.auth-link{background:none;border:0;color:var(--world-ink-soft);font:600 11px var(--font-body);cursor:pointer;padding:4px 0;border-bottom:1px solid transparent}.auth-link:hover{color:var(--world-ink);border-color:var(--world-line-strong)}.auth-note{font-size:11.5px;color:var(--world-ink-faint);margin:10px 0 14px;line-height:1.55}
.auth-secure{display:flex;align-items:center;justify-content:flex-start;gap:6px;font-size:9.5px;color:var(--world-ink-faint);font-family:var(--font-mono);text-transform:uppercase;letter-spacing:.04em;margin-top:17px;padding-top:14px;border-top:1px solid var(--world-line)}.auth-secure :deep(svg){color:var(--world-accent)}.auth-foot{margin-top:14px;padding-top:14px;border-top:1px solid var(--world-line);font-size:11px;color:var(--world-ink-faint);line-height:1.5;display:flex;gap:8px}.auth-foot :deep(svg){flex:0 0 auto;margin-top:2px}
.lp-fleet-link{display:flex;align-items:center;justify-content:flex-start;gap:7px;width:100%;margin-top:12px;padding:9px 0;background:none;border:0;color:var(--world-ink-faint);font:600 11px var(--font-body);cursor:pointer}.lp-fleet-link:hover{color:var(--world-ink)}
@media(max-width:900px){.lp-grid{grid-template-columns:1fr;width:min(720px,calc(100% - 36px));padding-top:42px;gap:44px}.lp-pitch{padding-top:0}.lp-auth{position:static}.lp-h1{font-size:clamp(46px,12vw,70px)}}
@media(max-width:560px){.lp-grid{width:calc(100% - 28px);padding-top:28px}.lp-h1{font-size:clamp(44px,14vw,62px)}.lp-stats{grid-template-columns:1fr}.lp-stat,.lp-stat+.lp-stat{border-left:0;border-bottom:1px solid var(--world-line);padding:13px 0}.lp-stat:last-child{border-bottom:0}.auth-box{padding:22px 18px}.auth-role{grid-template-columns:1fr 1fr}.role-pill:nth-child(2){border-right:0}.role-pill:nth-child(-n+2){border-bottom:1px solid var(--world-line)}.auth-links{align-items:flex-start;flex-direction:column}.fld input{font-size:16px}}
</style>