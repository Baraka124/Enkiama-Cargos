<script setup>
import { computed } from 'vue'
import { fmtTZS } from '../lib/supabase'
import { useConsignments } from '../composables/useConsignments'
import Icon from './Icon.vue'
const props = defineProps({ p: Object, why: String, urgent: Boolean })
const { STAGE_CAP, STAGE_ORDER } = useConsignments()
const failed = computed(() => props.p.stage === 'failed')
const idx = computed(() => STAGE_ORDER.indexOf(props.p.stage))
const stepIndex = computed(() => Math.max(1, Math.min(6, idx.value + 1)))
const progPct = computed(() => {
  if (failed.value) return 66
  return Math.round((Math.max(0, idx.value) / (STAGE_ORDER.length - 1)) * 100)
})
const money = computed(() => {
  const p = props.p
  if (p.payMode === 'cash' || p.payMode === 'mobilemoney') {
    if (p.stage === 'confirmed' || ['collected','remitted','settled'].includes(p.payState))
      return { label: p.payState==='remitted'||p.payState==='settled' ? 'Settled' : 'Cash collected',
               cls: p.payState==='remitted'||p.payState==='settled' ? 'pay-settled' : 'pay-collected', owed: 0 }
    return { label: `Collect ${fmtTZS(p.cod)}`, cls: 'pay-cod', owed: p.cod }
  }
  if (p.payMode === 'feeonly') return { label: 'Fee only', cls: 'pay-prepaid', owed: 0 }
  return { label: 'Prepaid', cls: 'pay-prepaid', owed: 0 }
})
function stageOn(stage, i) {
  if (failed.value) return i <= STAGE_ORDER.indexOf('with_driver')
  return i <= idx.value
}
function cap(stage) {
  if (failed.value && stage === 'delivered') return 'Failed'
  return STAGE_CAP[stage]
}
const settled = computed(() => (props.p.payMode==='cash'||props.p.payMode==='mobilemoney') && ['collected','remitted','settled'].includes(props.p.payState))

// #8 staleness — how long in current pipeline, flag stale action items
const age = computed(() => {
  const ts = props.p.updatedAt || props.p.createdAt
  if (!ts) return null
  const days = Math.floor((Date.now() - new Date(ts).getTime()) / 86400000)
  const active = !['delivered','confirmed','cancelled'].includes(props.p.stage)
  if (!active) return null
  if (days >= 3) return { label: `${days}d waiting`, cls: 'stale' }
  if (days >= 1) return { label: `${days}d`, cls: 'warn' }
  return { label: 'today', cls: '' }
})
</script>

<template>
  <div class="wb" :class="{ urgent, failed }">
    <!-- top line: code · status · money — all one row -->
    <div class="wb-top">
      <span class="wb-code">{{ p.code }}</span>
      <span class="wb-stage" :class="'st-'+(failed?'fail':p.stage)">{{ failed ? 'Failed' : cap(p.stage) }}</span>
      <div class="grow"></div>
      <span v-if="age" class="wb-age" :class="age.cls">{{ age.label }}</span>
      <span class="wb-money" :class="money.cls">{{ money.label }}</span>
    </div>

    <!-- route: from → to on one dense line -->
    <div class="wb-route">
      <div class="wb-end">
        <div class="wb-party">{{ p.sender || '—' }}</div>
        <div class="wb-detail">{{ p.item || 'Parcel' }}<span v-if="p.weight && !isNaN(p.weight)"> · {{ p.weight }}kg</span></div>
      </div>
      <Icon name="arrow" :size="15" class="wb-arr" />
      <div class="wb-end wb-end-r">
        <div class="wb-party">{{ p.receiver }}</div>
        <div class="wb-detail"><Icon name="pin" :size="11" /> {{ p.addr }}</div>
      </div>
    </div>

    <!-- slim progress + driver on one line -->
    <div class="wb-meta">
      <div class="wb-prog-track"><div class="wb-prog-fill" :class="{fail:failed}" :style="{width: progPct + '%'}"></div></div>
      <span class="wb-driver" :class="{alert: !p.driver && (p.stage==='linehaul'||failed)}">
        <Icon :name="p.driver ? 'bike' : 'clock'" :size="12" /> {{ p.driver || (why || 'No driver') }}
      </span>
    </div>

    <div v-if="p.attemptCount" class="wb-attempt">
      <Icon name="clock" :size="11" /> {{ p.attemptCount }} attempt{{ p.attemptCount>1?'s':'' }}<span v-if="p.lastReason"> · {{ p.lastReason }}</span>
    </div>

    <div class="cons-actions"><slot /></div>
  </div>
</template>

<style scoped>
.wb{background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:16px 18px;margin-bottom:12px;box-shadow:var(--shadow-sm);transition:box-shadow var(--dur) var(--ease),border-color var(--dur) var(--ease),transform var(--dur-fast) var(--ease);position:relative;overflow:hidden}
.wb::before{content:'';position:absolute;left:0;top:0;bottom:0;width:3px;background:var(--accent);opacity:0;transition:opacity var(--dur) var(--ease)}
.wb:hover{box-shadow:var(--shadow-md);border-color:var(--hairline-2);transform:translateY(-1px)}
.wb:hover::before{opacity:.5}
.wb.urgent::before{background:var(--warn);opacity:1}
.wb.failed::before{background:var(--owed);opacity:1}

/* top line — code, stage, money all inline */
.wb-top{display:flex;align-items:center;gap:10px;margin-bottom:12px}
.wb-code{font-family:'Spline Sans Mono',monospace;font-weight:600;font-size:14px;letter-spacing:.02em;color:var(--ink);background:var(--surface-2);padding:3px 9px;border-radius:7px}
.wb-stage{font-size:10px;font-weight:700;padding:3px 10px;border-radius:var(--r-full);text-transform:uppercase;letter-spacing:.04em}
.st-booked{background:var(--surface-3);color:var(--ink-soft)}
.st-collected,.st-linehaul{background:var(--accent-soft);color:var(--accent-ink)}
.st-with_driver{background:var(--warn-soft);color:var(--warn-ink)}
.st-delivered,.st-confirmed{background:var(--go-soft);color:var(--go-ink)}
.st-fail{background:var(--owed-soft);color:var(--owed-ink)}
.grow{flex:1}
.wb-age{font-size:11px;font-weight:600;color:var(--ink-faint)}
.wb-age.warn{color:var(--warn-ink)}
.wb-age.stale{color:var(--owed-ink);font-weight:700}
.wb-money{font-size:12.5px;font-weight:700;font-variant-numeric:tabular-nums;padding:4px 10px;border-radius:8px}
.wb-money.pay-cod{background:var(--owed-soft);color:var(--owed-ink)}
.wb-money.pay-collected,.wb-money.pay-settled{background:var(--go-soft);color:var(--go-ink)}
.wb-money.pay-prepaid{background:var(--surface-3);color:var(--ink-soft)}

/* route — dense single line */
.wb-route{display:flex;align-items:center;gap:14px;margin-bottom:14px;padding:12px;background:var(--surface-2);border-radius:11px}
.wb-end{min-width:0;flex:1}
.wb-end-r{text-align:right}
.wb-party{font-size:14px;font-weight:650;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.wb-detail{font-size:12px;color:var(--ink-faint);margin-top:2px;display:flex;align-items:center;gap:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.wb-end-r .wb-detail{justify-content:flex-end}
.wb-arr{color:var(--accent);flex-shrink:0}

/* progress + driver on one slim line */
.wb-meta{display:flex;align-items:center;gap:12px;margin-bottom:2px}
.wb-prog-track{flex:1;height:5px;background:var(--surface-3);border-radius:var(--r-full);overflow:hidden}
.wb-prog-fill{height:100%;background:linear-gradient(90deg,var(--accent),var(--accent-hi,var(--accent)));border-radius:var(--r-full);transition:width var(--dur-slow) var(--ease)}
.wb-prog-fill.fail{background:var(--owed)}
.wb-driver{display:flex;align-items:center;gap:5px;font-size:12px;color:var(--ink-soft);font-weight:600;white-space:nowrap}
.wb-driver.alert{color:var(--owed-ink)}
.wb-attempt{display:flex;align-items:center;gap:5px;font-size:11px;color:var(--warn-ink);margin-top:8px}
.cons-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}
.cons-actions:empty{display:none}
</style>
