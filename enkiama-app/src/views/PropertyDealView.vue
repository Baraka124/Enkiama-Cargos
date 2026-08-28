<script setup>
// A land purchase as a tracked, protected journey — the custody timeline applied to buying property.
import { ref, computed, onMounted, inject } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import AppHeader from '../components/AppHeader.vue'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import EmptyState from '../components/EmptyState.vue'

const route = useRoute()
const toast = inject('toast')

const data = ref(null)
const loading = ref(true)
const notFound = ref(false)
const busy = ref(false)

// the journey stages, in order — the "custody" of a land purchase
const STAGES = [
  { key: 'enquired',    label: 'Enquiry started',    icon: 'inbox',   desc: 'Buyer expressed serious interest' },
  { key: 'viewing',     label: 'Site viewing',       icon: 'pin',     desc: 'Buyer visits and inspects the land' },
  { key: 'offer',       label: 'Offer made',         icon: 'star',    desc: 'Buyer makes a formal offer' },
  { key: 'deposit',     label: 'Deposit in escrow',  icon: 'shield',  desc: 'Deposit held safely by Enkiama' },
  { key: 'title_check', label: 'Title verification', icon: 'check',   desc: 'Ownership & title confirmed' },
  { key: 'completed',   label: 'Sale completed',     icon: 'check',   desc: 'Title transferred — deal done' },
]
const STAGE_ORDER = STAGES.map(s => s.key)

async function load() {
  loading.value = true
  try {
    const { data: res } = await supabase.rpc('get_property_deal', { p_deal_id: route.params.id })
    if (res?.ok) data.value = res; else notFound.value = true
  } catch (e) { notFound.value = true }
  loading.value = false
}
const deal = computed(() => data.value?.deal || {})
const listing = computed(() => data.value?.listing || {})
const events = computed(() => data.value?.events || [])
const currentIdx = computed(() => STAGE_ORDER.indexOf(deal.value.stage))
const cancelled = computed(() => deal.value.stage === 'cancelled')

function stageDone(i) { return i < currentIdx.value }
function stageCurrent(i) { return i === currentIdx.value }
function stageEventTime(key) {
  const e = events.value.find(ev => ev.stage === key)
  if (!e) return ''
  const d = new Date(e.created_at)
  if (isNaN(d)) return ''
  return d.toLocaleDateString('en-GB', { day:'numeric', month:'short' }) + ' · ' + d.toLocaleTimeString('en-GB', { hour:'2-digit', minute:'2-digit' })
}
function tzs(n) { return n ? 'TZS ' + Number(n).toLocaleString() : '' }

// advancing the deal
const nextStage = computed(() => {
  const i = currentIdx.value
  return i >= 0 && i < STAGE_ORDER.length - 1 ? STAGES[i + 1] : null
})
async function advance(toStage) {
  busy.value = true
  try {
    const { data: res } = await supabase.rpc('advance_property_deal', { p_deal_id: deal.value.id, p_stage: toStage })
    if (res?.ok) { toast('Journey updated', 'ok'); await load() }
    else toast(res?.error || 'Could not update', 'warn')
  } catch (e) { toast('Could not update', 'warn') }
  busy.value = false
}
async function cancelDeal() {
  if (!confirm('Cancel this purchase journey?')) return
  await advance('cancelled')
}

onMounted(load)
</script>

<template>
  <AppHeader />
  <div class="wrap deal-wrap">
    <div v-if="loading" class="deal-load"><Spinner :size="26" /></div>
    <EmptyState v-else-if="notFound" icon="pin" title="Deal not found" hint="It may have been removed, or isn't yours to view." />
    <template v-else>
      <RouterLink :to="`/property/${listing.id}`" class="deal-back"><Icon name="arrow" :size="14" style="transform:rotate(180deg)" /> {{ listing.title }}</RouterLink>

      <div class="deal-head">
        <div>
          <div class="deal-code mono">{{ deal.code }}</div>
          <h1 class="deal-title">{{ listing.title }}</h1>
          <div class="deal-loc"><Icon name="pin" :size="13" /> {{ listing.location }}<template v-if="listing.region">, {{ listing.region }}</template></div>
        </div>
        <div class="deal-price">{{ tzs(listing.price_tzs) }}</div>
      </div>

      <div class="deal-grid">
        <!-- the signature journey timeline -->
        <div class="deal-journey">
          <div class="deal-journey-h"><Icon name="shield" :size="15" /> Your protected purchase journey</div>
          <div v-if="cancelled" class="deal-cancelled">This purchase journey was cancelled.</div>
          <div v-else class="tl deal-tl">
            <div v-for="(st,i) in STAGES" :key="st.key" class="tl-row" :class="{done:stageDone(i), current:stageCurrent(i)}">
              <div class="tl-marker">
                <div class="tl-node"><Icon v-if="stageDone(i)" name="check" :size="13" /><Icon v-else :name="st.icon" :size="13" /></div>
                <div v-if="i < STAGES.length-1" class="tl-line" :class="{filled:stageDone(i+1)||stageCurrent(i+1), active:stageCurrent(i+1)}"></div>
              </div>
              <div class="tl-content">
                <div class="tl-stage">{{ st.label }}<span v-if="stageCurrent(i)" class="tl-live"><span class="tl-live-dot"></span> Now</span></div>
                <div class="tl-when">{{ stageEventTime(st.key) || st.desc }}</div>
              </div>
            </div>
          </div>
        </div>

        <!-- controls + protection -->
        <div class="deal-side">
          <div class="deal-protect">
            <div class="deal-protect-ic"><Icon name="shield" :size="20" /></div>
            <b>Protected by Enkiama</b>
            <p>Every step is recorded. Your deposit is held in escrow and only released when title is verified — never pay the full amount before completion.</p>
          </div>

          <div v-if="!cancelled && nextStage" class="deal-advance">
            <div class="deal-advance-h">Next step</div>
            <div class="deal-advance-stage"><Icon :name="nextStage.icon" :size="15" /> {{ nextStage.label }}</div>
            <p class="deal-advance-desc">{{ nextStage.desc }}</p>
            <button class="btn btn-accent btn-block btn-lg" :disabled="busy" @click="advance(nextStage.key)">
              <Spinner v-if="busy" :size="15" /><span v-else>Mark as {{ nextStage.label.toLowerCase() }}</span>
            </button>
          </div>
          <div v-else-if="deal.stage==='completed'" class="deal-complete">
            <Icon name="check" :size="22" /> <b>Sale completed</b><span>Congratulations — this purchase is done.</span>
          </div>

          <button v-if="!cancelled && deal.stage!=='completed'" class="deal-cancel-btn" @click="cancelDeal">Cancel journey</button>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.deal-wrap{max-width:960px}
.deal-load{display:flex;justify-content:center;padding:80px}
.deal-back{display:inline-flex;align-items:center;gap:6px;font-size:13.5px;font-weight:600;color:var(--ink-soft);text-decoration:none;margin-bottom:18px}
.deal-back:hover{color:var(--accent-ink)}
.deal-head{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;margin-bottom:28px;padding-bottom:22px;border-bottom:1px solid var(--hairline)}
.deal-code{font-size:12px;font-weight:600;color:var(--ink-faint);letter-spacing:.04em;margin-bottom:5px}
.deal-title{font-family:'Space Grotesk',sans-serif;font-size:26px;font-weight:700;letter-spacing:-.02em;color:var(--ink);line-height:1.15}
.deal-loc{font-size:13.5px;color:var(--ink-soft);display:flex;align-items:center;gap:5px;margin-top:6px}
.deal-price{font-family:'Space Grotesk',sans-serif;font-size:22px;font-weight:700;color:var(--ink);white-space:nowrap}
.deal-grid{display:grid;grid-template-columns:1fr 320px;gap:32px;align-items:start}
@media(max-width:760px){.deal-grid{grid-template-columns:1fr}}

.deal-journey-h,.deal-advance-h{display:flex;align-items:center;gap:8px;font-size:13px;font-weight:700;color:var(--accent-ink);margin-bottom:18px;text-transform:uppercase;letter-spacing:.03em}
.deal-cancelled{padding:20px;background:var(--owed-soft);color:var(--owed-ink);border-radius:12px;font-weight:600;text-align:center}

.deal-tl .tl-content{padding-bottom:8px}
.tl-when{font-size:12.5px;color:var(--ink-faint);margin-top:2px}

.deal-side{display:flex;flex-direction:column;gap:16px}
.deal-protect{background:linear-gradient(145deg,var(--accent-soft),var(--go-soft));border:1px solid var(--accent);border-radius:16px;padding:18px;text-align:center}
.deal-protect-ic{width:46px;height:46px;border-radius:12px;background:var(--accent);color:#fff;display:flex;align-items:center;justify-content:center;margin:0 auto 12px}
.deal-protect b{display:block;font-size:15px;color:var(--accent-ink);margin-bottom:6px}
.deal-protect p{font-size:12.5px;line-height:1.55;color:var(--ink-soft)}

.deal-advance{background:var(--surface);border:1px solid var(--hairline-2);border-radius:16px;padding:18px;box-shadow:var(--shadow-sm)}
.deal-advance-stage{display:flex;align-items:center;gap:8px;font-family:'Space Grotesk',sans-serif;font-size:16px;font-weight:700;color:var(--ink);margin-bottom:4px}
.deal-advance-desc{font-size:12.5px;color:var(--ink-soft);margin-bottom:14px}
.deal-complete{background:var(--go-soft);color:var(--go-ink);border-radius:16px;padding:20px;text-align:center;display:flex;flex-direction:column;align-items:center;gap:6px}
.deal-complete b{font-size:16px}.deal-complete span{font-size:12.5px}
.deal-cancel-btn{background:none;border:none;color:var(--ink-faint);font-size:12.5px;font-weight:600;cursor:pointer;padding:8px;text-decoration:underline}
.deal-cancel-btn:hover{color:var(--owed-ink)}
</style>
