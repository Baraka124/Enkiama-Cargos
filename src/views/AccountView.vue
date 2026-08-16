<script setup>
import { ref, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'

const router = useRouter()
const toast = inject('toast')
const { session, profile, emailVerified, updateMyProfile, updatePassword, resendVerification, signOut, signOutEverywhere } = useAuth()

const name = ref(''); const phone = ref('')
const newPw = ref(''); const newPw2 = ref('')
const busy = ref(false)

onMounted(() => { name.value = profile.value?.name || ''; phone.value = profile.value?.phone || '' })

async function saveProfile() {
  busy.value = true
  try { await updateMyProfile(name.value, phone.value); toast('Profile updated', 'ok') }
  catch (e) { toast(e.message, 'warn') }
  busy.value = false
}
async function changePw() {
  if (newPw.value.length < 8) { toast('Use at least 8 characters', 'warn'); return }
  if (newPw.value !== newPw2.value) { toast('Passwords don\u2019t match', 'warn'); return }
  busy.value = true
  try { await updatePassword(newPw.value); toast('Password changed', 'ok'); newPw.value=''; newPw2.value='' }
  catch (e) { toast(e.message, 'warn') }
  busy.value = false
}
async function resend() {
  try { await resendVerification(session.value.user.email); toast('Verification email sent', 'ok') }
  catch (e) { toast(e.message, 'warn') }
}
async function logout() { await signOut(); router.push('/login') }
async function logoutAll() { await signOutEverywhere(); toast('Signed out on all devices', 'ok'); router.push('/login') }
</script>

<template>
  <div class="topbar"><div class="inner">
    <button class="btn btn-ghost" @click="router.back()">← Back</button>
    <div class="tb-spacer"></div>
    <div class="tb-name">Account</div>
  </div></div>

  <div class="wrap" style="max-width:640px">
    <!-- email verification banner -->
    <div v-if="session?.user?.email && !emailVerified" class="panel" style="border-color:var(--owed-soft);background:var(--owed-soft)">
      <h2>Verify your email</h2>
      <div class="sub" style="color:var(--owed-ink)">We sent a link to {{ session.user.email }}. Verify to secure your account.</div>
      <button class="btn btn-ghost" @click="resend">Resend verification email</button>
    </div>

    <div class="panel">
      <h2>Your profile</h2>
      <div class="sub">This is how you appear across the platform.</div>
      <div class="fg"><label>Name</label><input v-model="name" /></div>
      <div class="fg"><label>Phone</label><input v-model="phone" placeholder="+255…" /></div>
      <button class="btn btn-accent" :disabled="busy" @click="saveProfile">Save profile</button>
    </div>

    <div class="panel">
      <h2>Change password</h2>
      <div class="sub">Use at least 8 characters.</div>
      <div class="fg"><label>New password</label><input v-model="newPw" type="password" /></div>
      <div class="fg"><label>Confirm</label><input v-model="newPw2" type="password" /></div>
      <button class="btn btn-accent" :disabled="busy" @click="changePw">Change password</button>
    </div>

    <div class="panel">
      <h2>Sessions</h2>
      <div class="sub">Signed in as {{ session?.user?.email || session?.user?.phone }}.</div>
      <div style="display:flex;gap:10px;flex-wrap:wrap">
        <button class="btn btn-ghost" @click="logout">Sign out</button>
        <button class="btn btn-owed" @click="logoutAll">Sign out everywhere</button>
      </div>
    </div>
  </div>
</template>
