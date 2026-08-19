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
  <div class="join-wrap">
    <div class="join-card">
      <div class="join-brand"><BrandMark variant="full" :height="36" /></div>

      <div v-if="loading" class="join-loading"><Spinner :size="24" /></div>

      <template v-else-if="!token || !info?.valid">
        <div class="join-bad">
          <Icon name="alert" :size="28" />
          <h2>This invite link isn't valid</h2>
          <p>It may have already been used or expired. Ask your carrier for a new link.</p>
        </div>
      </template>

      <template v-else>
        <div class="join-head">
          <div class="join-badge"><Icon name="bike" :size="18" /></div>
          <h1>Join {{ info.carrier }} as a driver</h1>
          <p>Set up your account. Once verified, you'll see your assigned deliveries, earnings, and tasks.</p>
        </div>

        <label class="fld">Full name<input v-model="form.name" placeholder="e.g. Juma Hassan" /></label>
        <div class="join-row">
          <label class="fld">Phone<input v-model="form.phone" type="tel" placeholder="+255 7XX XXX XXX" /></label>
          <label class="fld">Vehicle<input v-model="form.vehicle" placeholder="e.g. Bajaji T123" /></label>
        </div>
        <label class="fld">License no. <span class="fld-opt">optional</span><input v-model="form.license" placeholder="Driving licence number" /></label>
        <div class="join-sep"></div>
        <label class="fld">Email<input v-model="form.email" type="email" autocomplete="email" placeholder="you@example.com" /></label>
        <label class="fld">Create a password<input v-model="form.password" type="password" autocomplete="new-password" placeholder="At least 8 characters" /></label>

        <button class="auth-btn" :disabled="busy" @click="register">
          <Spinner v-if="busy" :size="16" /><span v-else>Create my driver account</span>
        </button>
        <p class="join-foot">Your carrier manages your assignments. You'll always see your full profile and tasks once signed in.</p>
      </template>
    </div>
  </div>
</template>

<style scoped>
.join-wrap{min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;background:var(--paper)}
.join-card{width:100%;max-width:440px;background:var(--surface);border:1px solid var(--hairline);border-radius:20px;padding:28px;box-shadow:var(--shadow-lg)}
.join-brand{display:flex;justify-content:center;margin-bottom:20px}
.join-loading{display:flex;justify-content:center;padding:40px}
.join-head{text-align:center;margin-bottom:22px}
.join-badge{width:48px;height:48px;border-radius:14px;background:var(--accent);color:#fff;display:flex;align-items:center;justify-content:center;margin:0 auto 14px;box-shadow:var(--shadow-md)}
.join-head h1{font-size:20px;margin-bottom:8px}
.join-head p{font-size:14px;color:var(--ink-soft);line-height:1.5}
.join-row{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.join-sep{height:1px;background:var(--hairline);margin:18px 0}
.join-foot{font-size:12px;color:var(--ink-faint);text-align:center;margin-top:14px;line-height:1.5}
.join-bad{text-align:center;padding:20px 0;color:var(--ink-soft)}
.join-bad :deep(svg){color:var(--warn)}
.join-bad h2{font-size:18px;margin:12px 0 8px}
.join-bad p{font-size:14px;color:var(--ink-faint)}
</style>
