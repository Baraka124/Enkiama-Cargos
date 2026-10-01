<script setup>
import { ref, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import AppHeader from '../components/AppHeader.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import { humanError } from '../lib/humanError'

const router = useRouter()
const toast = inject('toast')
const { session, profile, emailVerified, updateMyProfile, updatePassword, resendVerification, signOut, signOutEverywhere } = useAuth()

const name = ref(''); const phone = ref('')
const newPw = ref(''); const newPw2 = ref('')
const savingProfile = ref(false); const savingPw = ref(false)
const driverProfile = ref(null)
const dVehicle = ref(''); const dLicense = ref(''); const savingDriver = ref(false)

onMounted(async () => {
  name.value = profile.value?.name || ''; phone.value = profile.value?.phone || ''
  if (profile.value?.role === 'driver') {
    try {
      const { supabase } = await import('../lib/supabase')
      const { data } = await supabase.rpc('my_driver_profile')
      driverProfile.value = data
      dVehicle.value = data?.vehicle || ''; dLicense.value = data?.license_no || ''
    } catch (e) {}
  }
})

async function saveDriver() {
  savingDriver.value = true
  try {
    const { supabase } = await import('../lib/supabase')
    const { data } = await supabase.rpc('update_my_driver_profile', { p_vehicle: dVehicle.value || null, p_license: dLicense.value || null })
    if (data?.ok) toast('Driver details saved', 'ok'); else toast(data?.error || 'Could not save', 'warn')
  } catch (e) { toast(humanError(e), 'warn') }
  savingDriver.value = false
}

async function saveProfile() {
  savingProfile.value = true
  try { await updateMyProfile(name.value, phone.value); toast('Profile updated', 'ok') }
  catch (e) { toast(humanError(e), 'warn') }
  savingProfile.value = false
}
async function changePw() {
  if (newPw.value.length < 8) { toast('Use at least 8 characters', 'warn'); return }
  if (newPw.value !== newPw2.value) { toast('Passwords don\u2019t match', 'warn'); return }
  savingPw.value = true
  try { await updatePassword(newPw.value); toast('Password changed', 'ok'); newPw.value=''; newPw2.value='' }
  catch (e) { toast(humanError(e), 'warn') }
  savingPw.value = false
}
async function resend() {
  try { await resendVerification(session.value.user.email); toast('Verification email sent', 'ok') }
  catch (e) { toast(humanError(e), 'warn') }
}
async function logout() { await signOut(); router.push('/login') }
async function logoutAll() { await signOutEverywhere(); toast('Signed out on all devices', 'ok'); router.push('/login') }
function initials(n) { return (n||'?').split(' ').map(w=>w[0]).slice(0,2).join('').toUpperCase() }
</script>

<template>
  <AppHeader title="Account" :subtitle="profile?.role ? profile.role.replace('_',' ') : 'Settings'">
    <button class="btn btn-ghost" @click="router.back()"><Icon name="arrow" :size="15" style="transform:rotate(180deg)" /> Back</button>
  </AppHeader>

  <div class="wrap acct">
    <!-- identity summary -->
    <div class="acct-hero">
      <div class="acct-avatar">{{ initials(profile?.name) }}</div>
      <div>
        <div class="acct-name">{{ profile?.name || 'Your account' }}</div>
        <div class="acct-email">{{ session?.user?.email || session?.user?.phone }}</div>
      </div>
      <span v-if="emailVerified" class="acct-verified"><Icon name="check" :size="13" /> Verified</span>
    </div>

    <!-- email verification -->
    <div v-if="session?.user?.email && !emailVerified" class="acct-card warn">
      <div class="acct-card-ic warn"><Icon name="alert" :size="18" /></div>
      <div style="flex:1">
        <div class="acct-card-h">Verify your email</div>
        <p class="acct-card-p">We sent a link to {{ session.user.email }}. Verify to secure your account.</p>
        <button class="btn btn-ghost" @click="resend">Resend verification email</button>
      </div>
    </div>

    <!-- profile -->
    <div class="acct-card">
      <div class="acct-card-ic"><Icon name="user" :size="18" /></div>
      <div style="flex:1">
        <div class="acct-card-h">Your profile</div>
        <p class="acct-card-p">How you appear across the platform.</p>
        <div class="row2">
          <div class="fg"><label>Name</label><input v-model="name" placeholder="Your name" /></div>
          <div class="fg"><label>Phone</label><input v-model="phone" type="tel" inputmode="tel" placeholder="+255…" /></div>
        </div>
        <button class="btn btn-accent" :disabled="savingProfile" @click="saveProfile"><Spinner v-if="savingProfile" :size="15" /><span v-else>Save profile</span></button>
      </div>
    </div>

    <!-- driver-specific: their vehicle & license -->
    <div v-if="profile?.role === 'driver'" class="acct-card">
      <div class="acct-card-ic"><Icon name="bike" :size="18" /></div>
      <div style="flex:1">
        <div class="acct-card-h">Driver details</div>
        <p class="acct-card-p">Your vehicle and licence — shown to the carrier that assigns you.</p>
        <div v-if="driverProfile" class="acct-driver-stat"><Icon name="check" :size="13" /> {{ driverProfile.delivered }} delivered<template v-if="driverProfile.carrier"> · {{ driverProfile.carrier }}</template></div>
        <div class="row2">
          <div class="fg"><label>Vehicle</label><input v-model="dVehicle" placeholder="bajaji, bodaboda, truck…" /></div>
          <div class="fg"><label>Licence no.</label><input v-model="dLicense" placeholder="Driving licence number" /></div>
        </div>
        <button class="btn btn-accent" :disabled="savingDriver" @click="saveDriver"><Spinner v-if="savingDriver" :size="15" /><span v-else>Save driver details</span></button>
      </div>
    </div>

    <!-- password -->
    <div class="acct-card">
      <div class="acct-card-ic"><Icon name="lock" :size="18" /></div>
      <div style="flex:1">
        <div class="acct-card-h">Change password</div>
        <p class="acct-card-p">At least 8 characters. Choose something private.</p>
        <div class="row2">
          <div class="fg"><label>New password</label><input v-model="newPw" type="password" placeholder="••••••••" /></div>
          <div class="fg"><label>Confirm</label><input v-model="newPw2" type="password" placeholder="••••••••" /></div>
        </div>
        <button class="btn btn-accent" :disabled="savingPw" @click="changePw"><Spinner v-if="savingPw" :size="15" /><span v-else>Change password</span></button>
      </div>
    </div>

    <!-- sessions -->
    <div class="acct-card">
      <div class="acct-card-ic"><Icon name="phone" :size="18" /></div>
      <div style="flex:1">
        <div class="acct-card-h">Sessions & sign out</div>
        <p class="acct-card-p">Signed in as {{ session?.user?.email || session?.user?.phone }}.</p>
        <div style="display:flex;gap:10px;flex-wrap:wrap">
          <button class="btn btn-ghost" @click="logout">Sign out</button>
          <button class="btn btn-ghost acct-danger" @click="logoutAll">Sign out everywhere</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.acct{max-width:820px;padding-top:24px}.acct-hero{display:grid;grid-template-columns:52px 1fr auto;align-items:center;gap:16px;padding:28px 0 34px;border-bottom:1px solid var(--world-line)}.acct-avatar{width:52px;height:52px;border-radius:50%;border:1px solid var(--world-line-strong);background:var(--world-surface);color:var(--world-ink);font:600 14px var(--font-display);display:grid;place-items:center;box-shadow:none}.acct-name{font:600 25px/1.05 var(--font-display);letter-spacing:-.04em;color:var(--world-ink)}.acct-email{font-size:12px;color:var(--world-ink-faint);margin-top:4px}.acct-verified{display:inline-flex;align-items:center;gap:5px;font:600 9px var(--font-mono);text-transform:uppercase;letter-spacing:.06em;color:var(--world-accent);padding:5px 0;border-bottom:1px solid var(--world-line-strong)}
.acct-card{display:grid;grid-template-columns:36px minmax(0,1fr);gap:18px;background:transparent;border:0;border-bottom:1px solid var(--world-line);border-radius:0;padding:28px 0;margin:0;box-shadow:none}.acct-card:hover{box-shadow:none}.acct-card.warn{border:0;border-bottom:1px solid color-mix(in srgb,var(--warn) 28%,var(--world-line));background:transparent}.acct-card-ic{width:32px;height:32px;border:1px solid var(--world-line);border-radius:6px;background:transparent;color:var(--world-accent);display:grid;place-items:center}.acct-card-ic.warn{background:transparent;color:var(--warn-ink);border-color:color-mix(in srgb,var(--warn) 36%,var(--world-line))}.acct-card-h{font:600 17px/1.2 var(--font-display);letter-spacing:-.025em;color:var(--world-ink);margin-bottom:4px}.acct-card-p{font-size:12px;color:var(--world-ink-faint);margin-bottom:18px;line-height:1.55}.acct-danger{color:var(--util-danger);border-color:color-mix(in srgb,var(--util-danger) 28%,var(--world-line))}.acct-danger:hover{color:var(--util-danger);border-color:var(--util-danger);background:transparent}.acct-driver-stat{display:inline-flex;align-items:center;gap:5px;font:600 10px var(--font-mono);text-transform:uppercase;letter-spacing:.04em;color:var(--world-accent);background:transparent;padding:0 0 8px;border-bottom:1px solid var(--world-line);margin-bottom:16px}.acct-driver-stat svg{color:var(--world-accent)}
@media(max-width:560px){.acct{padding-inline:18px}.acct-hero{grid-template-columns:46px 1fr}.acct-avatar{width:46px;height:46px}.acct-verified{grid-column:2;justify-self:start}.acct-card{grid-template-columns:1fr;gap:10px;padding:24px 0}.acct-card-ic{width:30px;height:30px}}
</style>