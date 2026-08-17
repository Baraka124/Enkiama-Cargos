<script setup>
import { ref } from 'vue'
import Icon from './Icon.vue'
import Spinner from './Spinner.vue'

const emit = defineEmits(['found', 'close'])
const busy = ref(false)
const status = ref('')
const preview = ref('')
const fileInput = ref(null)

function pick() { fileInput.value?.click() }

async function onFile(e) {
  const file = e.target.files?.[0]
  if (!file) return
  preview.value = URL.createObjectURL(file)
  busy.value = true
  status.value = 'Reading the waybill…'
  try {
    // lazy-load Tesseract only when scanning (keeps the app light)
    const { default: Tesseract } = await import('tesseract.js')
    const { data } = await Tesseract.recognize(file, 'eng', {
      logger: m => { if (m.status === 'recognizing text') status.value = `Reading… ${Math.round(m.progress*100)}%` }
    })
    const text = (data.text || '').toUpperCase()
    // find an ENK-#### style tracking code
    const match = text.match(/ENK[-\s]?(\d{3,5})/)
    if (match) {
      const code = 'ENK-' + match[1]
      status.value = `Found ${code}`
      emit('found', code)
    } else {
      status.value = 'No code found — try a clearer photo, or type it in.'
    }
  } catch (err) {
    status.value = 'Could not read the photo. Type the code instead.'
  }
  busy.value = false
}
</script>

<template>
  <div class="overlay" @click.self="emit('close')">
    <div class="modal cs-modal">
      <div class="cs-head">
        <div><h3>Scan the waybill</h3><p>Snap a photo of the parcel's code label.</p></div>
        <button class="cs-x" @click="emit('close')"><Icon name="plus" :size="16" style="transform:rotate(45deg)" /></button>
      </div>

      <input ref="fileInput" type="file" accept="image/*" capture="environment" style="display:none" @change="onFile" />

      <div v-if="preview" class="cs-preview" :style="{backgroundImage:`url(${preview})`}"></div>
      <button v-else class="cs-drop" @click="pick"><Icon name="camera" :size="28" /><span>Take a photo</span></button>

      <div v-if="busy" class="cs-status"><Spinner :size="16" /> {{ status }}</div>
      <div v-else-if="status" class="cs-status done">{{ status }}</div>

      <button v-if="preview && !busy" class="btn btn-ghost btn-block" style="margin-top:10px" @click="pick">Retake</button>
    </div>
  </div>
</template>

<style scoped>
.cs-modal{max-width:400px}
.cs-head{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:16px}
.cs-head p{font-size:var(--t-sm);color:var(--ink-faint);margin-top:2px}
.cs-x{width:32px;height:32px;border-radius:50%;background:var(--surface-2);border:none;display:flex;align-items:center;justify-content:center;cursor:pointer;color:var(--ink-soft);flex-shrink:0}
.cs-drop{width:100%;height:150px;border:2px dashed var(--hairline-2);border-radius:var(--r);background:var(--surface-2);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;cursor:pointer;color:var(--ink-faint);font-size:var(--t-base);font-family:inherit}
.cs-drop:hover{border-color:var(--accent);color:var(--accent-ink)}
.cs-preview{width:100%;height:150px;border-radius:var(--r);background-size:cover;background-position:center}
.cs-status{display:flex;align-items:center;gap:8px;font-size:var(--t-sm);color:var(--ink-soft);margin-top:12px}
.cs-status.done{color:var(--go-ink);font-weight:600}
</style>
