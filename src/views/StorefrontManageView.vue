<script setup>
import { ref, computed, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useStorefront } from '../composables/useStorefront'
import { useAuth } from '../composables/useAuth'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import AppHeader from '../components/AppHeader.vue'
import EmptyState from '../components/EmptyState.vue'
import PhotoUpload from '../components/PhotoUpload.vue'
import CarrierMark from '../components/CarrierMark.vue'
import Skeleton from '../components/Skeleton.vue'

const router = useRouter()
const toast = inject('toast')
const { profile, signOut } = useAuth()
const sf = useStorefront()

const store = ref(null)
const products = ref([])
const setupIncomplete = computed(() => products.value.length === 0 || !selectedCarrier.value)
const loading = ref(true)
const saving = ref(false)

const form = ref({ slug:'', name:'', tagline:'', about:'', region:'', delivers_to:'', phone:'', accent:'#4338CA' })
const newProd = ref({ name:'', description:'', price_tzs:'', image_url:'', section_id:'', category:'' })
const sections = ref([])
const newSection = ref('')
async function loadSections() {
  if (!store.value?.id) return
  const { data } = await sf.listSections(store.value.id)
  sections.value = data || []
}
async function addSection() {
  if (!newSection.value.trim()) return
  try {
    const { error } = await sf.addSection(store.value.id, newSection.value.trim(), sections.value.length)
    if (error) throw error
    newSection.value = ''; await loadSections()
    toast('Section added', 'ok')
  } catch (e) { toast(e.message || 'Could not add section', 'warn') }
}
async function removeSection(s) {
  try {
    await sf.deleteSection(s.id)
    await loadSections(); await loadProducts?.()
    toast('Section removed', 'ok')
  } catch (e) { toast(e.message || 'Could not remove', 'warn') }
}
const carriers = ref([])
const selectedCarrier = ref(null)
async function loadCarriers() {
  const { data } = await sf.activeCarriers()
  carriers.value = data || []
}
async function pickCarrier(c) {
  try {
    const { error } = await sf.selectCarrier(store.value.slug, c.id)
    if (error) throw error
    selectedCarrier.value = c.id
    toast(`${c.name} will deliver your orders — they've been notified`, 'ok')
  } catch (e) { toast(e.message || 'Could not select carrier', 'warn') }
}

async function load() {
  loading.value = true
  const { data } = await sf.myStore(profile.value?.user_id)
  if (data) {
    store.value = data
    form.value = { slug:data.slug, name:data.name, tagline:data.tagline||'', about:data.about||'', region:data.region||'', delivers_to:data.delivers_to||'', phone:data.phone||'', accent:data.accent||'#4338CA' }
    const { data: prods } = await sf.listProducts(data.id)
    products.value = prods || []
  }
  loading.value = false
}
async function saveStore() {
  if (!form.value.slug || !form.value.name) { toast('Handle and name are required', 'warn'); return }
  saving.value = true
  try {
    const { error } = await sf.upsertStore({
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
  const { error } = await sf.addProduct({
    storefront_id: store.value.id, name: newProd.value.name,
    description: newProd.value.description || null, price_tzs: Number(newProd.value.price_tzs) || null, image_url: newProd.value.image_url || null, section_id: newProd.value.section_id || null, category: newProd.value.category || null,
  })
  if (error) { toast(error.message, 'warn'); return }
  toast('Product added', 'ok')
  newProd.value = { name:"", description:"", price_tzs:"", image_url:"", section_id:"", category:"" }
  await load()
}
async function delProduct(id) {
  await sf.deleteProduct(id)
  toast('Product removed', 'ok'); await load()
}
async function logout() { await signOut(); router.push('/login') }
onMounted(async () => { await load(); await loadCarriers(); await loadSections(); selectedCarrier.value = store.value?.carrier_id })
</script>

<template>
  <AppHeader title="My storefront" :subtitle="'Business · ' + (profile?.name || '')">
    <RouterLink v-if="store" :to="`/shop/${store.slug}`" class="btn btn-ghost">View public page</RouterLink>
    <button class="btn btn-ghost" style="margin-left:8px" @click="logout">Sign out</button>
  </AppHeader>

  <div class="wrap" style="max-width:760px">
    <Skeleton v-if="loading" variant="line" :count="6" />
    <template v-else>
      <!-- FIRST-RUN WELCOME — only for a brand-new business with no shop yet -->
      <div v-if="!store" class="biz-welcome">
        <div class="biz-welcome-badge"><Icon name="box" :size="22" /></div>
        <h1>Welcome to Enkiama Cargos</h1>
        <p>Let's get your shop live. In three steps you'll be selling with tracked delivery built in — every order ships through a real carrier and both you and your buyer follow it end to end.</p>
        <div class="biz-steps">
          <div class="biz-step"><span class="biz-step-n">1</span><div><b>Open your shop</b><span>Name, handle, and what you sell — just below.</span></div></div>
          <div class="biz-step"><span class="biz-step-n">2</span><div><b>Add products &amp; a carrier</b><span>List items with photos, pick who delivers.</span></div></div>
          <div class="biz-step"><span class="biz-step-n">3</span><div><b>Share your shop link</b><span>Buyers order, orders ship tracked.</span></div></div>
        </div>
      </div>

      <!-- SETUP PROGRESS — once a shop exists, show what's left to do -->
      <div v-else-if="setupIncomplete" class="biz-progress">
        <div class="biz-progress-h"><Icon name="check" :size="14" /> Finish setting up your shop</div>
        <div class="biz-checks">
          <span class="biz-check done"><Icon name="check" :size="13" /> Shop created</span>
          <span class="biz-check" :class="{done: products.length>0}"><Icon name="check" :size="13" /> {{ products.length>0 ? 'Products added' : 'Add your first product' }}</span>
          <span class="biz-check" :class="{done: !!selectedCarrier}"><Icon name="check" :size="13" /> {{ selectedCarrier ? 'Carrier chosen' : 'Choose a carrier' }}</span>
        </div>
      </div>

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
          <div class="form-section-h"><Icon name="truck" :size="13" /> Who delivers your orders</div>
          <p class="mgr-hint">Pick the carrier that ships your goods. They'll be notified you chose them. Always powered by Enkiama Cargos.</p>
          <div class="carrier-pick">
            <button v-for="c in carriers" :key="c.id" class="carrier-opt" :class="{on:selectedCarrier===c.id}" @click="pickCarrier(c)">
              <CarrierMark :slug="c.slug" :mark="c.mark" :name="c.name" :accent="c.accent" :size="30" />
              <div class="carrier-opt-info"><div class="carrier-opt-name">{{ c.name }}</div><div class="carrier-opt-region">{{ c.region || '—' }}</div></div>
              <Icon v-if="selectedCarrier===c.id" name="check" :size="16" class="carrier-opt-check" />
            </button>
          </div>
        </div>

        <div class="mgr-card">
          <div class="form-section-h"><Icon name="grid" :size="13" /> Shop sections</div>
          <p class="mgr-hint">Organise your shop into named sections — like "New Arrivals" or "Wedding Fabrics".</p>
          <div v-if="sections.length" class="section-chips">
            <span v-for="s in sections" :key="s.id" class="section-chip">{{ s.name }}<button aria-label="Close" @click="removeSection(s)"><Icon name="plus" :size="11" style="transform:rotate(45deg)" /></button></span>
          </div>
          <div class="section-add">
            <input v-model="newSection" placeholder="New section name…" @keyup.enter="addSection" />
            <button class="btn btn-ghost" @click="addSection">Add section</button>
          </div>
        </div>

        <div class="mgr-card">
          <div class="form-section-h"><Icon name="package" :size="13" /> Products</div>
          <EmptyState v-if="!products.length" icon="package" title="No products yet" hint="Add your first product below." />
          <div v-else class="mgr-prods">
            <div v-for="p in products" :key="p.id" class="mgr-prod">
              <div style="flex:1"><div class="mgr-prod-name">{{ p.name }}</div><div v-if="p.description" class="p-sub">{{ p.description }}</div></div>
              <div class="mgr-prod-price">{{ p.price_tzs ? 'TZS '+p.price_tzs.toLocaleString() : '—' }}</div>
              <button aria-label="Close" class="btn btn-ghost" @click="delProduct(p.id)"><Icon name="plus" :size="14" style="transform:rotate(45deg)" /></button>
            </div>
          </div>
          <div class="mgr-add">
            <div class="row2">
              <div class="fg"><label>Product name</label><input v-model="newProd.name" placeholder="Kitenge — 6 yards" /></div>
              <div class="fg"><label>Price (TZS)</label><input v-model="newProd.price_tzs" type="number" inputmode="numeric" placeholder="45000" /></div>
            </div>
            <div class="fg"><label>Description</label><input v-model="newProd.description" placeholder="Premium wax print" /></div>
            <div class="fg"><label>Category <span class="fld-opt">helps buyers find it</span></label><input v-model="newProd.category" list="cat-suggestions" placeholder="e.g. Fabric, Electronics, Food" /><datalist id="cat-suggestions"><option>Fabric</option><option>Electronics</option><option>Food &amp; Spices</option><option>Beauty</option><option>Home</option><option>Clothing</option><option>Accessories</option></datalist></div>
            <div v-if="sections.length" class="fg"><label>Section</label>
              <select v-model="newProd.section_id">
                <option value="">No section</option>
                <option v-for="s in sections" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
            </div>
            <div class="fg"><label>Photo</label><PhotoUpload v-model="newProd.image_url" /></div>
            <button class="btn btn-accent" @click="addProduct"><Icon name="plus" :size="15" /> Add product</button>
          </div>
        </div>
      </template>
    </template>
  </div>
</template>

<style scoped>
.mgr-card{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:24px;margin-bottom:18px;box-shadow:var(--shadow-sm)}
.mgr-prods{display:flex;flex-direction:column;gap:10px;margin-bottom:18px}
.mgr-prod{display:flex;align-items:center;gap:12px;background:var(--surface-2);border-radius:12px;padding:12px 14px}
.mgr-prod-name{font-weight:600;font-size:14px}
.mgr-prod-price{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:14px;white-space:nowrap}
.mgr-add{border-top:1px solid var(--hairline);padding-top:16px}
</style>
