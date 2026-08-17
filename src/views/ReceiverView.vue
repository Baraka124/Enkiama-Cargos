<script setup>
import { ref, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { usePublic } from '../composables/usePublic'
import { useAuth } from '../composables/useAuth'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import EmptyState from '../components/EmptyState.vue'
import Skeleton from '../components/Skeleton.vue'
import CarrierMark from '../components/CarrierMark.vue'
import BrandMark from '../components/BrandMark.vue'

const router = useRouter()
const toast = inject('toast')
const { profile, signOut } = useAuth()

const claimedPhone = ref('')
const phoneInput = ref('')
const deliveries = ref([])
const loading = ref(true)
const pub = usePublic()
const claiming = ref(false)

const STAGE_LABELS = { booked:'Booked', collected:'Collected', linehaul:'On road', with_driver:'Out for delivery', delivered:'Delivered', confirmed:'Confirmed', failed:'Attempted', cancelled:'Cancelled' }
function stageLabel(s){ return STAGE_LABELS[s]||s }
function stageClass(s){ return ['delivered','confirmed'].includes(s)?'go':s==='failed'?'owed':'accent' }

async function load() {
  loading.value = true
  claimedPhone.value = profile.value?.claimed_phone || ''
  if (claimedPhone.value) {
    const { data } = await pub.myDeliveries()
    deliveries.value = (data || [])
  }
  loading.value = false
}
async function claimPhone() {
  if (!phoneInput.value.trim()) { toast('Enter your phone number', 'warn'); return }
  claiming.value = true
  try {
    const { error } = await pub.claimReceiverPhone(phoneInput.value.trim())
    if (error) throw error
    toast('Phone linked — showing your deliveries', 'ok')
    if (profile.value) profile.value.claimed_phone = phoneInput.value.trim()
    await load()
  } catch (e) { toast(e.message || 'Could not link phone', 'warn') }
  claiming.value = false
}
async function logout(){ await signOut(); router.push('/login') }
onMounted(load)
</script>

<template>
  <div class="topbar"><div class="inner">
    <BrandMark variant="mark" :height="32" />
    <div class="tb-idblock"><div class="tb-name">My deliveries</div><div class="tb-role">Receiver · {{ profile?.name }}</div></div>
    <div class="tb-spacer"></div>
    <button class="btn btn-ghost" @click="logout">Sign out</button>
  </div></div>

  <div class="wrap">
    <!-- claim phone if not yet linked -->
    <div v-if="!claimedPhone" class="claim-card">
      <div class="claim-ic"><Icon name="phone" :size="26" /></div>
      <h2 class="claim-h">See every parcel coming to you</h2>
      <p class="claim-p">Enter the phone number your senders use for you. We'll show every delivery addressed to it — across all carriers, live.</p>
      <div class="fg"><label>Your phone number</label>
        <input v-model="phoneInput" type="tel" inputmode="tel" placeholder="+255 7XX XXX XXX" @keyup.enter="claimPhone" />
      </div>
      <button class="btn btn-accent btn-block btn-lg" :disabled="claiming" @click="claimPhone">
        <Spinner v-if="claiming" :size="16" /><span v-else>Show my deliveries</span>
      </button>
    </div>

    <!-- deliveries list -->
    <template v-else>
      <div class="psec-head"><div><h2 class="psec-title">Incoming to {{ claimedPhone }}</h2><span class="psec-sub">Every parcel addressed to you, across all carriers</span></div></div>
      <Skeleton v-if="loading" variant="card" :count="2" />
      <EmptyState v-else-if="!deliveries.length" icon="inbox" title="Nothing incoming yet" hint="When a sender ships to your number, it appears here automatically." />
      <div v-else class="ship-list">
        <router-link v-for="d in deliveries" :key="d.id" :to="`/track/${d.code}`" class="ship-card">
          <div class="ship-top">
            <span class="ship-code mono">{{ d.code }}</span>
            <span class="ship-stage" :class="stageClass(d.stage)">{{ stageLabel(d.stage) }}</span>
          </div>
          <div class="ship-to">{{ d.item }} → {{ d.dest_address }}</div>
          <div class="ship-foot">
            <span class="ship-carrier"><Icon name="package" :size="15" /> from {{ d.sender_name || 'a sender' }}</span>
            <span class="ship-track">Track <Icon name="arrow" :size="13" /></span>
          </div>
        </router-link>
      </div>
    </template>
  </div>
</template>

<style scoped>
.claim-card{max-width:460px;margin:40px auto;background:var(--surface);border:1px solid var(--hairline);border-radius:20px;padding:32px 28px;text-align:center;box-shadow:var(--shadow-md)}
.claim-ic{width:60px;height:60px;border-radius:16px;background:var(--accent-soft);color:var(--accent-ink);display:flex;align-items:center;justify-content:center;margin:0 auto 20px}
.claim-h{font-size:21px;font-weight:700;margin-bottom:10px}
.claim-p{font-size:14px;color:var(--ink-soft);line-height:1.6;margin-bottom:22px}
.claim-card .fg{text-align:left;margin-bottom:16px}
.ship-track{display:inline-flex;align-items:center;gap:4px;font-size:12.5px;font-weight:600;color:var(--accent-ink)}
</style>
