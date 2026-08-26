<script setup>
// Visible reputation — turns the custody/delivery record into a trust signal.
import { computed } from 'vue'
import Icon from './Icon.vue'

const props = defineProps({
  rep: { type: Object, default: null },   // { tier, delivered, on_time_pct/fulfilment_pct, avg_rating, reviews }
  compact: { type: Boolean, default: false },
})

const TIERS = {
  trusted:     { label: 'Enkiama Trusted', icon: 'shield', cls: 'trusted' },
  established: { label: 'Established',      icon: 'check',  cls: 'established' },
  active:      { label: 'Active',          icon: 'route',  cls: 'active' },
  new:         { label: 'New',             icon: 'star',   cls: 'new' },
}
const tier = computed(() => TIERS[props.rep?.tier] || TIERS.new)
const pct = computed(() => props.rep?.on_time_pct ?? props.rep?.fulfilment_pct ?? null)
</script>

<template>
  <div v-if="rep" class="tb" :class="[tier.cls, {compact}]">
    <span class="tb-badge"><Icon :name="tier.icon" :size="compact ? 11 : 13" /> {{ tier.label }}</span>
    <template v-if="!compact">
      <span v-if="rep.delivered" class="tb-stat"><b>{{ rep.delivered }}</b> delivered</span>
      <span v-if="pct !== null" class="tb-stat"><b>{{ pct }}%</b> on time</span>
      <span v-if="rep.avg_rating" class="tb-stat tb-rating"><Icon name="star" :size="12" /> {{ rep.avg_rating }}<span v-if="rep.reviews" class="tb-rc"> ({{ rep.reviews }})</span></span>
    </template>
  </div>
</template>

<style scoped>
.tb{display:inline-flex;align-items:center;gap:12px;flex-wrap:wrap}
.tb-badge{display:inline-flex;align-items:center;gap:5px;font-size:12px;font-weight:700;padding:5px 11px;border-radius:999px;letter-spacing:.01em}
.tb.trusted .tb-badge{background:linear-gradient(135deg,var(--accent-soft),var(--go-soft));color:var(--accent-ink);box-shadow:inset 0 0 0 1px var(--accent)}
.tb.established .tb-badge{background:var(--go-soft);color:var(--go-ink)}
.tb.active .tb-badge{background:var(--accent-soft);color:var(--accent-ink)}
.tb.new .tb-badge{background:var(--surface-3);color:var(--ink-soft)}
.tb-stat{font-size:12.5px;color:var(--ink-faint)}
.tb-stat b{color:var(--ink);font-weight:700;font-variant-numeric:tabular-nums}
.tb-rating{display:inline-flex;align-items:center;gap:3px}
.tb-rating svg{color:#E0A82E}
.tb-rc{color:var(--ink-faint)}
.tb.compact{gap:0}
.tb.compact .tb-badge{font-size:10.5px;padding:3px 9px}
</style>
