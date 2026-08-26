<script setup>
// Full carrier profile — everything a platform admin needs: profile, live stats,
// drivers, recent parcels, and full edit of every onboarding field.
import { ref, onMounted, computed, inject } from 'vue'
import { supabase } from '../lib/supabase'
import Icon from './Icon.vue'
import Spinner from './Spinner.vue'
import CarrierMark from './CarrierMark.vue'
import TrustBadge from './TrustBadge.vue'

const props = defineProps({ carrierId: { type: String, required: true } })
const emit = defineEmits(['close', 'changed'])
const toast = inject('toast')

const data = ref(null)
const loading = ref(true)
const tab = ref('overview')  // overview | edit
const busy = ref(false)
const form = ref({})

async function load() {
  loading.value = true
  try {
    const { data: res } = await supabase.rpc('admin_carrier_profile', { p_carrier_id: props.carrierId })
    if (res?.ok) { data.value = res; form.value = { ...res.carrier } }
  } catch (e) {}
  loading.value = false
}
const c = computed(() => data.value?.carrier || {})
const s = computed(() => data.value?.stats || {})

async function save() {
  busy.value = true
  try {
    const f = form.value
    const { data: res } = await supabase.rpc('admin_update_carrier', {
      p_id: props.carrierId, p_name: f.name, p_mark: f.mark, p_accent: f.accent, p_region: f.region,
      p_phone: f.phone, p_email: f.email, p_address: f.address, p_contact_person: f.contact_person,
      p_fleet_size: f.fleet_size ? Number(f.fleet_size) : null, p_vehicle_types: f.vehicle_types,
      p_reg_number: f.reg_number, p_corridors: f.corridors, p_about: f.about,
      p_listed_in_marketplace: f.listed_in_marketplace,
    })
    if (res?.ok) { toast('Carrier updated', 'ok'); await load(); emit('changed'); tab.value = 'overview' }
    else toast(res?.error || 'Could not save', 'warn')
  } catch (e) { toast('Could not save', 'warn') }
  busy.value = false
}

async function toggleSuspend() {
  const suspend = c.value.status !== 'suspended'
  try {
    await supabase.from('carrier').update({ status: suspend ? 'suspended' : 'active' }).eq('id', props.carrierId)
    toast(suspend ? 'Carrier suspended' : 'Carrier reactivated', suspend ? 'warn' : 'ok')
    await load(); emit('changed')
  } catch (e) { toast('Could not update status', 'warn') }
}

onMounted(load)
</script>

<template>
  <div class="cp-overlay" @click.self="emit('close')">
    <div class="cp">
      <button class="cp-x" @click="emit('close')"><Icon name="plus" :size="18" style="transform:rotate(45deg)" /></button>

      <div v-if="loading" class="cp-load"><Spinner :size="26" /></div>
      <template v-else-if="data">
        <!-- header -->
        <div class="cp-head" :style="{'--c': c.accent || 'var(--accent)'}">
          <CarrierMark :slug="c.slug" :mark="c.mark" :name="c.name" :accent="c.accent" :size="60" />
          <div class="cp-head-id">
            <div class="cp-name">{{ c.name }}
              <span v-if="c.status==='suspended'" class="cp-tag susp">Suspended</span>
              <span v-else class="cp-tag active">Active</span>
            </div>
            <div class="cp-sub">{{ c.region || 'No region set' }} · <span class="mono">{{ c.slug }}</span></div>
            <TrustBadge v-if="data.reputation && data.reputation.tier !== 'new'" :rep="data.reputation" class="cp-trust" />
          </div>
        </div>

        <!-- tabs -->
        <div class="cp-tabs">
          <button class="cp-tab" :class="{on:tab==='overview'}" @click="tab='overview'">Overview</button>
          <button class="cp-tab" :class="{on:tab==='edit'}" @click="tab='edit'">Edit profile</button>
        </div>

        <!-- OVERVIEW -->
        <div v-if="tab==='overview'" class="cp-body">
          <div class="cp-stats">
            <div class="cp-stat"><span class="cp-stat-v">{{ s.total_parcels }}</span><span class="cp-stat-l">Total parcels</span></div>
            <div class="cp-stat"><span class="cp-stat-v">{{ s.on_road }}</span><span class="cp-stat-l">On road</span></div>
            <div class="cp-stat"><span class="cp-stat-v">{{ s.delivered }}</span><span class="cp-stat-l">Delivered</span></div>
            <div class="cp-stat"><span class="cp-stat-v" :class="{bad:s.failed}">{{ s.failed }}</span><span class="cp-stat-l">Failed</span></div>
            <div class="cp-stat"><span class="cp-stat-v">{{ s.drivers }}</span><span class="cp-stat-l">Drivers</span></div>
            <div class="cp-stat"><span class="cp-stat-v">TZS {{ Number(s.cash_to_collect||0).toLocaleString() }}</span><span class="cp-stat-l">Cash to collect</span></div>
          </div>

          <div class="cp-cols">
            <div class="cp-col">
              <div class="cp-sec-t">Contact &amp; operations</div>
              <div class="cp-field"><span>Contact person</span><b>{{ c.contact_person || '—' }}</b></div>
              <div class="cp-field"><span>Phone</span><b>{{ c.phone || '—' }}</b></div>
              <div class="cp-field"><span>Email</span><b>{{ c.email || '—' }}</b></div>
              <div class="cp-field"><span>Address</span><b>{{ c.address || '—' }}</b></div>
              <div class="cp-field"><span>Fleet size</span><b>{{ c.fleet_size || '—' }}</b></div>
              <div class="cp-field"><span>Vehicles</span><b>{{ c.vehicle_types || '—' }}</b></div>
              <div class="cp-field"><span>Corridors</span><b>{{ c.corridors || '—' }}</b></div>
              <div class="cp-field"><span>Reg. number</span><b>{{ c.reg_number || '—' }}</b></div>
              <div class="cp-field"><span>In marketplace</span><b>{{ c.listed_in_marketplace ? 'Yes' : 'No' }}</b></div>
            </div>
            <div class="cp-col">
              <div class="cp-sec-t">Drivers ({{ data.drivers.length }})</div>
              <div v-if="!data.drivers.length" class="cp-empty">No active drivers</div>
              <div v-for="d in data.drivers" :key="d.id" class="cp-driver">
                <span class="cp-driver-name">{{ d.name }}</span>
                <span class="cp-driver-veh">{{ d.vehicle || '—' }}</span>
              </div>
              <div v-if="s.pending_drivers" class="cp-pending">{{ s.pending_drivers }} pending application{{ s.pending_drivers>1?'s':'' }}</div>
            </div>
          </div>

          <div class="cp-sec-t">Recent parcels</div>
          <div v-if="!data.recent_parcels.length" class="cp-empty">No parcels yet</div>
          <div v-else class="cp-parcels">
            <div v-for="p in data.recent_parcels" :key="p.code" class="cp-parcel">
              <span class="mono cp-parcel-code">{{ p.code }}</span>
              <span class="cp-parcel-to">{{ p.receiver }} · {{ p.dest }}</span>
              <span class="cp-parcel-stage" :class="'st-'+p.stage">{{ p.stage }}</span>
            </div>
          </div>

          <div class="cp-danger">
            <button class="btn" :class="c.status==='suspended' ? 'btn-accent' : 'btn-danger'" @click="toggleSuspend">
              {{ c.status==='suspended' ? 'Reactivate carrier' : 'Suspend carrier' }}
            </button>
            <span class="cp-danger-note">{{ c.status==='suspended' ? 'Currently suspended — cannot operate.' : 'Suspending freezes their drivers and parcels.' }}</span>
          </div>
        </div>

        <!-- EDIT -->
        <div v-else class="cp-body">
          <div class="cp-sec-t">Company</div>
          <div class="row2"><div class="fg"><label>Name</label><input v-model="form.name" /></div><div class="fg"><label>Badge</label><input v-model="form.mark" maxlength="3" /></div></div>
          <div class="row2"><div class="fg"><label>Region</label><input v-model="form.region" /></div><div class="fg"><label>Accent colour</label><input type="color" v-model="form.accent" class="cp-color" /></div></div>
          <div class="fg"><label>About</label><textarea v-model="form.about" rows="2"></textarea></div>

          <div class="cp-sec-t">Contact</div>
          <div class="row2"><div class="fg"><label>Contact person</label><input v-model="form.contact_person" /></div><div class="fg"><label>Phone</label><input v-model="form.phone" /></div></div>
          <div class="row2"><div class="fg"><label>Email</label><input v-model="form.email" /></div><div class="fg"><label>Reg. number</label><input v-model="form.reg_number" /></div></div>
          <div class="fg"><label>Address</label><input v-model="form.address" /></div>

          <div class="cp-sec-t">Operations</div>
          <div class="row2"><div class="fg"><label>Fleet size</label><input type="number" v-model="form.fleet_size" /></div><div class="fg"><label>Vehicle types</label><input v-model="form.vehicle_types" /></div></div>
          <div class="fg"><label>Corridors served</label><input v-model="form.corridors" placeholder="e.g. Dar–Mbeya, Dar–Arusha" /></div>
          <label class="cp-check"><input type="checkbox" v-model="form.listed_in_marketplace" /> List this carrier in the marketplace</label>

          <div class="form-actions">
            <button class="btn btn-ghost" @click="tab='overview'">Cancel</button>
            <button class="btn btn-accent" :disabled="busy" @click="save"><Spinner v-if="busy" :size="15" /><span v-else>Save changes</span></button>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.cp-overlay{position:fixed;inset:0;background:rgba(20,24,31,.55);backdrop-filter:blur(4px);z-index:1000;display:flex;align-items:flex-start;justify-content:center;padding:30px 16px;overflow-y:auto}
.cp{background:var(--surface);border-radius:20px;max-width:760px;width:100%;box-shadow:var(--shadow-xl);position:relative;overflow:hidden}
.cp-x{position:absolute;top:16px;right:16px;z-index:5;width:34px;height:34px;border-radius:10px;border:1px solid var(--hairline-2);background:var(--surface-2);color:var(--ink-faint);cursor:pointer;display:flex;align-items:center;justify-content:center}
.cp-load{display:flex;justify-content:center;padding:80px}
.cp-head{display:flex;gap:18px;align-items:center;padding:28px;background:linear-gradient(140deg, color-mix(in srgb, var(--c) 12%, var(--surface)), var(--surface));border-bottom:1px solid var(--hairline)}
.cp-name{font-family:'Space Grotesk',sans-serif;font-size:24px;font-weight:700;letter-spacing:-.02em;color:var(--ink);display:flex;align-items:center;gap:10px}
.cp-tag{font-size:11px;font-weight:700;padding:3px 10px;border-radius:999px}
.cp-tag.active{background:var(--go-soft);color:var(--go-ink)}
.cp-tag.susp{background:var(--owed-soft);color:var(--owed-ink)}
.cp-sub{font-size:13.5px;color:var(--ink-faint);margin-top:4px}
.cp-trust{margin-top:10px}
.cp-tabs{display:flex;gap:4px;padding:12px 28px 0}
.cp-tab{background:none;border:none;font-family:inherit;font-size:14px;font-weight:600;color:var(--ink-faint);padding:8px 14px;border-radius:10px;cursor:pointer}
.cp-tab.on{background:var(--accent-soft);color:var(--accent-ink);font-weight:700}
.cp-body{padding:22px 28px 28px}
.cp-stats{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:24px}
.cp-stat{background:var(--surface-2);border-radius:12px;padding:14px 16px}
.cp-stat-v{display:block;font-family:'Space Grotesk',sans-serif;font-size:22px;font-weight:700;letter-spacing:-.02em;color:var(--ink);font-variant-numeric:tabular-nums}
.cp-stat-v.bad{color:var(--owed-ink)}
.cp-stat-l{font-size:12px;color:var(--ink-faint);font-weight:600}
.cp-cols{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-bottom:20px}
.cp-sec-t{font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;color:var(--accent-ink);margin:18px 0 12px;padding-bottom:7px;border-bottom:1px solid var(--hairline)}
.cp-field{display:flex;justify-content:space-between;gap:12px;font-size:13px;padding:6px 0}
.cp-field span{color:var(--ink-faint)}
.cp-field b{color:var(--ink);text-align:right;font-weight:600}
.cp-driver{display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--hairline);font-size:13px}
.cp-driver-name{font-weight:600;color:var(--ink)}
.cp-driver-veh{color:var(--ink-faint)}
.cp-pending{font-size:12px;color:var(--warn-ink);margin-top:10px;font-weight:600}
.cp-empty{font-size:13px;color:var(--ink-faint);padding:8px 0}
.cp-parcels{display:flex;flex-direction:column;gap:2px}
.cp-parcel{display:grid;grid-template-columns:100px 1fr auto;gap:12px;align-items:center;padding:9px 0;border-bottom:1px solid var(--hairline);font-size:13px}
.cp-parcel-code{font-weight:600;color:var(--ink)}
.cp-parcel-to{color:var(--ink-soft);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.cp-parcel-stage{font-size:11px;font-weight:700;padding:3px 9px;border-radius:999px;background:var(--surface-3);color:var(--ink-soft);text-transform:capitalize}
.cp-danger{display:flex;align-items:center;gap:14px;margin-top:26px;padding-top:20px;border-top:1px solid var(--hairline)}
.cp-danger-note{font-size:12.5px;color:var(--ink-faint)}
.btn-danger{background:var(--owed-soft);color:var(--owed-ink);border:1px solid transparent}
.btn-danger:hover{background:var(--owed);color:#fff}
.cp-color{height:42px;padding:4px;cursor:pointer}
.cp-check{display:flex;align-items:center;gap:9px;font-size:13.5px;color:var(--ink-soft);margin-top:14px;cursor:pointer}
.cp-check input{width:16px;height:16px;accent-color:var(--accent)}
@media(max-width:640px){.cp-stats{grid-template-columns:repeat(2,1fr)}.cp-cols{grid-template-columns:1fr}}
</style>
