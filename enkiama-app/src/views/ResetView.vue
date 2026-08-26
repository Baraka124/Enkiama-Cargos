<script setup>
import { ref, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import BrandMark from '../components/BrandMark.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'

const router = useRouter()
const toast = inject('toast')
const { updatePassword } = useAuth()
const pw = ref(''); const pw2 = ref(''); const busy = ref(false)
const done = ref(false)

async function submit() {
  if (pw.value.length < 8) { toast('Use at least 8 characters', 'warn'); return }
  if (pw.value !== pw2.value) { toast('Passwords don\u2019t match', 'warn'); return }
  busy.value = true
  try {
    await updatePassword(pw.value)
    done.value = true
    setTimeout(() => router.push('/login'), 1600)
  } catch (e) { toast(e.message, 'warn') }
  busy.value = false
}
</script>

<template>
  <div class="rst-wrap">
    <div class="rst-card">
      <BrandMark variant="full" :height="42" class="rst-logo" />
      <template v-if="done">
        <div class="rst-ic go"><Icon name="check" :size="30" /></div>
        <h1 class="rst-h">Password updated</h1>
        <p class="rst-p">Taking you to sign in…</p>
      </template>
      <template v-else>
        <div class="rst-ic"><Icon name="lock" :size="26" /></div>
        <h1 class="rst-h">Set a new password</h1>
        <p class="rst-p">Choose something private you'll remember.</p>
        <div class="fg"><label>New password</label><input v-model="pw" type="password" placeholder="At least 8 characters" /></div>
        <div class="fg"><label>Confirm password</label><input v-model="pw2" type="password" placeholder="Repeat it" @keyup.enter="submit" /></div>
        <button class="btn btn-accent btn-block btn-lg" :disabled="busy" @click="submit"><Spinner v-if="busy" :size="16" /><span v-else>Update password</span></button>
      </template>
    </div>
    <p class="rst-foot">Enkiama Cargos · One parcel, one truth.</p>
  </div>
</template>

<style scoped>
.rst-wrap{min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:var(--s5);background:radial-gradient(120% 80% at 50% 0%, var(--surface-2), var(--paper))}
.rst-card{background:var(--surface);border:1px solid var(--hairline);border-radius:var(--r-xl);padding:var(--s8) var(--s7);max-width:420px;width:100%;text-align:center;box-shadow:var(--shadow-lg)}
.rst-logo{margin-bottom:var(--s6)}
.rst-ic{width:60px;height:60px;border-radius:var(--r-lg);background:var(--accent-soft);color:var(--accent-ink);display:flex;align-items:center;justify-content:center;margin:0 auto var(--s5)}
.rst-ic.go{background:var(--go-soft);color:var(--go-ink);animation:rstPop .4s var(--ease)}
@keyframes rstPop{from{transform:scale(0);opacity:0}to{transform:scale(1);opacity:1}}
.rst-h{font-family:'Space Grotesk',sans-serif;font-size:var(--t-2xl);font-weight:700;margin-bottom:var(--s2)}
.rst-p{font-size:var(--t-base);color:var(--ink-soft);margin-bottom:var(--s6);line-height:1.55}
.rst-card .fg{text-align:left;margin-bottom:var(--s4)}
.rst-foot{font-size:var(--t-sm);color:var(--ink-faint);margin-top:var(--s6)}
</style>
