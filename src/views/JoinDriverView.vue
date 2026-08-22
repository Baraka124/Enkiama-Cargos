<script setup>
import { ref, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuth } from '../composables/useAuth'
import BrandMark from '../components/BrandMark.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'

const router = useRouter()
const toast = inject('toast')
const { reloadProfile } = useAuth()

const token = ref('')
const info = ref(null)
const loading = ref(true)
const busy = ref(false)
const form = ref({ name: '', phone: '', vehicle: '', license: '', email: '', password: '' })

onMounted(async () => {
  const q = new URLSearchParams(window.location.hash.split('?')[1] || '')
  token.value = q.get('t') || ''
  if (!token.value) { loading.value = false; return }
  try {
    const { data } = await supabase.rpc('driver_invite_info', { p_token: token.value })
    info.value = data
    if (data?.prefill_name) form.value.name = data.prefill_name
    if (data?.prefill_phone) form.value.phone = data.prefill_phone
  } catch (e) {}
  loading.value = false
})

async function register() {
  if (!form.value.name || !form.value.email || !form.value.password) {
    toast('Name, email and password are required', 'warn'); return
  }
  busy.value = true
  try {
    const { error } = await supabase.auth.signUp({
      email: form.value.email,
      password: form.value.password,
      options: { data: {
        intent: 'driver', invite: token.value,
        name: form.value.name, phone: form.value.phone,
        vehicle: form.value.vehicle, license: form.value.license
      } }
    })
    if (error) throw error
    toast('Account created! Check your email to verify, then sign in.', 'ok')
    setTimeout(() => router.push('/login'), 1500)
  } catch (e) {
    toast(e.message || 'Could not register', 'warn')
  }
  busy.value = false
}
</script>

<template>
  <div class="join2">
    <!-- LEFT: the pitch — why join, what you get -->
    <aside class="join2-pitch">
      <div class="join2-pitch-top">
        <BrandMark variant="full" :height="30" class="join2-logo" />
        <div class="join2-eyebrow">Driver onboarding</div>
        <h1 class="join2-hero">Drive with <span>{{ info?.valid ? info.carrier : 'Enkiama' }}</span>.<br>Get paid, tracked, on time.</h1>
        <p class="join2-sub">Every delivery logged end to end. You always see your assigned parcels, your earnings, and the cash you're holding — nothing hidden, nothing disputed.</p>
      </div>
      <ul class="join2-benefits">
        <li><span class="join2-bic"><Icon name="box" :size="16" /></span><div><b>Your run, clearly laid out</b><span>See every parcel, pickup, and drop the moment it's assigned.</span></div></li>
        <li><span class="join2-bic"><Icon name="cash" :size="16" /></span><div><b>Cash tracked to the shilling</b><span>Every collection and remittance recorded — your record protects you.</span></div></li>
        <li><span class="join2-bic"><Icon name="pin" :size="16" /></span><div><b>Proof at every step</b><span>Photo proof of delivery, timestamps, one verified truth.</span></div></li>
      </ul>
      <div class="join2-trust"><Icon name="check" :size="14" /> Trusted road-freight platform · one parcel, one truth</div>
    </aside>

    <!-- RIGHT: the action -->
    <main class="join2-action">
      <div v-if="loading" class="join2-loading"><Spinner :size="28" /></div>

      <div v-else-if="!token || !info?.valid" class="join2-form-wrap">
        <div class="join2-bad">
          <div class="join2-bad-ic"><Icon name="alert" :size="26" /></div>
          <h2>This invite link isn't valid</h2>
          <p>It may have already been used or expired. Ask your carrier to send you a fresh link.</p>
          <RouterLink to="/track" class="btn btn-ghost btn-block" style="margin-top:8px">Track a parcel instead</RouterLink>
        </div>
      </div>

      <div v-else class="join2-form-wrap">
        <div class="join2-form-head">
          <h2>Create your driver account</h2>
          <p>Joining <strong>{{ info.carrier }}</strong> — takes a minute.</p>
        </div>
        <label class="fld">Full name<input v-model="form.name" placeholder="e.g. Juma Hassan" /></label>
        <div class="join2-row">
          <label class="fld">Phone<input v-model="form.phone" type="tel" placeholder="+255 7XX XXX XXX" /></label>
          <label class="fld">Vehicle<input v-model="form.vehicle" placeholder="e.g. Bajaji T123" /></label>
        </div>
        <label class="fld">License no. <span class="fld-opt">optional</span><input v-model="form.license" placeholder="Driving licence number" /></label>
        <div class="join2-sep"><span>account login</span></div>
        <label class="fld">Email<input v-model="form.email" type="email" autocomplete="email" placeholder="you@example.com" /></label>
        <label class="fld">Create a password<input v-model="form.password" type="password" autocomplete="new-password" placeholder="At least 8 characters" /></label>
        <button class="auth-btn" :disabled="busy" @click="register">
          <Spinner v-if="busy" :size="16" /><span v-else>Create my driver account</span>
        </button>
        <p class="join2-foot"><Icon name="check" :size="13" /> Your carrier manages your assignments. You control your profile.</p>
      </div>
    </main>
  </div>
</template>

<style scoped>
.join2{min-height:100vh;display:grid;grid-template-columns:1.05fr 1fr}
/* LEFT pitch */
.join2-pitch{position:relative;background:var(--nav);color:#fff;padding:48px 52px;display:flex;flex-direction:column;justify-content:space-between;overflow:hidden}
.join2-pitch::before{content:'';position:absolute;inset:0;pointer-events:none;background:
  radial-gradient(800px 600px at 80% -15%, rgba(11,110,93,.4), transparent 60%),
  radial-gradient(500px 400px at 5% 115%, rgba(11,110,93,.16), transparent 55%)}
.join2-pitch::after{content:'';position:absolute;inset:0;pointer-events:none;opacity:.5;
  background-image:linear-gradient(rgba(255,255,255,.025) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.025) 1px,transparent 1px);
  background-size:40px 40px;mask-image:radial-gradient(circle at 70% 20%,black,transparent 75%)}
.join2-pitch-top{position:relative;z-index:1}
.join2-logo{margin-bottom:40px;opacity:.95}
.join2-eyebrow{font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:var(--accent);margin-bottom:16px}
.join2-hero{font-family:'Space Grotesk',sans-serif;font-size:clamp(30px,3.6vw,44px);font-weight:700;line-height:1.05;letter-spacing:-.035em;margin-bottom:18px}
.join2-hero span{color:#4FD1B5}
.join2-sub{font-size:15px;line-height:1.6;color:rgba(255,255,255,.68);max-width:440px}
.join2-benefits{position:relative;z-index:1;list-style:none;padding:0;margin:36px 0;display:flex;flex-direction:column;gap:20px}
.join2-benefits li{display:flex;gap:14px;align-items:flex-start}
.join2-bic{width:36px;height:36px;border-radius:10px;background:rgba(79,209,181,.14);color:#4FD1B5;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.join2-benefits b{display:block;font-size:14.5px;font-weight:650;margin-bottom:2px}
.join2-benefits span{font-size:13px;color:rgba(255,255,255,.55);line-height:1.5}
.join2-trust{position:relative;z-index:1;display:inline-flex;align-items:center;gap:8px;font-size:12.5px;color:rgba(255,255,255,.6);font-weight:500}
.join2-trust :deep(svg){color:#4FD1B5}
/* RIGHT action */
.join2-action{display:flex;align-items:center;justify-content:center;padding:48px 40px;background:var(--surface)}
.join2-loading{display:flex;justify-content:center}
.join2-form-wrap{width:100%;max-width:400px}
.join2-form-head{margin-bottom:24px}
.join2-form-head h2{font-family:'Space Grotesk',sans-serif;font-size:26px;font-weight:700;letter-spacing:-.03em;color:var(--ink);line-height:1.1}
.join2-form-head p{font-size:14px;color:var(--ink-soft);margin-top:6px}
.join2-row{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.join2-sep{display:flex;align-items:center;gap:12px;margin:20px 0;color:var(--ink-ghost);font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:.06em}
.join2-sep::before,.join2-sep::after{content:'';flex:1;height:1px;background:var(--hairline)}
.join2-foot{display:flex;align-items:center;gap:6px;justify-content:center;font-size:12px;color:var(--ink-faint);margin-top:16px}
.join2-foot :deep(svg){color:var(--go)}
.join2-bad{text-align:center}
.join2-bad-ic{width:56px;height:56px;border-radius:16px;background:var(--warn-soft);color:var(--warn-ink);display:flex;align-items:center;justify-content:center;margin:0 auto 16px}
.join2-bad h2{font-family:'Space Grotesk',sans-serif;font-size:22px;font-weight:700;letter-spacing:-.02em;margin-bottom:8px}
.join2-bad p{font-size:14px;color:var(--ink-faint);line-height:1.55;margin-bottom:8px}
@media(max-width:860px){
  .join2{grid-template-columns:1fr}
  .join2-pitch{padding:36px 28px;min-height:auto}
  .join2-benefits{margin:24px 0;gap:14px}
  .join2-action{padding:32px 24px}
}
</style>
