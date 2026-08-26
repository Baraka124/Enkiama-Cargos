<script setup>
// Driver onboarding: pick a carrier, submit identity documents, await approval.
import { ref, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import AppHeader from '../components/AppHeader.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import DocUpload from '../components/DocUpload.vue'
import { humanError } from '../lib/humanError'

const router = useRouter()
const toast = inject('toast')

const carriers = ref([])
const f = ref({ carrier_id: '', name: '', phone: '', vehicle: '', license_no: '', license_photo: '', national_id_no: '', national_id_photo: '' })
const busy = ref(false)
const loadingCarriers = ref(true)

onMounted(async () => {
  try { const { data } = await supabase.rpc('joinable_carriers'); carriers.value = data || [] } catch (e) {}
  loadingCarriers.value = false
})

async function submit() {
  if (!f.value.carrier_id) { toast('Choose a carrier to join', 'warn'); return }
  if (!f.value.name || !f.value.phone) { toast('Name and phone are required', 'warn'); return }
  if (!f.value.license_photo || !f.value.national_id_photo) { toast('Upload your licence and national ID photos', 'warn'); return }
  busy.value = true
  try {
    const { data } = await supabase.rpc('apply_to_carrier', {
      p_carrier_id: f.value.carrier_id, p_name: f.value.name, p_phone: f.value.phone, p_vehicle: f.value.vehicle,
      p_license_no: f.value.license_no || null, p_license_photo: f.value.license_photo,
      p_national_id_no: f.value.national_id_no || null, p_national_id_photo: f.value.national_id_photo,
    })
    if (data?.ok) { toast('Application sent — the carrier will review it', 'ok'); router.push('/driver') }
    else toast(data?.error || 'Could not submit', 'warn')
  } catch (e) { toast(humanError(e), 'warn') }
  busy.value = false
}
</script>

<template>
  <AppHeader title="Become a driver" subtitle="Join a carrier" />

  <div class="da-hero">
    <div class="da-hero-inner">
      <div class="da-eyebrow"><Icon name="bike" :size="14" /> Driver application</div>
      <h1 class="da-h1">Join a carrier, <span class="da-grad">start earning.</span></h1>
      <p class="da-sub">Choose the carrier you want to drive for and verify your identity. Once they approve you, you'll see parcels and can start running.</p>
    </div>
  </div>

  <div class="wrap da-wrap">
    <div class="da-card">
      <div class="da-sec">1 · Choose your carrier</div>
      <div v-if="loadingCarriers" class="da-loading"><Spinner :size="20" /></div>
      <div v-else class="da-carriers">
        <button v-for="c in carriers" :key="c.id" class="da-carrier" :class="{on:f.carrier_id===c.id}" @click="f.carrier_id=c.id">
          <span class="da-carrier-mark" :style="{background:c.accent||'#0B6E5D'}">{{ c.name.slice(0,2).toUpperCase() }}</span>
          <span class="da-carrier-info"><b>{{ c.name }}</b><span v-if="c.region">{{ c.region }}</span></span>
          <Icon v-if="f.carrier_id===c.id" name="check" :size="16" class="da-carrier-check" />
        </button>
      </div>

      <div class="da-sec">2 · Your details</div>
      <div class="fg"><label>Full name</label><input v-model="f.name" placeholder="e.g. Charles Temba" /></div>
      <div class="row2">
        <div class="fg"><label>Phone</label><input v-model="f.phone" placeholder="+255…" /></div>
        <div class="fg"><label>Vehicle</label><input v-model="f.vehicle" placeholder="bajaji, bodaboda, truck…" /></div>
      </div>

      <div class="da-sec">3 · Verify your identity</div>
      <p class="da-privacy"><Icon name="lock" :size="13" /> Your documents are private — only your chosen carrier can see them to verify you. They are never shown publicly.</p>
      <div class="row2">
        <div class="fg"><label>Driving licence number</label><input v-model="f.license_no" placeholder="Licence no." /></div>
        <div class="fg"><label>National ID number</label><input v-model="f.national_id_no" placeholder="NIDA no." /></div>
      </div>
      <div class="row2">
        <div class="da-doc"><span class="da-doc-l">Licence photo</span><DocUpload v-model="f.license_photo" label="Upload licence" /></div>
        <div class="da-doc"><span class="da-doc-l">National ID photo</span><DocUpload v-model="f.national_id_photo" label="Upload national ID" /></div>
      </div>

      <button class="btn btn-accent btn-block btn-lg da-submit" :disabled="busy" @click="submit">
        <Spinner v-if="busy" :size="16" /><span v-else>Submit application</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.da-hero{background:linear-gradient(160deg,var(--ink),#1A2430 70%,var(--accent));color:#fff;padding:40px 24px 36px}
.da-hero-inner{max-width:720px;margin:0 auto}
.da-eyebrow{display:inline-flex;align-items:center;gap:7px;font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:#4FD1B5;margin-bottom:14px}
.da-h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(26px,3.5vw,38px);font-weight:700;letter-spacing:-.03em;line-height:1.08;margin-bottom:12px}
.da-grad{background:linear-gradient(110deg,#4FD1B5,#7EE8CF);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.da-sub{font-size:14.5px;line-height:1.6;color:rgba(255,255,255,.72);max-width:520px}
.da-wrap{max-width:720px;padding-top:24px}
.da-card{background:var(--surface);border:1px solid var(--hairline-2);border-radius:16px;padding:26px;box-shadow:var(--shadow-md)}
.da-sec{font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;color:var(--accent-ink);margin:22px 0 12px;padding-bottom:7px;border-bottom:1px solid var(--hairline)}
.da-sec:first-child{margin-top:0}
.da-loading{display:flex;justify-content:center;padding:20px}
.da-carriers{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.da-carrier{display:flex;align-items:center;gap:11px;padding:13px;border:1.5px solid var(--hairline-2);border-radius:12px;background:var(--surface);cursor:pointer;text-align:left;font-family:inherit;transition:.15s;position:relative}
.da-carrier:hover{border-color:var(--accent)}
.da-carrier.on{border-color:var(--accent);background:var(--accent-soft)}
.da-carrier-mark{width:38px;height:38px;border-radius:10px;color:#fff;display:flex;align-items:center;justify-content:center;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:14px;flex-shrink:0}
.da-carrier-info{display:flex;flex-direction:column;min-width:0}
.da-carrier-info b{font-size:14px;color:var(--ink)}
.da-carrier-info span{font-size:12px;color:var(--ink-faint)}
.da-carrier-check{color:var(--accent-ink);margin-left:auto}
.da-privacy{display:flex;align-items:center;gap:7px;font-size:12.5px;color:var(--ink-soft);background:var(--surface-2);padding:10px 12px;border-radius:10px;margin-bottom:14px;line-height:1.4}
.da-privacy svg{color:var(--accent-ink);flex-shrink:0}
.da-doc{display:flex;flex-direction:column}
.da-doc-l{font-size:12.5px;font-weight:600;color:var(--ink-soft);margin-bottom:7px}
.da-submit{margin-top:20px}
@media(max-width:560px){.da-carriers{grid-template-columns:1fr}}
</style>
