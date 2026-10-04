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
      <h1 class="np-h">Access is not assigned yet.</h1>
      <p class="np-p">Signed in as <b>{{ email }}</b>. This identity exists, but no operational role has been attached to it yet.</p>
      <div class="np-steps">
        <div class="np-step"><span class="np-num">1</span><span>Ask the relevant carrier or platform administrator to assign your role.</span></div>
        <div class="np-step"><span class="np-num">2</span><span>After the role is assigned, recheck access below.</span></div>
      </div>
      <button class="btn btn-accent btn-block btn-lg" :disabled="checking" @click="recheck"><Spinner v-if="checking" :size="16" /><span v-else>Recheck access</span></button>
      <button class="btn btn-ghost btn-block" style="margin-top:10px" @click="logout">Sign out</button>
    </div>
    <p class="np-foot">Enkiama access control</p>
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


/* PHASE 25 — unassigned identity state */
.np-wrap{min-height:100svh;background:#e9e4da;padding:32px}
.np-card{
  max-width:620px;border:0;border-top:1px solid var(--hairline);border-bottom:1px solid var(--hairline);
  border-radius:0;box-shadow:none;background:transparent;padding:44px 0;text-align:left
}
.np-logo{margin-bottom:44px}
.np-ic{width:36px;height:36px;border-radius:50%;margin:0 0 20px}
.np-h{font:500 clamp(34px,5vw,52px)/.96 var(--font-display);letter-spacing:-.055em;color:var(--ink)}
.np-p{max-width:560px;font-size:14px;line-height:1.7;color:var(--ink-soft);margin:16px 0 28px}
.np-steps{border-top:1px solid var(--hairline);gap:0;margin-bottom:28px}
.np-step{display:grid;grid-template-columns:36px 1fr;gap:12px;padding:15px 0;border-bottom:1px solid var(--hairline);font-size:13px}
.np-num{width:auto;height:auto;border-radius:0;background:none;font:500 10px/1 var(--font-mono);color:var(--ink-faint)}
.np-foot{font:500 9px/1 var(--font-mono);letter-spacing:.11em;text-transform:uppercase;color:var(--ink-ghost)}

</style>
