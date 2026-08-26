<script setup>
import { ref, computed } from 'vue'
import { supabase } from '../lib/supabase'
import Icon from './Icon.vue'
import Spinner from './Spinner.vue'

const props = defineProps({
  modelValue: { type: Array, default: () => [] },
  max: { type: Number, default: 5 },
})
const emit = defineEmits(['update:modelValue'])
const uploading = ref(false)
const fileInput = ref(null)
const camInput = ref(null)
function pickCamera() { if (canAdd.value) camInput.value?.click() }
const err = ref('')

const photos = computed(() => props.modelValue || [])
const canAdd = computed(() => photos.value.length < props.max)

function pick() { if (canAdd.value) fileInput.value?.click() }

async function onFiles(e) {
  const files = Array.from(e.target.files || [])
  if (!files.length) return
  err.value = ''
  uploading.value = true
  const added = []
  for (const file of files) {
    if (photos.value.length + added.length >= props.max) break
    if (file.size > 5 * 1024 * 1024) { err.value = 'Each photo must be under 5MB'; continue }
    try {
      const ext = (file.name.split('.').pop() || 'jpg').toLowerCase()
      const path = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`
      const { error } = await supabase.storage.from('product-photos').upload(path, file, { cacheControl: '3600', upsert: false })
      if (error) throw error
      const { data } = supabase.storage.from('product-photos').getPublicUrl(path)
      added.push(data.publicUrl)
    } catch (e2) {
      err.value = e2.message || 'Upload failed'
    }
  }
  if (added.length) emit('update:modelValue', [...photos.value, ...added])
  if (fileInput.value) fileInput.value.value = ''
  uploading.value = false
}

function remove(i) {
  const next = photos.value.slice()
  next.splice(i, 1)
  emit('update:modelValue', next)
}
function makeFirst(i) {
  if (i === 0) return
  const next = photos.value.slice()
  const [img] = next.splice(i, 1)
  next.unshift(img)
  emit('update:modelValue', next)
}
</script>

<template>
  <div class="mpu">
    <input ref="fileInput" type="file" accept="image/jpeg,image/png,image/webp" multiple style="display:none" @change="onFiles" />
    <input ref="camInput" type="file" accept="image/*" capture="environment" style="display:none" @change="onFiles" />
    <div class="mpu-grid">
      <div v-for="(img,i) in photos" :key="img" class="mpu-item" :style="{backgroundImage:`url(${img})`}">
        <span v-if="i===0" class="mpu-main">Main</span>
        <div class="mpu-item-actions">
          <button v-if="i!==0" type="button" class="mpu-act" title="Make main photo" @click="makeFirst(i)"><Icon name="star" :size="12" /></button>
          <button type="button" class="mpu-act danger" title="Remove" @click="remove(i)"><Icon name="plus" :size="12" style="transform:rotate(45deg)" /></button>
        </div>
      </div>
      <div v-if="canAdd" class="mpu-add-group">
        <button type="button" class="mpu-add cam" :disabled="uploading" @click="pickCamera">
          <Spinner v-if="uploading" :size="18" />
          <template v-else><Icon name="camera" :size="20" /><span>Take photo</span></template>
        </button>
        <button type="button" class="mpu-add gallery" :disabled="uploading" @click="pick">
          <Icon name="package" :size="18" /><span>Gallery</span><small>{{ photos.length }}/{{ max }}</small>
        </button>
      </div>
    </div>
    <div v-if="err" class="mpu-err">{{ err }}</div>
    <div v-if="photos.length" class="mpu-hint">First photo is the main image customers see. Tap ★ to change which is main.</div>
  </div>
</template>

<style scoped>
.mpu-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(96px,1fr));gap:10px}
.mpu-item{position:relative;aspect-ratio:1;border-radius:12px;background-size:cover;background-position:center;background-color:var(--surface-3);border:1px solid var(--hairline);overflow:hidden}
.mpu-main{position:absolute;top:6px;left:6px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.04em;background:var(--accent);color:#fff;padding:3px 7px;border-radius:6px}
.mpu-item-actions{position:absolute;top:6px;right:6px;display:flex;gap:4px;opacity:0;transition:opacity .15s ease}
.mpu-item:hover .mpu-item-actions{opacity:1}
.mpu-act{width:24px;height:24px;border-radius:6px;border:none;background:rgba(255,255,255,.92);color:var(--ink-soft);display:flex;align-items:center;justify-content:center;cursor:pointer}
.mpu-act.danger:hover{background:var(--owed);color:#fff}
.mpu-act:hover{background:#fff;color:var(--accent)}
.mpu-add{aspect-ratio:1;border-radius:12px;border:2px dashed var(--hairline-2);background:var(--surface-2);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px;cursor:pointer;color:var(--ink-faint);font-family:inherit;font-size:12.5px;font-weight:600;transition:all .15s ease}
.mpu-add:hover:not(:disabled){border-color:var(--accent);color:var(--accent-ink);background:var(--accent-soft)}
.mpu-add small{font-size:10px;color:var(--ink-ghost);font-weight:500}
.mpu-err{font-size:12.5px;color:var(--owed-ink);margin-top:8px}
.mpu-hint{font-size:11px;color:var(--ink-faint);margin-top:10px;line-height:1.5}

.mpu-add-group{display:flex;gap:8px}
.mpu-add.cam{background:var(--accent-soft);border-color:var(--accent);color:var(--accent-ink)}
.mpu-add.cam:hover{background:var(--accent);color:#fff}
.mpu-add.gallery{background:var(--surface-2)}
</style>
