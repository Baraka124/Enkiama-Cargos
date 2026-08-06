<script setup>
import { ref, onMounted, computed, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { supabase, fmtTZS } from '../lib/supabase'

const router = useRouter()
const toast = inject('toast')
const { profile, isPlatformAdmin, setHat, signOut } = useAuth()

const carriers = ref([])
const stats = ref({ carriers: 0, consignments: 0, onRoad: 0, settledToday: 0 })
const loading = ref(true)

// onboarding form
const showForm = ref(false)
const f = ref({ name: '', slug: '', mark: '', accent: '#3E5BD6', region: '', adminEmail: '' })
const busy = ref(false)

onMounted(load)
async function load() {
  loading.value = true
  const { data: cs } = await supabase.from('carrier').select('*').order('created_at', { ascending: true })
  carriers.value = cs || []
  // platform-wide counts (platform admin can read across carriers)
  const { data: cons } = await supabase.from('consignment').select('id,stage,carrier_id')
  const all = cons || []
  stats.value = {
    carriers: carriers.value.length,
    consignments: all.length,
    onRoad: all.filter(c => ['collected','linehaul','with_driver'].includes(c.stage)).length,
    settledToday: 0,
  }
  // per-carrier consignment counts
  const counts = {}
  all.forEach(c => { counts[c.carrier_id] = (counts[c.carrier_id]||0)+1 })
  carriers.value.forEach(c => c._count = counts[c.id] || 0)
  loading.value = false
}

function autoSlug() {
  if (!f.value.slug) f.value.slug = f.value.name.toLowerCase().replace(/[^a-z0-9]+/g,'').slice(0,12)
  if (!f.value.mark) f.value.mark = f.value.name.slice(0,2).toUpperCase()
}

async function onboard() {
  const v = f.value
  if (!v.name || !v.slug || !v.adminEmail) { toast('Name, slug and admin email are required', 'warn'); return }
  busy.value = true
  const { error } = await supabase.rpc('create_carrier_with_admin', {
    p_slug: v.slug, p_name: v.name, p_mark: v.mark || v.name.slice(0,2).toUpperCase(),
    p_accent: v.accent, p_region: v.region, p_admin_email: v.adminEmail,
  })
  busy.value = false
  if (error) { toast(error.message || 'Could not onboard carrier', 'warn'); return }
  toast(`${v.name} onboarded — invite sent to ${v.adminEmail}`, 'ok')
  showForm.value = false
  f.value = { name: '', slug: '', mark: '', accent: '#3E5BD6', region: '', adminEmail: '' }
  load()
}

function runAsEnkiama() {
  // switch hat to carrier console (platform admin also runs Enkiama)
  setHat('carrier'); router.push('/dispatch')
}
async function logout() { await signOut(); router.push('/login') }

// ── manage a carrier (edit / suspend) ──
const manageModal = ref(null)   // the carrier being managed
const m = ref({ name:'', mark:'', accent:'', region:'' })
function openManage(c) {
  manageModal.value = c
  m.value = { name:c.name, mark:c.mark, accent:c.accent, region:c.region }
}
async function saveCarrier() {
  const c = manageModal.value
  const { error } = await supabase.rpc('update_carrier', {
    p_carrier: c.id, p_name: m.value.name, p_mark: m.value.mark,
    p_accent: m.value.accent, p_region: m.value.region,
  })
  if (error) { toast(error.message, 'warn'); return }
  toast('Carrier updated', 'ok'); manageModal.value = null; load()
}
async function toggleStatus(c) {
  const next = c.status === 'active' ? 'suspended' : 'active'
  const { error } = await supabase.rpc('set_carrier_status', { p_carrier: c.id, p_status: next })
  if (error) { toast(error.message, 'warn'); return }
  toast(`${c.name} ${next}`, 'ok'); manageModal.value = null; load()
}

function initials(n){ return (n||'?').split(' ').map(w=>w[0]).slice(0,2).join('').toUpperCase() }
</script>

<template>
  <div class="topbar"><div class="inner">
    <div class="tb-mark" style="background:linear-gradient(135deg,#EAE7DE,#B4AE9E);color:#0A0C10">EN</div>
    <div><div class="tb-name">Enkiama Cargos</div><div class="tb-role">Platform console · {{ profile?.name || 'Admin' }}</div></div>
    <div class="tb-spacer"></div>
    <button class="btn btn-ghost" @click="runAsEnkiama">↔ Run Enkiama as carrier</button>
    <button class="btn btn-ghost" style="margin-left:8px" @click="logout">Sign out</button>
  </div></div>

  <div class="wrap">
    <div class="strip">
      <div class="cell"><div class="cl">Carriers on platform</div><div class="cv">{{ stats.carriers }}</div></div>
      <div class="cell"><div class="cl">Consignments (all)</div><div class="cv">{{ stats.consignments }}</div></div>
      <div class="cell"><div class="cl">On the road now</div><div class="cv">{{ stats.onRoad }}</div></div>
      <div class="cell"><div class="cl">Your role</div><div class="cv" style="font-size:16px">Platform admin</div></div>
    </div>

    <div class="dtabs" style="justify-content:space-between">
      <div style="display:flex;align-items:center"><span class="dtab on">Carriers</span></div>
      <button class="btn btn-accent" @click="showForm=true">+ Onboard a carrier</button>
    </div>

    <div v-if="loading" class="empty"><p>Loading platform…</p></div>
    <div v-else-if="!carriers.length" class="empty"><span class="e-ic">🚚</span><p>No carriers yet</p><small>Onboard your first delivery company to get started.</small></div>

    <div v-for="c in carriers" :key="c.id" class="cons" style="padding:16px;display:flex;align-items:center;gap:14px">
      <div class="tb-mark" :style="{ background: c.accent }">{{ c.mark || initials(c.name) }}</div>
      <div>
        <div style="font-weight:600;font-size:15px">{{ c.name }}
          <span v-if="c.slug==='enkiama'" class="paychip pay-prepaid" style="margin-left:6px">You</span>
          <span v-if="c.status==='suspended'" class="paychip pay-cod" style="margin-left:6px">Suspended</span>
        </div>
        <div class="p-sub">{{ c.region || '—' }} · {{ c._count }} consignments</div>
      </div>
      <div style="margin-left:auto;display:flex;align-items:center;gap:12px">
        <span class="p-sub mono">{{ c.slug }}</span>
        <button class="btn btn-ghost" @click="openManage(c)">Manage</button>
      </div>
    </div>
  </div>

  <!-- MANAGE CARRIER MODAL -->
  <div v-if="manageModal" class="overlay" @click.self="manageModal=null">
    <div class="modal">
      <h3>Manage {{ manageModal.name }}</h3>
      <p>Edit the carrier's brand, or suspend them from operating.</p>
      <div class="fg"><label>Name</label><input v-model="m.name" /></div>
      <div class="row2">
        <div class="fg"><label>Badge</label><input v-model="m.mark" maxlength="2" /></div>
        <div class="fg"><label>Colour</label><input v-model="m.accent" type="color" style="height:44px;padding:4px" /></div>
      </div>
      <div class="fg"><label>Region</label><input v-model="m.region" /></div>
      <div style="display:flex;gap:10px;margin-top:4px">
        <button class="btn" :class="manageModal.status==='active' ? 'btn-owed' : 'btn-go'" @click="toggleStatus(manageModal)">
          {{ manageModal.status==='active' ? 'Suspend carrier' : 'Reactivate' }}
        </button>
        <button class="btn btn-accent" style="flex:1" @click="saveCarrier">Save changes</button>
      </div>
      <button class="btn btn-ghost btn-block" style="margin-top:8px" @click="manageModal=null">Close</button>
    </div>
  </div>

  <!-- ONBOARD MODAL -->
  <div v-if="showForm" class="overlay" @click.self="showForm=false">
    <div class="modal">
      <h3>Onboard a carrier</h3>
      <p>Create the company and invite its admin. They set their own password by signing up with this email.</p>
      <div class="fg"><label>Company name</label><input v-model="f.name" placeholder="USIRI Cargo" @blur="autoSlug" /></div>
      <div class="row2">
        <div class="fg"><label>Slug (url id)</label><input v-model="f.slug" placeholder="usiri" /></div>
        <div class="fg"><label>Badge (2 letters)</label><input v-model="f.mark" maxlength="2" placeholder="US" /></div>
      </div>
      <div class="row2">
        <div class="fg"><label>Brand colour</label><input v-model="f.accent" type="color" style="height:44px;padding:4px" /></div>
        <div class="fg"><label>Region</label><input v-model="f.region" placeholder="Dar es Salaam" /></div>
      </div>
      <div class="fg"><label>Admin email (they'll be invited)</label><input v-model="f.adminEmail" type="email" placeholder="admin@usiri.co.tz" /></div>
      <div style="display:flex;gap:10px;margin-top:6px">
        <button class="btn btn-ghost" @click="showForm=false">Cancel</button>
        <button class="btn btn-accent" style="flex:1" :disabled="busy" @click="onboard">Onboard carrier</button>
      </div>
    </div>
  </div>
</template>
