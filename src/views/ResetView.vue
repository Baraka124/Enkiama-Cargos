<script setup>
import { ref, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'

const router = useRouter()
const toast = inject('toast')
const { updatePassword } = useAuth()
const pw = ref(''); const pw2 = ref(''); const busy = ref(false)

async function submit() {
  if (pw.value.length < 8) { toast('Use at least 8 characters', 'warn'); return }
  if (pw.value !== pw2.value) { toast('Passwords don\u2019t match', 'warn'); return }
  busy.value = true
  try {
    await updatePassword(pw.value)
    toast('Password updated — you can sign in now', 'ok')
    router.push('/login')
  } catch (e) { toast(e.message, 'warn') }
  busy.value = false
}
</script>

<template>
  <div class="auth-wrap">
    <div class="auth-card">
      <div class="auth-brand">
        <div class="auth-logo"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#fff"><path d="M3 8l9-5 9 5v8l-9 5-9-5V8z" stroke-width="1.5" stroke-linejoin="round"/><path d="M3 8l9 5 9-5M12 13v8" stroke-width="1.5" stroke-linejoin="round"/></svg></div>
        <div><div style="font-family:'Space Grotesk';font-weight:600;font-size:18px">Set a new password</div><div class="p-sub">Choose something you'll remember.</div></div>
      </div>
      <div class="panel">
        <div class="fg"><label>New password</label><input v-model="pw" type="password" placeholder="At least 8 characters" /></div>
        <div class="fg"><label>Confirm password</label><input v-model="pw2" type="password" @keyup.enter="submit" /></div>
        <button class="btn btn-accent btn-block btn-lg" :disabled="busy" @click="submit">Update password</button>
      </div>
    </div>
  </div>
</template>
