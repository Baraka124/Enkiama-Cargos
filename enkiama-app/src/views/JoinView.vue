<script setup>
// Branded per-audience login/join window. One secure backend (useAuth),
// but a distinct, customizable entry experience per role.
import { ref, computed, inject } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import BrandMark from '../components/BrandMark.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import { useAuth } from '../composables/useAuth'
import { humanError } from '../lib/humanError'

const route = useRoute()
const router = useRouter()
const toast = inject('toast')
const { signInEmail, signUpSender, signUpDriver, signUpReceiver } = useAuth()

// Per-audience branding — everything customizable here.
const AUDIENCES = {
  business: {
    role: 'sender', eyebrow: 'For businesses', accent: '#0B6E5D',
    headline: 'Business account', headlineAccent: 'with movement built in.',
    sub: 'Create the business identity used for storefront orders, direct shipments and delivery records.',
    benefits: [
      ['box', 'Your own online storefront', 'List products with photos, share one link.'],
      ['route', 'Tracked delivery on every order', 'Through the Enkiama carrier network.'],
      ['cash', 'Cash on delivery, reconciled', 'We collect and remit — you just sell.'],
    ],
    cta: 'Open your business account', nameLabel: 'Business name', namePh: 'e.g. Amina Fabrics',
  },
  driver: {
    role: 'driver', eyebrow: 'For drivers', accent: '#0B6E5D',
    headline: 'Driver account', headlineAccent: 'for one clear run record.',
    sub: 'Join a carrier, receive assignments and keep proof, cash and delivery status attached to the same run.',
    benefits: [
      ['route', 'Your run, mapped', 'See every stop in order, live.'],
      ['shield', 'Proof on every delivery', 'Photo + timestamp protects you.'],
      ['cash', 'Cash tracked & reconciled', 'No disputes over what you collected.'],
    ],
    cta: 'Create driver account', nameLabel: 'Full name', namePh: 'e.g. Charles Temba',
  },
  carrier: {
    role: 'carrier', eyebrow: 'For carriers', accent: '#2E6E8E',
    headline: 'Carrier access', headlineAccent: 'to the operating system.',
    sub: 'Set up the carrier record used for dispatch, drivers, cash reconciliation and public tracking.',
    benefits: [
      ['display', 'Command-center dispatch', 'Every parcel, driver and shilling in one view.'],
      ['bike', 'Your drivers, connected', 'Assign, invite, and track your whole team.'],
      ['scale', 'Cash reconciliation built in', 'Know exactly what is owed and remitted.'],
    ],
    cta: 'Apply to run a carrier', nameLabel: 'Company name', namePh: 'e.g. USIRI Cargo',
  },
  receiver: {
    role: 'receiver', eyebrow: 'For frequent buyers', accent: '#0B6E5D',
    headline: 'Receiver account', headlineAccent: 'for incoming movement.',
    sub: 'Link incoming deliveries to one signed-in receiver identity and follow each movement record.',
    benefits: [
      ['inbox', 'Every incoming parcel', 'One place for all your deliveries.'],
      ['star', 'Reorder in a tap', 'From the shops you already trust.'],
      ['bell', 'Know the moment it moves', 'Live updates on every step.'],
    ],
    cta: 'Create my account', nameLabel: 'Your name', namePh: 'e.g. Julius Mushi',
  },
}

const which = computed(() => route.params.audience || 'business')
const a = computed(() => AUDIENCES[which.value] || AUDIENCES.business)

const mode = ref('signup')  // signup | signin
const form = ref({ name: '', email: '', password: '', phone: '', location: '', vehicle: '' })
const busy = ref(false)

async function submit() {
  if (!form.value.email || !form.value.password) { toast('Email and password are required', 'warn'); return }
  busy.value = true
  try {
    if (mode.value === 'signin') {
      await signInEmail(form.value.email, form.value.password)
    } else if (a.value.role === 'sender') {
      await signUpSender(form.value.email, form.value.password, form.value.name || 'Business', form.value.location, '')
    } else if (a.value.role === 'driver') {
      await signUpDriver(form.value.email, form.value.password, form.value.name || 'Driver', form.value.phone || null, form.value.vehicle || null)
    } else if (a.value.role === 'receiver') {
      await signUpReceiver(form.value.email, form.value.password, form.value.name || 'Receiver')
    } else if (a.value.role === 'carrier') {
      // carrier applications go through the platform; route to the application flow
      router.push('/login?apply=carrier'); busy.value = false; return
    }
    router.push('/')
  } catch (e) {
    toast(humanError(e, 'Could not complete — please check your details'), 'warn')
  }
  busy.value = false
}
</script>

<template>
  <div class="jn" :style="{ '--jn-accent': a.accent }">
    <!-- LEFT: role context -->
    <div class="jn-left">
      <div class="jn-left-top">
        <RouterLink to="/" class="jn-brand"><BrandMark variant="full" :height="30" /></RouterLink>
      </div>
      <div class="jn-left-body">
        <div class="jn-eyebrow"><span class="jn-dot"></span> {{ a.eyebrow }}</div>
        <h1 class="jn-h1">{{ a.headline }}<br><span class="jn-grad">{{ a.headlineAccent }}</span></h1>
        <p class="jn-sub">{{ a.sub }}</p>
        <div class="jn-benefits">
          <div v-for="(b,i) in a.benefits" :key="i" class="jn-benefit">
            <span class="jn-benefit-ic"><Icon :name="b[0]" :size="18" /></span>
            <div><b>{{ b[1] }}</b><span>{{ b[2] }}</span></div>
          </div>
        </div>
      </div>
      <div class="jn-left-foot">Identity · role · access</div>
    </div>

    <!-- RIGHT: the form -->
    <div class="jn-right">
      <div class="jn-form">
        <div class="jn-switch">
          <button :class="{on:mode==='signup'}" @click="mode='signup'">Create account</button>
          <button :class="{on:mode==='signin'}" @click="mode='signin'">Sign in</button>
        </div>

        <template v-if="mode==='signup'">
          <div class="fg"><label>{{ a.nameLabel }}</label><input v-model="form.name" :placeholder="a.namePh" /></div>
          <div v-if="a.role==='driver'" class="row2">
            <div class="fg"><label>Phone</label><input v-model="form.phone" placeholder="+255…" /></div>
            <div class="fg"><label>Vehicle</label><input v-model="form.vehicle" placeholder="bajaji, truck…" /></div>
          </div>
          <div v-if="a.role==='sender'" class="fg"><label>Location</label><input v-model="form.location" placeholder="City / area" /></div>
        </template>

        <div class="fg"><label>Email</label><input v-model="form.email" type="email" placeholder="you@example.com" /></div>
        <div class="fg"><label>Password</label><input v-model="form.password" type="password" placeholder="••••••••" /></div>

        <button class="btn btn-accent btn-block btn-lg jn-submit" :disabled="busy" @click="submit">
          <Spinner v-if="busy" :size="16" /><template v-else>{{ mode==='signin' ? 'Sign in' : a.cta }}</template>
        </button>

        <div class="jn-alt">
          <RouterLink to="/join/business" :class="{cur:which==='business'}">Business</RouterLink>
          <RouterLink to="/join/driver" :class="{cur:which==='driver'}">Driver</RouterLink>
          <RouterLink to="/join/carrier" :class="{cur:which==='carrier'}">Carrier</RouterLink>
          <RouterLink to="/join/receiver" :class="{cur:which==='receiver'}">Buyer</RouterLink>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.jn{display:grid;grid-template-columns:1.1fr 1fr;min-height:100vh;background:var(--paper)}
.jn-left{background:linear-gradient(160deg,var(--ink),#1A2028 60%,var(--jn-accent));color:#fff;padding:36px 48px;display:flex;flex-direction:column;position:relative;overflow:hidden}
.jn-left::before{content:'';position:absolute;inset:0;background:radial-gradient(600px 400px at 80% 10%,rgba(255,255,255,.08),transparent 60%);pointer-events:none}
.jn-brand{display:inline-block;filter:brightness(0) invert(1);opacity:.95}
.jn-left-body{margin:auto 0;position:relative;z-index:1}
.jn-eyebrow{display:inline-flex;align-items:center;gap:8px;font-size:12.5px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:rgba(255,255,255,.8);margin-bottom:20px}
.jn-dot{width:7px;height:7px;border-radius:50%;background:#4FD1B5}
.jn-h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(32px,3.6vw,46px);font-weight:700;line-height:1.04;letter-spacing:-.035em;margin-bottom:18px}
.jn-grad{background:linear-gradient(110deg,#4FD1B5,#7EE8CF);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.jn-sub{font-size:15px;line-height:1.6;color:rgba(255,255,255,.7);max-width:420px;margin-bottom:30px}
.jn-benefits{display:flex;flex-direction:column;gap:16px}
.jn-benefit{display:flex;gap:13px;align-items:flex-start}
.jn-benefit-ic{width:38px;height:38px;border-radius:10px;background:rgba(255,255,255,.1);display:flex;align-items:center;justify-content:center;flex-shrink:0;color:#4FD1B5}
.jn-benefit b{display:block;font-size:14px;font-weight:650;margin-bottom:2px}
.jn-benefit span{font-size:13px;color:rgba(255,255,255,.6);line-height:1.45}
.jn-left-foot{font-size:12.5px;color:rgba(255,255,255,.4);position:relative;z-index:1;margin-top:24px}

.jn-right{display:flex;align-items:center;justify-content:center;padding:36px}
.jn-form{width:100%;max-width:400px}
.jn-switch{display:flex;background:var(--surface-2);border:1px solid var(--hairline);border-radius:12px;padding:4px;margin-bottom:24px}
.jn-switch button{flex:1;padding:10px;border:none;background:none;font-family:inherit;font-size:14px;font-weight:600;color:var(--ink-faint);border-radius:10px;cursor:pointer;transition:.15s}
.jn-switch button.on{background:var(--surface);color:var(--ink);box-shadow:var(--shadow-sm)}
.jn-submit{margin-top:8px}
.jn-alt{display:flex;gap:6px;justify-content:center;margin-top:22px;flex-wrap:wrap}
.jn-alt a{font-size:12.5px;font-weight:600;color:var(--ink-faint);text-decoration:none;padding:5px 11px;border-radius:999px;border:1px solid var(--hairline);transition:.15s}
.jn-alt a:hover{border-color:var(--jn-accent);color:var(--jn-accent)}
.jn-alt a.cur{background:var(--ink);color:#fff;border-color:var(--ink)}

@media(max-width:860px){
  .jn{grid-template-columns:1fr}
  .jn-left{display:none}
}


/* PHASE 25 — unified role entry */
.jn{
  min-height:100svh;display:grid;grid-template-columns:minmax(360px,.88fr) minmax(480px,1.12fr);
  background:var(--world-canvas)
}
.jn-left{
  background:#e9e4da;color:var(--ink);padding:44px 48px;border-right:1px solid var(--hairline);
  position:relative;display:flex;flex-direction:column;justify-content:space-between;overflow:hidden
}
.jn-left::before{display:none}
.jn-brand :deep(img){filter:none}
.jn-left-body{max-width:520px;margin:auto 0}
.jn-eyebrow{
  display:flex;align-items:center;gap:8px;margin-bottom:22px;
  font:600 10px/1 var(--font-mono);letter-spacing:.12em;text-transform:uppercase;color:var(--ink-faint)
}
.jn-dot{width:7px;height:7px;border-radius:50%;background:var(--jn-accent);box-shadow:none}
.jn-h1{font:500 clamp(42px,5vw,68px)/.94 var(--font-display);letter-spacing:-.06em;color:var(--ink);margin-bottom:20px}
.jn-grad{display:block;background:none;-webkit-text-fill-color:initial;color:var(--ink);font-family:var(--font-editorial);font-weight:500;letter-spacing:-.04em}
.jn-sub{max-width:480px;font-size:14px;line-height:1.7;color:var(--ink-soft)}
.jn-benefits{margin-top:34px;border-top:1px solid var(--hairline);display:block}
.jn-benefit{
  display:grid;grid-template-columns:34px 160px minmax(0,1fr);gap:14px;padding:16px 0;border-bottom:1px solid var(--hairline);align-items:start
}
.jn-benefit-ic{width:28px;height:28px;border-radius:50%;background:transparent;color:var(--ink-soft);border:1px solid var(--hairline)}
.jn-benefit b{display:block;font:600 13px/1.25 var(--font-display);color:var(--ink)}
.jn-benefit span{display:block;font-size:12px;line-height:1.5;color:var(--ink-faint)}
.jn-left-foot{font:500 9px/1 var(--font-mono);letter-spacing:.12em;text-transform:uppercase;color:var(--ink-ghost)}
.jn-right{display:flex;align-items:center;justify-content:center;padding:48px;background:var(--surface)}
.jn-form{width:min(440px,100%)}
.jn-switch{
  display:grid;grid-template-columns:1fr 1fr;margin-bottom:30px;border-bottom:1px solid var(--hairline);border-radius:0;background:transparent;padding:0
}
.jn-switch button{min-height:44px;border:0;border-bottom:2px solid transparent;border-radius:0;background:transparent;color:var(--ink-faint);font-weight:650}
.jn-switch button.on{background:transparent;color:var(--ink);border-bottom-color:var(--ink)}
.jn-submit{margin-top:8px}
.jn-alt{margin-top:28px;padding-top:18px;border-top:1px solid var(--hairline);display:flex;gap:8px;flex-wrap:wrap}
.jn-alt a{border-radius:999px;background:transparent}
.jn-alt a.cur{background:var(--ink);color:var(--surface);border-color:var(--ink)}
@media(max-width:860px){
  .jn{grid-template-columns:1fr}
  .jn-left{display:block;padding:28px 24px 24px;border-right:0;border-bottom:1px solid var(--hairline)}
  .jn-left-top{margin-bottom:34px}
  .jn-benefits{display:none}
  .jn-left-foot{display:none}
  .jn-right{padding:34px 24px 48px}
}

</style>
