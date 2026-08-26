<script setup>
import { ref, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import BrandMark from '../components/BrandMark.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'

const router = useRouter()
const toast = inject('toast')
const { session, signOut, reloadProfile } = useAuth()
const email = ref('')
const checking = ref(false)

onMounted(() => { email.value = session.value?.user?.email || session.value?.user?.phone || 'your account' })

async function recheck() {
  checking.value = true
  await reloadProfile()
  const { profile } = useAuth()
  if (profile.value?.role) {
    const r = profile.value.role
    router.push(r === 'driver' ? '/driver' : r === 'sender' ? '/send' : r === 'receiver' ? '/deliveries' : '/dispatch')
  } else {
    toast('Your account isn\u2019t linked yet — an admin needs to add you', 'warn')
  }
  checking.value = false
}
async function logout() { await signOut(); router.push('/login') }
</script>

<template>
  <div class="np-wrap">
    <div class="np-card">
      <BrandMark variant="full" :height="42" class="np-logo" />
      <div class="np-ic"><Icon name="clock" :size="28" /></div>
      <h1 class="np-h">You're almost in</h1>
      <p class="np-p">You're signed in as <b>{{ email }}</b>, but your account hasn't been linked to a carrier or role yet.</p>
      <div class="np-steps">
        <div class="np-step"><span class="np-num">1</span><span>Ask your carrier admin to add you to their team.</span></div>
        <div class="np-step"><span class="np-num">2</span><span>Once they do, tap the button below to come in.</span></div>
      </div>
      <button class="btn btn-accent btn-block btn-lg" :disabled="checking" @click="recheck"><Spinner v-if="checking" :size="16" /><span v-else>I've been added — take me in</span></button>
      <button class="btn btn-ghost btn-block" style="margin-top:10px" @click="logout">Sign out</button>
    </div>
    <p class="np-foot">Enkiama Cargos · One parcel, one truth.</p>
  </div>
</template>

<style scoped>
.np-wrap{min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:var(--s5);background:radial-gradient(120% 80% at 50% 0%, var(--surface-2), var(--paper))}
.np-card{background:var(--surface);border:1px solid var(--hairline);border-radius:var(--r-xl);padding:var(--s8) var(--s7);max-width:440px;width:100%;text-align:center;box-shadow:var(--shadow-lg)}
.np-logo{margin-bottom:var(--s6)}
.np-ic{width:60px;height:60px;border-radius:var(--r-lg);background:var(--warn-soft);color:var(--warn-ink);display:flex;align-items:center;justify-content:center;margin:0 auto var(--s5)}
.np-h{font-family:'Space Grotesk',sans-serif;font-size:var(--t-2xl);font-weight:700;margin-bottom:var(--s2)}
.np-p{font-size:var(--t-base);color:var(--ink-soft);margin-bottom:var(--s6);line-height:1.6}
.np-steps{text-align:left;margin-bottom:var(--s6);display:flex;flex-direction:column;gap:var(--s3)}
.np-step{display:flex;align-items:center;gap:var(--s3);font-size:var(--t-base);color:var(--ink-soft)}
.np-num{width:26px;height:26px;border-radius:var(--r-full);background:var(--accent-soft);color:var(--accent-ink);font-weight:700;font-size:var(--t-sm);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.np-foot{font-size:var(--t-sm);color:var(--ink-faint);margin-top:var(--s6)}
</style>
