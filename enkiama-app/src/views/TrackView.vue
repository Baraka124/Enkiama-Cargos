<script setup>
import { ref, onMounted, onUnmounted, inject, computed, nextTick } from 'vue'
import { useI18n } from '../composables/useI18n'
import TrustBadge from '../components/TrustBadge.vue'
import { supabase } from '../lib/supabase'
import { useRoute } from 'vue-router'
import { fmtTZS } from '../lib/supabase'
import { usePublic } from '../composables/usePublic'
import Icon from '../components/Icon.vue'
import AppHeader from '../components/AppHeader.vue'
import BrandMark from '../components/BrandMark.vue'
import Spinner from '../components/Spinner.vue'
import EmptyState from '../components/EmptyState.vue'

const { t, setLang, isSwahili } = useI18n()
const route = useRoute()
const toast = inject('toast')
const code = ref((route.params.code || '').toString().toUpperCase())
const parcel = ref(null)
const carrierRep = ref(null)

// #18 — live GPS map
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
const livePos = ref(null)
const liveAgo = ref('')
let trkMap = null, trkMarker = null, livePoll = null
async function loadLive() {
  try {
    const { data } = await supabase.rpc('track_live_location', { p_code: code.value })
    livePos.value = data || null
    if (data) {
      const mins = Math.round((Date.now() - new Date(data.updated_at)) / 60000)
      liveAgo.value = mins <= 1 ? 'just now' : `${mins} min ago`
      await nextTick(); renderLiveMap(data)
    }
  } catch (e) { livePos.value = null }
}
function renderLiveMap(d) {
  const el = document.getElementById('trkmap'); if (!el) return
  const ll = [d.lat, d.lng]
  if (!trkMap) {
    trkMap = L.map('trkmap', { zoomControl: true, attributionControl: false }).setView(ll, 14)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', { maxZoom: 19 }).addTo(trkMap)
  }
  const icon = L.divIcon({ className: 'trk-driver-pin', html: '<div class="tdp"></div>', iconSize: [22, 22] })
  if (!trkMarker) trkMarker = L.marker(ll, { icon }).addTo(trkMap).bindPopup(`<b>${d.driver}</b><br>heading to ${d.dest || 'you'}`)
  else trkMarker.setLatLng(ll)
  trkMap.panTo(ll)
}
const notFound = ref(false)
const busy = ref(false)
const pub = usePublic()
const searched = ref(false)

const STAGE_ORDER = ['booked','collected','linehaul','with_driver','delivered','confirmed']
const events = ref([])
function stageTime(s) {
  const e = events.value.find(ev => ev.stage === s)
  if (!e) return ''
  const d = new Date(e.at || e.created_at)
  if (isNaN(d)) return ''
  return d.toLocaleDateString('en-GB', { day:'numeric', month:'short' }) + ' · ' + d.toLocaleTimeString('en-GB', { hour:'2-digit', minute:'2-digit' })
}
// #15 trust depth — who performed each step (the verifiable "one truth")
function stageActor(s) {
  const e = events.value.find(ev => ev.stage === s)
  if (!e) return ''
  const who = e.actor_name || ''
  const role = e.actor_role ? e.actor_role.replace('_', ' ') : ''
  return who ? (role ? `${who} · ${role}` : who) : role
}
function stageNote(s) {
  const e = events.value.find(ev => ev.stage === s)
  return (e && e.note) ? e.note : ''
}
const STAGE_CAP = { booked:'Booked', collected:'Carrier has it', linehaul:'On road', with_driver:'With driver', delivered:'Delivered', confirmed:'Confirmed', failed:'Failed' }

async function track() {
  if (!code.value) return
  busy.value = true; notFound.value = false
  const { data, error } = await pub.track(code.value)
  busy.value = false; searched.value = true
  if (error || !data || !data.length) { notFound.value = true; parcel.value = null; return }
  const r = data[0]
  parcel.value = {
    code: r.code, receiver: r.receiver_name, addr: r.dest_address, item: r.item, weight: r.weight_kg,
    stage: r.stage, driver: r.driver_name, carrier: r.carrier_name, accent: r.carrier_accent,
    payMode: r.pay_mode, payState: r.pay_state, cod: r.cod_amount, fee: r.fee_amount,
    podPhoto: r.pod_photo_url, podAt: r.pod_at,
  }
  // load the verifiable event ledger
  try {
    const { data: rep } = await supabase.rpc('track_carrier_reputation', { p_code: code.value })
    carrierRep.value = rep || null
  } catch (e) {}
  // start live location polling (privacy-scoped server-side)
  await loadLive()
  if (livePoll) clearInterval(livePoll)
  livePoll = setInterval(loadLive, 15000)
  try {
    const { data: evs } = await pub.trackEvents(code.value)
    events.value = evs || []
  } catch (e) { events.value = [] }
  if (r.carrier_accent) document.documentElement.style.setProperty('--accent', r.carrier_accent)
}
const confirmStep = ref(false)   // showing the phone-check input
const last4 = ref('')
function startConfirm() { confirmStep.value = true; last4.value = '' }
async function confirm() {
  if (last4.value.replace(/\D/g,'').length < 4) { toast('Enter the last 4 digits of your phone', 'warn'); return }
  busy.value = true
  const { error } = await pub.confirmReceipt(code.value, last4.value)
  busy.value = false
  if (error) {
    toast(error.message?.includes('phone') ? 'That doesn\u2019t match the phone on this parcel' : 'Not able to confirm yet', 'warn')
    return
  }
  confirmStep.value = false
  toast('Receipt confirmed — asante!', 'ok')
  reviewStep.value = true   // now invite a review — best moment, parcel in hand
  track()
}

// ── review at confirmation (two-sided: delivery + product) ──
const reviewStep = ref(false)
const rvDelivery = ref(0); const rvProduct = ref(0)
const rvComment = ref(''); const rvName = ref('')
const reviewDone = ref(false)
async function submitReview() {
  if (!rvDelivery.value) { toast('Tap a star to rate the delivery', 'warn'); return }
  busy.value = true
  try {
    const { error } = await pub.leaveReview({
      p_code: code.value, p_delivery_rating: rvDelivery.value, p_delivery_comment: rvComment.value || null,
      p_product_rating: rvProduct.value || null, p_product_comment: null, p_name: rvName.value || null,
    })
    if (error) throw error
    reviewDone.value = true
    setTimeout(() => { reviewStep.value = false }, 1800)
  } catch (e) { toast(e.message || 'Could not save review', 'warn') }
  busy.value = false
}

// ── receiver agency: reschedule / report ──
// #2 — dispute resolution
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
      p_code: code.value, p_role: 'receiver', p_name: disputeName.value, p_phone: disputePhone.value,
      p_reason: disputeReason.value, p_detail: disputeDetail.value || null })
    if (data?.ok) { showDispute.value = false; toast('Dispute submitted — we\'ll review the custody record and follow up', 'ok') }
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

function openReschedule() { showReschedule.value = true }
function openReport() { showReport.value = true }

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
  requestSent.value = `${parcel.value.carrier} has been notified: "${issue}".`
  toast('Report sent to the carrier', 'ok')
}
function stageOn(s, i) {
  if (parcel.value.stage === 'failed') return i <= STAGE_ORDER.indexOf('with_driver')
  return i <= STAGE_ORDER.indexOf(parcel.value.stage)
}
const owed = computed(() => (parcel.value?.payMode==='cash' && !['collected','remitted','settled'].includes(parcel.value?.payState)) ? parcel.value.cod : 0)
const statusHeadline = computed(() => {
  const s = parcel.value?.stage
  return ({ booked:'Order booked', collected:'Picked up by carrier', linehaul:'On the road to you',
    with_driver:'Out for delivery', delivered:'Delivered', confirmed:'Delivered & confirmed',
    failed:'Delivery issue' }[s]) || 'In progress'
})
const statusSub = computed(() => {
  const s = parcel.value?.stage; const d = parcel.value?.driver
  if (s==='with_driver') return `${d || 'Your driver'} is bringing it today`
  if (s==='linehaul') return 'Moving toward your area'
  if (s==='collected') return 'Your parcel is with the carrier'
  if (s==='booked') return 'Waiting to be picked up'
  if (s==='delivered' || s==='confirmed') return 'This parcel has arrived'
  if (s==='failed') return 'Contact the carrier for details'
  return ''
})
onMounted(() => { if (code.value) track() })
onUnmounted(() => { if (livePoll) clearInterval(livePoll); if (trkMap) { trkMap.remove(); trkMap = null } })
</script>

<template>
  <AppHeader :title="parcel?.carrier || 'Enkiama Cargos'" subtitle="Track your parcel" />

  <div class="trk-hero">
    <div class="trk-hero-inner">
      <div class="trk-hero-badge"><Icon name="pin" :size="16" /> Live tracking</div>
      <h1 class="trk-hero-h1">{{ t('whereIsParcel') }}</h1>
      <p class="trk-hero-sub">Enter your tracking code to see exactly where your cargo is — no account needed.</p>
      <div class="trk-hero-search">
        <input v-model="code" class="mono" placeholder="ENK-XXXX" style="text-transform:uppercase" @keyup.enter="track" />
        <button class="btn btn-accent" :disabled="busy" @click="track">
          <Spinner v-if="busy" :size="16" /><template v-else>Track</template>
        </button>
      </div>
    </div>
  </div>

  <div class="wrap" style="max-width:560px">
    <EmptyState v-if="notFound" icon="search" title="No parcel with that code" hint="Check the code your sender shared with you." />

    <div v-if="parcel" class="cons">
      <div class="cons-hd">
        <div class="grow">
          <div class="cons-code mono">{{ parcel.code }}</div>
          <div class="cons-rte">{{ parcel.driver ? 'With ' + parcel.driver : 'Not yet with a driver' }}</div>
          <TrustBadge v-if="carrierRep && carrierRep.tier !== 'new'" :rep="carrierRep" compact class="trk-trust" />
        </div>
        <span class="paychip" :class="parcel.stage==='confirmed'?'pay-settled':parcel.stage==='failed'?'pay-cod':'pay-collected'">{{ STAGE_CAP[parcel.stage] }}</span>
      </div>
      <div class="cons-bd">
        <!-- prominent current-status statement — the first thing a receiver wants -->
        <div class="trk-statusline" :class="'st-'+parcel.stage">
          <div class="trk-statusline-ic"><Icon :name="parcel.stage==='confirmed'||parcel.stage==='delivered'?'check':parcel.stage==='with_driver'?'route':'package'" :size="20" /></div>
          <div class="trk-statusline-txt">
            <div class="trk-statusline-h">{{ statusHeadline }}</div>
            <div class="trk-statusline-sub">{{ statusSub }}</div>
          </div>
        </div>

        <div v-if="owed>0" class="trk-codsummary">
          <div><span class="trk-cod-lab">Pay on delivery</span><span class="trk-cod-amt mono">{{ fmtTZS(owed) }}</span></div>
          <span class="trk-cod-hint">Have this ready for {{ parcel.driver || 'the driver' }}</span>
        </div>

        <div class="party">
          <div><div class="p-lab">To</div><div class="p-val">{{ parcel.receiver }}</div><div class="p-sub">{{ parcel.addr }}</div></div>
          <div style="text-align:right"><div class="p-lab">Parcel</div><div class="p-val">{{ parcel.item }}</div><div class="p-sub">{{ parcel.weight }}kg</div></div>
        </div>

        <!-- #18 live GPS: driver's position while the parcel is with them -->
        <div v-if="livePos" class="trk-live-wrap">
          <div class="trk-live-head"><span class="trk-live-badge"><span class="trk-live-pulse"></span> LIVE</span> {{ parcel.driver }} is on the way · updated {{ liveAgo }}</div>
          <div id="trkmap" class="trk-map"></div>
        </div>

        <div class="wb-sec">
          <div class="trk-lab"><Icon name="link" :size="12" /> The ledger · one parcel, one truth</div>
          <div class="tl">
            <div v-for="(s,i) in STAGE_ORDER" :key="s" class="tl-row" :class="{done:stageOn(s,i), current:parcel.stage===s}">
              <div class="tl-marker">
                <div class="tl-node"><Icon v-if="stageOn(s,i)" name="check" :size="11" /></div>
                <div v-if="i < STAGE_ORDER.length-1" class="tl-line" :class="{filled:stageOn(STAGE_ORDER[i+1], i+1), active: parcel.stage===STAGE_ORDER[i+1]}"></div>
              </div>
              <div class="tl-body">
                <div class="tl-stage">{{ STAGE_CAP[s] }}<span v-if="parcel.stage===s" class="tl-live"><span class="tl-live-dot"></span>now</span></div>
                <div v-if="stageTime(s)" class="tl-time">{{ stageTime(s) }}</div>
                <div v-else-if="stageOn(s,i)" class="tl-time muted">completed</div>
                <div v-else class="tl-time pending">pending</div>
                <div v-if="stageActor(s)" class="tl-actor"><Icon name="shield" :size="10" /> {{ stageActor(s) }}</div>
                <div v-if="stageNote(s)" class="tl-note">"{{ stageNote(s) }}"</div>
              </div>
            </div>
          </div>
          <div class="tl-verify"><Icon name="check" :size="12" /> Verified record · every step logged, nothing can be altered</div>
        </div>

        <!-- proof shown once delivered -->
        <div v-if="parcel.podPhoto" class="wb-sec" style="margin-top:16px">
          <div class="trk-lab"><Icon name="camera" :size="12" /> Proof of delivery</div>
          <img :src="parcel.podPhoto" style="width:100%;border-radius:12px;margin-top:8px;max-height:220px;object-fit:cover" />
        </div>

        <div class="cons-actions">
          <template v-if="parcel.stage==='delivered'">
            <button v-if="!confirmStep" class="btn btn-go btn-block btn-lg" @click="startConfirm">
              <Icon name="check" :size="18" /> Confirm I received it
            </button>
            <div v-else class="confirm-verify">
              <label>Enter the last 4 digits of your phone to confirm</label>
              <div class="confirm-verify-row">
                <input v-model="last4" inputmode="numeric" maxlength="4" placeholder="0000" class="confirm-last4" @keyup.enter="confirm" />
                <button class="btn btn-go btn-lg" :disabled="busy" @click="confirm"><Spinner v-if="busy" :size="16" /><span v-else>Confirm</span></button>
              </div>
              <button class="confirm-cancel" @click="confirmStep=false">Cancel</button>
            </div>
          </template>
          <div v-else-if="parcel.stage==='confirmed'" class="money-bar done" style="width:100%">
            <Icon name="check" :size="16" /><span class="m-txt">Delivery confirmed — asante!</span>
          </div>
        </div>

        <!-- receiver agency: reschedule / report (before it's confirmed) -->
        <div v-if="!['confirmed','cancelled'].includes(parcel.stage)" class="rcv-agency">
          <div v-if="requestSent" class="rcv-sent">
            <Icon name="check" :size="16" /> {{ requestSent }}
          </div>
          <template v-else>
            <div class="rcv-prompt">Need something?</div>
            <div class="rcv-btns">
              <button class="btn btn-ghost" @click="openReschedule"><Icon name="clock" :size="15" /> Reschedule</button>
              <button class="btn btn-ghost" @click="openReport"><Icon name="alert" :size="15" /> Report a problem</button>
              <button class="btn btn-ghost rcv-dispute" @click="showDispute=true"><Icon name="shield" :size="15" /> Raise a dispute</button>
            </div>
          </template>
        </div>
      </div>
    </div>

    <!-- DISPUTE MODAL -->
    <div v-if="showDispute" class="overlay" v-escape="() => { showDispute=false }" @click.self="showDispute=false">
      <div class="modal" style="max-width:460px">
        <h3>Raise a dispute</h3>
        <p>If something went wrong, tell us. Your parcel's custody record — every step and proof of delivery — is reviewed as evidence, so disputes are resolved fairly.</p>
        <div class="fg"><label>What's the problem?</label>
          <select v-model="disputeReason">
            <option value="not_delivered">It was never delivered</option>
            <option value="damaged">It arrived damaged</option>
            <option value="wrong_item">Wrong item</option>
            <option value="not_as_described">Not as described</option>
            <option value="other">Something else</option>
          </select>
        </div>
        <div class="fg"><label>Your name</label><input v-model="disputeName" placeholder="Your name" /></div>
        <div class="fg"><label>Phone</label><input v-model="disputePhone" placeholder="+255…" /></div>
        <div class="fg"><label>Details</label><textarea v-model="disputeDetail" rows="3" placeholder="Explain what happened."></textarea></div>
        <div class="form-actions">
          <button class="btn btn-ghost" @click="showDispute=false">Cancel</button>
          <button class="btn btn-accent" :disabled="busy" @click="submitDispute"><Spinner v-if="busy" :size="15" /><span v-else>Submit dispute</span></button>
        </div>
      </div>
    </div>

    <!-- RESCHEDULE MODAL -->
    <div v-if="showReschedule" class="overlay" v-escape="() => { showReschedule=false }" @click.self="showReschedule=false">
      <div class="modal" style="max-width:420px">
        <h3>Reschedule delivery</h3>
        <p>Tell {{ parcel.carrier }} when works better. They'll see your request.</p>
        <div class="fg"><label>When would you like it?</label>
          <select v-model="reschedWhen">
            <option>Later today</option><option>Tomorrow</option>
            <option>This weekend</option><option>Call me first</option><option>Leave with neighbour</option>
          </select>
        </div>
        <div class="fg"><label>Anything to add? <span class="opt">optional</span></label>
          <input v-model="reschedNote" placeholder="e.g. after 5pm, gate on the left" />
        </div>
        <div class="confirm-actions">
          <button class="btn btn-ghost" @click="showReschedule=false">Cancel</button>
          <button class="btn btn-accent" :disabled="busy" @click="submitReschedule"><Spinner v-if="busy" :size="15" /><span v-else>Send request</span></button>
        </div>
      </div>
    </div>

    <!-- PRE-SEARCH: promote the platform (retain + convert receivers) -->
    <div v-if="!parcel && !notFound && !code" class="trk-promo">
      <div class="trk-promo-how">
        <div class="trk-promo-lab">How Enkiama works</div>
        <div class="trk-promo-steps">
          <div class="trk-promo-step"><span class="trk-promo-n">1</span><div><b>Your sender ships it</b><span>A shop or person books your parcel with a tracked carrier.</span></div></div>
          <div class="trk-promo-step"><span class="trk-promo-n">2</span><div><b>You follow every step</b><span>Booked, collected, on the road, with your driver — live.</span></div></div>
          <div class="trk-promo-step"><span class="trk-promo-n">3</span><div><b>Delivered with proof</b><span>Photo proof and a timestamp. One parcel, one truth.</span></div></div>
        </div>
      </div>
      <div class="trk-promo-shop">
        <div class="trk-promo-shop-txt">
          <div class="trk-promo-lab accent">Shop while you wait</div>
          <h3>Order from Tanzanian shops — delivered &amp; tracked</h3>
          <p>Fabric, spices, electronics and more, from trusted businesses. Every order ships with the same end-to-end tracking.</p>
          <RouterLink to="/market" class="btn btn-accent"><Icon name="box" :size="15" /> Browse the marketplace</RouterLink>
        </div>
      </div>
    </div>
    <div v-if="showReport" class="overlay" v-escape="() => { showReport=false }" @click.self="showReport=false">
      <div class="modal" style="max-width:420px">
        <h3>Report a problem</h3>
        <p>Let {{ parcel.carrier }} know what's wrong with parcel {{ parcel.code }}.</p>
        <div class="fg"><label>What's the issue?</label>
          <select v-model="reportIssue">
            <option>Wrong delivery address</option><option>Nobody was available</option>
            <option>Parcel looks damaged</option><option>Wrong item / not mine</option>
            <option>Driver couldn't find me</option><option>Other</option>
          </select>
        </div>
        <div class="fg" v-if="reportIssue==='Other'"><label>Describe it</label>
          <input v-model="reportOther" placeholder="Tell us what happened" />
        </div>
        <div class="confirm-actions">
          <button class="btn btn-ghost" @click="showReport=false">Cancel</button>
          <button class="btn btn-accent" :disabled="busy" @click="submitReport"><Spinner v-if="busy" :size="15" /><span v-else>Send report</span></button>
        </div>
      </div>
    </div>

    <footer class="track-foot">
      <BrandMark variant="full" :height="44" />
      <p>One parcel, one truth. · The trusted freight ledger.</p>
    </footer>

    <!-- REVIEW MODAL — captured right after confirming (best moment) -->
    <div v-if="reviewStep" class="overlay" v-escape="() => { reviewStep=false }" @click.self="reviewStep=false">
      <div class="modal rv-modal">
        <div v-if="reviewDone" class="rv-thanks">
          <div class="rv-thanks-ic"><Icon name="check" :size="30" /></div>
          <h3>Asante for your review!</h3>
          <p>Your feedback helps other buyers trust this seller and carrier.</p>
        </div>
        <template v-else>
          <h3>How was it?</h3>
          <p>Your rating builds trust for the next buyer. Takes 10 seconds.</p>

          <div class="rv-block">
            <label>The delivery</label>
            <div class="rv-stars">
              <button aria-label="Rate" v-for="n in 5" :key="n" class="rv-star" :class="{on:n<=rvDelivery}" @click="rvDelivery=n"><Icon name="star" :size="30" /></button>
            </div>
          </div>

          <div class="rv-block">
            <label>The product <span class="rv-opt">optional</span></label>
            <div class="rv-stars">
              <button aria-label="Rate" v-for="n in 5" :key="n" class="rv-star" :class="{on:n<=rvProduct}" @click="rvProduct=n"><Icon name="star" :size="30" /></button>
            </div>
          </div>

          <div class="fg"><input v-model="rvComment" placeholder="Add a comment (optional)" /></div>
          <div class="fg"><input v-model="rvName" placeholder="Your name (optional)" /></div>

          <div class="confirm-actions">
            <button class="btn btn-ghost" @click="reviewStep=false">Skip</button>
            <button class="btn btn-accent" :disabled="busy" @click="submitReview"><Spinner v-if="busy" :size="15" /><span v-else>Submit review</span></button>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
.trk-hero{position:relative;background:var(--nav);overflow:hidden}
.trk-hero::before{content:'';position:absolute;inset:0;pointer-events:none;background:
  radial-gradient(700px 400px at 70% -20%, rgba(11,110,93,.32), transparent 60%),
  radial-gradient(500px 350px at 15% 120%, rgba(15,157,88,.1), transparent 55%)}
.trk-hero::after{content:'';position:absolute;inset:0;pointer-events:none;opacity:.3;
  background-image:linear-gradient(rgba(255,255,255,.03) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.03) 1px,transparent 1px);
  background-size:40px 40px;mask-image:radial-gradient(circle at 50% 20%,black,transparent 72%)}
.trk-hero-inner{position:relative;z-index:1;max-width:560px;margin:0 auto;padding:40px 24px 44px;text-align:center}
.trk-hero-badge{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;font-weight:600;color:#fff;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.14);padding:6px 13px;border-radius:10px;margin-bottom:18px}
.trk-hero-h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(28px,6vw,40px);font-weight:700;letter-spacing:-.03em;color:#fff;margin-bottom:10px}
.trk-hero-h1 .grad{background:linear-gradient(100deg,#818CF8,#34D399) !important;-webkit-background-clip:text !important;background-clip:text !important;-webkit-text-fill-color:transparent !important;color:transparent !important}
.trk-hero-sub{font-size:15px;color:rgba(255,255,255,.6);line-height:1.6;max-width:400px;margin:0 auto 24px}
.trk-hero-search{display:flex;gap:10px;max-width:440px;margin:0 auto}
.trk-hero-search input{flex:1;padding:14px 18px;border:1px solid rgba(255,255,255,.16);border-radius:14px;font-size:16px;font-weight:600;letter-spacing:.05em;background:rgba(255,255,255,.95);color:var(--ink);box-shadow:var(--shadow-md)}
.trk-hero-search input:focus{outline:none;border-color:#818CF8;box-shadow:0 0 0 3px rgba(129,140,248,.3)}
.trk-hero-search .btn{padding:14px 24px;font-size:15px}
.wrap{margin-top:24px}

/* ═══ TRUST-LEDGER TIMELINE — the beautiful vertical journey ═══ */
.tl{display:flex;flex-direction:column;margin-top:6px}
.tl-row{display:flex;gap:16px;min-height:56px}
.tl-marker{display:flex;flex-direction:column;align-items:center;flex-shrink:0}
.tl-node{width:28px;height:28px;border-radius:50%;background:var(--surface-3);border:2px solid var(--hairline-2);display:flex;align-items:center;justify-content:center;color:#fff;flex-shrink:0;transition:all .35s cubic-bezier(.34,1.56,.64,1);z-index:1;position:relative}
.tl-line{width:2.5px;flex:1;background:var(--hairline-2);margin:2px 0;border-radius:2px;position:relative;overflow:hidden;transition:background .5s ease}
.tl-line.filled{background:linear-gradient(180deg,var(--go),var(--accent))}
.tl-row.done .tl-node{background:linear-gradient(135deg,var(--go),#0FA968);border-color:transparent;box-shadow:0 2px 6px rgba(15,157,88,.3)}
.tl-row.current .tl-node{background:linear-gradient(135deg,var(--accent),#12B886);border-color:transparent;box-shadow:0 0 0 5px var(--accent-soft),0 3px 10px rgba(11,110,93,.35)}
.tl-row.current .tl-node::before{content:'';position:absolute;inset:-2px;border-radius:50%;border:2px solid var(--accent);animation:tlRadiate 1.8s ease-out infinite}
.tl-row.current .tl-node::after{content:'';position:absolute;inset:-2px;border-radius:50%;border:2px solid var(--accent);animation:tlRadiate 1.8s ease-out infinite .9s}
@keyframes tlRadiate{0%{transform:scale(1);opacity:.7}100%{transform:scale(2.1);opacity:0}}
/* the in-progress line to the current stage gets a traveling shimmer */
.tl-row.current .tl-line, .tl-line.active{background:var(--hairline-2)}
.tl-line.active::after{content:'';position:absolute;left:0;right:0;height:40%;background:linear-gradient(180deg,transparent,var(--accent),transparent);animation:tlTravel 1.6s ease-in-out infinite}
@keyframes tlTravel{0%{top:-40%}100%{top:100%}}
.tl-stage{font-size:14px;font-weight:600;color:var(--ink-faint);display:flex;align-items:center;gap:8px;transition:color .3s ease}
.tl-row.done .tl-stage{color:var(--ink)}
.tl-row.current .tl-stage{color:var(--accent-ink);font-weight:700;font-size:15px}
.tl-live{display:inline-flex;align-items:center;gap:4px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;color:var(--accent);background:var(--accent-soft);padding:2px 8px;border-radius:999px}
.tl-live-dot{width:5px;height:5px;border-radius:50%;background:var(--accent);animation:tlPulse2 1.4s ease-in-out infinite}
@keyframes tlPulse{0%,100%{box-shadow:0 0 0 5px var(--accent-soft)}50%{box-shadow:0 0 0 9px transparent}}
.tl-body{padding-bottom:18px;padding-top:2px}
.tl-stage{font-weight:650;font-size:14px;color:var(--ink-faint);display:flex;align-items:center;gap:8px}
.tl-row.done .tl-stage{color:var(--ink)}
.tl-row.current .tl-stage{color:var(--accent-ink);font-weight:700}
.tl-live{display:inline-flex;align-items:center;gap:4px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;color:var(--accent);background:var(--accent-soft);padding:2px 7px;border-radius:999px}
.tl-live-dot{width:5px;height:5px;border-radius:50%;background:var(--accent);animation:tlPulse2 1.4s ease-in-out infinite}
@keyframes tlPulse2{0%,100%{opacity:1}50%{opacity:.3}}
.tl-time{font-size:12.5px;color:var(--ink-soft);margin-top:3px;font-variant-numeric:tabular-nums}
.tl-time.muted{color:var(--ink-faint)}
.tl-time.pending{color:var(--ink-ghost)}
.tl-verify{display:flex;align-items:center;gap:7px;font-size:11px;font-weight:600;color:var(--go-ink);margin-top:6px;padding:10px 12px;background:var(--go-soft);border-radius:10px}

/* ═══ TRACK PRE-SEARCH PROMO — retain + convert ═══ */
.trk-promo{max-width:560px;margin:0 auto;display:flex;flex-direction:column;gap:16px}
.trk-promo-how{background:var(--surface);border:1px solid var(--hairline);border-radius:var(--r-lg);padding:24px;box-shadow:var(--shadow-sm)}
.trk-promo-lab{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:var(--ink-faint);margin-bottom:16px}
.trk-promo-lab.accent{color:var(--accent-ink)}
.trk-promo-steps{display:flex;flex-direction:column;gap:16px}
.trk-promo-step{display:flex;gap:14px;align-items:flex-start}
.trk-promo-n{width:26px;height:26px;border-radius:8px;background:var(--accent-soft);color:var(--accent-ink);font-family:"Space Grotesk",sans-serif;font-weight:700;font-size:13px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.trk-promo-step b{display:block;font-size:14px;font-weight:650;color:var(--ink);margin-bottom:2px}
.trk-promo-step span{font-size:12.5px;color:var(--ink-faint);line-height:1.5}
.trk-promo-shop{background:linear-gradient(135deg,var(--ink),#20262F);border-radius:var(--r-lg);padding:26px;color:#fff;overflow:hidden;position:relative}
.trk-promo-shop::before{content:"";position:absolute;inset:0;background:radial-gradient(500px 300px at 90% 0%,rgba(11,110,93,.4),transparent 60%);pointer-events:none}
.trk-promo-shop-txt{position:relative}
.trk-promo-shop .trk-promo-lab{color:#4FD1B5}
.trk-promo-shop h3{font-family:"Space Grotesk",sans-serif;font-size:20px;font-weight:700;letter-spacing:-.02em;line-height:1.15;margin-bottom:8px;color:#fff}
.trk-promo-shop p{font-size:13px;color:rgba(255,255,255,.62);line-height:1.55;margin-bottom:18px}

.tl-actor{display:flex;align-items:center;gap:4px;font-size:11px;color:var(--accent-ink);font-weight:600;margin-top:3px}
.tl-actor svg{color:var(--accent)}
.tl-note{font-size:12.5px;color:var(--ink-faint);font-style:italic;margin-top:2px}
.trk-trust{margin-top:8px}

.trk-live-wrap{margin:16px 0;border:1px solid var(--hairline-2);border-radius:14px;overflow:hidden;box-shadow:var(--shadow-sm)}
.trk-live-head{display:flex;align-items:center;gap:8px;padding:11px 14px;background:var(--surface);font-size:13px;font-weight:600;color:var(--ink-soft);border-bottom:1px solid var(--hairline)}
.trk-live-badge{display:inline-flex;align-items:center;gap:5px;font-size:10.5px;font-weight:800;letter-spacing:.05em;color:#fff;background:var(--owed);padding:3px 9px;border-radius:999px}
.trk-live-pulse{width:7px;height:7px;border-radius:50%;background:#fff;animation:trkpulse 1.4s infinite}
@keyframes trkpulse{0%,100%{opacity:1}50%{opacity:.3}}
.trk-map{height:260px;width:100%}
:global(.trk-driver-pin .tdp){width:22px;height:22px;border-radius:50%;background:var(--accent);border:3px solid #fff;box-shadow:0 0 0 4px rgba(11,110,93,.3),0 2px 6px rgba(0,0,0,.3)}

.trk-statusline{display:flex;align-items:center;gap:14px;padding:16px;border-radius:14px;margin-bottom:14px;background:var(--surface-2)}
.trk-statusline.st-with_driver{background:linear-gradient(135deg,var(--accent-soft),var(--go-soft));border:1px solid var(--accent)}
.trk-statusline.st-delivered,.trk-statusline.st-confirmed{background:var(--go-soft)}
.trk-statusline.st-failed{background:var(--owed-soft)}
.trk-statusline-ic{width:48px;height:48px;border-radius:13px;background:var(--surface);color:var(--accent-ink);display:flex;align-items:center;justify-content:center;flex-shrink:0;box-shadow:var(--shadow-sm)}
.trk-statusline.st-with_driver .trk-statusline-ic{background:var(--accent);color:#fff}
.trk-statusline.st-delivered .trk-statusline-ic,.trk-statusline.st-confirmed .trk-statusline-ic{background:var(--go);color:#fff}
.trk-statusline-h{font-family:'Space Grotesk',sans-serif;font-size:19px;font-weight:700;color:var(--ink);letter-spacing:-.02em;line-height:1.15}
.trk-statusline-sub{font-size:13.5px;color:var(--ink-soft);margin-top:2px}
.trk-codsummary{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px 16px;border-radius:13px;background:var(--owed-soft);border:1px solid rgba(214,59,42,.25);margin-bottom:16px}
.trk-cod-lab{display:block;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;color:var(--owed-ink);margin-bottom:2px}
.trk-cod-amt{font-family:'Space Grotesk',sans-serif;font-size:22px;font-weight:700;color:var(--owed-ink);letter-spacing:-.02em}
.trk-cod-hint{font-size:12px;color:var(--ink-soft);text-align:right;max-width:130px}

/* calm-premium tracking result card */
.cons{background:var(--surface);border:1px solid var(--hairline-soft,rgba(20,24,31,.05));border-radius:22px;box-shadow:0 8px 32px rgba(20,24,31,.08)}
.cons-bd{padding:18px}
.trk-statusline{border-radius:16px}
.trk-statusline.st-with_driver{background:linear-gradient(135deg,var(--accent-soft),var(--go-soft));border:1px solid var(--hairline-soft,rgba(20,24,31,.06))}
.trk-codsummary{border-radius:16px}
</style>
