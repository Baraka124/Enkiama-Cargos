<script setup>
import Icon from './Icon.vue'
defineProps({ icon: { type: String, default: 'inbox' }, title: String, hint: String })
</script>
<template>
  <div class="es">
    <div class="es-ic"><Icon :name="icon" :size="26" :stroke="1.4" /></div>
    <div class="es-title">{{ title }}</div>
    <div v-if="hint" class="es-hint">{{ hint }}</div>
    <div class="es-actions"><slot /></div>
  </div>
</template>
<style scoped>
.es{text-align:center;padding:56px 24px;animation:esIn .5s cubic-bezier(.16,1,.3,1)}
.es-ic{width:60px;height:60px;border-radius:16px;margin:0 auto 16px;display:flex;align-items:center;justify-content:center;
  background:var(--surface-2);color:var(--ink-faint);border:1px solid var(--hairline)}
.es-title{font-family:'Space Grotesk',sans-serif;font-weight:600;font-size:16px;color:var(--ink-soft)}
.es-hint{font-size:13px;color:var(--ink-faint);margin-top:6px;max-width:320px;margin-left:auto;margin-right:auto;line-height:1.5}
.es-actions{margin-top:18px;display:flex;gap:10px;justify-content:center}
.es-actions:empty{display:none}
@keyframes esIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
</style>
