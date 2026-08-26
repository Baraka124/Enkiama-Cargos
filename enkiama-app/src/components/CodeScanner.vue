<script setup>
import { ref, onUnmounted } from 'vue'
import Icon from './Icon.vue'
import Spinner from './Spinner.vue'

const emit = defineEmits(['found', 'close'])
const busy = ref(false)
const status = ref('')
const preview = ref('')
const fileInput = ref(null)
const video = ref(null)
const cameraOn = ref(false)
const cameraError = ref('')
let stream = null
let scanLoop = null

function extractCode(text) {
  const m = (text || '').toUpperCase().match(/ENK[-\s]?(\d{3,5})/)
  return m ? 'ENK-' + m[1] : null
}

// ── LIVE CAMERA ──────────────────────────────────────────────
async function startCamera() {
  cameraError.value = ''
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: 'environment' } }, audio: false
    })
    cameraOn.value = true
    await new Promise(r => setTimeout(r, 50)) // let the <video> mount
    if (video.value) { video.value.srcObject = stream; await video.value.play() }
    // if the browser has a native BarcodeDetector, scan the live feed continuously
    if ('BarcodeDetector' in window) {
      const detector = new window.BarcodeDetector({ formats: ['qr_code','code_128','code_39','ean_13'] })
      scanLoop = setInterval(async () => {
        if (!video.value) return
        try {
          const codes = await detector.detect(video.value)
          for (const c of codes) {
            const code = extractCode(c.rawValue) || (c.rawValue?.match(/^ENK/i) ? c.rawValue.toUpperCase() : null)
            if (code) { stopCamera(); status.value = `Found ${code}`; emit('found', code); return }
          }
        } catch (e) {}
      }, 500)
    }
  } catch (err) {
    cameraError.value = 'Camera unavailable — you can upload a photo instead.'
    cameraOn.value = false
  }
}
function stopCamera() {
  if (scanLoop) { clearInterval(scanLoop); scanLoop = null }
  if (stream) { stream.getTracks().forEach(t => t.stop()); stream = null }
  cameraOn.value = false
}

// capture the current camera frame and OCR it (for text codes / no BarcodeDetector)
async function captureFrame() {
  if (!video.value) return
  busy.value = true; status.value = 'Reading the code…'
  const canvas = document.createElement('canvas')
  canvas.width = video.value.videoWidth; canvas.height = video.value.videoHeight
  canvas.getContext('2d').drawImage(video.value, 0, 0)
  preview.value = canvas.toDataURL('image/jpeg')
  try {
    const { default: Tesseract } = await import('tesseract.js')
    const { data } = await Tesseract.recognize(canvas, 'eng', {
      logger: m => { if (m.status === 'recognizing text') status.value = `Reading… ${Math.round(m.progress*100)}%` }
    })
    const code = extractCode(data.text)
    if (code) { stopCamera(); status.value = `Found ${code}`; emit('found', code) }
    else status.value = 'No code found — hold steady and try again, or type it in.'
  } catch (e) { status.value = 'Could not read it. Try again or type the code.' }
  busy.value = false
}

// ── FILE FALLBACK ────────────────────────────────────────────
function pickFile() { fileInput.value?.click() }
async function onFile(e) {
  const file = e.target.files?.[0]
  if (!file) return
  preview.value = URL.createObjectURL(file)
  busy.value = true; status.value = 'Reading the waybill…'
  try {
    const { default: Tesseract } = await import('tesseract.js')
    const { data } = await Tesseract.recognize(file, 'eng', {
      logger: m => { if (m.status === 'recognizing text') status.value = `Reading… ${Math.round(m.progress*100)}%` }
    })
    const code = extractCode(data.text)
    if (code) { status.value = `Found ${code}`; emit('found', code) }
    else status.value = 'No code found — try a clearer photo, or type it in.'
  } catch (err) { status.value = 'Could not read the photo. Type the code instead.' }
  busy.value = false
}

function close() { stopCamera(); emit('close') }
onUnmounted(stopCamera)
</script>

<template>
  <div class="overlay" @click.self="close">
    <div class="modal cs-modal">
      <div class="cs-head">
        <div><h3>Scan the waybill</h3><p>Point your camera at the parcel's code, or upload a photo.</p></div>
        <button class="cs-x" @click="close"><Icon name="plus" :size="16" style="transform:rotate(45deg)" /></button>
      </div>

      <input ref="fileInput" type="file" accept="image/*" capture="environment" style="display:none" @change="onFile" />

      <!-- live camera view -->
      <div v-if="cameraOn" class="cs-camera">
        <video ref="video" playsinline muted></video>
        <div class="cs-frame"></div>
      </div>
      <!-- captured preview -->
      <div v-else-if="preview" class="cs-preview" :style="{backgroundImage:`url(${preview})`}"></div>
      <!-- initial: start camera -->
      <button v-else class="cs-drop" @click="startCamera"><Icon name="camera" :size="28" /><span>Open camera</span></button>

      <div v-if="busy" class="cs-status"><Spinner :size="16" /> {{ status }}</div>
      <div v-else-if="status" class="cs-status done">{{ status }}</div>
      <div v-if="cameraError" class="cs-status err">{{ cameraError }}</div>

      <div class="cs-actions">
        <button v-if="cameraOn" class="btn btn-accent btn-block" :disabled="busy" @click="captureFrame">
          <Icon name="camera" :size="16" /> Capture code
        </button>
        <button class="btn btn-ghost btn-block" @click="pickFile">Upload a photo instead</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.cs-modal{max-width:420px}
.cs-head{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:16px}
.cs-head p{font-size:13px;color:var(--ink-faint);margin-top:2px}
.cs-x{width:32px;height:32px;border-radius:50%;background:var(--surface-2);border:none;display:flex;align-items:center;justify-content:center;cursor:pointer;color:var(--ink-soft);flex-shrink:0}
.cs-drop{width:100%;height:180px;border:2px dashed var(--hairline-2);border-radius:var(--r);background:var(--surface-2);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;cursor:pointer;color:var(--ink-faint);font-size:15px;font-family:inherit;font-weight:600}
.cs-drop:hover{border-color:var(--accent);color:var(--accent-ink);background:var(--accent-soft)}
.cs-camera{position:relative;width:100%;height:280px;border-radius:var(--r);overflow:hidden;background:#000}
.cs-camera video{width:100%;height:100%;object-fit:cover}
.cs-frame{position:absolute;inset:20% 12%;border:2px solid rgba(255,255,255,.9);border-radius:12px;box-shadow:0 0 0 100vmax rgba(0,0,0,.35)}
.cs-preview{width:100%;height:180px;border-radius:var(--r);background-size:cover;background-position:center}
.cs-status{display:flex;align-items:center;gap:8px;font-size:13px;color:var(--ink-soft);margin-top:12px}
.cs-status.done{color:var(--go-ink);font-weight:600}
.cs-status.err{color:var(--warn-ink)}
.cs-actions{display:flex;flex-direction:column;gap:8px;margin-top:14px}
</style>
