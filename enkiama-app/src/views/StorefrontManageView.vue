<script setup>
import { ref, computed, onMounted, inject } from 'vue'
import { supabase } from '../lib/supabase'
import RegionSelect from '../components/RegionSelect.vue'
import { useRouter } from 'vue-router'
import { useStorefront } from '../composables/useStorefront'
import { useAuth } from '../composables/useAuth'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import AppHeader from '../components/AppHeader.vue'
import EmptyState from '../components/EmptyState.vue'
import PhotoUpload from '../components/PhotoUpload.vue'
import MultiPhotoUpload from '../components/MultiPhotoUpload.vue'
import CarrierMark from '../components/CarrierMark.vue'
import Skeleton from '../components/Skeleton.vue'

const router = useRouter()
const toast = inject('toast')
const { profile, signOut } = useAuth()
const sf = useStorefront()

const store = ref(null)
const tzs = (n) => 'TZS ' + (Number(n) || 0).toLocaleString()
const products = ref([])
const setupIncomplete = computed(() => products.value.length === 0 || !selectedCarrier.value)
const loading = ref(true)
const saving = ref(false)

const form = ref({ slug:'', name:'', tagline:'', about:'', region:'', delivers_to:'', phone:'', accent:'#0B6E5D', cover_url:'', logo_url:'' })
const deliversToArr = computed({
  get() { return form.value.delivers_to ? form.value.delivers_to.split(',').map(s => s.trim()).filter(Boolean) : [] },
  set(arr) { form.value.delivers_to = (arr || []).join(', ') }
})
const newProd = ref({ name:'', description:'', price_tzs:'', compare_at_tzs:'', delivery_included:false, delivery_fee_tzs:'', images:[], section_id:'', category:'' })
const categories = ref([])
async function loadCategories() { try { const { data } = await supabase.rpc('list_categories'); categories.value = data || [] } catch (e) {} }

// #10 shop verification
const showVerify = ref(false)
const verifBusy = ref(false)
const verifState = ref('unverified')  // unverified | pending | verified | rejected
const verifNote = ref('')
const verifForm = ref({ business_name: '', business_reg: '', owner_phone: '' })
async function loadVerification() {
  try { const { data } = await supabase.rpc('my_shop_verification'); if (data) { verifState.value = data.status || 'unverified'; verifNote.value = data.note || '' } } catch (e) {}
}
async function submitVerify() {
  if (!verifForm.value.business_name || !verifForm.value.owner_phone) { toast('Business name and phone are required', 'warn'); return }
  verifBusy.value = true
  try {
    const { data } = await supabase.rpc('apply_shop_verification', {
      p_business_name: verifForm.value.business_name, p_business_reg: verifForm.value.business_reg || null, p_owner_phone: verifForm.value.owner_phone })
    if (data?.ok) { showVerify.value = false; verifState.value = 'pending'; toast('Application submitted — we\'ll review it shortly', 'ok') }
    else toast(data?.error || 'Could not submit', 'warn')
  } catch (e) { toast('Could not submit', 'warn') }
  verifBusy.value = false
}
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
    form.value = { slug:data.slug, name:data.name, tagline:data.tagline||'', about:data.about||'', region:data.region||'', delivers_to:data.delivers_to||'', phone:data.phone||'', accent:data.accent||'#0B6E5D', cover_url:data.cover_url||'', logo_url:data.logo_url||'' }
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
      p_cover_url: form.value.cover_url || null, p_logo_url: form.value.logo_url || null,
    })
    if (error) throw error
    toast('Storefront saved', 'ok')
    await load()
  } catch (e) { toast(e.message || 'Could not save', 'warn') }
  saving.value = false
}
async function toggleAvailable(p) {
  const next = p.available === false
  try {
    const { data } = await supabase.rpc('set_product_available', { p_product_id: p.id, p_available: next })
    if (data?.ok) { p.available = next; toast(next ? 'Marked in stock' : 'Marked sold out', 'ok') }
  } catch (e) { toast('Could not update', 'warn') }
}
async function saveStock(p, track, qty) {
  try {
    const { data } = await supabase.rpc('set_product_stock', { p_product_id: p.id, p_track: track, p_qty: track ? (qty ?? p.stock_qty ?? 0) : null })
    if (data?.ok) {
      p.track_stock = track
      if (track) { p.stock_qty = qty ?? p.stock_qty ?? 0; p.available = p.stock_qty > 0 }
      toast(track ? 'Stock count on' : 'Back to simple in-stock', 'ok')
    }
  } catch (e) { toast('Could not update', 'warn') }
}

// product variants / options
const optProduct = ref(null)
const optDraft = ref([])
const optBusy = ref(false)
function openOptions(p) {
  optProduct.value = p
  optDraft.value = (Array.isArray(p.options) ? p.options : []).map(o => ({ name: o.name, choices: [...(o.choices||[])], newChoice: '' }))
  if (!optDraft.value.length) optDraft.value = [{ name: '', choices: [], newChoice: '' }]
}
function addChoice(opt) {
  const v = (opt.newChoice || '').trim()
  if (v && !opt.choices.includes(v)) opt.choices.push(v)
  opt.newChoice = ''
}
async function saveOptions() {
  optBusy.value = true
  const clean = optDraft.value
    .filter(o => o.name?.trim() && o.choices.length)
    .map(o => ({ name: o.name.trim(), choices: o.choices }))
  try {
    const { data } = await supabase.rpc('set_product_options', { p_product_id: optProduct.value.id, p_options: clean })
    if (data?.ok) { optProduct.value.options = clean; toast('Options saved', 'ok'); optProduct.value = null }
    else toast(data?.error || 'Could not save', 'warn')
  } catch (e) { toast('Could not save', 'warn') }
  optBusy.value = false
}

async function addProduct() {
  if (!newProd.value.name) { toast('Product name required', 'warn'); return }
  if (!store.value) { toast('Save your storefront first', 'warn'); return }
  const price = Number(newProd.value.price_tzs) || null
  const compareAt = Number(newProd.value.compare_at_tzs) || null
  if (!price) { toast('Enter a price for this product', 'warn'); return }
  // "compare at" is the original/was price — it must be higher than the selling price
  if (compareAt && compareAt <= price) {
    toast('The "compare at" price must be higher than your selling price — that\'s what shows the discount', 'warn'); return
  }
  const { error } = await sf.addProduct({
    storefront_id: store.value.id, name: newProd.value.name,
    description: newProd.value.description || null, price_tzs: price, compare_at_tzs: compareAt, delivery_included: !!newProd.value.delivery_included, delivery_fee_tzs: newProd.value.delivery_included ? null : (Number(newProd.value.delivery_fee_tzs) || null), images: newProd.value.images || [], image_url: (newProd.value.images && newProd.value.images[0]) || null, section_id: newProd.value.section_id || null, category: newProd.value.category || null,
  })
  if (error) {
    // never surface raw DB constraint text to the user
    const msg = /chk_discount_valid/.test(error.message) ? 'The "compare at" price must be higher than your selling price'
      : /violates|constraint|null value/.test(error.message) ? 'Please check the product details and try again'
      : error.message
    toast(msg, 'warn'); return
  }
  toast('Product added', 'ok')
  newProd.value = { name:"", description:"", price_tzs:"", compare_at_tzs:"", delivery_included:false, delivery_fee_tzs:"", images:[], section_id:"", category:"" }
  await load()
}
async function delProduct(id) {
  await sf.deleteProduct(id)
  toast('Product removed', 'ok'); await load()
}
async function logout() { await signOut(); router.push('/login') }

// #6 setup checklist — guide a shop to a complete, credible storefront
const setupSteps = computed(() => {
  const s = store.value
  return [
    { key:'create', label:'Create your storefront', done: !!s, hint:'Your public page on the marketplace' },
    { key:'logo', label:'Add a logo', done: !!(s?.logo_url), hint:'Shops with a logo look more trustworthy' },
    { key:'cover', label:'Add a cover image', done: !!(s?.cover_url), hint:'A banner across the top of your shop' },
    { key:'about', label:'Write a short description', done: !!(s?.about && s.about.length > 10), hint:'Tell buyers who you are' },
    { key:'carrier', label:'Choose a delivery carrier', done: !!selectedCarrier.value, hint:'Who transports your orders' },
    { key:'products', label:'Add at least 3 products', done: products.value.length >= 3, hint:`${products.value.length}/3 added`, count: products.value.length },
    { key:'photo', label:'Add photos to products', done: products.value.some(p => p.image_url || (p.images && p.images.length)), hint:'Products with photos sell far better' },
    { key:'verify', label:'Apply for verification', done: verifState.value !== 'unverified', hint:'Earn the Verified badge' },
  ]
})
const setupDone = computed(() => setupSteps.value.filter(s => s.done).length)
const setupPct = computed(() => Math.round(100 * setupDone.value / setupSteps.value.length))
const setupComplete = computed(() => setupDone.value === setupSteps.value.length)
const showChecklist = ref(true)
onMounted(async () => { await load(); await loadCarriers(); await loadSections(); await loadCategories(); await loadVerification(); selectedCarrier.value = store.value?.carrier_id })
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

      <!-- #6 setup checklist -->
      <div v-if="store && !setupComplete && showChecklist" class="setup-card">
        <div class="setup-head">
          <div>
            <div class="setup-title">Finish setting up your shop</div>
            <div class="setup-sub">{{ setupDone }} of {{ setupSteps.length }} done — complete these to build buyer trust</div>
          </div>
          <div class="setup-ring" :style="{'--p': setupPct}">{{ setupPct }}%</div>
        </div>
        <div class="setup-bar"><div class="setup-bar-fill" :style="{width: setupPct + '%'}"></div></div>
        <div class="setup-steps">
          <div v-for="st in setupSteps" :key="st.key" class="setup-step" :class="{done: st.done}">
            <span class="setup-check"><Icon :name="st.done ? 'check' : 'plus'" :size="13" /></span>
            <div class="setup-step-body"><span class="setup-step-label">{{ st.label }}</span><span class="setup-step-hint">{{ st.hint }}</span></div>
          </div>
        </div>
      </div>
      <div v-else-if="store && setupComplete" class="setup-done-banner">
        <Icon name="check" :size="16" /> Your shop is fully set up — nicely done.
      </div>

      <!-- #10 verified shop -->
      <div v-if="store" class="verif-card" :class="verifState">
        <div class="verif-ic"><Icon :name="verifState==='verified' ? 'shield' : verifState==='pending' ? 'clock' : 'shield'" :size="20" /></div>
        <div class="verif-body">
          <template v-if="verifState==='verified'">
            <b>Verified shop</b><span>Buyers see the Verified badge on your storefront — a strong trust signal.</span>
          </template>
          <template v-else-if="verifState==='pending'">
            <b>Verification under review</b><span>We're reviewing your business details. You'll get the Verified badge once approved.</span>
          </template>
          <template v-else-if="verifState==='rejected'">
            <b>Verification not approved</b><span>{{ verifNote || 'Please check your details and apply again.' }}</span>
            <button class="btn btn-accent verif-btn" @click="showVerify=true">Apply again</button>
          </template>
          <template v-else>
            <b>Become a verified shop</b><span>Verified shops earn a trust badge that makes buyers far more likely to order. Apply with your business details.</span>
            <button class="btn btn-accent verif-btn" @click="showVerify=true"><Icon name="shield" :size="14" /> Apply for verification</button>
          </template>
        </div>
      </div>

      <div class="mgr-card">
        <div class="form-section-h"><Icon name="box" :size="13" /> Shop details</div>
        <div class="row2">
          <div class="fg"><label>Handle (URL) <span class="req">*</span></label><input v-model="form.slug" :disabled="!!store" placeholder="aminas-fabrics" /><div class="field-hint">marketplace.../shop/<b>{{ form.slug || 'your-handle' }}</b></div></div>
          <div class="fg"><label>Shop name <span class="req">*</span></label><input v-model="form.name" placeholder="Amina's Fabrics" /></div>
        </div>
        <div class="sf-branding">
          <div class="sf-cover-upload" :style="form.cover_url ? {backgroundImage:`url(${form.cover_url})`} : {background:`linear-gradient(135deg, ${form.accent}, ${form.accent}99)`}">
            <div class="sf-logo-upload">
              <PhotoUpload v-model="form.logo_url" kind="logo" />
            </div>
            <div class="sf-cover-btn"><PhotoUpload v-model="form.cover_url" kind="cover" /></div>
          </div>
          <div class="sf-branding-hint">Add a cover photo and logo — this is how your shop appears on the marketplace.</div>
        </div>
        <div class="fg"><label>Tagline</label><input v-model="form.tagline" placeholder="Kitenge & kanga, delivered nationwide" /></div>
        <div class="fg"><label>About</label><input v-model="form.about" placeholder="Tell buyers about your business" /></div>
        <div class="row2">
          <div class="fg"><label>Based in</label><RegionSelect v-model="form.region" placeholder="Choose your region…" /></div>
          <div class="fg"><label>Phone</label><input v-model="form.phone" type="tel" inputmode="tel" placeholder="+255…" /></div>
        </div>
        <div class="fg"><label>Delivers to <span class="fld-opt">tap all regions you deliver to</span></label><RegionSelect v-model="deliversToArr" multiple /></div>
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
            <div v-for="p in products" :key="p.id" class="mgr-prod" :class="{soldout: p.available === false}">
              <div style="flex:1">
                <div class="mgr-prod-name">{{ p.name }}<span v-if="p.available === false" class="mgr-soldout">Sold out</span><span v-else-if="p.track_stock && p.stock_qty <= 3" class="mgr-low">Only {{ p.stock_qty }} left</span></div>
                <div v-if="p.description" class="p-sub">{{ p.description }}</div>
                <div v-if="p.options && p.options.length" class="mgr-opts-line">{{ p.options.map(o => o.name + ' (' + o.choices.length + ')').join(' · ') }}</div>
              </div>
              <div class="mgr-prod-price">{{ p.price_tzs ? 'TZS '+p.price_tzs.toLocaleString() : '—' }}</div>
              <button class="mgr-opt-btn" @click="openOptions(p)" title="Sizes, colours, variants"><Icon name="swap" :size="13" /> Options</button>
              <div class="mgr-stockbox">
                <template v-if="p.track_stock">
                  <input type="number" min="0" class="mgr-qty" :value="p.stock_qty" @change="e => saveStock(p, true, +e.target.value)" title="Units in stock" />
                  <button class="mgr-stock-off" @click="saveStock(p, false)" title="Stop counting stock">×</button>
                </template>
                <template v-else>
                  <button class="mgr-stock" :class="{on: p.available !== false}" @click="toggleAvailable(p)" :title="p.available === false ? 'Mark in stock' : 'Mark sold out'">{{ p.available === false ? 'Sold out' : 'In stock' }}</button>
                  <button class="mgr-track-btn" @click="saveStock(p, true, 10)" title="Track exact quantity">Count stock</button>
                </template>
              </div>
              <button aria-label="Close" class="btn btn-ghost" @click="delProduct(p.id)"><Icon name="plus" :size="14" style="transform:rotate(45deg)" /></button>
            </div>
          </div>
          <div class="mgr-add">
            <div class="row2">
              <div class="fg"><label>Product name</label><input v-model="newProd.name" placeholder="Kitenge — 6 yards" /></div>
              <div class="fg"><label>Price (TZS) <span class="fld-opt">what buyers pay</span></label><input v-model="newProd.price_tzs" type="number" inputmode="numeric" placeholder="45000" /></div>
            </div>
            <div class="fg"><label>Original price <span class="fld-opt">optional — shows a discount</span></label>
              <input v-model="newProd.compare_at_tzs" type="number" inputmode="numeric" placeholder="e.g. 60000 (crossed out to show the deal)" />
              <div v-if="Number(newProd.compare_at_tzs) > Number(newProd.price_tzs) && newProd.price_tzs" class="prod-save-hint">
                Buyers save {{ tzs(Number(newProd.compare_at_tzs) - Number(newProd.price_tzs)) }} ({{ Math.round((1 - Number(newProd.price_tzs)/Number(newProd.compare_at_tzs))*100) }}% off)
              </div>
              <div v-else-if="Number(newProd.compare_at_tzs) > 0 && Number(newProd.compare_at_tzs) <= Number(newProd.price_tzs) && newProd.price_tzs" class="prod-warn-hint">
                <Icon name="alert" :size="12" /> The "compare at" price should be higher than your selling price — leave it blank if there's no discount.
              </div>
            </div>
            <div class="fg"><label>Delivery</label>
              <div class="deliv-toggle">
                <button type="button" class="deliv-opt" :class="{on:newProd.delivery_included}" @click="newProd.delivery_included=true">Included in price</button>
                <button type="button" class="deliv-opt" :class="{on:!newProd.delivery_included}" @click="newProd.delivery_included=false">Charged separately</button>
              </div>
              <input v-if="!newProd.delivery_included" v-model="newProd.delivery_fee_tzs" type="number" inputmode="numeric" placeholder="Delivery fee (TZS) — leave blank if carrier quotes it" style="margin-top:8px" />
            </div>
            <div class="fg"><label>Description</label><input v-model="newProd.description" placeholder="Premium wax print" /></div>
            <div class="fg"><label>Category <span class="fld-opt">helps buyers find it</span></label>
              <select v-model="newProd.category">
                <option value="">Choose a category…</option>
                <option v-for="cat in categories" :key="cat.id" :value="cat.name">{{ cat.name }}</option>
              </select>
            </div>
            <div v-if="sections.length" class="fg"><label>Section</label>
              <select v-model="newProd.section_id">
                <option value="">No section</option>
                <option v-for="s in sections" :key="s.id" :value="s.id">{{ s.name }}</option>
              </select>
            </div>
            <div class="fg"><label>Photos <span style="color:var(--ink-faint);font-weight:400">(up to 5)</span></label><MultiPhotoUpload v-model="newProd.images" :max="5" /></div>
            <button class="btn btn-accent" @click="addProduct"><Icon name="plus" :size="15" /> Add product</button>
          </div>
        </div>
      </template>
    </template>

    <!-- product options editor -->
    <div v-if="optProduct" class="overlay" @click.self="optProduct=null">
      <div class="modal" style="max-width:480px">
        <h3>Options for {{ optProduct.name }}</h3>
        <p>Add choices like size or colour. Buyers pick one when ordering — perfect for clothing, fabric, and anything with variants.</p>
        <div v-for="(opt,oi) in optDraft" :key="oi" class="opt-group">
          <div class="opt-group-head">
            <input v-model="opt.name" class="opt-name-in" placeholder="e.g. Size" />
            <button class="opt-del" @click="optDraft.splice(oi,1)"><Icon name="plus" :size="13" style="transform:rotate(45deg)" /></button>
          </div>
          <div class="opt-choices">
            <span v-for="(ch,ci) in opt.choices" :key="ci" class="opt-choice">{{ ch }}<button @click="opt.choices.splice(ci,1)">×</button></span>
            <input v-model="opt.newChoice" class="opt-choice-in" placeholder="Add choice + Enter" @keydown.enter.prevent="addChoice(opt)" />
          </div>
        </div>
        <button class="btn btn-ghost opt-add-group" @click="optDraft.push({name:'',choices:[],newChoice:''})"><Icon name="plus" :size="14" /> Add an option group</button>
        <div class="form-actions">
          <button class="btn btn-ghost" @click="optProduct=null">Cancel</button>
          <button class="btn btn-accent" :disabled="optBusy" @click="saveOptions"><Spinner v-if="optBusy" :size="15" /><span v-else>Save options</span></button>
        </div>
      </div>
    </div>

    <!-- verification apply modal -->
    <div v-if="showVerify" class="overlay" @click.self="showVerify=false">
      <div class="modal" style="max-width:440px">
        <h3>Apply for verification</h3>
        <p>Verified shops earn a trust badge buyers look for. Tell us about your business — our team reviews each application.</p>
        <div class="fg"><label>Registered business name</label><input v-model="verifForm.business_name" placeholder="e.g. Amina Fabrics Ltd" /></div>
        <div class="fg"><label>Business registration no. <span class="fld-opt">optional</span></label><input v-model="verifForm.business_reg" placeholder="BRELA / TIN number" /></div>
        <div class="fg"><label>Owner phone</label><input v-model="verifForm.owner_phone" placeholder="+255…" /></div>
        <div class="form-actions">
          <button class="btn btn-ghost" @click="showVerify=false">Cancel</button>
          <button class="btn btn-accent" :disabled="verifBusy" @click="submitVerify"><Spinner v-if="verifBusy" :size="15" /><span v-else>Submit application</span></button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.mgr-card{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:24px;margin-bottom:18px;box-shadow:var(--shadow-sm)}
.mgr-prods{display:flex;flex-direction:column;gap:10px;margin-bottom:18px}
.mgr-prod{display:flex;align-items:center;gap:12px;background:var(--surface-2);border-radius:12px;padding:12px 14px}
.mgr-prod-name{font-weight:600;font-size:14px}
.mgr-prod-price{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:14px;white-space:nowrap}
.mgr-add{border-top:1px solid var(--hairline);padding-top:16px}

.sf-branding{margin-bottom:16px}
.sf-cover-upload{position:relative;height:130px;border-radius:14px;background-size:cover;background-position:center;overflow:visible;margin-bottom:34px}
.sf-cover-btn{position:absolute;top:10px;right:10px;width:auto}
.sf-cover-btn :deep(.pu-preview),.sf-cover-btn :deep(.pu-drop){width:auto;height:auto}
.sf-logo-upload{position:absolute;bottom:-24px;left:16px;width:64px;height:64px;border-radius:16px;border:3px solid var(--surface);background:var(--surface);box-shadow:0 4px 12px rgba(0,0,0,.15);overflow:hidden}
.sf-branding-hint{font-size:12.5px;color:var(--ink-faint);margin-top:6px;line-height:1.5}

.prod-save-hint{font-size:12.5px;color:var(--go-ink);font-weight:600;margin-top:6px}
.prod-warn-hint{display:flex;align-items:center;gap:5px;font-size:12.5px;color:var(--warn-ink);font-weight:600;margin-top:6px}
.prod-warn-hint svg{flex-shrink:0}
.deliv-toggle{display:flex;gap:8px}
.deliv-opt{flex:1;padding:11px;border:1px solid var(--hairline-2);background:var(--surface);border-radius:10px;font-family:inherit;font-size:13px;font-weight:600;color:var(--ink-soft);cursor:pointer;transition:all .15s ease}
.deliv-opt:hover{border-color:var(--ink-faint)}
.deliv-opt.on{border-color:var(--accent);background:var(--accent-soft);color:var(--accent-ink)}

@media(max-width:560px){
  .mgr-tabs{overflow-x:auto;-webkit-overflow-scrolling:touch;flex-wrap:nowrap;padding-bottom:4px}
  .mgr-tabs::-webkit-scrollbar{display:none}
  .mgr-tab{white-space:nowrap;flex-shrink:0}
  .sf-cover-upload{height:120px}
  .mgr-prod{flex-wrap:wrap;gap:8px}
  .mgr-prod-price{margin-left:auto}
  .mgr-opt-btn{font-size:11px;padding:5px 9px}
  .setup-ring-wrap{flex-direction:column;text-align:center;gap:12px}
}
</style>
