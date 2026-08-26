<script setup>
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import Icon from './Icon.vue'
import Spinner from './Spinner.vue'

const props = defineProps({ modelValue: { type: String, default: '' } })
const emit = defineEmits(['update:modelValue'])
const uploading = ref(false)
const fileInput = ref(null)
const err = ref('')

function pick() { fileInput.value?.click() }

async function onFile(e) {
  const file = e.target.files?.[0]
  if (!file) return
  if (file.size > 5 * 1024 * 1024) { err.value = 'Photo must be under 5MB'; return }
  err.value = ''
  uploading.value = true
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
  </div>
</template>

<style scoped>
.pu{display:inline-block}
.pu-drop{width:88px;height:88px;border:2px dashed var(--hairline-2);border-radius:var(--r);background:var(--surface-2);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;cursor:pointer;color:var(--ink-faint);font-size:var(--t-xs);font-family:inherit;transition:border-color var(--dur-fast) var(--ease),color var(--dur-fast) var(--ease)}
.pu-drop:hover{border-color:var(--accent);color:var(--accent-ink)}
.pu-preview{width:88px;height:88px;border-radius:var(--r);background-size:cover;background-position:center;position:relative;border:1px solid var(--hairline)}
.pu-remove{position:absolute;top:-8px;right:-8px;width:24px;height:24px;border-radius:50%;background:var(--ink);color:#fff;border:2px solid var(--paper);display:flex;align-items:center;justify-content:center;cursor:pointer}
.pu-err{font-size:var(--t-xs);color:var(--owed-ink);margin-top:6px}
</style>
