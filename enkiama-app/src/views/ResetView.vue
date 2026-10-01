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
.rst-wrap{min-height:100svh;display:grid;place-items:center;padding:32px;background:var(--world-canvas);position:relative}.rst-wrap::before{content:"";position:absolute;inset:0;background:linear-gradient(90deg,transparent 49.95%,var(--world-line) 50%,transparent 50.05%);pointer-events:none}.rst-card{position:relative;background:var(--world-surface);border:1px solid var(--world-line);border-radius:10px;padding:34px 32px;max-width:430px;width:100%;text-align:left;box-shadow:0 24px 70px rgba(25,28,24,.07)}.rst-logo{margin-bottom:30px}.rst-ic{width:38px;height:38px;border:1px solid var(--world-line-strong);border-radius:6px;background:transparent;color:var(--world-accent);display:grid;place-items:center;margin:0 0 22px}.rst-ic.go{background:var(--world-accent-soft);border-color:var(--world-accent);color:var(--world-accent)}.rst-h{font:600 28px/1.05 var(--font-display);letter-spacing:-.04em;margin-bottom:8px}.rst-p{font-size:13px;color:var(--world-ink-soft);margin-bottom:26px;line-height:1.55}.rst-card .fg{text-align:left;margin-bottom:16px}.rst-foot{position:absolute;bottom:22px;left:0;right:0;text-align:center;font:500 9.5px var(--font-mono);letter-spacing:.06em;text-transform:uppercase;color:var(--world-ink-faint)}@media(max-width:520px){.rst-wrap{padding:18px;place-items:start center;padding-top:14vh}.rst-card{padding:28px 20px}.rst-foot{position:static;margin-top:18px}}
</style>