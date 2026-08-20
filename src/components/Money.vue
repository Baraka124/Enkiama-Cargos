<script setup>
// Renders money the way premium fintech does: currency symbol set lighter and
// smaller than the value, value in tabular figures. "TZS 45,000" → muted TZS + bold 45,000.
defineProps({
  amount: { type: [Number, String], default: 0 },
  currency: { type: String, default: 'TZS' },
  size: { type: String, default: '' }, // '', 'lg', 'xl' for emphasis
})
</script>

<template>
  <span class="money" :class="size ? 'money--'+size : ''">
    <span class="money-cur">{{ currency }}</span><span class="money-val">{{ Number(amount || 0).toLocaleString() }}</span>
  </span>
</template>

<style scoped>
.money{display:inline-flex;align-items:baseline;gap:4px;font-family:'Space Grotesk',sans-serif;font-variant-numeric:tabular-nums;font-feature-settings:'tnum' 1;white-space:nowrap}
.money-cur{font-size:.72em;font-weight:600;color:var(--ink-faint);letter-spacing:.02em}
.money-val{font-weight:700;color:inherit;letter-spacing:-.01em}
.money--lg{font-size:20px}
.money--xl{font-size:28px}
</style>
