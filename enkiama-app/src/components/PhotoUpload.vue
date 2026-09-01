<script setup>
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import Icon from './Icon.vue'
import Spinner from './Spinner.vue'
import { analyzeImage } from '../lib/imageQuality'

const props = defineProps({
  modelValue: { type: String, default: '' },
  kind: { type: String, default: 'photo' }, // 'logo' | 'cover' | 'photo'
})
const emit = defineEmits(['update:modelValue'])
const uploading = ref(false)
const fileInput = ref(null)
const err = ref('')
const qtip = ref(null)

function pick() { fileInput.value?.click() }

async function onFile(e) {
  const file = e.target.files?.[0]
  if (!file) return
  if (file.size > 5 * 1024 * 1024) { err.value = 'Photo must be under 5MB'; return }
  err.value = ''
  qtip.value = null
  uploading.value = true
  // context-aware quality check
  try {
    const q = await analyzeImage(file)
    if (q?.ok && !q.unknown) {
      const tips = contextTips(q)
      if (tips.length) qtip.value = { severity: worstLevel(tips), tips }
    }
  } catch (e3) {}
  try {
    const ext = (file.name.split('.').pop() || 'jpg').toLowerCase()
    const path = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`
    const { error } = await supabase.storage.from('product-photos').upload(path, file, { cacheControl: '3600', upsert: false })
    if (error) throw error
    const { data } = supabase.storage.from('product-photos').getPublicUrl(path)
    emit('update:modelValue', data.publicUrl)
  } catch (e2) {
    err.value = e2.message || 'Upload failed'
  }
  uploading.value = false
}

// tailor advice to what the image is FOR
function contextTips(q) {
  const out = []
  if (props.kind === 'logo') {
    if (q.width < 200 || q.height < 200) out.push({ level: 'warn', msg: `Logo is small (${q.width}×${q.height}px). 400×400 stays crisp.` })
    if (q.aspect > 1.4 || q.aspect < 0.7) out.push({ level: 'warn', msg: 'Logos look best square — this one may get cropped.' })
    if (q.sharpness < 60) out.push({ level: 'warn', msg: 'A bit soft — a crisp logo builds trust.' })
  } else if (props.kind === 'cover') {
    if (q.width < 900) out.push({ level: 'warn', msg: `Cover is a bit narrow (${q.width}px wide). 1200px+ looks sharp across the banner.` })
    if (q.aspect < 1.6) out.push({ level: 'warn', msg: 'Covers are wide banners — a landscape photo fills it better than a square one.' })
    if (q.brightness < 0.22) out.push({ level: 'warn', msg: 'Quite dark — a brighter cover is more inviting.' })
  } else {
    // reuse the product-photo grading already in q.issues
    for (const i of (q.issues || [])) out.push({ level: i.level, msg: i.msg })
  }
  return out
}
function worstLevel(tips) { return tips.some(t => t.level === 'poor') ? 'poor' : 'warn' }

function clear() { emit('update:modelValue', ''); if (fileInput.value) fileInput.value.value = '' }
</script>

<template>
  <div class="pu">
    <input ref="fileInput" type="file" accept="image/jpeg,image/png,image/webp" style="display:none" @change="onFile" />
    <div v-if="modelValue" class="pu-preview" :style="{backgroundImage:`url(${modelValue})`}">
      <button class="pu-remove" @click="clear" type="button"><Icon name="plus" :size="14" style="transform:rotate(45deg)" /></button>
    </div>
    <button v-else class="pu-drop" :disabled="uploading" @click="pick" type="button">
      <Spinner v-if="uploading" :size="18" />
      <template v-else><Icon name="camera" :size="20" /><span>Add photo</span></template>
    </button>
    <div v-if="err" class="pu-err">{{ err }}</div>
    <div v-if="qtip" class="pu-qtip" :class="qtip.severity">
      <div class="pu-qtip-head"><Icon name="star" :size="12" /> Photo tip</div>
      <ul><li v-for="(t,i) in qtip.tips" :key="i">{{ t.msg }}</li></ul>
    </div>
  </div>
</template>

<style scoped>
.pu{display:inline-block}
.pu-drop{width:88px;height:88px;border:2px dashed var(--hairline-2);border-radius:var(--r);background:var(--surface-2);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;cursor:pointer;color:var(--ink-faint);font-size:var(--t-xs);font-family:inherit;transition:border-color var(--dur-fast) var(--ease),color var(--dur-fast) var(--ease)}
.pu-drop:hover{border-color:var(--accent);color:var(--accent-ink)}
.pu-preview{width:88px;height:88px;border-radius:var(--r);background-size:cover;background-position:center;position:relative;border:1px solid var(--hairline)}
.pu-remove{position:absolute;top:-8px;right:-8px;width:24px;height:24px;border-radius:50%;background:var(--ink);color:#fff;border:2px solid var(--paper);display:flex;align-items:center;justify-content:center;cursor:pointer}
.pu-err{font-size:var(--t-xs);color:var(--owed-ink);margin-top:6px}

.pu-qtip{margin-top:8px;border-radius:10px;padding:10px 12px;font-size:12px}
.pu-qtip.warn{background:var(--warn-soft);color:var(--warn-ink)}
.pu-qtip.poor{background:var(--owed-soft);color:var(--owed-ink)}
.pu-qtip-head{display:flex;align-items:center;gap:5px;font-weight:700;margin-bottom:4px}
.pu-qtip ul{margin:0;padding-left:16px;line-height:1.5}
</style>
