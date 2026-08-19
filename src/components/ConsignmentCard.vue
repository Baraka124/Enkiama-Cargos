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
  <div class="wb" :class="{ urgent }">
    <!-- waybill header: code as document number -->
    <div class="wb-hd">
      <div class="wb-id">
        <div class="wb-code mono">{{ p.code }}</div>
        <div class="wb-strip"><i v-for="n in 22" :key="n" :style="{opacity: (n*7%3)?1:.35}"></i></div>
      </div>
      <div class="grow"></div>
      <span v-if="age" class="age-badge" :class="age.cls">{{ age.label }}</span>
      <span class="paychip" :class="money.cls">{{ money.label }}</span>
    </div>

    <!-- route: from → to -->
    <div class="wb-route">
      <div class="wb-party">
        <div class="p-lab">From</div>
        <div class="p-val">{{ p.sender || '—' }}</div>
        <div class="p-sub">{{ p.item }} · {{ p.weight }}kg</div>
      </div>
      <div class="wb-arrow"><Icon name="arrow" :size="16" /></div>
      <div class="wb-party" style="text-align:right">
        <div class="p-lab">To</div>
        <div class="p-val">{{ p.receiver }}</div>
        <div class="p-sub"><Icon name="pin" :size="12" /> {{ p.addr }}</div>
      </div>
    </div>

    <div class="wb-driver">
      <Icon :name="p.driver ? 'bike' : 'clock'" :size="14" />
      {{ p.driver ? p.driver : 'No local driver yet' }}
      <span v-if="why" class="wb-why why-rank">· <span class="why-dot" :class="failed ? 'hi' : (!p.driver && p.stage==='linehaul') ? 'mid' : 'lo'"></span>{{ why }}</span>
    </div>

    <!-- custody: compact progress (was a giant 6-stage rail) -->
    <div class="wb-progress">
      <div class="wb-prog-track"><div class="wb-prog-fill" :class="{fail:failed}" :style="{width: progPct + '%'}"></div></div>
      <div class="wb-prog-cap"><span class="wb-prog-now" :class="{fail:failed}">{{ failed ? 'Delivery failed' : cap(p.stage) }}</span><span class="wb-prog-step">{{ stepIndex }}/6</span></div>
    </div>

    <!-- payment -->
    <div class="wb-sec">
      <div class="trk-lab"><Icon name="cash" :size="12" /> Payment</div>
      <div v-if="money.owed > 0" class="money-bar owed">
        <Icon name="cash" :size="16" />
        <span class="m-txt">Cash on delivery — collected on handover</span>
        <span class="m-amt mono">{{ fmtTZS(money.owed) }}</span>
      </div>
      <div v-else-if="settled" class="money-bar done">
        <Icon :name="p.momoConfirmed ? 'phone' : 'check'" :size="16" />
        <span class="m-txt">{{ p.payState==='remitted'||p.payState==='settled' ? 'Remitted to carrier' : (p.momoConfirmed ? 'Paid by mobile money' : 'Collected — awaiting remit') }}</span>
        <span class="m-amt mono">{{ fmtTZS(p.cod) }}</span>
      </div>
      <div v-else class="money-bar">
        <Icon name="check" :size="16" />
        <span class="m-txt">{{ p.payMode==='feeonly' ? 'Goods free — fee prepaid' : 'Goods prepaid' }}</span>
        <span class="m-amt mono">{{ fmtTZS(p.fee) }} fee</span>
      </div>
    </div>

    <div v-if="p.attemptCount" class="wb-attempt">
      <Icon name="clock" :size="12" /> {{ p.attemptCount }} attempt{{ p.attemptCount>1?'s':'' }}<span v-if="p.lastReason"> · {{ p.lastReason }}</span>
    </div>

    <div class="cons-actions"><slot /></div>
  </div>
</template>

<style scoped>
.wb{background:var(--surface);border:1px solid var(--hairline);border-radius:var(--r-lg);padding:0;margin-bottom:14px;box-shadow:var(--shadow-sm);transition:box-shadow .2s,transform .2s;overflow:hidden}
.wb:hover{box-shadow:var(--shadow-md)}
.wb.urgent{border-color:var(--owed-soft)}
.wb-hd{display:flex;align-items:center;gap:12px;padding:14px 18px 12px;border-bottom:1px dashed var(--hairline-2)}
.wb.urgent .wb-hd{background:var(--owed-soft)}
.wb-code{font-family:'Space Grotesk',sans-serif;font-size:16px;font-weight:700;letter-spacing:.04em;color:var(--ink)}
.wb-strip{display:flex;gap:1.5px;margin-top:5px;height:11px;align-items:stretch}
.wb-strip i{width:2px;background:var(--ink);border-radius:.5px}
.wb-route{display:flex;align-items:center;gap:12px;padding:14px 18px 10px}
.wb-party{flex:1;min-width:0}
.wb-arrow{color:var(--ink-ghost);padding-top:14px;flex-shrink:0}
.p-lab{font-size:9.5px;color:var(--ink-faint);text-transform:uppercase;letter-spacing:.07em;font-weight:600}
.p-val{font-size:15px;font-weight:650;margin-top:2px;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.p-sub{font-size:12px;color:var(--ink-faint);margin-top:2px;display:inline-flex;align-items:center;gap:4px}
.wb-driver{padding:0 18px 14px;font-size:12.5px;color:var(--ink-soft);display:flex;align-items:center;gap:6px}
.wb-why{color:var(--owed-ink);font-weight:550}
.wb-sec{padding:14px 18px;border-top:1px solid var(--hairline)}
.trk-lab{font-size:9.5px;color:var(--ink-faint);text-transform:uppercase;letter-spacing:.07em;font-weight:600;margin-bottom:11px;display:flex;align-items:center;gap:5px}
.custody{display:flex;align-items:flex-start}
.cst{flex:1;display:flex;flex-direction:column;align-items:center;position:relative}
.cst .pt{width:11px;height:11px;border-radius:50%;background:var(--surface);border:2px solid var(--hairline-2);z-index:1;transition:all .35s cubic-bezier(.4,0,.2,1)}
.cst.on .pt{background:var(--accent);border-color:var(--accent);box-shadow:0 0 0 3px var(--accent-soft)}
.cst.on:last-child .pt{background:var(--go);border-color:var(--go);box-shadow:0 0 0 3px var(--go-soft)}
.cst.fail .pt{background:var(--owed);border-color:var(--owed);box-shadow:0 0 0 3px var(--owed-soft)}
.cst .cap{font-size:8px;color:var(--ink-ghost);text-transform:uppercase;font-weight:600;margin-top:7px;text-align:center;letter-spacing:.02em}
.cst.on .cap{color:var(--ink-soft)}
.cst:not(:last-child)::after{content:"";position:absolute;top:5px;left:calc(50% + 7px);width:calc(100% - 14px);height:2px;background:var(--hairline-2);transition:background .35s}
.cst.on:not(:last-child)::after{background:var(--accent)}
.money-bar{background:var(--surface-2);border:1px solid var(--hairline);border-radius:11px;padding:11px 13px;display:flex;align-items:center;gap:10px;color:var(--ink-soft)}
.money-bar.owed{border-color:var(--owed-soft);background:var(--owed-soft);color:var(--owed-ink)}
.money-bar.done{background:var(--go-soft);border-color:var(--go-soft);color:var(--go-ink)}
.money-bar .m-txt{flex:1;font-size:12px}
.money-bar .m-amt{font-size:14px;font-weight:600}
.wb-attempt{padding:0 18px 12px;font-size:11.5px;color:var(--ink-faint);display:flex;align-items:center;gap:5px}
.cons-actions{display:flex;gap:9px;padding:0 18px 16px;flex-wrap:wrap}
.cons-actions:empty{display:none}

.wb-progress{padding:10px 18px 12px}
.wb-prog-track{height:5px;background:var(--surface-3);border-radius:var(--r-full);overflow:hidden}
.wb-prog-fill{height:100%;background:var(--accent);border-radius:var(--r-full);transition:width var(--dur) var(--ease)}
.wb-prog-fill.fail{background:var(--owed)}
.wb-prog-cap{display:flex;align-items:center;justify-content:space-between;margin-top:7px}
.wb-prog-now{font-size:var(--t-sm);font-weight:650;color:var(--ink)}
.wb-prog-now.fail{color:var(--owed-ink)}
.wb-prog-step{font-size:var(--t-xs);color:var(--ink-faint);font-weight:600;font-variant-numeric:tabular-nums}
</style>
