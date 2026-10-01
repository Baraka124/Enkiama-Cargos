<script setup>
import { ref, onMounted, onUnmounted, inject, computed, nextTick, watch } from 'vue'
import { useRoute } from 'vue-router'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { useI18n } from '../composables/useI18n'
import { usePublic } from '../composables/usePublic'
import { supabase, fmtTZS } from '../lib/supabase'
import TrustBadge from '../components/TrustBadge.vue'
import Icon from '../components/Icon.vue'
import AppHeader from '../components/AppHeader.vue'
import BrandMark from '../components/BrandMark.vue'
import Spinner from '../components/Spinner.vue'
import EmptyState from '../components/EmptyState.vue'
import { viewName, signalMotionReady } from '../lib/motion'

const { t } = useI18n()
const route = useRoute()
const toast = inject('toast')
const pub = usePublic()

const code = ref((route.params.code || '').toString().toUpperCase())
const parcel = ref(null)
const carrierRep = ref(null)
const events = ref([])
const notFound = ref(false)
const busy = ref(false)
const searched = ref(false)

const STAGE_ORDER = ['booked','collected','linehaul','with_driver','delivered','confirmed']
const STAGE_CAP = {
  booked:'Booked', collected:'Collected', linehaul:'On the road', with_driver:'With your driver',
  delivered:'Delivered', confirmed:'Confirmed', failed:'Delivery issue'
}
const STAGE_SHORT = {
  booked:'Booked', collected:'Collected', linehaul:'Moving', with_driver:'Driver', delivered:'Delivered', confirmed:'Confirmed'
}
const STAGE_ICON = {
  booked:'waybill', collected:'handoff', linehaul:'road', with_driver:'route', delivered:'package', confirmed:'check'
}

const currentIndex = computed(() => {
  if (!parcel.value) return -1
  if (parcel.value.stage === 'failed') return Math.max(0, STAGE_ORDER.indexOf('with_driver'))
  return STAGE_ORDER.indexOf(parcel.value.stage)
})
const progressPct = computed(() => {
  if (currentIndex.value < 0) return 0
  return Math.min(100, Math.max(0, (currentIndex.value / (STAGE_ORDER.length - 1)) * 100))
})
const trackerStyle = computed(() => ({ '--carrier-accent': parcel.value?.accent || 'var(--accent)' }))

function eventForStage(s) { return events.value.find(ev => ev.stage === s) }
function stageTime(s) {
  const e = eventForStage(s)
  if (!e) return ''
  const d = new Date(e.at || e.created_at)
  if (isNaN(d)) return ''
  return d.toLocaleDateString('en-GB', { day:'numeric', month:'short' }) + ' · ' + d.toLocaleTimeString('en-GB', { hour:'2-digit', minute:'2-digit' })
}
function stageActor(s) {
  const e = eventForStage(s)
  if (!e) return ''
  const who = e.actor_name || ''
  const role = e.actor_role ? e.actor_role.replaceAll('_', ' ') : ''
  return who ? (role ? `${who} · ${role}` : who) : role
}
function stageNote(s) { return eventForStage(s)?.note || '' }
function stageOn(s) {
  const i = STAGE_ORDER.indexOf(s)
  return i >= 0 && i <= currentIndex.value
}

const completedEvents = computed(() => STAGE_ORDER
  .filter(s => eventForStage(s))
  .map(s => ({ stage:s, event:eventForStage(s) }))
  .reverse())

const statusHeadline = computed(() => {
  const s = parcel.value?.stage
  return ({
    booked:'Your journey has started', collected:'The carrier has your parcel', linehaul:'Your parcel is moving',
    with_driver:'It is coming to you now', delivered:'It has arrived', confirmed:'Journey complete',
    failed:'The journey needs attention'
  }[s]) || 'Journey in progress'
})
const statusSub = computed(() => {
  const s = parcel.value?.stage
  const d = parcel.value?.driver
  if (s === 'with_driver') return `${d || 'Your driver'} is handling the final movement to you.`
  if (s === 'linehaul') return 'The parcel is moving through the carrier network toward your area.'
  if (s === 'collected') return 'Custody has transferred from the sender to the carrier.'
  if (s === 'booked') return 'The shipment is registered and waiting for carrier collection.'
  if (s === 'delivered') return 'The carrier has recorded delivery. Confirm receipt when you have the parcel.'
  if (s === 'confirmed') return 'Receipt has been confirmed and the custody record is complete.'
  if (s === 'failed') return 'A delivery issue was recorded. You can report, reschedule or raise a dispute below.'
  return ''
})
const movementLabel = computed(() => {
  const s = parcel.value?.stage
  if (s === 'with_driver') return 'Final movement'
  if (s === 'linehaul') return 'In transit'
  if (['delivered','confirmed'].includes(s)) return 'Arrived'
  if (s === 'failed') return 'Needs attention'
  return 'Preparing movement'
})
const owed = computed(() => (parcel.value?.payMode === 'cash' && !['collected','remitted','settled'].includes(parcel.value?.payState)) ? parcel.value.cod : 0)

// live driver position — privacy-scoped by the existing RPC
const livePos = ref(null)
const liveAgo = ref('')
let trkMap = null
let trkMarker = null
let livePoll = null

function destroyMap() {
  if (trkMap) { trkMap.remove(); trkMap = null; trkMarker = null }
}
async function loadLive() {
  if (!code.value) return
  try {
    const { data } = await supabase.rpc('track_live_location', { p_code: code.value })
    livePos.value = data || null
    if (!data) return
    const mins = Math.round((Date.now() - new Date(data.updated_at)) / 60000)
    liveAgo.value = mins <= 1 ? 'just now' : `${mins} min ago`
    await nextTick()
    renderLiveMap(data)
  } catch (e) { livePos.value = null }
}
function renderLiveMap(d) {
  const el = document.getElementById('trkmap')
  if (!el) return
  const ll = [d.lat, d.lng]
  if (!trkMap) {
    trkMap = L.map('trkmap', { zoomControl:true, attributionControl:false, scrollWheelZoom:false }).setView(ll, 14)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', { maxZoom:19 }).addTo(trkMap)
  }
  const icon = L.divIcon({ className:'trk-driver-pin', html:'<div class="tdp"><span></span></div>', iconSize:[30,30], iconAnchor:[15,15] })
  if (!trkMarker) trkMarker = L.marker(ll, { icon }).addTo(trkMap).bindPopup(`<b>${d.driver || 'Driver'}</b><br>heading to ${d.dest || 'you'}`)
  else trkMarker.setLatLng(ll)
  trkMap.panTo(ll)
}

function resetTrackingVisuals() {
  if (livePoll) { clearInterval(livePoll); livePoll = null }
  destroyMap()
  livePos.value = null
  liveAgo.value = ''
  carrierRep.value = null
  events.value = []
}

async function track() {
  const clean = code.value.trim().toUpperCase()
  if (!clean) return
  code.value = clean
  busy.value = true
  notFound.value = false
  resetTrackingVisuals()
  const { data, error } = await pub.track(clean)
  busy.value = false
  searched.value = true
  if (error || !data || !data.length) {
    notFound.value = true
    parcel.value = null
    await nextTick()
    signalMotionReady()
    return
  }
  const r = data[0]
  parcel.value = {
    code:r.code, receiver:r.receiver_name, addr:r.dest_address, item:r.item, weight:r.weight_kg,
    stage:r.stage, driver:r.driver_name, carrier:r.carrier_name, accent:r.carrier_accent,
    payMode:r.pay_mode, payState:r.pay_state, cod:r.cod_amount, fee:r.fee_amount,
    podPhoto:r.pod_photo_url, podAt:r.pod_at,
  }
  await nextTick()
  signalMotionReady()

  try {
    const [repResult, eventResult] = await Promise.all([
      supabase.rpc('track_carrier_reputation', { p_code:clean }),
      pub.trackEvents(clean),
    ])
    carrierRep.value = repResult.data || null
    events.value = eventResult.data || []
  } catch (e) {
    carrierRep.value = null
    events.value = []
  }

  await loadLive()
  livePoll = setInterval(loadLive, 15000)
}

// confirmation + review
const confirmStep = ref(false)
const last4 = ref('')
function startConfirm() { confirmStep.value = true; last4.value = '' }
async function confirm() {
  if (last4.value.replace(/\D/g,'').length < 4) { toast('Enter the last 4 digits of your phone', 'warn'); return }
  busy.value = true
  const { error } = await pub.confirmReceipt(code.value, last4.value)
  busy.value = false
  if (error) {
    toast(error.message?.includes('phone') ? 'That doesn’t match the phone on this parcel' : 'Not able to confirm yet', 'warn')
    return
  }
  confirmStep.value = false
  toast('Receipt confirmed — asante!', 'ok')
  reviewStep.value = true
  await track()
}

const reviewStep = ref(false)
const rvDelivery = ref(0)
const rvProduct = ref(0)
const rvComment = ref('')
const rvName = ref('')
const reviewDone = ref(false)
async function submitReview() {
  if (!rvDelivery.value) { toast('Tap a star to rate the delivery', 'warn'); return }
  busy.value = true
  try {
    const { error } = await pub.leaveReview({
      p_code:code.value, p_delivery_rating:rvDelivery.value, p_delivery_comment:rvComment.value || null,
      p_product_rating:rvProduct.value || null, p_product_comment:null, p_name:rvName.value || null,
    })
    if (error) throw error
    reviewDone.value = true
    setTimeout(() => { reviewStep.value = false }, 1800)
  } catch (e) { toast(e.message || 'Could not save review', 'warn') }
  busy.value = false
}

// receiver agency
const showDispute = ref(false)
const disputeReason = ref('not_delivered')
const disputeName = ref('')
const disputePhone = ref('')
const disputeDetail = ref('')
async function submitDispute() {
  if (!disputeName.value || !disputePhone.value) { toast('Add your name and phone', 'warn'); return }
  busy.value = true
  try {
    const { data } = await supabase.rpc('raise_dispute', {
      p_code:code.value, p_role:'receiver', p_name:disputeName.value, p_phone:disputePhone.value,
      p_reason:disputeReason.value, p_detail:disputeDetail.value || null,
    })
    if (data?.ok) { showDispute.value = false; toast('Dispute submitted — we’ll review the custody record and follow up', 'ok') }
    else toast(data?.error || 'Could not submit', 'warn')
  } catch (e) { toast('Could not submit dispute', 'warn') }
  busy.value = false
}

const showReschedule = ref(false)
const showReport = ref(false)
const reschedWhen = ref('Tomorrow')
const reschedNote = ref('')
const reportIssue = ref('Nobody was available')
const reportOther = ref('')
const requestSent = ref('')
async function submitReschedule() {
  busy.value = true
  const { error } = await pub.reschedule(code.value, reschedWhen.value, reschedNote.value)
  busy.value = false
  if (error) { toast(error.message || 'Could not send request', 'warn'); return }
  showReschedule.value = false
  requestSent.value = `${parcel.value.carrier} has your reschedule request (${reschedWhen.value}).`
  toast('Request sent to the carrier', 'ok')
}
async function submitReport() {
  const issue = reportIssue.value === 'Other' ? (reportOther.value || 'Other issue') : reportIssue.value
  busy.value = true
  const { error } = await pub.report(code.value, issue)
  busy.value = false
  if (error) { toast(error.message || 'Could not send report', 'warn'); return }
  showReport.value = false
  requestSent.value = `${parcel.value.carrier} has been notified: “${issue}”.`
  toast('Report sent to the carrier', 'ok')
}

watch(() => route.params.code, async (next) => {
  const incoming = (next || '').toString().toUpperCase()
  if (incoming && incoming !== code.value) {
    code.value = incoming
    parcel.value = null
    await track()
  }
})

onMounted(() => { if (code.value) track() })
onUnmounted(() => { resetTrackingVisuals() })
</script>

<template>
  <AppHeader title="Enkiama Movement" subtitle="A parcel journey you can verify" />

  <main class="movement-page">
    <!-- SEARCH / ARRIVAL -->
    <section class="movement-entry" :class="{ compact: parcel }">
      <div class="movement-entry-grid"></div>
      <div class="movement-entry-inner">
        <div class="movement-kicker"><span class="movement-live-dot"></span> Movement / Tanzania</div>
        <h1 v-if="!parcel">Where is<br><em>your parcel?</em></h1>
        <h1 v-else class="result-entry-title">Follow the movement.</h1>
        <p class="movement-entry-copy">One code opens the current position, custody history and delivery proof. No account required.</p>
        <div class="movement-search">
          <span class="movement-search-index">01</span>
          <input v-model="code" class="mono" placeholder="ENK-XXXX" aria-label="Tracking code" @keyup.enter="track" />
          <button class="movement-search-btn" :disabled="busy" @click="track">
            <Spinner v-if="busy" :size="16" />
            <template v-else>Track <Icon name="arrow" :size="15" /></template>
          </button>
        </div>
      </div>
    </section>

    <section v-if="notFound" class="movement-state wrap-narrow">
      <EmptyState icon="search" title="No parcel with that code" hint="Check the code your sender shared with you." />
    </section>

    <!-- RESULT -->
    <template v-if="parcel">
      <div class="movement-shell" :style="trackerStyle">
        <!-- CHAPTER 01 / NOW -->
        <section class="movement-now">
          <div class="movement-wrap">
            <div class="chapter-line"><span>01</span><span>Now</span><span>{{ movementLabel }}</span></div>

            <div class="now-grid">
              <div class="now-copy">
                <div class="now-code mono" :style="{viewTransitionName:viewName('parcel', parcel.code)}">{{ parcel.code }}</div>
                <h2>{{ statusHeadline }}</h2>
                <p>{{ statusSub }}</p>
                <TrustBadge v-if="carrierRep && carrierRep.tier !== 'new'" :rep="carrierRep" compact class="now-trust" />
              </div>

              <div class="now-object" :class="'stage-'+parcel.stage">
                <div class="now-object-orbit"></div>
                <div class="now-object-core">
                  <Icon :name="parcel.stage==='with_driver' ? 'route' : parcel.stage==='failed' ? 'alert' : ['delivered','confirmed'].includes(parcel.stage) ? 'check' : 'package'" :size="34" />
                </div>
                <div class="now-object-label">{{ STAGE_CAP[parcel.stage] }}</div>
              </div>
            </div>

            <div v-if="owed > 0" class="movement-payment">
              <div><span>Pay on delivery</span><strong class="mono">{{ fmtTZS(owed) }}</strong></div>
              <p>Have this ready for {{ parcel.driver || 'the driver' }} when the parcel reaches you.</p>
            </div>

            <div class="movement-facts">
              <div><span>To</span><strong>{{ parcel.receiver || 'Receiver' }}</strong><small>{{ parcel.addr || 'Delivery address' }}</small></div>
              <div><span>Object</span><strong>{{ parcel.item || 'Parcel' }}</strong><small>{{ parcel.weight ? parcel.weight + ' kg' : 'Tracked cargo' }}</small></div>
              <div><span>Carrier</span><strong>{{ parcel.carrier || 'Carrier' }}</strong><small>{{ parcel.driver ? 'With ' + parcel.driver : 'Driver assigned later' }}</small></div>
            </div>
          </div>
        </section>

        <!-- CHAPTER 02 / ROUTE -->
        <section v-reveal class="movement-route-section">
          <div class="movement-wrap">
            <div class="chapter-line"><span>02</span><span>Movement</span><span>{{ Math.round(progressPct) }}% recorded</span></div>
            <div class="route-heading">
              <div><h2>From handoff<br>to arrival.</h2></div>
              <p>Each custody transition is written into the parcel record. The upper line shows the journey at a glance; the ledger below shows who did what and when.</p>
            </div>

            <div class="route-rail" :class="{ issue: parcel.stage === 'failed' }">
              <div class="route-track"><div class="route-fill" :style="{ width: progressPct + '%' }"></div></div>
              <div v-for="(s,i) in STAGE_ORDER" :key="s" class="route-stop" :class="{ done:stageOn(s), current:parcel.stage===s }" :style="{ left:(i/(STAGE_ORDER.length-1)*100) + '%' }">
                <div class="route-stop-node"><Icon :name="STAGE_ICON[s]" :size="15" /></div>
                <div class="route-stop-copy"><strong>{{ STAGE_SHORT[s] }}</strong><span>{{ stageTime(s) || (stageOn(s) ? 'recorded' : 'pending') }}</span></div>
              </div>
            </div>

            <div v-if="parcel.stage==='failed'" class="movement-issue"><Icon name="alert" :size="18" /><div><strong>A delivery issue was recorded.</strong><span>The existing custody history is preserved. Use the actions below if you need to reschedule, report the issue or open a dispute.</span></div></div>
          </div>
        </section>

        <!-- LIVE MAP -->
        <section v-if="livePos" v-reveal class="movement-live-map">
          <div class="movement-live-overlay">
            <div class="live-eyebrow"><span></span> Live position · updated {{ liveAgo }}</div>
            <h2>{{ parcel.driver || 'Your driver' }} is moving toward you.</h2>
            <p>This position is provided by the active delivery record and refreshes automatically.</p>
          </div>
          <div id="trkmap" class="trk-map"></div>
        </section>

        <!-- CHAPTER 03 / LEDGER -->
        <section v-reveal class="movement-ledger-section">
          <div class="movement-wrap ledger-wrap">
            <div class="chapter-line"><span>03</span><span>Custody</span><span>Verifiable history</span></div>
            <div class="ledger-heading">
              <div><h2>The record behind<br>the movement.</h2></div>
              <div class="ledger-principle"><Icon name="shield" :size="18" /><p>Every recorded handoff remains visible with its timestamp and, when available, the actor who performed it.</p></div>
            </div>

            <div v-if="completedEvents.length" class="ledger-list">
              <article v-for="(row,idx) in completedEvents" :key="row.stage" class="ledger-row" :class="{ current: parcel.stage===row.stage }">
                <div class="ledger-index mono">{{ String(completedEvents.length - idx).padStart(2,'0') }}</div>
                <div class="ledger-mark"><Icon :name="STAGE_ICON[row.stage]" :size="17" /></div>
                <div class="ledger-main">
                  <div class="ledger-title"><strong>{{ STAGE_CAP[row.stage] }}</strong><span v-if="parcel.stage===row.stage">Current</span></div>
                  <div class="ledger-time mono">{{ stageTime(row.stage) }}</div>
                  <div v-if="stageActor(row.stage)" class="ledger-actor"><Icon name="shield" :size="12" /> {{ stageActor(row.stage) }}</div>
                  <blockquote v-if="stageNote(row.stage)">{{ stageNote(row.stage) }}</blockquote>
                </div>
              </article>
            </div>
            <div v-else class="ledger-empty">The shipment is registered. Custody events will appear here as movement is recorded.</div>
          </div>
        </section>

        <!-- CHAPTER 04 / PROOF + ACTION -->
        <section v-reveal class="movement-proof-section">
          <div class="movement-wrap">
            <div class="chapter-line"><span>04</span><span>Arrival</span><span>Proof & receiver agency</span></div>

            <div v-if="parcel.podPhoto" class="proof-grid">
              <div class="proof-image"><img :src="parcel.podPhoto" alt="Proof of delivery" /></div>
              <div class="proof-copy">
                <div class="proof-kicker">Proof of delivery</div>
                <h2>A visible final handoff.</h2>
                <p>The delivery record includes photographic proof{{ parcel.podAt ? ' and a recorded timestamp' : '' }}.</p>
                <div v-if="parcel.podAt" class="proof-time mono">{{ new Date(parcel.podAt).toLocaleString('en-GB') }}</div>
              </div>
            </div>

            <div class="arrival-action" :class="{ complete:parcel.stage==='confirmed' }">
              <template v-if="parcel.stage==='delivered'">
                <div class="arrival-action-copy"><span>Parcel in hand?</span><h2>Close the journey.</h2><p>Confirm receipt with the last four digits of the phone attached to this parcel.</p></div>
                <div class="arrival-action-control">
                  <button v-if="!confirmStep" class="arrival-primary" @click="startConfirm">Confirm receipt <Icon name="arrow" :size="16" /></button>
                  <div v-else class="arrival-confirm">
                    <label>Last 4 phone digits</label>
                    <div><input v-model="last4" inputmode="numeric" maxlength="4" placeholder="0000" class="mono" @keyup.enter="confirm" /><button :disabled="busy" @click="confirm"><Spinner v-if="busy" :size="15" /><span v-else>Confirm</span></button></div>
                    <button class="arrival-cancel" @click="confirmStep=false">Cancel</button>
                  </div>
                </div>
              </template>
              <template v-else-if="parcel.stage==='confirmed'">
                <div class="arrival-complete-icon"><Icon name="check" :size="28" /></div>
                <div><span>Complete</span><h2>Delivery confirmed.</h2><p>The parcel journey is closed and its custody history remains available above.</p></div>
              </template>
              <template v-else>
                <div class="arrival-action-copy"><span>Receiver controls</span><h2>Need to change something?</h2><p>You can ask the carrier to reschedule or report an issue without leaving the tracking record.</p></div>
              </template>
            </div>

            <div v-if="!['confirmed','cancelled'].includes(parcel.stage)" class="receiver-agency">
              <div v-if="requestSent" class="agency-sent"><Icon name="check" :size="16" /> {{ requestSent }}</div>
              <template v-else>
                <button @click="showReschedule=true"><Icon name="clock" :size="15" /><span>Reschedule</span><small>Ask for another delivery time</small></button>
                <button @click="showReport=true"><Icon name="alert" :size="15" /><span>Report</span><small>Tell the carrier what went wrong</small></button>
                <button class="agency-dispute" @click="showDispute=true"><Icon name="shield" :size="15" /><span>Dispute</span><small>Ask Enkiama to review the custody record</small></button>
              </template>
            </div>
          </div>
        </section>
      </div>
    </template>

    <!-- PRE-SEARCH DISCOVERY -->
    <section v-if="!parcel && !notFound" class="movement-primer">
      <div class="movement-primer-inner">
        <div class="chapter-line light"><span>How it works</span><span>One code</span><span>End-to-end visibility</span></div>
        <div class="primer-grid">
          <div class="primer-intro"><h2>A shipment should never disappear between sender and receiver.</h2><p>Enkiama turns each handoff into a visible movement record.</p></div>
          <div class="primer-steps">
            <div><span>01</span><strong>Registered</strong><p>The sender creates a shipment and a tracking identity.</p></div>
            <div><span>02</span><strong>Moved</strong><p>Collection, road movement and final-driver handoff are recorded.</p></div>
            <div><span>03</span><strong>Received</strong><p>Delivery can include proof and receiver confirmation.</p></div>
          </div>
        </div>
        <div class="primer-market"><span>Need something moved?</span><RouterLink to="/market">Explore Enkiama Market <Icon name="arrow" :size="14" /></RouterLink></div>
      </div>
    </section>

    <footer class="movement-footer"><BrandMark variant="full" :height="40" /><span>Movement you can verify.</span></footer>

    <!-- DISPUTE -->
    <div v-if="showDispute" class="overlay" v-escape="() => { showDispute=false }" @click.self="showDispute=false">
      <div class="modal movement-modal">
        <div class="modal-kicker">Custody review</div><h3>Raise a dispute</h3>
        <p>Tell us what happened. The existing custody events and available proof can be reviewed as evidence.</p>
        <div class="fg"><label>What's the problem?</label><select v-model="disputeReason"><option value="not_delivered">It was never delivered</option><option value="damaged">It arrived damaged</option><option value="wrong_item">Wrong item</option><option value="not_as_described">Not as described</option><option value="other">Something else</option></select></div>
        <div class="fg"><label>Your name</label><input v-model="disputeName" placeholder="Your name" /></div>
        <div class="fg"><label>Phone</label><input v-model="disputePhone" placeholder="+255…" /></div>
        <div class="fg"><label>Details</label><textarea v-model="disputeDetail" rows="3" placeholder="Explain what happened."></textarea></div>
        <div class="form-actions"><button class="btn btn-ghost" @click="showDispute=false">Cancel</button><button class="btn btn-accent" :disabled="busy" @click="submitDispute"><Spinner v-if="busy" :size="15" /><span v-else>Submit dispute</span></button></div>
      </div>
    </div>

    <!-- RESCHEDULE -->
    <div v-if="showReschedule" class="overlay" v-escape="() => { showReschedule=false }" @click.self="showReschedule=false">
      <div class="modal movement-modal"><div class="modal-kicker">Receiver request</div><h3>Reschedule delivery</h3><p>Tell {{ parcel?.carrier }} when works better.</p>
        <div class="fg"><label>When would you like it?</label><select v-model="reschedWhen"><option>Later today</option><option>Tomorrow</option><option>This weekend</option><option>Call me first</option><option>Leave with neighbour</option></select></div>
        <div class="fg"><label>Anything to add? <span class="opt">optional</span></label><input v-model="reschedNote" placeholder="e.g. after 5pm, gate on the left" /></div>
        <div class="confirm-actions"><button class="btn btn-ghost" @click="showReschedule=false">Cancel</button><button class="btn btn-accent" :disabled="busy" @click="submitReschedule"><Spinner v-if="busy" :size="15" /><span v-else>Send request</span></button></div>
      </div>
    </div>

    <!-- REPORT -->
    <div v-if="showReport" class="overlay" v-escape="() => { showReport=false }" @click.self="showReport=false">
      <div class="modal movement-modal"><div class="modal-kicker">Carrier notice</div><h3>Report a problem</h3><p>Let {{ parcel?.carrier }} know what is wrong with {{ parcel?.code }}.</p>
        <div class="fg"><label>What's the issue?</label><select v-model="reportIssue"><option>Wrong delivery address</option><option>Nobody was available</option><option>Parcel looks damaged</option><option>Wrong item / not mine</option><option>Driver couldn't find me</option><option>Other</option></select></div>
        <div class="fg" v-if="reportIssue==='Other'"><label>Describe it</label><input v-model="reportOther" placeholder="Tell us what happened" /></div>
        <div class="confirm-actions"><button class="btn btn-ghost" @click="showReport=false">Cancel</button><button class="btn btn-accent" :disabled="busy" @click="submitReport"><Spinner v-if="busy" :size="15" /><span v-else>Send report</span></button></div>
      </div>
    </div>

    <!-- REVIEW -->
    <div v-if="reviewStep" class="overlay" v-escape="() => { reviewStep=false }" @click.self="reviewStep=false">
      <div class="modal movement-modal review-modal">
        <div v-if="reviewDone" class="review-thanks"><div><Icon name="check" :size="28" /></div><h3>Asante.</h3><p>Your review adds another layer of useful experience data.</p></div>
        <template v-else>
          <div class="modal-kicker">Journey complete</div><h3>How was the movement?</h3><p>Rate the delivery first. Product rating is optional.</p>
          <div class="review-block"><label>Delivery</label><div class="review-stars"><button v-for="n in 5" :key="n" :class="{ on:n<=rvDelivery }" @click="rvDelivery=n"><Icon name="star" :size="28" /></button></div></div>
          <div class="review-block"><label>Product <span>optional</span></label><div class="review-stars"><button v-for="n in 5" :key="n" :class="{ on:n<=rvProduct }" @click="rvProduct=n"><Icon name="star" :size="28" /></button></div></div>
          <div class="fg"><input v-model="rvComment" placeholder="Comment (optional)" /></div><div class="fg"><input v-model="rvName" placeholder="Your name (optional)" /></div>
          <div class="confirm-actions"><button class="btn btn-ghost" @click="reviewStep=false">Skip</button><button class="btn btn-accent" :disabled="busy" @click="submitReview"><Spinner v-if="busy" :size="15" /><span v-else>Submit review</span></button></div>
        </template>
      </div>
    </div>
  </main>
</template>

<style scoped>
.movement-page{background:#f4f1eb;color:var(--ink);min-height:100vh}
.movement-entry{position:relative;min-height:560px;background:#111412;color:#fff;overflow:hidden;display:flex;align-items:center}
.movement-entry.compact{min-height:390px}
.movement-entry::before{content:"";position:absolute;width:560px;height:560px;border:1px solid rgba(255,255,255,.09);border-radius:50%;right:-110px;top:-170px;box-shadow:0 0 0 120px rgba(255,255,255,.018),0 0 0 240px rgba(255,255,255,.012)}
.movement-entry::after{content:"";position:absolute;width:360px;height:360px;left:-100px;bottom:-260px;border-radius:50%;background:radial-gradient(circle,rgba(92,145,117,.22),transparent 68%)}
.movement-entry-grid{position:absolute;inset:0;opacity:.14;background-image:linear-gradient(rgba(255,255,255,.08) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.08) 1px,transparent 1px);background-size:76px 76px;mask-image:linear-gradient(to bottom,rgba(0,0,0,.8),transparent)}
.movement-entry-inner,.movement-wrap,.movement-primer-inner{width:min(1180px,calc(100% - 64px));margin:0 auto;position:relative;z-index:1}
.movement-entry-inner{padding:84px 0 76px}
.movement-kicker{display:flex;align-items:center;gap:9px;font-size:11px;text-transform:uppercase;letter-spacing:.18em;color:rgba(255,255,255,.55);margin-bottom:36px}
.movement-live-dot{width:7px;height:7px;border-radius:50%;background:#7bc69c;box-shadow:0 0 0 6px rgba(123,198,156,.1)}
.movement-entry h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(58px,8vw,118px);font-weight:500;letter-spacing:-.075em;line-height:.82;max-width:840px;margin:0}
.movement-entry h1 em{font-family:Georgia,'Times New Roman',serif;font-weight:400;color:#a9cdb9}
.movement-entry h1.result-entry-title{font-size:clamp(50px,7vw,92px)}
.movement-entry-copy{max-width:500px;font-size:15px;line-height:1.7;color:rgba(255,255,255,.58);margin:36px 0 30px}
.movement-search{width:min(660px,100%);height:70px;display:grid;grid-template-columns:58px 1fr auto;align-items:center;border-top:1px solid rgba(255,255,255,.25);border-bottom:1px solid rgba(255,255,255,.25)}
.movement-search-index{font-size:11px;letter-spacing:.12em;color:rgba(255,255,255,.38)}
.movement-search input{height:100%;border:0;background:transparent;color:#fff;font-family:'Space Grotesk',sans-serif;font-size:20px;letter-spacing:.08em;text-transform:uppercase;outline:none;min-width:0}
.movement-search input::placeholder{color:rgba(255,255,255,.3)}
.movement-search-btn{border:0;background:transparent;color:#fff;display:flex;align-items:center;gap:9px;font-size:13px;font-weight:650;text-transform:uppercase;letter-spacing:.08em;cursor:pointer;padding:15px 0 15px 22px}
.movement-search-btn:disabled{opacity:.5;cursor:default}
.wrap-narrow{width:min(760px,calc(100% - 40px));margin:40px auto}

.chapter-line{display:grid;grid-template-columns:64px 1fr auto;align-items:center;border-top:1px solid rgba(21,25,22,.16);padding-top:14px;font-size:10px;text-transform:uppercase;letter-spacing:.16em;color:#6f746f}
.chapter-line.light{border-color:rgba(255,255,255,.16);color:rgba(255,255,255,.45)}
.movement-now{padding:92px 0 84px;background:#f4f1eb}
.now-grid{display:grid;grid-template-columns:minmax(0,1fr) 340px;gap:80px;align-items:center;padding:72px 0 54px}
.now-code{font-size:12px;letter-spacing:.14em;color:#747971;margin-bottom:20px}
.now-copy h2,.route-heading h2,.ledger-heading h2,.proof-copy h2,.arrival-action h2,.primer-intro h2{font-family:'Space Grotesk',sans-serif;font-weight:500;letter-spacing:-.055em;line-height:.95;margin:0}
.now-copy h2{font-size:clamp(44px,6vw,82px);max-width:730px}
.now-copy>p{max-width:580px;font-size:16px;line-height:1.75;color:#60665f;margin:28px 0 0}
.now-trust{margin-top:22px}
.now-object{height:340px;position:relative;display:flex;align-items:center;justify-content:center}
.now-object-orbit{position:absolute;width:310px;height:310px;border:1px solid #cac7bf;border-radius:50%;animation:softOrbit 18s linear infinite}
.now-object-orbit::before,.now-object-orbit::after{content:"";position:absolute;border-radius:50%;background:var(--carrier-accent);width:7px;height:7px;top:50%;transform:translateY(-50%)}
.now-object-orbit::before{left:-4px}.now-object-orbit::after{right:-4px}
.now-object-core{width:124px;height:124px;border-radius:50%;display:flex;align-items:center;justify-content:center;background:#171b18;color:#fff;box-shadow:0 26px 70px rgba(17,20,18,.18);position:relative;z-index:2}
.now-object.stage-confirmed .now-object-core,.now-object.stage-delivered .now-object-core{background:#236b4a}.now-object.stage-failed .now-object-core{background:#833d32}
.now-object-label{position:absolute;bottom:26px;left:50%;transform:translateX(-50%);font-size:11px;text-transform:uppercase;letter-spacing:.16em;color:#6b706a;white-space:nowrap}
@keyframes softOrbit{to{transform:rotate(360deg)}}
.movement-payment{border-top:1px solid #d4d0c7;border-bottom:1px solid #d4d0c7;padding:24px 0;display:flex;justify-content:space-between;align-items:center;gap:30px}
.movement-payment div{display:flex;align-items:baseline;gap:22px}.movement-payment span{font-size:11px;text-transform:uppercase;letter-spacing:.14em;color:#8a5047}.movement-payment strong{font-size:26px;color:#6f312a}.movement-payment p{font-size:13px;color:#756761;max-width:350px;margin:0}
.movement-facts{display:grid;grid-template-columns:repeat(3,1fr);border-bottom:1px solid #d4d0c7}
.movement-facts>div{padding:30px 30px 28px 0;border-right:1px solid #d4d0c7}.movement-facts>div+div{padding-left:30px}.movement-facts>div:last-child{border-right:0}
.movement-facts span{display:block;font-size:10px;text-transform:uppercase;letter-spacing:.15em;color:#878b85;margin-bottom:10px}.movement-facts strong{display:block;font-size:16px;font-weight:620}.movement-facts small{display:block;font-size:12px;color:#777c76;line-height:1.5;margin-top:5px}

.movement-route-section{background:#171a18;color:#fff;padding:96px 0 110px}
.movement-route-section .chapter-line,.movement-ledger-section .chapter-line{border-color:rgba(255,255,255,.16);color:rgba(255,255,255,.44)}
.route-heading,.ledger-heading{display:grid;grid-template-columns:1fr 1fr;gap:80px;padding:62px 0 96px;align-items:end}
.route-heading h2,.ledger-heading h2{font-size:clamp(48px,6vw,78px)}
.route-heading p{font-size:15px;line-height:1.75;color:rgba(255,255,255,.52);max-width:500px;margin:0 0 6px}
.route-rail{height:220px;position:relative;margin:0 38px}
.route-track{position:absolute;left:0;right:0;top:44px;height:1px;background:rgba(255,255,255,.18)}
.route-fill{height:2px;background:linear-gradient(90deg,#9fc7af,var(--carrier-accent));transition:width .8s cubic-bezier(.22,1,.36,1)}
.route-stop{position:absolute;top:29px;transform:translateX(-50%);width:130px;text-align:center;color:rgba(255,255,255,.32)}
.route-stop-node{width:31px;height:31px;border-radius:50%;border:1px solid rgba(255,255,255,.22);background:#171a18;display:flex;align-items:center;justify-content:center;margin:0 auto 18px;transition:.3s ease}
.route-stop.done{color:rgba(255,255,255,.74)}.route-stop.done .route-stop-node{border-color:#7fa68e;color:#b9d6c4}.route-stop.current .route-stop-node{background:#e7eee9;color:#19221c;border-color:#e7eee9;box-shadow:0 0 0 8px rgba(231,238,233,.07)}
.route-stop-copy strong{display:block;font-size:11px;text-transform:uppercase;letter-spacing:.1em}.route-stop-copy span{display:block;font-size:10px;color:rgba(255,255,255,.35);margin-top:7px;white-space:nowrap}
.movement-issue{border-top:1px solid rgba(255,255,255,.16);padding:22px 0;display:flex;gap:16px;color:#eab4ab}.movement-issue div{display:flex;flex-direction:column;gap:4px}.movement-issue strong{font-size:13px}.movement-issue span{font-size:12px;color:rgba(255,255,255,.52)}

.movement-live-map{height:560px;position:relative;background:#dcded9;overflow:hidden}
.trk-map{position:absolute;inset:0;width:100%;height:100%;filter:saturate(.45) contrast(.95)}
.movement-live-overlay{position:absolute;z-index:500;left:max(32px,calc((100% - 1180px)/2));top:50%;transform:translateY(-50%);width:min(420px,calc(100% - 64px));background:rgba(18,22,19,.92);backdrop-filter:blur(14px);color:#fff;padding:38px;box-shadow:0 25px 70px rgba(17,20,18,.18)}
.live-eyebrow{display:flex;align-items:center;gap:8px;font-size:10px;text-transform:uppercase;letter-spacing:.14em;color:rgba(255,255,255,.55);margin-bottom:25px}.live-eyebrow span{width:7px;height:7px;background:#71ca96;border-radius:50%;animation:livePulse 1.8s ease-in-out infinite}
.movement-live-overlay h2{font-family:'Space Grotesk',sans-serif;font-weight:500;font-size:38px;letter-spacing:-.05em;line-height:1;margin:0 0 18px}.movement-live-overlay p{font-size:13px;line-height:1.7;color:rgba(255,255,255,.55);margin:0}
@keyframes livePulse{50%{opacity:.35;transform:scale(.8)}}
:global(.trk-driver-pin){background:transparent!important;border:0!important}:global(.trk-driver-pin .tdp){position:relative;width:30px;height:30px;border-radius:50%;background:#18251d;border:6px solid #fff;box-shadow:0 0 0 1px rgba(24,37,29,.15),0 6px 20px rgba(24,37,29,.32)}:global(.trk-driver-pin .tdp span){position:absolute;inset:-12px;border:1px solid rgba(24,37,29,.28);border-radius:50%;animation:mapPulse 2s ease-out infinite}@keyframes mapPulse{to{transform:scale(1.5);opacity:0}}

.movement-ledger-section{background:#20231f;color:#fff;padding:96px 0 116px}.ledger-wrap{max-width:1040px}.ledger-heading{padding-bottom:72px}.ledger-principle{display:flex;gap:16px;align-items:flex-start;color:#a9cdb9}.ledger-principle p{font-size:14px;line-height:1.7;color:rgba(255,255,255,.52);margin:0;max-width:420px}
.ledger-list{border-top:1px solid rgba(255,255,255,.16)}.ledger-row{display:grid;grid-template-columns:72px 60px 1fr;gap:24px;padding:30px 0;border-bottom:1px solid rgba(255,255,255,.13);align-items:start}.ledger-row.current{background:linear-gradient(90deg,rgba(169,205,185,.05),transparent)}
.ledger-index{font-size:11px;color:rgba(255,255,255,.28);padding-top:10px}.ledger-mark{width:42px;height:42px;border:1px solid rgba(255,255,255,.18);border-radius:50%;display:flex;align-items:center;justify-content:center;color:#a9cdb9}.ledger-title{display:flex;align-items:center;gap:12px}.ledger-title strong{font-size:16px;font-weight:600}.ledger-title span{font-size:9px;text-transform:uppercase;letter-spacing:.13em;color:#a9cdb9;border:1px solid rgba(169,205,185,.28);padding:4px 8px;border-radius:999px}.ledger-time{font-size:11px;color:rgba(255,255,255,.38);margin-top:6px}.ledger-actor{display:flex;align-items:center;gap:6px;font-size:11px;color:#a9cdb9;margin-top:8px}.ledger-main blockquote{margin:9px 0 0;padding:0;border:0;font-family:Georgia,serif;font-style:italic;font-size:14px;color:rgba(255,255,255,.52)}.ledger-empty{border-top:1px solid rgba(255,255,255,.16);padding:34px 0;font-size:13px;color:rgba(255,255,255,.45)}

.movement-proof-section{background:#f4f1eb;padding:96px 0 120px}.proof-grid{display:grid;grid-template-columns:1.15fr .85fr;gap:72px;align-items:center;padding:64px 0 88px}.proof-image{height:520px;overflow:hidden;background:#ddd8cf}.proof-image img{width:100%;height:100%;object-fit:cover}.proof-kicker,.arrival-action-copy>span,.arrival-action>div>span{font-size:10px;text-transform:uppercase;letter-spacing:.16em;color:#737871;margin-bottom:18px}.proof-copy h2{font-size:clamp(42px,5vw,68px)}.proof-copy p{font-size:15px;line-height:1.75;color:#646963;margin:24px 0}.proof-time{font-size:11px;color:#7e837d;border-top:1px solid #d4d0c7;padding-top:16px}
.arrival-action{border-top:1px solid #bfc0ba;border-bottom:1px solid #bfc0ba;padding:48px 0;display:grid;grid-template-columns:1fr 1fr;gap:70px;align-items:center}.arrival-action h2{font-size:clamp(38px,4.5vw,58px)}.arrival-action p{font-size:14px;line-height:1.7;color:#676c66;max-width:470px;margin:18px 0 0}.arrival-primary{width:100%;display:flex;align-items:center;justify-content:space-between;border:0;border-bottom:1px solid #171a18;background:transparent;padding:18px 0;font-size:14px;font-weight:650;cursor:pointer}.arrival-confirm label{display:block;font-size:10px;text-transform:uppercase;letter-spacing:.13em;color:#777b75;margin-bottom:10px}.arrival-confirm>div{display:grid;grid-template-columns:1fr auto;border-bottom:1px solid #171a18}.arrival-confirm input{border:0;background:transparent;padding:14px 0;font-size:22px;letter-spacing:.22em;outline:none}.arrival-confirm>div button{border:0;background:transparent;font-weight:650;cursor:pointer}.arrival-cancel{border:0;background:transparent;color:#777b75;padding:10px 0;font-size:11px;cursor:pointer}.arrival-action.complete{grid-template-columns:70px 1fr}.arrival-complete-icon{width:58px;height:58px;border-radius:50%;background:#2f704f;color:#fff;display:flex;align-items:center;justify-content:center}.arrival-action.complete h2{font-size:44px}
.receiver-agency{display:grid;grid-template-columns:repeat(3,1fr);border-bottom:1px solid #bfc0ba}.receiver-agency button{border:0;border-right:1px solid #d4d0c7;background:transparent;text-align:left;padding:28px 30px 28px 0;display:grid;grid-template-columns:28px 1fr;cursor:pointer;color:#262a27}.receiver-agency button+button{padding-left:30px}.receiver-agency button:last-child{border-right:0}.receiver-agency button svg{grid-row:1/3}.receiver-agency button span{font-size:13px;font-weight:650}.receiver-agency button small{display:block;font-size:11px;line-height:1.45;color:#7b807a;margin-top:4px}.receiver-agency button:hover span{color:#2d684b}.agency-sent{grid-column:1/-1;padding:26px 0;display:flex;align-items:center;gap:10px;color:#2d684b;font-size:13px}

.movement-primer{background:#171a18;color:#fff;padding:96px 0 106px}.primer-grid{display:grid;grid-template-columns:1fr 1fr;gap:90px;padding:70px 0}.primer-intro h2{font-size:clamp(42px,5vw,68px)}.primer-intro p{font-size:14px;line-height:1.7;color:rgba(255,255,255,.48);max-width:460px;margin-top:24px}.primer-steps{border-top:1px solid rgba(255,255,255,.16)}.primer-steps>div{display:grid;grid-template-columns:54px 150px 1fr;gap:18px;border-bottom:1px solid rgba(255,255,255,.13);padding:22px 0;align-items:start}.primer-steps span{font-size:10px;color:rgba(255,255,255,.3)}.primer-steps strong{font-size:13px}.primer-steps p{font-size:12px;line-height:1.55;color:rgba(255,255,255,.45);margin:0}.primer-market{border-top:1px solid rgba(255,255,255,.16);padding-top:24px;display:flex;align-items:center;justify-content:space-between;font-size:11px;text-transform:uppercase;letter-spacing:.12em;color:rgba(255,255,255,.4)}.primer-market a{color:#c5dbcD;text-decoration:none;display:flex;align-items:center;gap:8px}
.movement-footer{height:110px;background:#111412;color:rgba(255,255,255,.42);display:flex;align-items:center;justify-content:center;gap:22px;font-size:10px;text-transform:uppercase;letter-spacing:.15em}.movement-footer :deep(svg),.movement-footer :deep(img){filter:brightness(0) invert(1);opacity:.9}

.movement-modal{max-width:460px}.modal-kicker{font-size:10px;text-transform:uppercase;letter-spacing:.14em;color:var(--accent-ink);margin-bottom:9px}.movement-modal h3{font-family:'Space Grotesk',sans-serif;font-size:28px;letter-spacing:-.035em}.movement-modal>p{font-size:13px;line-height:1.65;color:var(--ink-soft);margin-bottom:20px}.review-thanks{text-align:center;padding:25px 10px}.review-thanks>div{width:58px;height:58px;border-radius:50%;background:var(--go-soft);color:var(--go);display:flex;align-items:center;justify-content:center;margin:0 auto 18px}.review-block{padding:16px 0;border-top:1px solid var(--hairline)}.review-block label{font-size:12px;font-weight:650}.review-block label span{font-weight:400;color:var(--ink-faint)}.review-stars{display:flex;gap:4px;margin-top:8px}.review-stars button{border:0;background:transparent;color:var(--hairline-2);padding:2px;cursor:pointer}.review-stars button.on{color:#c69b45}

@media(max-width:820px){
  .movement-entry-inner,.movement-wrap,.movement-primer-inner{width:min(100% - 36px,1180px)}
  .movement-entry{min-height:510px}.movement-entry.compact{min-height:340px}.movement-entry-inner{padding:64px 0 54px}.movement-entry h1{font-size:clamp(50px,15vw,80px)}
  .now-grid,.route-heading,.ledger-heading,.proof-grid,.arrival-action,.primer-grid{grid-template-columns:1fr;gap:36px}.now-grid{padding:54px 0 34px}.now-object{height:260px}.now-object-orbit{width:240px;height:240px}.now-object-core{width:100px;height:100px}
  .movement-facts{grid-template-columns:1fr}.movement-facts>div,.movement-facts>div+div{padding:22px 0;border-right:0;border-bottom:1px solid #d4d0c7}.movement-facts>div:last-child{border-bottom:0}
  .route-heading,.ledger-heading{padding:48px 0 62px}.route-rail{height:auto;margin:0;padding-left:24px}.route-track{left:39px;right:auto;top:0;bottom:0;width:1px;height:auto}.route-fill{width:2px!important;height:var(--progress,100%)}.route-stop{position:relative!important;left:auto!important;top:auto;transform:none;width:auto;text-align:left;display:flex;align-items:flex-start;gap:18px;margin-bottom:26px}.route-stop-node{margin:0}.route-stop-copy{padding-top:5px}.route-stop-copy span{white-space:normal}.route-track,.route-fill{display:none}
  .movement-live-map{height:640px}.movement-live-overlay{top:auto;bottom:22px;left:18px;transform:none;width:calc(100% - 36px);padding:28px}.movement-live-overlay h2{font-size:31px}.trk-map{height:100%}
  .ledger-row{grid-template-columns:48px 46px 1fr;gap:12px}.ledger-index{font-size:9px}.proof-image{height:380px}.arrival-action{padding:36px 0}.arrival-action.complete{grid-template-columns:60px 1fr;gap:18px}
  .receiver-agency{grid-template-columns:1fr}.receiver-agency button,.receiver-agency button+button{padding:22px 0;border-right:0;border-bottom:1px solid #d4d0c7}.receiver-agency button:last-child{border-bottom:0}
  .primer-grid{padding:52px 0}.primer-steps>div{grid-template-columns:44px 1fr}.primer-steps p{grid-column:2}.chapter-line{grid-template-columns:44px 1fr auto}
}
@media(max-width:520px){
  .movement-entry-inner,.movement-wrap,.movement-primer-inner{width:calc(100% - 28px)}.movement-entry{min-height:480px}.movement-entry.compact{min-height:310px}.movement-entry h1{font-size:52px}.movement-entry h1.result-entry-title{font-size:48px}.movement-entry-copy{font-size:13px;margin:26px 0 22px}.movement-search{grid-template-columns:36px 1fr auto;height:62px}.movement-search input{font-size:16px}.movement-search-btn{font-size:11px;padding-left:10px}.movement-search-btn svg{display:none}
  .movement-now,.movement-route-section,.movement-ledger-section,.movement-proof-section,.movement-primer{padding-top:70px;padding-bottom:78px}.chapter-line{grid-template-columns:34px 1fr;row-gap:6px}.chapter-line span:last-child{grid-column:2;font-size:8px}.now-copy h2{font-size:44px}.now-copy>p{font-size:14px}.movement-payment{align-items:flex-start;flex-direction:column;gap:8px}.movement-payment p{max-width:none}.now-object{height:230px}.now-object-orbit{width:210px;height:210px}.now-object-core{width:88px;height:88px}
  .route-heading h2,.ledger-heading h2,.proof-copy h2,.primer-intro h2{font-size:43px}.route-heading p{font-size:13px}.movement-live-map{height:560px}.movement-live-overlay{padding:23px}.movement-live-overlay h2{font-size:29px}
  .ledger-row{grid-template-columns:36px 1fr;gap:12px}.ledger-mark{display:none}.ledger-index{padding-top:6px}.proof-image{height:320px}.arrival-action h2,.arrival-action.complete h2{font-size:38px}.arrival-action.complete{grid-template-columns:1fr}.receiver-agency button{grid-template-columns:26px 1fr}.movement-footer{height:90px;flex-direction:column;gap:10px}
}
@media(prefers-reduced-motion:reduce){.now-object-orbit,.live-eyebrow span,:global(.trk-driver-pin .tdp span){animation:none!important}.route-fill{transition:none}}

/* PHASE 9 — MOVEMENT / live journey fills the phone without trapping it */
@media(max-width:820px){
  .movement-entry{min-height:max(500px,72svh)}
  .movement-search{min-height:62px}.movement-search input{font-size:16px}
  .movement-live-map{height:min(78svh,680px);min-height:520px}
  .movement-live-overlay{bottom:calc(16px + env(safe-area-inset-bottom));max-height:42%;overflow:auto;overscroll-behavior:contain}
  .receiver-agency button{min-height:76px}
}
@media(max-width:520px){
  .movement-entry-inner,.movement-wrap,.movement-primer-inner{width:calc(100% - 28px)}
  .movement-search{grid-template-columns:34px minmax(0,1fr) auto}.movement-search-btn{min-height:48px;padding:0 4px 0 10px}
  .movement-live-map{height:72svh;min-height:500px}.movement-live-overlay{left:14px;width:calc(100% - 28px);padding:20px}
  .proof-image{margin-left:-14px;margin-right:-14px;width:calc(100% + 28px);height:min(74vw,340px)}
  .arrival-action{padding-bottom:calc(32px + env(safe-area-inset-bottom))}
  .movement-footer{padding-bottom:env(safe-area-inset-bottom);height:calc(90px + env(safe-area-inset-bottom))}
}
</style>
