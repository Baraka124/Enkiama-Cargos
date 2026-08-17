<script setup>
import { ref, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuth } from '../composables/useAuth'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import BrandMark from '../components/BrandMark.vue'
import EmptyState from '../components/EmptyState.vue'
import Skeleton from '../components/Skeleton.vue'

const router = useRouter()
const toast = inject('toast')
const { profile, signOut } = useAuth()

const store = ref(null)
const products = ref([])
const loading = ref(true)
const saving = ref(false)

const form = ref({ slug:'', name:'', tagline:'', about:'', region:'', delivers_to:'', phone:'', accent:'#C08A2D' })
const newProd = ref({ name:'', description:'', price_tzs:'' })

async function load() {
  loading.value = true
  const { data } = await supabase.from('storefront').select('*').eq('owner_id', profile.value?.user_id).maybeSingle()
  if (data) {
    store.value = data
    form.value = { slug:data.slug, name:data.name, tagline:data.tagline||'', about:data.about||'', region:data.region||'', delivers_to:data.delivers_to||'', phone:data.phone||'', accent:data.accent||'#C08A2D' }
    const { data: prods } = await supabase.from('product').select('*').eq('storefront_id', data.id).order('created_at')
    products.value = prods || []
  }
  loading.value = false
}
async function saveStore() {
  if (!form.value.slug || !form.value.name) { toast('Handle and name are required', 'warn'); return }
  saving.value = true
  try {
    const { error } = await supabase.rpc('upsert_storefront', {
      p_slug: form.value.slug, p_name: form.value.name, p_tagline: form.value.tagline || null,
      p_about: form.value.about || null, p_region: form.value.region || null,
      p_delivers_to: form.value.delivers_to || null, p_phone: form.value.phone || null, p_accent: form.value.accent,
    })
    if (error) throw error
    toast('Storefront saved', 'ok')
    await load()
  } catch (e) { toast(e.message || 'Could not save', 'warn') }
  saving.value = false
}
async function addProduct() {
  if (!newProd.value.name) { toast('Product name required', 'warn'); return }
  if (!store.value) { toast('Save your storefront first', 'warn'); return }
  const { error } = await supabase.from('product').insert({
    storefront_id: store.value.id, name: newProd.value.name,
    description: newProd.value.description || null, price_tzs: Number(newProd.value.price_tzs) || null,
  })
  if (error) { toast(error.message, 'warn'); return }
  toast('Product added', 'ok')
  newProd.value = { name:'', description:'', price_tzs:'' }
  await load()
}
async function delProduct(id) {
  await supabase.from('product').delete().eq('id', id)
  toast('Product removed', 'ok'); await load()
}
async function logout() { await signOut(); router.push('/login') }
onMounted(load)
</script>

<template>
  <div class="topbar"><div class="inner">
    <BrandMark variant="mark" :height="32" />
    <div class="tb-idblock"><div class="tb-name">My storefront</div><div class="tb-role">Business · {{ profile?.name }}</div></div>
    <div class="tb-spacer"></div>
    <RouterLink v-if="store" :to="`/shop/${store.slug}`" class="btn btn-ghost">View public page</RouterLink>
    <button class="btn btn-ghost" style="margin-left:8px" @click="logout">Sign out</button>
  </div></div>

  <div class="wrap" style="max-width:760px">
    <Skeleton v-if="loading" variant="line" :count="6" />
    <template v-else>
      <div class="psec-head"><div><h2 class="psec-title">{{ store ? 'Edit your storefront' : 'Open your storefront' }}</h2><span class="psec-sub">Your public page on the marketplace — products shipped with tracked delivery.</span></div></div>

      <div class="mgr-card">
        <div class="form-section-h"><Icon name="box" :size="13" /> Shop details</div>
        <div class="row2">
          <div class="fg"><label>Handle (URL) <span class="req">*</span></label><input v-model="form.slug" :disabled="!!store" placeholder="aminas-fabrics" /><div class="field-hint">marketplace.../shop/<b>{{ form.slug || 'your-handle' }}</b></div></div>
          <div class="fg"><label>Shop name <span class="req">*</span></label><input v-model="form.name" placeholder="Amina's Fabrics" /></div>
        </div>
        <div class="fg"><label>Tagline</label><input v-model="form.tagline" placeholder="Kitenge & kanga, delivered nationwide" /></div>
        <div class="fg"><label>About</label><input v-model="form.about" placeholder="Tell buyers about your business" /></div>
        <div class="row2">
          <div class="fg"><label>Based in</label><input v-model="form.region" placeholder="Dar es Salaam" /></div>
          <div class="fg"><label>Phone</label><input v-model="form.phone" type="tel" inputmode="tel" placeholder="+255…" /></div>
        </div>
        <div class="fg"><label>Delivers to (corridors)</label><input v-model="form.delivers_to" placeholder="Mbeya, Arusha, Mwanza" /></div>
        <div class="fg"><label>Brand colour</label><input v-model="form.accent" type="color" style="height:44px;padding:4px;cursor:pointer;width:80px" /></div>
        <button class="btn btn-accent btn-lg" :disabled="saving" @click="saveStore"><Spinner v-if="saving" :size="15" /><span v-else>{{ store ? 'Save changes' : 'Create storefront' }}</span></button>
      </div>

      <template v-if="store">
        <div class="mgr-card">
          <div class="form-section-h"><Icon name="package" :size="13" /> Products</div>
          <EmptyState v-if="!products.length" icon="package" title="No products yet" hint="Add your first product below." />
          <div v-else class="mgr-prods">
            <div v-for="p in products" :key="p.id" class="mgr-prod">
              <div style="flex:1"><div class="mgr-prod-name">{{ p.name }}</div><div v-if="p.description" class="p-sub">{{ p.description }}</div></div>
              <div class="mgr-prod-price">{{ p.price_tzs ? 'TZS '+p.price_tzs.toLocaleString() : '—' }}</div>
              <button class="btn btn-ghost" @click="delProduct(p.id)"><Icon name="plus" :size="14" style="transform:rotate(45deg)" /></button>
            </div>
          </div>
          <div class="mgr-add">
            <div class="row2">
              <div class="fg"><label>Product name</label><input v-model="newProd.name" placeholder="Kitenge — 6 yards" /></div>
              <div class="fg"><label>Price (TZS)</label><input v-model="newProd.price_tzs" type="number" inputmode="numeric" placeholder="45000" /></div>
            </div>
            <div class="fg"><label>Description</label><input v-model="newProd.description" placeholder="Premium wax print" /></div>
            <button class="btn btn-accent" @click="addProduct"><Icon name="plus" :size="15" /> Add product</button>
          </div>
        </div>
      </template>
    </template>
  </div>
</template>

<style scoped>
.mgr-card{background:var(--surface);border:1px solid var(--hairline);border-radius:18px;padding:22px;margin-bottom:18px;box-shadow:var(--shadow-sm)}
.mgr-prods{display:flex;flex-direction:column;gap:10px;margin-bottom:18px}
.mgr-prod{display:flex;align-items:center;gap:12px;background:var(--surface-2);border-radius:11px;padding:12px 14px}
.mgr-prod-name{font-weight:600;font-size:14px}
.mgr-prod-price{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:14px;white-space:nowrap}
.mgr-add{border-top:1px solid var(--hairline);padding-top:16px}
</style>
