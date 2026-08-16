<script setup>
import { ref, computed, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { useConsignments } from '../composables/useConsignments'
import { supabase, fmtTZS } from '../lib/supabase'
import ConsignmentCard from '../components/ConsignmentCard.vue'
import CarrierMark from '../components/CarrierMark.vue'
import Icon from '../components/Icon.vue'

const STAGE_LABELS = { booked:'Booked', collected:'Collected', linehaul:'On road', with_driver:'With driver', delivered:'Delivered', confirmed:'Confirmed', failed:'Failed', cancelled:'Cancelled' }
function stageLabel(s) { return STAGE_LABELS[s] || s }
function stageClass(s) { return ['delivered','confirmed'].includes(s) ? 'go' : s==='failed' ? 'owed' : 'accent' }
import EmptyState from '../components/EmptyState.vue'

const router = useRouter()
const toast = inject('toast')
const { profile, signOut } = useAuth()
const { consignments, fetchAll, subscribe, unsubscribe, book } = useConsignments()

const tab = ref('send')
const carriers = ref([])
const busy = ref(false)
const lastCode = ref('')

const f = ref({
  carrierId: '', receiver: '', receiverPhone: '', addr: '', item: '', weight: 1,
  mode: 'prepaid', cod: 0, fee: 0,
})

onMounted(async () => {
  const { data } = await supabase.from('carrier').select('*').eq('status','active').order('name')
  carriers.value = data || []
  if (carriers.value.length) f.value.carrierId = carriers.value[0].id
  await loadMyShipments()
})
const myParcels = ref([])
async function loadMyShipments() {
  // sender's own parcels across ALL carriers (RLS: sender_user_id = auth.uid())
  const { data } = await supabase.from('consignment')
    .select('*, payment(*), driver(name,vehicle), carrier(name,accent,slug,mark)')
    .order('created_at', { ascending: false })
  myParcels.value = (data || []).map(shapeSender)
}
function shapeSender(row) {
  const pay = Array.isArray(row.payment) ? (row.payment[0]||{}) : (row.payment||{})
  const car = Array.isArray(row.carrier) ? (row.carrier[0]||{}) : (row.carrier||{})
  return {
    id: row.id, code: row.code, stage: row.stage,
    receiver: row.receiver_name, receiverPhone: row.receiver_phone, addr: row.dest_address,
    item: row.item, weight: Number(row.weight_kg),
    carrierName: car.name, carrierAccent: car.accent, carrierSlug: car.slug, carrierMark: car.mark,
    payMode: pay.mode, payState: pay.state, cod: pay.cod_amount || 0,
  }
}

async function submit() {
  if (!f.value.carrierId) { toast('Pick a carrier', 'warn'); return }
  if (!f.value.receiver || !f.value.receiverPhone) { toast('Receiver name and phone required', 'warn'); return }
  busy.value = true
  try {
    const { data: code, error } = await supabase.rpc('sender_book', {
      p_carrier_id: f.value.carrierId,
      p_receiver: f.value.receiver, p_receiver_ph: f.value.receiverPhone,
      p_addr: f.value.addr, p_item: f.value.item, p_weight: Number(f.value.weight) || 1,
      p_mode: f.value.mode, p_cod: Number(f.value.cod) || 0, p_fee: Number(f.value.fee) || 0,
    })
    if (error) throw error
    lastCode.value = code
    toast(`Booked — code ${code}`, 'ok')
    f.value.receiver = ''; f.value.receiverPhone = ''; f.value.addr = ''; f.value.item = ''
    await loadMyShipments()
    tab.value = 'mine'
  } catch (e) { toast(e.message || 'Booking failed', 'warn') }
  busy.value = false
}
async function logout() { await signOut(); router.push('/login') }
</script>

<template>
  <div class="topbar"><div class="inner">
    <div class="tb-mark" style="background:linear-gradient(135deg,#EAE7DE,#B4AE9E);color:#0A0C10">EN</div>
    <div><div class="tb-name">Enkiama Cargos</div><div class="tb-role">Sender · {{ profile?.name }}</div></div>
    <div class="tb-spacer"></div>
    <RouterLink to="/my-shop" class="btn btn-ghost"><Icon name="box" :size="15" /> My storefront</RouterLink>
    <button class="btn btn-ghost" style="margin-left:8px" @click="logout">Sign out</button>
  </div></div>

  <div class="wrap" style="max-width:720px">
    <div class="dtabs">
      <button class="dtab" :class="{on:tab==='send'}" @click="tab='send'">Send a parcel</button>
      <button class="dtab" :class="{on:tab==='mine'}" @click="tab='mine'">My parcels <span class="tb-count">{{ myParcels.length }}</span></button>
    </div>

    <!-- SEND -->
    <div v-if="tab==='send'">
      <div class="panel">
        <h2>Send a parcel</h2>
        <div class="sub">Choose a carrier to move it, tell us who receives it, and you'll get a tracking code to share.</div>

        <div class="fg"><label>Carrier</label>
          <select v-model="f.carrierId">
            <option v-for="c in carriers" :key="c.id" :value="c.id">{{ c.name }} — {{ c.region }}</option>
          </select>
        </div>

        <div class="row2">
          <div class="fg"><label>Receiver name</label><input v-model="f.receiver" placeholder="Grace Mwangi" /></div>
          <div class="fg"><label>Receiver phone</label><input v-model="f.receiverPhone" type="tel" inputmode="tel" placeholder="+255 712 345 678" /></div>
        </div>
        <div class="fg"><label>Delivery address</label><input v-model="f.addr" placeholder="Mikocheni, Dar es Salaam" /></div>
        <div class="row2">
          <div class="fg"><label>What's inside</label><input v-model="f.item" placeholder="Documents" /></div>
          <div class="fg"><label>Weight (kg)</label><input v-model="f.weight" type="number" inputmode="decimal" min="0" step="0.5" /></div>
        </div>

        <div class="fg"><label>Payment</label>
          <select v-model="f.mode">
            <option value="prepaid">Prepaid — I've paid for the goods</option>
            <option value="cod">Cash on delivery — receiver pays</option>
            <option value="feeonly">Goods free — just the delivery fee</option>
          </select>
        </div>
        <div class="row2">
          <div class="fg" v-if="f.mode==='cod'"><label>Cash to collect (TZS)</label><input v-model="f.cod" type="number" inputmode="numeric" min="0" /></div>
          <div class="fg"><label>Delivery fee (TZS)</label><input v-model="f.fee" type="number" inputmode="numeric" min="0" /></div>
        </div>

        <button class="btn btn-accent btn-block btn-lg" :disabled="busy" @click="submit">Book &amp; get tracking code</button>
      </div>

      <div v-if="lastCode" class="panel" style="border-color:var(--go)">
        <h2>Booked — {{ lastCode }}</h2>
        <div class="sub">Share this code with your receiver, or send them the tracking link:</div>
        <div class="mono" style="word-break:break-all;color:var(--accent-hi)">{{ location.origin }}/#/track/{{ lastCode }}</div>
      </div>
    </div>

    <!-- MINE -->
    <div v-else>
      <EmptyState v-if="!myParcels.length" icon="inbox" title="No parcels yet" hint="Book one and track it here, live — across any carrier." />
      <div v-else class="ship-list">
        <router-link v-for="p in myParcels" :key="p.id" :to="`/track/${p.code}`" class="ship-card">
          <div class="ship-top">
            <span class="ship-code mono">{{ p.code }}</span>
            <span class="ship-stage" :class="stageClass(p.stage)">{{ stageLabel(p.stage) }}</span>
          </div>
          <div class="ship-to">To {{ p.receiver }} · {{ p.addr }}</div>
          <div class="ship-foot">
            <span class="ship-carrier"><CarrierMark :slug="p.carrierSlug" :mark="p.carrierMark" :name="p.carrierName" :accent="p.carrierAccent" :size="22" /> {{ p.carrierName }}</span>
            <span v-if="p.payMode==='cash' && p.cod" class="ship-cod">TZS {{ p.cod.toLocaleString() }} COD</span>
          </div>
        </router-link>
      </div>
    </div>
  </div>
</template>
