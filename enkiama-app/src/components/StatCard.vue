<script setup>
import Icon from './Icon.vue'
defineProps({
  label: String,
  value: [String, Number],
  icon: String,
  tone: { type: String, default: 'default' }, // default | accent | go | owed | warn | muted
  alert: Boolean,
})
</script>
<template>
  <div class="statcard card" :class="{ alert }">
    <span v-if="icon" class="statcard-ic" :class="tone"><Icon :name="icon" :size="18" /></span>
    <div class="statcard-body">
      <div class="statcard-l">{{ label }}</div>
      <div class="statcard-v" :class="{ 'owed-ink': tone==='owed', 'go-ink': tone==='go' }">{{ value }}</div>
    </div>
  </div>
</template>
