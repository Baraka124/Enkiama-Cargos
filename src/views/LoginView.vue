<script setup>
import { ref, computed, onMounted, onUnmounted, inject } from 'vue'
import { usePublic } from '../composables/usePublic'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import BrandMark from '../components/BrandMark.vue'

const router = useRouter()
const toast = inject('toast')
const pub = usePublic()
const { signInEmail, signUpEmail, signUpSender, signUpReceiver, sendPhoneOtp, verifyPhoneOtp, sendPasswordReset, reloadProfile } = useAuth()

// ── auth state (all logic preserved) ──
const mode = ref('email')            // email | phone
const role = ref('carrier')          // carrier | driver | sender
const email = ref(''); const password = ref('')
const phone = ref(''); const otp = ref(''); const otpSent = ref(false)
const senderName = ref('')
const busy = ref(false)
const showReset = ref(false)
const signupMode = ref(false)

async function doEmail() {
  if (!email.value || !password.value) { toast('Email and password required', 'warn'); return }
  busy.value = true
  try {
    if (signupMode.value && role.value === 'sender') {
      await signUpSender(email.value, password.value, senderName.value || 'Sender')
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
  try { await verifyPhoneOtp(phone.value, otp.value); await reloadProfile(); router.push('/') }
  catch (e) { toast(e.message || 'Wrong code', 'warn') }
  busy.value = false
}
function pickRole(r) {
  role.value = r
  mode.value = (r === 'driver') ? 'phone' : 'email'
  signupMode.value = false; showReset.value = false; otpSent.value = false
}

// ── live ledger (kept, drives the proof strip) ──
const parcelsToday = ref(2841)
const onRoad = ref(63)
const settledTZS = ref(48920000)
const carriersLive = ref(11)
const NAMES = ['Grace Mwangi','Peter Otieno','Neema Joseph','Hamisi Bakari','John Mkwawa','Asha Salum','Baraka Omari','Zainab Ali','Juma Hassan','Rehema Said']
const PLACES = ['Mikocheni','Kariakoo','Msasani','Uyole','Kimara','Tabata','Mbezi','Sinza','Ilala','Temeke']
const CARRIERS = [['USIRI','#3E5BD6'],['Sumry','#137A5E'],['Kimoto','#B4472B'],['Enkiama','#C08A2D']]
const EVENTS = [['booked','booked'],['collected','collected'],['on road','linehaul'],['delivered','delivered'],['cash collected','cash'],['confirmed','confirmed']]
const feed = ref([])
let code = 4470
function makeEvent() {
  code++
  const c = CARRIERS[Math.floor(Math.random()*CARRIERS.length)]
  const ev = EVENTS[Math.floor(Math.random()*EVENTS.length)]
  return { id: code+'-'+Math.random(), code: c[0].slice(0,3).toUpperCase()+'-'+code,
    who: NAMES[Math.floor(Math.random()*NAMES.length)], place: PLACES[Math.floor(Math.random()*PLACES.length)],
    carrier: c[0], accent: c[1], ev: ev[0], evClass: ev[1] }
}
let timers = []
onMounted(() => {
  // surface any auth error captured before boot (expired link, etc.)
  try {
    const notice = sessionStorage.getItem('auth_notice')
    if (notice) { toast(notice, 'warn'); sessionStorage.removeItem('auth_notice') }
  } catch (e) {}
  for (let i=0;i<5;i++) feed.value.push(makeEvent())
  timers.push(setInterval(() => { feed.value.unshift(makeEvent()); if (feed.value.length>6) feed.value.pop() }, 2400))
  timers.push(setInterval(() => {
    parcelsToday.value += Math.floor(Math.random()*3)
    if (Math.random()>0.6) onRoad.value += (Math.random()>0.5?1:-1)
    onRoad.value = Math.max(40, Math.min(90, onRoad.value))
    settledTZS.value += Math.floor(Math.random()*40000)
  }, 1900))
})
onUnmounted(() => timers.forEach(clearInterval))
const settledStr = computed(() => 'TZS ' + settledTZS.value.toLocaleString())

const roleLabels = { carrier: 'Carrier team', driver: 'Driver', sender: 'Sending a parcel', receiver: 'Receiving parcels' }

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
      <span class="lp-live"><span class="lp-dot"></span>{{ carriersLive }} carriers live</span>
    </header>

    <div class="lp-grid">
      <!-- LEFT / TOP: pitch + proof -->
      <section class="lp-pitch">
        <h1 class="lp-h1">One parcel,<br><span class="grad">one truth.</span></h1>
        <p class="lp-sub">The ledger every road-freight carrier runs on — movement and money, tracked end to end, for every hand that touches the cargo.</p>

        <div class="lp-doors">
          <button class="lp-door" @click="pickRole('receiver'); scrollToAuth()"><Icon name="inbox" :size="18" /><div><div class="lp-door-t">My deliveries</div><div class="lp-door-s">See all parcels coming to you</div></div></button>
          <router-link to="/track" class="lp-door"><Icon name="pin" :size="18" /><div><div class="lp-door-t">Quick track</div><div class="lp-door-s">One parcel, no account</div></div></router-link>
          <router-link to="/market" class="lp-door"><Icon name="box" :size="18" /><div><div class="lp-door-t">Browse the marketplace</div><div class="lp-door-s">Shops that deliver, tracked</div></div></router-link>
          <button class="lp-door" @click="pickRole('sender'); scrollToAuth()"><Icon name="box" :size="18" /><div><div class="lp-door-t">Send a parcel</div><div class="lp-door-s">Ship via any carrier</div></div></button>
          <button class="lp-door" @click="showFleet=true"><Icon name="truck" :size="18" /><div><div class="lp-door-t">Operate a fleet</div><div class="lp-door-s">Join as a carrier</div></div></button>
        </div>

        <div class="lp-stats">
          <div class="lp-stat"><div class="lp-sv">{{ parcelsToday.toLocaleString() }}</div><div class="lp-sl">parcels today</div></div>
          <div class="lp-stat"><div class="lp-sv">{{ onRoad }}</div><div class="lp-sl">on the road now</div></div>
          <div class="lp-stat"><div class="lp-sv mono">{{ settledStr }}</div><div class="lp-sl">settled today</div></div>
        </div>

        <!-- live feed — now a proper responsive card, visible on mobile -->
        <div class="lp-feed">
          <div class="lp-feed-hd"><span class="lp-live"><span class="lp-dot"></span>Live ledger</span></div>
          <transition-group name="feed" tag="div" class="lp-feed-list">
            <div v-for="f in feed" :key="f.id" class="lp-feed-row">
              <span class="lp-code mono" :style="{color:f.accent}">{{ f.code }}</span>
              <span class="lp-who">{{ f.who }} · {{ f.place }}</span>
              <span class="lp-ev" :class="'ev-'+f.evClass">{{ f.ev }}</span>
            </div>
          </transition-group>
        </div>
      </section>

      <!-- RIGHT / BOTTOM: the actual sign-in, inline (no awkward slide-panel) -->
      <section class="lp-auth">
        <div class="auth-box">
          <div class="auth-role">
            <button v-for="r in ['carrier','driver','sender','receiver']" :key="r" class="role-pill" :class="{on:role===r}" @click="pickRole(r)">
              <Icon :name="r==='carrier'?'building':r==='driver'?'bike':r==='receiver'?'inbox':'box'" :size="15" /> {{ r==='carrier'?'Carrier':r==='driver'?'Driver':r==='receiver'?'Receive':'Send' }}
            </button>
          </div>
          <div class="auth-role-label">{{ roleLabels[role] }}</div>

          <!-- EMAIL flow (carrier / sender) -->
          <template v-if="mode==='email'">
            <template v-if="showReset">
              <label class="fld">Email<input v-model="email" type="email" inputmode="email" placeholder="you@carrier.co.tz" /></label>
              <p class="auth-note">We'll email you a link to reset your password.</p>
              <button class="auth-btn" :disabled="busy" @click="doReset"><Spinner v-if="busy" :size="16" /><span v-else>Send reset link</span></button>
              <button class="auth-link" @click="showReset=false">← Back to sign in</button>
            </template>
            <template v-else>
              <label v-if="signupMode && role==='sender'" class="fld">Your name<input v-model="senderName" placeholder="e.g. Grace M." /></label>
              <label class="fld">Email<input v-model="email" type="email" inputmode="email" placeholder="you@carrier.co.tz" @keyup.enter="doEmail" /></label>
              <label class="fld">Password<input v-model="password" type="password" placeholder="••••••••" @keyup.enter="doEmail" /></label>
              <button class="auth-btn" :disabled="busy" @click="doEmail">
                <Spinner v-if="busy" :size="16" /><span v-else>{{ signupMode ? 'Create account' : 'Sign in' }}</span>
              </button>
              <div class="auth-links">
                <button class="auth-link" @click="signupMode=!signupMode">{{ signupMode ? 'Have an account? Sign in' : 'Create account' }}</button>
                <button v-if="!signupMode" class="auth-link" @click="showReset=true">Forgot password?</button>
              </div>
            </template>
          </template>

          <!-- PHONE flow (driver) -->
          <template v-else>
            <template v-if="!otpSent">
              <label class="fld">Phone number<input v-model="phone" type="tel" inputmode="tel" placeholder="+255 7XX XXX XXX" @keyup.enter="doSendOtp" /></label>
              <button class="auth-btn" :disabled="busy" @click="doSendOtp"><Spinner v-if="busy" :size="16" /><span v-else>Send code</span></button>
              <p class="auth-note">We'll text you a one-time code to sign in.</p>
            </template>
            <template v-else>
              <label class="fld">Enter the 6-digit code<input v-model="otp" inputmode="numeric" maxlength="6" placeholder="000000" class="otp-input mono" @keyup.enter="doVerify" /></label>
              <button class="auth-btn" :disabled="busy" @click="doVerify"><Spinner v-if="busy" :size="16" /><span v-else>Verify & sign in</span></button>
              <button class="auth-link" @click="otpSent=false">← Change number</button>
            </template>
          </template>

          <div class="auth-foot">
            <Icon name="box" :size="13" /> Receiving a parcel? Just open the tracking link your sender shared — no account needed.
          </div>
        </div>
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
.lp{min-height:100vh;background:
  radial-gradient(1200px 500px at 80% -10%, var(--accent-soft), transparent 60%),
  var(--paper);padding:0 0 40px}
.lp-top{display:flex;align-items:center;justify-content:space-between;padding:18px 20px;max-width:1140px;margin:0 auto}
.lp-brand{display:flex;align-items:center;gap:10px;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:17px;color:var(--ink)}
.lp-brand-name{letter-spacing:-.01em}
.lp-live{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:600;color:var(--go-ink)}
.lp-dot{width:7px;height:7px;border-radius:50%;background:var(--go);animation:pl 1.8s infinite}
@keyframes pl{0%{box-shadow:0 0 0 0 var(--go-soft)}70%{box-shadow:0 0 0 6px transparent}100%{box-shadow:0 0 0 0 transparent}}

.lp-grid{max-width:1140px;margin:0 auto;padding:12px 20px;display:grid;gap:28px;grid-template-columns:1fr}
@media(min-width:920px){.lp-grid{grid-template-columns:1.1fr .9fr;gap:48px;align-items:start;padding-top:40px}}

.lp-h1{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:clamp(38px,11vw,64px);line-height:1.02;letter-spacing:-.03em;color:var(--ink);margin-top:8px}
.grad{background:linear-gradient(100deg,var(--accent),var(--go));-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.lp-sub{color:var(--ink-soft);font-size:15.5px;line-height:1.6;margin-top:16px;max-width:34em}

.lp-stats{display:flex;gap:26px;margin-top:26px;flex-wrap:wrap}
.lp-sv{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:23px;color:var(--ink);letter-spacing:-.02em}
.lp-sv.mono{font-size:18px}
.lp-sl{font-size:12px;color:var(--ink-faint);margin-top:3px}

.lp-feed{margin-top:28px;background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:14px 16px;box-shadow:var(--shadow-sm)}
.lp-feed-hd{margin-bottom:8px}
.lp-feed-list{display:flex;flex-direction:column}
.lp-feed-row{display:flex;align-items:center;gap:10px;padding:9px 0;border-bottom:1px solid var(--hairline);font-size:13px}
.lp-feed-row:last-child{border-bottom:none}
.lp-code{font-weight:700;font-size:12px;flex-shrink:0;width:64px}
.lp-who{color:var(--ink-soft);flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.lp-ev{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.03em;padding:3px 8px;border-radius:6px;flex-shrink:0}
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
.auth-box{background:var(--surface);border:1px solid var(--hairline);border-radius:20px;padding:22px;box-shadow:var(--shadow-lg)}
.auth-role{display:flex;gap:6px;background:var(--surface-2);padding:5px;border-radius:13px;margin-bottom:6px}
.role-pill{flex:1;display:flex;align-items:center;justify-content:center;gap:6px;padding:11px 8px;border:none;background:transparent;border-radius:9px;font-family:inherit;font-weight:600;font-size:13px;color:var(--ink-faint);cursor:pointer;transition:.15s}
.role-pill.on{background:var(--surface);color:var(--ink);box-shadow:var(--shadow-sm)}
.auth-role-label{font-size:12px;color:var(--ink-faint);margin:12px 2px 16px;font-weight:500}
.fld{display:block;font-size:12.5px;font-weight:600;color:var(--ink-soft);margin-bottom:14px}
.fld input{width:100%;margin-top:7px;padding:13px 14px;border:1px solid var(--hairline-2);border-radius:12px;font-size:16px;font-family:inherit;background:var(--surface);color:var(--ink);transition:.15s}
.fld input:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px var(--accent-soft)}
.otp-input{letter-spacing:.4em;text-align:center;font-size:22px !important}
.auth-btn{width:100%;padding:15px;border:none;border-radius:13px;background:var(--accent);color:#fff;font-family:inherit;font-weight:650;font-size:15.5px;cursor:pointer;transition:.16s;display:flex;align-items:center;justify-content:center;gap:8px;box-shadow:var(--shadow-sm)}
.auth-btn:hover:not(:disabled){background:var(--accent-ink);box-shadow:var(--shadow-md)}
.auth-btn:active{transform:translateY(1px)} .auth-btn:disabled{opacity:.6}
.auth-links{display:flex;justify-content:space-between;margin-top:14px;gap:10px}
.auth-link{background:none;border:none;color:var(--accent-ink);font-family:inherit;font-weight:600;font-size:13px;cursor:pointer;padding:4px 0}
.auth-note{font-size:12.5px;color:var(--ink-faint);margin:12px 2px 0;line-height:1.5}
.auth-foot{margin-top:20px;padding-top:16px;border-top:1px solid var(--hairline);font-size:12px;color:var(--ink-faint);line-height:1.5;display:flex;gap:8px;align-items:flex-start}
.auth-foot svg{flex-shrink:0;margin-top:1px;color:var(--ink-ghost)}
</style>
