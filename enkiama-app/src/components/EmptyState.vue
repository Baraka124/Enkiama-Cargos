<script setup>
import Icon from './Icon.vue'
defineProps({ icon: { type: String, default: 'inbox' }, title: String, hint: String })
</script>
<template>
  <div class="es">
    <div class="es-halo">
      <div class="es-ic"><Icon :name="icon" :size="28" :stroke="1.5" /></div>
    </div>
    <div class="es-title">{{ title }}</div>
    <div v-if="hint" class="es-hint">{{ hint }}</div>
    <div class="es-actions"><slot /></div>
  </div>
</template>
<style scoped>
.es{text-align:center;padding:60px 24px;animation:esIn .5s cubic-bezier(.16,1,.3,1)}
.es-halo{position:relative;width:80px;height:80px;margin:0 auto 18px;display:flex;align-items:center;justify-content:center}
.es-halo::before{content:'';position:absolute;inset:0;border-radius:50%;
  background:radial-gradient(circle, var(--accent-soft), transparent 70%);opacity:.7;animation:esPulse 3s ease-in-out infinite}
.es-ic{position:relative;width:60px;height:60px;border-radius:18px;display:flex;align-items:center;justify-content:center;
  background:linear-gradient(145deg, var(--surface), var(--surface-2));color:var(--accent);
  border:1px solid var(--hairline);box-shadow:0 4px 12px rgba(40,30,20,.06),inset 0 1px 0 rgba(255,255,255,.6)}
.es-title{font-family:'Space Grotesk',sans-serif;font-weight:650;font-size:16px;color:var(--ink);letter-spacing:-.01em}
.es-hint{font-size:13px;color:var(--ink-faint);margin-top:7px;max-width:340px;margin-left:auto;margin-right:auto;line-height:1.55}
.es-actions{margin-top:20px;display:flex;gap:10px;justify-content:center}
.es-actions:empty{display:none}
@keyframes esIn{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}
@keyframes esPulse{0%,100%{transform:scale(1);opacity:.7}50%{transform:scale(1.15);opacity:.4}}
@media(prefers-reduced-motion:reduce){.es-halo::before{animation:none}}
</style>
