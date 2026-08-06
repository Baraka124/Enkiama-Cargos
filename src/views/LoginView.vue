<script setup>
import { ref, onMounted, onUnmounted, inject, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'

const router = useRouter()
const toast = inject('toast')
const { signInEmail, signUpEmail, signUpSender, sendPhoneOtp, verifyPhoneOtp, sendPasswordReset, reloadProfile } = useAuth()

const panelOpen = ref(false)
const mode = ref('email')
const email = ref(''); const password = ref('')
const phone = ref(''); const otp = ref(''); const otpSent = ref(false)
const busy = ref(false)
const senderName = ref('')
const showReset = ref(false)

function openPanel(m = 'email') { mode.value = m; panelOpen.value = true }

async function doReset() {
  if (!email.value) { toast('Enter your email first', 'warn'); return }
  busy.value = true
  try { await sendPasswordReset(email.value); toast('Reset link sent — check your inbox', 'ok'); showReset.value = false }
  catch (e) { toast(e.message, 'warn') }
  busy.value = false
}

// sign up as a SENDER — atomic: v11 trigger creates the profile
async function doSenderSignup() {
  if (!email.value || !password.value) { toast('Email and password required', 'warn'); return }
  if (password.value.length < 8) { toast('Password needs at least 8 characters', 'warn'); return }
  busy.value = true
  try {
    await signUpSender(email.value, password.value, senderName.value || 'Sender')
    toast('Account created — check your email to verify, then sign in', 'ok')
    mode.value = 'email'
  } catch (e) { toast(e.message || 'Sign-up failed', 'warn') }
  busy.value = false
}

async function doEmail(signup) {
  busy.value = true
  try {
    if (signup) { await signUpEmail(email.value, password.value); toast('Account created', 'ok') }
    else await signInEmail(email.value, password.value)
    await reloadProfile(); router.push('/')
  } catch (e) { toast(e.message || 'Sign-in failed', 'warn') }
  busy.value = false
}
async function doSendOtp() {
  busy.value = true
  try { await sendPhoneOtp(phone.value); otpSent.value = true; toast('Code sent by SMS', 'ok') }
  catch (e) { toast(e.message || 'Could not send code', 'warn') }
  busy.value = false
}
async function doVerify() {
  busy.value = true
  try { await verifyPhoneOtp(phone.value, otp.value); await reloadProfile(); router.push('/') }
  catch (e) { toast(e.message || 'Wrong code', 'warn') }
  busy.value = false
}

const parcelsToday = ref(2841)
const onRoad = ref(63)
const settledTZS = ref(48920000)
const carriersLive = ref(11)

const STAGES = ['Booked', 'Collected', 'On road', 'With driver', 'Delivered', 'Confirmed']
const activeNode = ref(0)

const NAMES = ['Grace Mwangi','Peter Otieno','Neema Joseph','Hamisi Bakari','John Mkwawa','Asha Salum','Baraka Omari','Zainab Ali','Juma Hassan','Rehema Said']
const PLACES = ['Mikocheni','Kariakoo','Msasani','Uyole','Kimara','Tabata','Mbezi','Sinza','Ilala','Temeke']
const CARRIERS = [['USIRI','#3E5BD6'],['Sumry Cargo','#137A5E'],['Kimoto','#B4472B'],['Enkiama','#C08A2D']]
const EVENTS = ['booked','collected','on road','delivered','cash collected','confirmed']

const feed = ref([])
let code = 4470
function makeEvent() {
  code++
  const c = CARRIERS[Math.floor(Math.random() * CARRIERS.length)]
  const ev = EVENTS[Math.floor(Math.random() * EVENTS.length)]
  return {
    id: code + '-' + Math.random(),
    code: c[0].slice(0,3).toUpperCase() + '-' + code,
    who: NAMES[Math.floor(Math.random()*NAMES.length)],
    place: PLACES[Math.floor(Math.random()*PLACES.length)],
    carrier: c[0], accent: c[1], ev,
  }
}

let timers = []
onMounted(() => {
  for (let i = 0; i < 6; i++) feed.value.push(makeEvent())
  timers.push(setInterval(() => {
    feed.value.unshift(makeEvent())
    if (feed.value.length > 7) feed.value.pop()
  }, 2200))
  timers.push(setInterval(() => {
    parcelsToday.value += Math.floor(Math.random() * 3)
    if (Math.random() > 0.6) onRoad.value += (Math.random() > 0.5 ? 1 : -1)
    onRoad.value = Math.max(40, Math.min(90, onRoad.value))
    settledTZS.value += Math.floor(Math.random() * 40000)
  }, 1800))
  timers.push(setInterval(() => { activeNode.value = (activeNode.value + 1) % STAGES.length }, 1400))
})
onUnmounted(() => timers.forEach(clearInterval))

const settledStr = computed(() => 'TZS ' + settledTZS.value.toLocaleString())
</script>

<template>
  <div class="hero">
    <div class="glow glow-a"></div>
    <div class="glow glow-b"></div>
    <div class="grid-lines"></div>

    <header class="hero-top">
      <div class="brand">
        <div class="brand-mark">
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none">
            <path d="M3 8l9-5 9 5v8l-9 5-9-5V8z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>
            <path d="M3 8l9 5 9-5M12 13v8" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>
          </svg>
        </div>
        <div class="brand-word">Enkiama&nbsp;<b>Cargos</b></div>
      </div>
      <button class="btn-signin-top" @click="openPanel('email')">Sign in</button>
    </header>

    <main class="hero-main">
      <div class="hero-left">
        <div class="eyebrow"><span class="live-dot"></span> Live freight ledger · {{ carriersLive }} carriers operating now</div>
        <h1 class="hero-title">One parcel,<br><span class="accentword">one truth.</span></h1>
        <p class="hero-sub">
          The ledger every road-freight carrier runs on. Movement and money,
          tracked end to end — for every hand that touches the cargo.
        </p>
        <div class="hero-cta">
          <button class="btn-primary" @click="openPanel('email')">Sign in to your carrier</button>
          <button class="btn-secondary" @click="openPanel('phone')">I'm a driver</button>
        </div>
        <div class="stats-row">
          <div class="stat"><div class="stat-v mono">{{ parcelsToday.toLocaleString() }}</div><div class="stat-l">parcels today</div></div>
          <div class="stat"><div class="stat-v mono">{{ onRoad }}</div><div class="stat-l">on the road now</div></div>
          <div class="stat"><div class="stat-v mono">{{ settledStr }}</div><div class="stat-l">settled today</div></div>
        </div>
      </div>

      <div class="hero-right">
        <div class="sim-card">
          <div class="sim-head">
            <span class="sim-title">CONSIGNMENT&nbsp;·&nbsp;LIVE</span>
            <span class="sim-status"><span class="live-dot"></span> tracking</span>
          </div>
          <div class="route">
            <div class="route-line"><div class="route-fill" :style="{ width: (activeNode/(STAGES.length-1))*100 + '%' }"></div></div>
            <div class="nodes">
              <div v-for="(s,i) in STAGES" :key="s" class="node" :class="{ done: i < activeNode, active: i === activeNode }">
                <div class="node-dot"></div>
                <div class="node-cap">{{ s }}</div>
              </div>
            </div>
            <div class="parcel" :style="{ left: (activeNode/(STAGES.length-1))*100 + '%' }">📦</div>
          </div>
          <div class="ticker">
            <transition-group name="tick">
              <div class="tick-row" v-for="e in feed" :key="e.id">
                <span class="tick-code mono" :style="{ color: e.accent }">{{ e.code }}</span>
                <span class="tick-txt">{{ e.who }} · {{ e.place }}</span>
                <span class="tick-ev" :style="{ borderColor: e.accent, color: e.accent }">{{ e.ev }}</span>
              </div>
            </transition-group>
          </div>
        </div>
        <div class="powered-by">Powered by Enkiama Cargos · a multi-carrier freight platform</div>
      </div>
    </main>

    <transition name="slide">
      <div v-if="panelOpen" class="panel-scrim" @click.self="panelOpen=false">
        <div class="panel">
          <button class="panel-close" @click="panelOpen=false">✕</button>
          <div class="panel-brand">
            <div class="brand-mark sm">
              <svg viewBox="0 0 24 24" width="18" height="18" fill="none"><path d="M3 8l9-5 9 5v8l-9 5-9-5V8z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/><path d="M3 8l9 5 9-5M12 13v8" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg>
            </div>
            <span>Enkiama Cargos</span>
          </div>
          <div class="tabs">
            <button class="tab" :class="{on:mode==='email'}" @click="mode='email'">Carrier</button>
            <button class="tab" :class="{on:mode==='phone'}" @click="mode='phone'">Driver</button>
            <button class="tab" :class="{on:mode==='sender'}" @click="mode='sender'">Send</button>
          </div>
          <template v-if="mode==='email'">
            <label class="fld">Email<input v-model="email" type="email" placeholder="you@carrier.co.tz" /></label>
            <template v-if="!showReset">
              <label class="fld">Password<input v-model="password" type="password" placeholder="********" @keyup.enter="doEmail(false)" /></label>
              <button class="btn-primary block" :disabled="busy" @click="doEmail(false)">Sign in</button>
              <button class="btn-text" :disabled="busy" @click="doEmail(true)">Create account</button>
              <button class="btn-text" @click="showReset=true">Forgot password?</button>
            </template>
            <template v-else>
              <p style="font-size:13px;color:#A6ADBB;margin-bottom:12px">We'll email you a link to reset your password.</p>
              <button class="btn-primary block" :disabled="busy" @click="doReset">Send reset link</button>
              <button class="btn-text" @click="showReset=false">← Back to sign in</button>
            </template>
          </template>
          <template v-else-if="mode==='phone'">
            <label class="fld">Phone number<input v-model="phone" type="tel" placeholder="+255712345678" :disabled="otpSent" /></label>
            <template v-if="!otpSent">
              <button class="btn-primary block" :disabled="busy" @click="doSendOtp">Send code by SMS</button>
            </template>
            <template v-else>
              <label class="fld">6-digit code<input v-model="otp" class="mono" inputmode="numeric" placeholder="123456" @keyup.enter="doVerify" /></label>
              <button class="btn-primary block" :disabled="busy" @click="doVerify">Verify &amp; sign in</button>
              <button class="btn-text" @click="otpSent=false">Change number</button>
            </template>
          </template>
          <template v-else>
            <label class="fld">Your name<input v-model="senderName" placeholder="Asha Traders" /></label>
            <label class="fld">Email<input v-model="email" type="email" placeholder="you@email.com" /></label>
            <label class="fld">Password<input v-model="password" type="password" placeholder="******** (6+ chars)" @keyup.enter="doSenderSignup" /></label>
            <button class="btn-primary block" :disabled="busy" @click="doSenderSignup">Create sender account</button>
            <button class="btn-text" :disabled="busy" @click="doEmail(false)">I already have an account — sign in</button>
          </template>
          <p class="panel-note">Receiving a parcel? You don't need an account — open the tracking link your sender shared.</p>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.hero{position:fixed;inset:0;overflow:hidden;background:#080A0E;color:#EAE7DE;font-family:'Inter','Segoe UI',sans-serif;display:flex;flex-direction:column}
.mono{font-family:'Spline Sans Mono',ui-monospace,'SF Mono',Consolas,monospace;font-variant-numeric:tabular-nums}
.glow{position:absolute;border-radius:50%;filter:blur(90px);opacity:.5;pointer-events:none}
.glow-a{width:640px;height:640px;background:radial-gradient(circle,#2b3f9e,transparent 66%);top:-220px;right:-120px;animation:float1 16s ease-in-out infinite}
.glow-b{width:520px;height:520px;background:radial-gradient(circle,#0f6e54,transparent 66%);bottom:-200px;left:-120px;animation:float2 20s ease-in-out infinite}
@keyframes float1{0%,100%{transform:translate(0,0)}50%{transform:translate(-40px,40px)}}
@keyframes float2{0%,100%{transform:translate(0,0)}50%{transform:translate(50px,-30px)}}
.grid-lines{position:absolute;inset:0;opacity:.06;pointer-events:none;background-image:linear-gradient(#fff 1px,transparent 1px),linear-gradient(90deg,#fff 1px,transparent 1px);background-size:64px 64px;-webkit-mask-image:radial-gradient(circle at 60% 40%,#000,transparent 80%);mask-image:radial-gradient(circle at 60% 40%,#000,transparent 80%)}
.hero-top{position:relative;z-index:5;display:flex;align-items:center;justify-content:space-between;padding:22px 34px}
.brand{display:flex;align-items:center;gap:11px}
.brand-mark{width:38px;height:38px;border-radius:11px;background:linear-gradient(135deg,#EAE7DE,#B4AE9E);color:#0A0C10;display:flex;align-items:center;justify-content:center}
.brand-mark.sm{width:30px;height:30px;border-radius:9px}
.brand-word{font-family:'Space Grotesk','Segoe UI',sans-serif;font-weight:600;font-size:19px;letter-spacing:-.3px}
.brand-word b{font-weight:700}
.btn-signin-top{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.14);color:#EAE7DE;padding:9px 18px;border-radius:10px;font-family:inherit;font-weight:600;font-size:13px;cursor:pointer;transition:.16s}
.btn-signin-top:hover{background:rgba(255,255,255,.12)}
.hero-main{position:relative;z-index:4;flex:1;display:grid;grid-template-columns:1.05fr .95fr;gap:40px;align-items:center;padding:0 34px 40px;max-width:1280px;margin:0 auto;width:100%}
@media(max-width:920px){.hero-main{grid-template-columns:1fr;gap:24px;overflow-y:auto;padding-top:10px}.hero-right{display:none}}
.eyebrow{display:inline-flex;align-items:center;gap:9px;font-size:12px;font-weight:600;color:#9AA3B2;letter-spacing:.4px;margin-bottom:22px;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.08);padding:7px 13px;border-radius:100px}
.live-dot{width:7px;height:7px;border-radius:50%;background:#3ED598;animation:pulse 1.8s infinite}
@keyframes pulse{0%{box-shadow:0 0 0 0 rgba(62,213,152,.5)}70%{box-shadow:0 0 0 8px rgba(62,213,152,0)}100%{box-shadow:0 0 0 0 rgba(62,213,152,0)}}
.hero-title{font-family:'Space Grotesk','Segoe UI',sans-serif;font-weight:700;font-size:clamp(44px,6vw,88px);line-height:.98;letter-spacing:-2.5px;margin-bottom:20px}
.accentword{background:linear-gradient(120deg,#8FA2F2,#3ED598);-webkit-background-clip:text;background-clip:text;color:transparent}
.hero-sub{font-size:clamp(15px,1.5vw,18px);color:#A6ADBB;max-width:480px;line-height:1.6;margin-bottom:30px}
.hero-cta{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:40px}
.btn-primary{background:linear-gradient(120deg,#4E6BE6,#3ED598);color:#06131a;border:none;padding:14px 26px;border-radius:12px;font-family:inherit;font-weight:700;font-size:15px;cursor:pointer;transition:.18s;box-shadow:0 10px 30px rgba(78,107,230,.35)}
.btn-primary:hover:not(:disabled){transform:translateY(-2px);box-shadow:0 16px 40px rgba(78,107,230,.45)}
.btn-primary:disabled{opacity:.5;cursor:not-allowed}
.btn-secondary{background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.16);color:#EAE7DE;padding:14px 24px;border-radius:12px;font-family:inherit;font-weight:600;font-size:15px;cursor:pointer;transition:.18s}
.btn-secondary:hover{background:rgba(255,255,255,.1)}
.stats-row{display:flex;gap:34px}
.stat-v{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:26px;letter-spacing:-.5px}
.stat-l{font-size:12px;color:#7B8494;margin-top:3px}
.hero-right{position:relative}
.sim-card{background:rgba(18,22,30,.72);backdrop-filter:blur(20px);border:1px solid rgba(255,255,255,.1);border-radius:22px;padding:24px;box-shadow:0 30px 70px rgba(0,0,0,.5)}
.sim-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:26px}
.sim-title{font-family:'Spline Sans Mono',monospace;font-size:11px;letter-spacing:2px;color:#7B8494}
.sim-status{display:inline-flex;align-items:center;gap:7px;font-size:11px;color:#3ED598;font-weight:600}
.route{position:relative;padding:8px 6px 4px}
.route-line{position:absolute;top:14px;left:16px;right:16px;height:2px;background:rgba(255,255,255,.1);border-radius:2px}
.route-fill{height:100%;background:linear-gradient(90deg,#4E6BE6,#3ED598);border-radius:2px;transition:width 1.2s cubic-bezier(.4,0,.2,1)}
.nodes{display:flex;justify-content:space-between;position:relative}
.node{display:flex;flex-direction:column;align-items:center;gap:8px;width:16%}
.node-dot{width:12px;height:12px;border-radius:50%;background:#2A3140;border:2px solid #12161e;transition:.4s;position:relative;z-index:2}
.node.done .node-dot{background:#4E6BE6}
.node.active .node-dot{background:#3ED598;box-shadow:0 0 0 5px rgba(62,213,152,.2)}
.node-cap{font-size:9px;color:#5A6474;text-transform:uppercase;letter-spacing:.4px;font-weight:700;text-align:center}
.node.done .node-cap,.node.active .node-cap{color:#A6ADBB}
.parcel{position:absolute;top:-14px;transform:translateX(-50%);font-size:20px;transition:left 1.2s cubic-bezier(.4,0,.2,1);filter:drop-shadow(0 4px 8px rgba(0,0,0,.5))}
.ticker{margin-top:26px;border-top:1px solid rgba(255,255,255,.08);padding-top:16px;height:210px;overflow:hidden}
.tick-row{display:flex;align-items:center;gap:10px;padding:9px 0;border-bottom:1px solid rgba(255,255,255,.05)}
.tick-code{font-size:12px;font-weight:600;flex-shrink:0}
.tick-txt{font-size:12.5px;color:#A6ADBB;flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.tick-ev{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.4px;border:1px solid;padding:3px 8px;border-radius:6px;flex-shrink:0}
.tick-enter-active{transition:all .5s cubic-bezier(.4,0,.2,1)}
.tick-enter-from{opacity:0;transform:translateY(-14px)}
.tick-leave-active{transition:all .4s;position:absolute}
.tick-leave-to{opacity:0}
.powered-by{text-align:center;font-size:11.5px;color:#5A6474;margin-top:16px}
.panel-scrim{position:fixed;inset:0;z-index:50;background:rgba(4,6,10,.6);backdrop-filter:blur(4px);display:flex;justify-content:flex-end}
.panel{width:min(440px,100%);height:100%;background:#0E1218;border-left:1px solid rgba(255,255,255,.1);padding:40px 34px;display:flex;flex-direction:column;justify-content:center;position:relative;box-shadow:-30px 0 80px rgba(0,0,0,.5)}
.panel-close{position:absolute;top:24px;right:26px;background:none;border:none;color:#7B8494;font-size:18px;cursor:pointer}
.panel-brand{display:flex;align-items:center;gap:10px;margin-bottom:28px;font-family:'Space Grotesk',sans-serif;font-weight:600;font-size:16px}
.panel-brand .brand-mark{color:#0A0C10}
.tabs{display:flex;gap:6px;background:rgba(255,255,255,.04);padding:4px;border-radius:12px;border:1px solid rgba(255,255,255,.08);margin-bottom:22px}
.tab{flex:1;padding:10px;border:none;border-radius:9px;background:transparent;color:#7B8494;font-family:inherit;font-weight:600;font-size:13px;cursor:pointer;transition:.16s}
.tab.on{background:linear-gradient(120deg,#4E6BE6,#3ED598);color:#06131a}
.fld{display:block;font-size:12px;font-weight:600;color:#A6ADBB;margin-bottom:14px}
.fld input{width:100%;margin-top:7px;padding:13px 14px;border:1px solid rgba(255,255,255,.12);border-radius:11px;background:rgba(255,255,255,.03);color:#EAE7DE;font-size:14px;font-family:inherit}
.fld input:focus{outline:none;border-color:#4E6BE6;box-shadow:0 0 0 3px rgba(78,107,230,.2)}
.btn-primary.block{width:100%;margin-top:4px}
.btn-text{width:100%;background:none;border:none;color:#8FA2F2;font-family:inherit;font-weight:600;font-size:13px;cursor:pointer;margin-top:12px;padding:8px}
.panel-note{font-size:12px;color:#5A6474;text-align:center;margin-top:24px;line-height:1.5}
.slide-enter-active,.slide-leave-active{transition:opacity .3s}
.slide-enter-active .panel,.slide-leave-active .panel{transition:transform .32s cubic-bezier(.4,0,.2,1)}
.slide-enter-from,.slide-leave-to{opacity:0}
.slide-enter-from .panel,.slide-leave-to .panel{transform:translateX(100%)}
@media(prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
</style>
