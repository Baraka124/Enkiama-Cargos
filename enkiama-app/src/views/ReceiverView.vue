<script setup>
import { ref, onMounted, inject, computed, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { usePublic } from '../composables/usePublic'
import { useAuth } from '../composables/useAuth'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import EmptyState from '../components/EmptyState.vue'
import { viewName, signalMotionReady } from '../lib/motion'
import Skeleton from '../components/Skeleton.vue'
import AppHeader from '../components/AppHeader.vue'

const router = useRouter()
const toast = inject('toast')
const { profile } = useAuth()
const pub = usePublic()

const claimedPhone = ref('')
const phoneInput = ref('')
const deliveries = ref([])
const loading = ref(true)
const claiming = ref(false)

const STAGE_LABELS = {
  booked:'Booked', collected:'Collected', linehaul:'Moving', with_driver:'Coming to you',
  delivered:'Delivered', confirmed:'Confirmed', failed:'Needs attention', cancelled:'Cancelled'
}
const STAGE_INDEX = { booked:0, collected:1, linehaul:2, with_driver:3, delivered:4, confirmed:5 }
function stageLabel(s) { return STAGE_LABELS[s] || s }
function stageProgress(s) {
  if (s === 'failed') return 65
  const i = STAGE_INDEX[s]
  return i === undefined ? 0 : Math.round((i / 5) * 100)
}
function isComplete(s) { return ['delivered','confirmed','cancelled'].includes(s) }
function isAttention(s) { return s === 'failed' }

const activeDeliveries = computed(() => deliveries.value.filter(d => !isComplete(d.stage)))
const pastDeliveries = computed(() => deliveries.value.filter(d => isComplete(d.stage)))
const attentionCount = computed(() => deliveries.value.filter(d => isAttention(d.stage)).length)

async function load() {
  loading.value = true
  claimedPhone.value = profile.value?.claimed_phone || ''
  if (claimedPhone.value) {
    const { data } = await pub.myDeliveries()
    deliveries.value = data || []
  }
  loading.value = false
  await nextTick()
  signalMotionReady()
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
onMounted(load)
</script>

<template>
  <AppHeader title="My Movement" :subtitle="'Receiver · ' + (profile?.name || 'Enkiama')" />

  <main class="receiver-page">
    <section v-if="!claimedPhone" class="receiver-claim">
      <div class="receiver-claim-inner">
        <div class="claim-kicker">Receiver identity</div>
        <h1>Bring every<br><em>incoming journey</em><br>into one place.</h1>
        <p>Link the phone number your senders use. Parcels addressed to that number appear here across participating carriers.</p>
        <div class="claim-field">
          <span>+255</span>
          <input v-model="phoneInput" type="tel" inputmode="tel" placeholder="Your phone number" @keyup.enter="claimPhone" />
          <button :disabled="claiming" @click="claimPhone"><Spinner v-if="claiming" :size="15" /><template v-else>Link number <Icon name="arrow" :size="14" /></template></button>
        </div>
        <div class="claim-note"><Icon name="shield" :size="14" /> This links delivery visibility to your signed-in receiver account.</div>
      </div>
    </section>

    <template v-else>
      <section class="receiver-hero">
        <div class="receiver-wrap">
          <div class="receiver-kicker">Movement / Receiver</div>
          <div class="receiver-hero-grid">
            <div><h1>Your parcels,<br><em>in motion.</em></h1><p>One place for everything addressed to {{ claimedPhone }}.</p></div>
            <div class="receiver-metrics">
              <div><strong>{{ activeDeliveries.length }}</strong><span>Active</span></div>
              <div><strong>{{ pastDeliveries.length }}</strong><span>Arrived</span></div>
              <div v-if="attentionCount"><strong>{{ attentionCount }}</strong><span>Attention</span></div>
            </div>
          </div>
        </div>
      </section>

      <section class="receiver-content">
        <div class="receiver-wrap">
          <Skeleton v-if="loading" variant="card" :count="2" />
          <EmptyState v-else-if="!deliveries.length" icon="inbox" title="Nothing incoming yet" hint="When a sender ships to your number, it appears here automatically." />

          <template v-else>
            <section v-reveal class="movement-group">
              <div class="group-head"><span>01</span><h2>In movement</h2><small>{{ activeDeliveries.length }} current</small></div>
              <div v-if="activeDeliveries.length" class="delivery-list">
                <router-link v-for="d in activeDeliveries" :key="d.id || d.code" :to="`/track/${d.code}`" class="delivery-row" :class="{ attention:isAttention(d.stage) }" data-cursor="Track">
                  <div class="delivery-code mono" :style="{viewTransitionName:viewName('parcel', d.code)}">{{ d.code }}</div>
                  <div class="delivery-object"><strong>{{ d.item || 'Parcel' }}</strong><span>From {{ d.sender_name || 'sender' }}</span></div>
                  <div class="delivery-destination"><span>To</span><strong>{{ d.dest_address || 'Your delivery address' }}</strong></div>
                  <div class="delivery-status">
                    <div class="delivery-status-top"><span>{{ stageLabel(d.stage) }}</span><small>{{ stageProgress(d.stage) }}%</small></div>
                    <div class="delivery-progress"><i :style="{ width:stageProgress(d.stage)+'%' }"></i></div>
                  </div>
                  <div class="delivery-arrow"><Icon name="arrow" :size="16" /></div>
                </router-link>
              </div>
              <div v-else class="group-empty">No parcels are currently moving toward you.</div>
            </section>

            <section v-reveal class="movement-group past-group">
              <div class="group-head"><span>02</span><h2>Arrived</h2><small>{{ pastDeliveries.length }} recorded</small></div>
              <div v-if="pastDeliveries.length" class="delivery-list past-list">
                <router-link v-for="d in pastDeliveries" :key="d.id || d.code" :to="`/track/${d.code}`" class="delivery-row past" data-cursor="Track">
                  <div class="delivery-code mono" :style="{viewTransitionName:viewName('parcel', d.code)}">{{ d.code }}</div>
                  <div class="delivery-object"><strong>{{ d.item || 'Parcel' }}</strong><span>From {{ d.sender_name || 'sender' }}</span></div>
                  <div class="delivery-destination"><span>Destination</span><strong>{{ d.dest_address || 'Delivery address' }}</strong></div>
                  <div class="delivery-status final"><span>{{ stageLabel(d.stage) }}</span><Icon name="check" :size="15" /></div>
                  <div class="delivery-arrow"><Icon name="arrow" :size="16" /></div>
                </router-link>
              </div>
            </section>
          </template>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.receiver-page{min-height:100vh;background:#f4f1eb;color:var(--ink)}
.receiver-wrap{width:min(1180px,calc(100% - 64px));margin:0 auto}
.receiver-claim{min-height:calc(100vh - 70px);background:#151815;color:#fff;display:flex;align-items:center;position:relative;overflow:hidden}
.receiver-claim::before{content:"";position:absolute;width:650px;height:650px;border-radius:50%;border:1px solid rgba(255,255,255,.08);right:-160px;top:-220px;box-shadow:0 0 0 130px rgba(255,255,255,.018),0 0 0 260px rgba(255,255,255,.01)}
.receiver-claim-inner{width:min(820px,calc(100% - 48px));margin:0 auto;padding:80px 0;position:relative;z-index:1}
.claim-kicker,.receiver-kicker{font-size:10px;text-transform:uppercase;letter-spacing:.17em;color:rgba(255,255,255,.45);margin-bottom:28px}
.receiver-claim h1,.receiver-hero h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(54px,8vw,104px);line-height:.88;letter-spacing:-.07em;font-weight:500;margin:0}
.receiver-claim h1 em,.receiver-hero h1 em{font-family:Georgia,'Times New Roman',serif;font-weight:400;color:#a9cdb9}
.receiver-claim> .receiver-claim-inner>p{max-width:530px;font-size:15px;line-height:1.7;color:rgba(255,255,255,.53);margin:32px 0}
.claim-field{display:grid;grid-template-columns:64px 1fr auto;align-items:center;border-top:1px solid rgba(255,255,255,.25);border-bottom:1px solid rgba(255,255,255,.25);height:72px;max-width:680px}
.claim-field>span{font-size:12px;color:rgba(255,255,255,.4)}.claim-field input{height:100%;border:0;background:transparent;color:#fff;font-size:18px;outline:none}.claim-field input::placeholder{color:rgba(255,255,255,.26)}.claim-field button{border:0;background:transparent;color:#fff;display:flex;align-items:center;gap:8px;font-size:12px;font-weight:650;text-transform:uppercase;letter-spacing:.08em;cursor:pointer}.claim-note{display:flex;align-items:center;gap:8px;font-size:11px;color:rgba(255,255,255,.36);margin-top:18px}
.receiver-hero{background:#171a18;color:#fff;padding:82px 0 72px}.receiver-hero-grid{display:grid;grid-template-columns:1fr auto;gap:70px;align-items:end}.receiver-hero h1{font-size:clamp(58px,8vw,108px)}.receiver-hero> .receiver-wrap p{font-size:14px;color:rgba(255,255,255,.45);margin:28px 0 0}.receiver-metrics{display:flex;border-top:1px solid rgba(255,255,255,.16);border-bottom:1px solid rgba(255,255,255,.16)}.receiver-metrics>div{padding:20px 28px;min-width:112px;border-right:1px solid rgba(255,255,255,.14)}.receiver-metrics>div:last-child{border-right:0}.receiver-metrics strong{display:block;font-family:'Space Grotesk',sans-serif;font-size:32px;font-weight:500}.receiver-metrics span{display:block;font-size:9px;text-transform:uppercase;letter-spacing:.13em;color:rgba(255,255,255,.36);margin-top:5px}
.receiver-content{padding:90px 0 120px}.movement-group+.movement-group{margin-top:86px}.group-head{display:grid;grid-template-columns:60px 1fr auto;align-items:baseline;border-top:1px solid #bfc0ba;padding:18px 0 30px}.group-head>span,.group-head small{font-size:9px;text-transform:uppercase;letter-spacing:.14em;color:#7f847e}.group-head h2{font-family:'Space Grotesk',sans-serif;font-size:32px;letter-spacing:-.045em;font-weight:500;margin:0}.delivery-list{border-top:1px solid #d2cec5}.delivery-row{display:grid;grid-template-columns:120px 1.3fr 1.2fr 1fr 34px;gap:24px;align-items:center;padding:27px 0;border-bottom:1px solid #d2cec5;text-decoration:none;color:inherit;transition:padding .22s ease}.delivery-row:hover{padding-left:10px}.delivery-row.attention{background:linear-gradient(90deg,rgba(145,72,61,.055),transparent)}.delivery-code{font-size:10px;color:#767b75;letter-spacing:.08em}.delivery-object strong,.delivery-destination strong{display:block;font-size:13px;font-weight:620}.delivery-object span,.delivery-destination span{display:block;font-size:10px;color:#81857f;margin-top:4px}.delivery-destination>span{font-size:8px;text-transform:uppercase;letter-spacing:.12em;margin:0 0 5px}.delivery-status-top{display:flex;align-items:center;justify-content:space-between;font-size:10px}.delivery-status-top span{font-weight:650}.delivery-status-top small{color:#8a8f88}.delivery-progress{height:1px;background:#cecac1;margin-top:10px;overflow:hidden}.delivery-progress i{display:block;height:2px;background:#2f704f}.delivery-row.attention .delivery-progress i{background:#91483d}.delivery-status.final{display:flex;align-items:center;justify-content:flex-end;gap:8px;font-size:10px;color:#397456}.delivery-arrow{color:#797e78;display:flex;justify-content:flex-end}.delivery-row:hover .delivery-arrow{color:#2f704f}.group-empty{border-top:1px solid #d2cec5;border-bottom:1px solid #d2cec5;padding:30px 0;font-size:12px;color:#7d827b}
@media(max-width:900px){.receiver-wrap{width:calc(100% - 36px)}.receiver-hero-grid{grid-template-columns:1fr;gap:42px}.receiver-metrics{width:max-content}.delivery-row{grid-template-columns:105px 1fr 1fr 34px}.delivery-destination{display:none}}
@media(max-width:620px){.receiver-claim-inner{width:calc(100% - 30px);padding:60px 0}.receiver-claim h1,.receiver-hero h1{font-size:54px}.claim-field{grid-template-columns:44px 1fr;height:auto;min-height:68px}.claim-field button{grid-column:1/-1;border-top:1px solid rgba(255,255,255,.14);padding:16px 0;justify-content:space-between}.receiver-wrap{width:calc(100% - 28px)}.receiver-hero{padding:62px 0 54px}.receiver-metrics{width:100%}.receiver-metrics>div{min-width:0;flex:1;padding:16px}.receiver-metrics strong{font-size:26px}.receiver-content{padding:64px 0 90px}.group-head{grid-template-columns:34px 1fr;row-gap:7px}.group-head small{grid-column:2}.group-head h2{font-size:28px}.delivery-row{grid-template-columns:1fr 34px;gap:12px;padding:22px 0}.delivery-code{grid-column:1}.delivery-object{grid-column:1}.delivery-status{grid-column:1}.delivery-arrow{grid-column:2;grid-row:1/4;align-self:center}.delivery-row:hover{padding-left:0}.delivery-status.final{justify-content:flex-start}.movement-group+.movement-group{margin-top:64px}}
@media(prefers-reduced-motion:reduce){.delivery-row{transition:none}}

/* PHASE 9 — MY MOVEMENT / one-thumb dashboard */
@media(max-width:620px){
  .receiver-claim{min-height:calc(100svh - 58px)}
  .receiver-claim-inner{padding-top:52px;padding-bottom:calc(52px + env(safe-area-inset-bottom))}
  .claim-field input{font-size:16px;min-width:0}.claim-field button{min-height:50px}
  .receiver-hero{padding-top:54px}.receiver-metrics{overflow-x:auto;scrollbar-width:none}.receiver-metrics::-webkit-scrollbar{display:none}.receiver-metrics>div{min-width:96px}
  .delivery-row{min-height:132px}.delivery-arrow{width:34px;height:44px;align-items:center}
  .receiver-content{padding-bottom:calc(90px + env(safe-area-inset-bottom))}
}
@media(max-width:390px){
  .receiver-claim h1,.receiver-hero h1{font-size:48px}.receiver-wrap{width:calc(100% - 24px)}
  .receiver-metrics>div{padding:14px 11px}.receiver-metrics strong{font-size:24px}
  .group-head h2{font-size:26px}.delivery-row{padding:19px 0}
}
</style>
