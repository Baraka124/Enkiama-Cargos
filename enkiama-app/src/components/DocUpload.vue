<script setup>
// Private document upload (licence, national ID). Stores into the private
// driver-docs bucket under the user's own folder (matches RLS). Keeps the
// storage PATH in the model — not a public URL — since these are sensitive.
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuth } from '../composables/useAuth'
import Icon from './Icon.vue'
import Spinner from './Spinner.vue'

const props = defineProps({ modelValue: { type: String, default: '' }, label: { type: String, default: 'Upload document' } })
const emit = defineEmits(['update:modelValue'])
const { session } = useAuth()
const fileInput = ref(null)
const uploading = ref(false)
const err = ref('')
const done = ref(false)

function pick() { fileInput.value?.click() }
async function onFile(e) {
  const file = e.target.files?.[0]
  if (!file) return
  if (file.size > 5 * 1024 * 1024) { err.value = 'File must be under 5MB'; return }
  err.value = ''; uploading.value = true
  try {
    const uid = session.value?.user?.id
    const ext = (file.name.split('.').pop() || 'jpg').toLowerCase()
    const path = `${uid}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`
    const { error } = await supabase.storage.from('driver-docs').upload(path, file, { cacheControl: '3600', upsert: false })
    if (error) throw error
    emit('update:modelValue', path)   // store the private path, not a public URL
    done.value = true
  } catch (e2) { err.value = e2.message || 'Upload failed' }
  uploading.value = false
}
function clear() { emit('update:modelValue', ''); done.value = false; if (fileInput.value) fileInput.value.value = '' }
</script>

<template>
  <div class="doc">
    <input ref="fileInput" type="file" accept="image/*" class="doc-input" @change="onFile" />
    <button v-if="!modelValue" class="doc-btn" :class="{busy:uploading}" @click="pick" :disabled="uploading">
      <Spinner v-if="uploading" :size="16" />
      <template v-else><Icon name="camera" :size="18" /> {{ label }}</template>
    </button>
    <div v-else class="doc-done">
      <span class="doc-done-l"><Icon name="check" :size="15" /> Uploaded</span>
      <button class="doc-replace" @click="clear">Replace</button>
    </div>
    <p v-if="err" class="doc-err">{{ err }}</p>
  </div>
</template>

<style scoped>
.doc-input{display:none}
.doc-btn{display:flex;align-items:center;justify-content:center;gap:8px;width:100%;padding:14px;border:1.5px dashed var(--hairline-2);border-radius:12px;background:var(--surface-2);color:var(--ink-soft);font-family:inherit;font-size:14px;font-weight:600;cursor:pointer;transition:.15s}
.doc-btn:hover{border-color:var(--accent);color:var(--accent-ink)}
.doc-done{display:flex;align-items:center;justify-content:space-between;padding:12px 14px;border:1px solid var(--go);border-radius:12px;background:var(--go-soft)}
.doc-done-l{display:flex;align-items:center;gap:7px;font-size:14px;font-weight:600;color:var(--go-ink)}
.doc-replace{background:none;border:none;font-family:inherit;font-size:13px;font-weight:600;color:var(--ink-faint);cursor:pointer}
.doc-replace:hover{color:var(--ink)}
.doc-err{font-size:12.5px;color:var(--owed-ink);margin-top:6px}
</style>
