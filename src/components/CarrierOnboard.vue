<script setup>
import { ref } from 'vue'
import Icon from './Icon.vue'
import Spinner from './Spinner.vue'
import BrandMark from './BrandMark.vue'
const props = defineProps({ carrier: Object })
const emit = defineEmits(['done', 'add-driver', 'book'])
const step = ref(0)
const steps = [
  { icon:'truck', title:'Welcome to Enkiama Cargos', body:"Your carrier is live. Let's get you moving in three quick steps — add a driver, book your first parcel, and you're operating." },
  { icon:'bike', title:'Add your first driver', body:'Drivers carry parcels the last mile and collect cash on delivery. You can add more anytime from the Team tab.' },
  { icon:'package', title:'Book your first parcel', body:'Booking creates a tracked consignment with a code you can share. Cash-on-delivery, prepaid, or fee-only — all handled.' },
  { icon:'check', title:"You're ready to operate", body:'That\'s the core loop. Everything else — cash reconciliation, customers, your team — is in the tabs above. Welcome aboard.' },
]
function next() { if (step.value < steps.length - 1) step.value++; else emit('done') }
function skip() { emit('done') }
function act() {
  if (step.value === 1) emit('add-driver')
  else if (step.value === 2) emit('book')
  next()
}
</script>

<template>
  <div class="ob-scrim">
    <div class="ob-card">
      <div class="ob-progress"><div v-for="(s,i) in steps" :key="i" class="ob-dot" :class="{on:i<=step}"></div></div>
      <div class="ob-ic"><Icon :name="steps[step].icon" :size="30" /></div>
      <h2 class="ob-title">{{ steps[step].title }}</h2>
      <p class="ob-body">{{ steps[step].body }}</p>
      <div class="ob-actions">
        <button v-if="step===0" class="btn btn-accent btn-block btn-lg" @click="next">Let's go <Icon name="arrow" :size="16" /></button>
        <template v-else-if="step===1 || step===2">
          <button class="btn btn-accent btn-block btn-lg" @click="act">
            {{ step===1 ? 'Add a driver' : 'Book a parcel' }} <Icon name="arrow" :size="16" />
          </button>
          <button class="btn btn-ghost btn-block" @click="next">Skip for now</button>
        </template>
        <button v-else class="btn btn-accent btn-block btn-lg" @click="emit('done')">Start operating</button>
      </div>
      <button v-if="step<3" class="ob-skip" @click="skip">Skip setup</button>
    </div>
  </div>
</template>

<style scoped>
.ob-scrim{position:fixed;inset:0;z-index:2000;background:rgba(26,29,33,.5);backdrop-filter:blur(6px);display:flex;align-items:center;justify-content:center;padding:20px}
.ob-card{background:var(--paper);border-radius:20px;padding:36px 30px;max-width:440px;width:100%;text-align:center;box-shadow:var(--shadow-lg);animation:obRise .4s cubic-bezier(.16,1,.3,1)}
@keyframes obRise{from{transform:translateY(16px) scale(.98);opacity:0}to{transform:none;opacity:1}}
.ob-progress{display:flex;gap:7px;justify-content:center;margin-bottom:26px}
.ob-dot{width:34px;height:5px;border-radius:8px;background:var(--hairline);transition:.3s}
.ob-dot.on{background:var(--accent)}
.ob-ic{width:70px;height:70px;border-radius:16px;background:var(--accent-soft);color:var(--accent-ink);display:flex;align-items:center;justify-content:center;margin:0 auto 22px}
.ob-title{font-family:'Space Grotesk',sans-serif;font-size:22px;font-weight:700;margin-bottom:12px;color:var(--ink)}
.ob-body{font-size:14.5px;color:var(--ink-soft);line-height:1.65;margin-bottom:26px}
.ob-actions{display:flex;flex-direction:column;gap:10px}
.ob-skip{margin-top:16px;background:none;border:none;color:var(--ink-faint);font-size:13px;cursor:pointer;font-family:inherit}
.ob-skip:hover{color:var(--ink-soft)}
</style>
