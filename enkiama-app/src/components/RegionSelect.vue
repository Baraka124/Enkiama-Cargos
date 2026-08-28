<script setup>
// Reusable Tanzania region picker. Single select by default; multi-select for
// "delivers to" style fields where a shop serves several regions.
import { computed } from 'vue'
import { TZ_REGIONS } from '../lib/regions'

const props = defineProps({
  modelValue: { type: [String, Array], default: '' },
  multiple: { type: Boolean, default: false },
  placeholder: { type: String, default: 'Choose a region…' },
})
const emit = defineEmits(['update:modelValue'])

const selected = computed(() => {
  if (props.multiple) return Array.isArray(props.modelValue) ? props.modelValue
    : (props.modelValue ? String(props.modelValue).split(',').map(s => s.trim()).filter(Boolean) : [])
  return props.modelValue
})

function onSingle(e) { emit('update:modelValue', e.target.value) }
function toggle(region) {
  const cur = [...selected.value]
  const i = cur.indexOf(region)
  if (i >= 0) cur.splice(i, 1); else cur.push(region)
  emit('update:modelValue', cur)
}
</script>

<template>
  <select v-if="!multiple" :value="selected" @change="onSingle" class="region-select">
    <option value="">{{ placeholder }}</option>
    <option v-for="r in TZ_REGIONS" :key="r" :value="r">{{ r }}</option>
  </select>

  <div v-else class="region-multi">
    <button v-for="r in TZ_REGIONS" :key="r" type="button" class="region-chip"
      :class="{on: selected.includes(r)}" @click="toggle(r)">{{ r }}</button>
  </div>
</template>

<style scoped>
.region-multi{display:flex;flex-wrap:wrap;gap:7px;max-height:180px;overflow-y:auto;padding:4px 2px}
.region-chip{font-size:12.5px;font-weight:600;padding:6px 12px;border-radius:999px;border:1px solid var(--hairline-2);background:var(--surface);color:var(--ink-soft);cursor:pointer;font-family:inherit;transition:.12s}
.region-chip:hover{border-color:var(--accent)}
.region-chip.on{background:var(--accent-soft);border-color:var(--accent);color:var(--accent-ink)}
</style>
