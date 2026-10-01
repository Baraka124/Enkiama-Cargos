<script setup>
// A land purchase as a tracked, protected journey — the custody timeline applied to buying property.
import { ref, computed, onMounted, inject } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../lib/supabase'
import { formatTZS } from '../lib/format'
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
function tzs(n) { return n ? formatTZS(n, { fallback: '' }) : '' }

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
.deal-wrap{max-width:1020px;padding-top:24px}.deal-load{display:flex;justify-content:center;padding:80px}.deal-back{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:600;color:var(--world-ink-faint);text-decoration:none;margin-bottom:24px;border-bottom:1px solid transparent}.deal-back:hover{color:var(--world-ink);border-color:var(--world-line-strong)}.deal-head{display:grid;grid-template-columns:1fr auto;align-items:end;gap:30px;margin-bottom:34px;padding-bottom:24px;border-bottom:1px solid var(--world-line)}.deal-code{font:500 9.5px var(--font-mono);color:var(--world-ink-faint);letter-spacing:.08em;text-transform:uppercase;margin-bottom:7px}.deal-title{font:600 clamp(28px,4vw,44px)/1 var(--font-display);letter-spacing:-.045em;color:var(--world-ink)}.deal-loc{font-size:12px;color:var(--world-ink-soft);display:flex;align-items:center;gap:5px;margin-top:8px}.deal-price{font:600 18px var(--font-display);color:var(--world-ink);white-space:nowrap}.deal-grid{display:grid;grid-template-columns:minmax(0,1fr) 300px;gap:52px;align-items:start}@media(max-width:780px){.deal-grid{grid-template-columns:1fr;gap:34px}.deal-head{grid-template-columns:1fr}.deal-price{font-size:16px}}
.deal-journey-h,.deal-advance-h{display:flex;align-items:center;gap:8px;font:600 9.5px var(--font-mono);color:var(--world-ink-faint);margin-bottom:22px;text-transform:uppercase;letter-spacing:.07em}.deal-cancelled{padding:14px 0;border-block:1px solid color-mix(in srgb,var(--util-danger) 40%,var(--world-line));color:var(--util-danger);font-weight:600;text-align:left}.deal-tl .tl-content{padding-bottom:10px}.tl-when{font-size:11.5px;color:var(--world-ink-faint);margin-top:3px}
.deal-side{display:flex;flex-direction:column;gap:0;border-top:1px solid var(--world-line)}.deal-protect{background:transparent;border:0;border-bottom:1px solid var(--world-line);border-radius:0;padding:20px 0;text-align:left;display:grid;grid-template-columns:34px 1fr;column-gap:12px}.deal-protect-ic{width:32px;height:32px;border-radius:6px;border:1px solid var(--world-line-strong);background:transparent;color:var(--world-accent);display:grid;place-items:center;margin:0}.deal-protect b{display:block;font-size:12px;color:var(--world-ink);margin:1px 0 4px}.deal-protect p{grid-column:2;font-size:11.5px;line-height:1.55;color:var(--world-ink-soft)}.deal-advance{background:transparent;border:0;border-bottom:1px solid var(--world-line);border-radius:0;padding:20px 0;box-shadow:none}.deal-advance-stage{display:flex;align-items:center;gap:8px;font:600 15px var(--font-display);color:var(--world-ink);margin-bottom:5px}.deal-advance-desc{font-size:11.5px;color:var(--world-ink-soft);margin-bottom:16px}.deal-complete{background:transparent;color:var(--world-accent);border-bottom:1px solid var(--world-line);border-radius:0;padding:20px 0;text-align:left;display:grid;grid-template-columns:26px 1fr;gap:4px 8px}.deal-complete b{font-size:14px}.deal-complete span{grid-column:2;font-size:11.5px}.deal-cancel-btn{background:none;border:0;color:var(--world-ink-faint);font-size:11px;font-weight:600;cursor:pointer;padding:16px 0;text-align:left}.deal-cancel-btn:hover{color:var(--util-danger)}
</style>