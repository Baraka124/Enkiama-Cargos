<script setup>
import RegionSelect from './RegionSelect.vue'
import { ref, inject, onMounted, nextTick, onBeforeUnmount } from 'vue'
import { supabase } from '../lib/supabase'
import Icon from './Icon.vue'
import Spinner from './Spinner.vue'
import MultiPhotoUpload from './MultiPhotoUpload.vue'
import { humanError } from '../lib/humanError'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

const emit = defineEmits(['close', 'submitted'])
const toast = inject('toast')

const f = ref({
  kind: 'plot', title: '', region: '', location: '', price_tzs: '', price_basis: 'total',
  size_value: '', size_unit: 'acres', description: '', images: [],
  neighbours: '', services_5km: '', has_electricity: false, has_water: false, water_potable: false,
  ownership_declared: false, contact_phone: '',
  lister_role: 'owner', owner_name: '', owner_relation: 'family', owner_contact: '', rep_note: '',
  lat: null, lng: null,
  price_negotiable: false, installments_ok: false, deposit_pct: '', installment_months: '',
})
const busy = ref(false)
const isLand = () => f.value.kind === 'plot' || f.value.kind === 'farm'

// region centres for centring the pin map (mirror of DB region_center)
const REGION_CENTERS = {
  'Arusha':[-3.3869,36.6830],'Dar es Salaam':[-6.7924,39.2083],'Dodoma':[-6.1630,35.7516],
  'Geita':[-2.8725,32.2317],'Iringa':[-7.7669,35.6997],'Kagera':[-1.3350,31.8093],
  'Katavi':[-6.4300,31.1300],'Kigoma':[-4.8769,29.6267],'Kilimanjaro':[-3.3349,37.3400],
  'Lindi':[-9.9989,39.7167],'Manyara':[-4.3150,36.9500],'Mara':[-1.7754,34.1500],
  'Mbeya':[-8.9094,33.4608],'Morogoro':[-6.8278,37.6591],'Mtwara':[-10.2692,40.1817],
  'Mwanza':[-2.5164,32.9175],'Njombe':[-9.3333,34.7667],'Pwani':[-7.0000,38.9000],
  'Rukwa':[-8.0000,31.4500],'Ruvuma':[-10.6858,35.6500],'Shinyanga':[-3.6619,33.4231],
  'Simiyu':[-2.8333,34.0000],'Singida':[-4.8161,34.7439],'Songwe':[-8.8000,32.8000],
  'Tabora':[-5.0167,32.8000],'Tanga':[-5.0689,39.0988],'Zanzibar Urban/West':[-6.1650,39.2000],
}
let pinMap = null, pinMarker = null
onMounted(async () => {
  await nextTick()
  try {
    pinMap = L.map('pinmap', { zoomControl: true, attributionControl: false }).setView([-6.4, 35.0], 5)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', { maxZoom: 19 }).addTo(pinMap)
    pinMap.on('click', (e) => dropPin(e.latlng.lat, e.latlng.lng))
    setTimeout(() => pinMap && pinMap.invalidateSize(), 200)
  } catch (e) {}
})
onBeforeUnmount(() => { if (pinMap) { pinMap.remove(); pinMap = null } })
function dropPin(lat, lng) {
  f.value.lat = lat; f.value.lng = lng
  if (pinMarker) pinMarker.setLatLng([lat, lng])
  else pinMarker = L.marker([lat, lng]).addTo(pinMap)
}
function clearPin() {
  f.value.lat = null; f.value.lng = null
  if (pinMarker) { pinMap.removeLayer(pinMarker); pinMarker = null }
}
function onRegionChange(region) {
  f.value.region = region
  const c = REGION_CENTERS[region]
  if (c && pinMap && !f.value.lat) pinMap.setView(c, 9)
}

async function submit() {
  if (!f.value.title) { toast('Give the listing a title', 'warn'); return }
  if (!f.value.images.length) { toast('Add at least one photo', 'warn'); return }
  if (f.value.lister_role === 'representative') {
    if (!f.value.owner_name) { toast("Enter the legal owner's name", 'warn'); return }
    if (!f.value.owner_contact) { toast("Enter the legal owner's contact", 'warn'); return }
  }
  if (!f.value.ownership_declared) { toast('You must accept the declaration', 'warn'); return }
  busy.value = true
  try {
    const { data } = await supabase.rpc('submit_property', {
      p_kind: f.value.kind, p_title: f.value.title, p_region: f.value.region, p_location: f.value.location,
      p_price: f.value.price_tzs ? Number(f.value.price_tzs) : null, p_price_basis: f.value.price_basis,
      p_size_value: f.value.size_value ? Number(f.value.size_value) : null, p_size_unit: f.value.size_unit,
      p_description: f.value.description || null, p_images: f.value.images,
      p_neighbours: f.value.neighbours || null, p_services_5km: f.value.services_5km || null,
      p_has_electricity: f.value.has_electricity, p_has_water: f.value.has_water, p_water_potable: f.value.water_potable,
      p_ownership_declared: f.value.ownership_declared, p_contact_phone: f.value.contact_phone || null,
      p_lister_role: f.value.lister_role, p_owner_name: f.value.owner_name || null,
      p_owner_relation: f.value.owner_relation || null, p_owner_contact: f.value.owner_contact || null,
      p_rep_note: f.value.rep_note || null,
    })
    if (data?.ok) {
      if (f.value.lat && f.value.lng && data.id) {
        try { await supabase.rpc('set_property_location', { p_id: data.id, p_lat: f.value.lat, p_lng: f.value.lng }) } catch (e) {}
      }
      if (data.id && (f.value.installments_ok || f.value.price_negotiable)) {
        try { await supabase.rpc('set_property_terms', { p_id: data.id, p_installments: f.value.installments_ok, p_deposit_pct: f.value.deposit_pct ? Number(f.value.deposit_pct) : null, p_months: f.value.installment_months ? Number(f.value.installment_months) : null, p_negotiable: f.value.price_negotiable }) } catch (e) {}
      }
      emit('submitted')
    }
    else toast(data?.error || 'Could not submit', 'warn')
  } catch (e) { toast(humanError(e), 'warn') }
  busy.value = false
}
</script>

<template>
  <div class="pf-overlay" @click.self="emit('close')">
    <div class="pf-modal">
      <div class="pf-head">
        <h2>List a property</h2>
        <button class="pf-x" @click="emit('close')"><Icon name="plus" :size="18" style="transform:rotate(45deg)" /></button>
      </div>
      <p class="pf-intro">Our team reviews every listing before it goes live. Be accurate — false listings are removed.</p>

      <div class="pf-section">Type</div>
      <div class="pf-kinds">
        <button v-for="k in [['plot','Land plot'],['farm','Farm'],['house','House / building'],['rental','Rental']]" :key="k[0]"
          class="pf-kind" :class="{on:f.kind===k[0]}" @click="f.kind=k[0]">{{ k[1] }}</button>
      </div>

      <div class="pf-section">Details</div>
      <div class="fg"><label>Title</label><input v-model="f.title" placeholder="e.g. 2-acre plot near Mbeya town" /></div>
      <div class="row2">
        <div class="fg"><label>Region</label><RegionSelect v-model="f.region" @update:modelValue="onRegionChange" /></div>
        <div class="fg"><label>Area / ward / village</label><input v-model="f.location" placeholder="Iyunga" /></div>
      </div>

      <div class="fg">
        <label>Pin the exact location <span class="fld-opt">tap the map — helps buyers find it</span></label>
        <div class="pinmap-wrap">
          <div id="pinmap" class="pinmap"></div>
          <div v-if="!f.lat" class="pinmap-hint"><Icon name="pin" :size="14" /> Tap on the map to drop a pin</div>
          <div v-else class="pinmap-set"><Icon name="check" :size="13" /> Location pinned<button type="button" @click="clearPin">clear</button></div>
        </div>
      </div>
      <div class="row2">
        <div class="fg"><label>Size</label><input v-model="f.size_value" type="number" placeholder="2" /></div>
        <div class="fg"><label>Unit</label><select v-model="f.size_unit"><option value="acres">acres</option><option value="sqm">sq m</option><option value="plots">plots</option></select></div>
      </div>
      <div class="row2">
        <div class="fg"><label>Price (TZS)</label><input v-model="f.price_tzs" type="number" placeholder="15000000" /></div>
        <div class="fg"><label>Basis</label><select v-model="f.price_basis"><option value="total">total</option><option value="per_acre">per acre</option><option value="per_month">per month (rental)</option></select></div>
      </div>

      <div class="pf-terms">
        <label class="pf-check"><input type="checkbox" v-model="f.price_negotiable" /> <span>Price is negotiable</span></label>
        <label class="pf-check"><input type="checkbox" v-model="f.installments_ok" /> <span>Payment plan / installments available</span></label>
        <div v-if="f.installments_ok" class="row2 pf-terms-detail">
          <div class="fg"><label>Deposit %</label><input v-model="f.deposit_pct" type="number" min="0" max="100" placeholder="30" /></div>
          <div class="fg"><label>Over how many months?</label><input v-model="f.installment_months" type="number" min="1" placeholder="12" /></div>
        </div>
      </div>

      <div class="fg"><label>Description</label><textarea v-model="f.description" rows="2" placeholder="Anything a buyer should know."></textarea></div>

      <div class="pf-section">Photos <span class="pf-hint">1–5 required</span></div>
      <MultiPhotoUpload v-model="f.images" :max="5" bucket="properties" />

      <template v-if="isLand()">
        <div class="pf-section">Land information</div>
        <div class="fg"><label>Neighbouring names / property types</label><input v-model="f.neighbours" placeholder="e.g. Mwangi (residential), open farmland to the north" /></div>
        <div class="fg"><label>Social services within 5&nbsp;km</label><input v-model="f.services_5km" placeholder="e.g. primary school, dispensary, market" /></div>
      </template>

      <div class="pf-section">Utilities</div>
      <label class="pf-check"><input type="checkbox" v-model="f.has_electricity" /> Electricity available</label>
      <label class="pf-check"><input type="checkbox" v-model="f.has_water" /> Water available</label>
      <label v-if="f.has_water" class="pf-check pf-indent"><input type="checkbox" v-model="f.water_potable" /> Water is potable (drinkable)</label>

      <div class="pf-section">Who is listing?</div>
      <div class="pf-kinds">
        <button class="pf-kind" :class="{on:f.lister_role==='owner'}" @click="f.lister_role='owner'">I am the owner</button>
        <button class="pf-kind" :class="{on:f.lister_role==='representative'}" @click="f.lister_role='representative'">On behalf of the owner</button>
      </div>

      <template v-if="f.lister_role==='representative'">
        <div class="pf-rep">
          <div class="fg"><label>Legal owner's full name</label><input v-model="f.owner_name" placeholder="Name on the title" /></div>
          <div class="row2">
            <div class="fg"><label>Your relationship to owner</label>
              <select v-model="f.owner_relation">
                <option value="family">Family member</option>
                <option value="individual">Authorised individual</option>
                <option value="agent">Agent / broker</option>
                <option value="company">Company representative</option>
              </select>
            </div>
            <div class="fg"><label>Owner's contact</label><input v-model="f.owner_contact" placeholder="+255…" /></div>
          </div>
          <div class="fg"><label>How are you authorised? <span class="pf-hint">optional</span></label><input v-model="f.rep_note" placeholder="e.g. power of attorney, family agreement" /></div>
        </div>
      </template>

      <div class="pf-section">Contact</div>
      <div class="fg"><label>Phone for enquiries</label><input v-model="f.contact_phone" placeholder="+255…" /></div>

      <div class="pf-declare">
        <label class="pf-check"><input type="checkbox" v-model="f.ownership_declared" />
          <span v-if="f.lister_role==='owner'">I declare that this is my property and I have the right to list it. I understand any final sale is subject to full legal verification by the buyer.</span>
          <span v-else>I declare that I am authorised to list this property on behalf of the legal owner named above. I understand the <b>final sale and all signatures must come from the legal owner (family or individual)</b>, and that the sale is subject to full legal verification by the buyer.</span>
        </label>
      </div>

      <div class="pf-actions">
        <button class="btn btn-ghost" @click="emit('close')">Cancel</button>
        <button class="btn btn-accent" style="flex:1" :disabled="busy" @click="submit">
          <Spinner v-if="busy" :size="15" /><span v-else>Submit for review</span></button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.pf-overlay{position:fixed;inset:0;background:rgba(20,24,31,.55);backdrop-filter:blur(3px);z-index:1000;display:flex;align-items:flex-start;justify-content:center;padding:30px 16px;overflow-y:auto}
.pf-modal{background:var(--surface);border-radius:18px;max-width:540px;width:100%;padding:26px;box-shadow:var(--shadow-lg)}
.pf-head{display:flex;align-items:center;justify-content:space-between}
.pf-head h2{font-family:'Space Grotesk',sans-serif;font-size:20px;font-weight:700;letter-spacing:-.02em}
.pf-x{width:34px;height:34px;border-radius:10px;border:1px solid var(--hairline-2);background:var(--surface-2);color:var(--ink-faint);cursor:pointer;display:flex;align-items:center;justify-content:center}
.pf-intro{font-size:13px;color:var(--ink-faint);margin:4px 0 6px}
.pf-section{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:var(--accent-ink);margin:20px 0 10px;padding-bottom:6px;border-bottom:1px solid var(--hairline)}
.pf-hint{font-weight:400;color:var(--ink-faint);text-transform:none;letter-spacing:0}
.pf-kinds{display:flex;gap:8px;flex-wrap:wrap}
.pf-kind{padding:9px 15px;border-radius:10px;border:1px solid var(--hairline-2);background:var(--surface-2);font-family:inherit;font-size:13px;font-weight:600;color:var(--ink-soft);cursor:pointer;transition:.15s}
.pf-kind.on{background:var(--ink);color:#fff;border-color:var(--ink)}
.pf-check{display:flex;align-items:flex-start;gap:9px;font-size:13px;color:var(--ink-soft);margin:8px 0;cursor:pointer;line-height:1.45}
.pf-check input{width:16px;height:16px;accent-color:var(--accent);margin-top:1px;flex-shrink:0}
.pf-indent{margin-left:26px}
.pf-declare{margin-top:16px;padding:14px;background:var(--accent-soft);border-radius:10px}
.pf-declare .pf-check{color:var(--accent-ink);font-weight:500;margin:0}
.pf-actions{display:flex;gap:10px;margin-top:20px}
.pf-rep{background:var(--surface-2);border:1px solid var(--hairline);border-radius:12px;padding:14px;margin-top:4px}
</style>
