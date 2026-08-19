<script setup>
// Skeleton placeholder — shows while data loads. Variants: card | row | line
defineProps({ variant: { type: String, default: 'card' }, count: { type: Number, default: 3 } })
</script>
<template>
  <div class="sk-wrap">
    <template v-if="variant==='card'">
      <div v-for="i in count" :key="i" class="sk-card">
        <div class="sk-hd"><div class="sk-b" style="width:90px;height:14px"></div><div class="sk-b" style="width:70px;height:20px;border-radius:8px"></div></div>
        <div class="sk-bd">
          <div class="sk-b" style="width:55%;height:14px"></div>
          <div class="sk-b" style="width:40%;height:12px;margin-top:8px"></div>
          <div class="sk-track"><div v-for="d in 6" :key="d" class="sk-dot"></div></div>
        </div>
      </div>
    </template>
    <template v-else-if="variant==='row'">
      <div v-for="i in count" :key="i" class="sk-row">
        <div class="sk-b sk-circle"></div>
        <div style="flex:1"><div class="sk-b" style="width:40%;height:13px"></div><div class="sk-b" style="width:60%;height:11px;margin-top:6px"></div></div>
      </div>
    </template>
    <template v-else>
      <div v-for="i in count" :key="i" class="sk-b" style="width:100%;height:14px;margin-bottom:10px"></div>
    </template>
  </div>
</template>
<style scoped>
.sk-b{background:linear-gradient(90deg,var(--surface-2) 25%,var(--hairline) 37%,var(--surface-2) 63%);
  background-size:400% 100%;animation:shimmer 1.4s ease infinite;border-radius:8px}
@keyframes shimmer{0%{background-position:100% 0}100%{background-position:-100% 0}}
.sk-card{background:var(--surface);border:1px solid var(--hairline);border-radius:var(--r-lg);margin-bottom:14px;overflow:hidden}
.sk-hd{display:flex;justify-content:space-between;align-items:center;padding:15px 18px;border-bottom:1px solid var(--hairline)}
.sk-bd{padding:16px}
.sk-track{display:flex;justify-content:space-between;margin-top:20px}
.sk-dot{width:10px;height:10px;border-radius:50%;background:var(--surface-2);animation:shimmer 1.4s ease infinite;background:linear-gradient(90deg,var(--surface-2) 25%,var(--hairline) 37%,var(--surface-2) 63%);background-size:400% 100%}
.sk-row{display:flex;align-items:center;gap:13px;padding:14px 16px;background:var(--surface);border:1px solid var(--hairline);border-radius:var(--r-lg);margin-bottom:12px}
.sk-circle{width:40px;height:40px;border-radius:50%;flex-shrink:0}
</style>
