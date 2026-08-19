<script setup>
import { ref, computed, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { useConsignments } from '../composables/useConsignments'
import { fmtTZS } from '../lib/supabase'
import { usePublic } from '../composables/usePublic'
import ConsignmentCard from '../components/ConsignmentCard.vue'
import CarrierMark from '../components/CarrierMark.vue'
import Icon from '../components/Icon.vue'
import AppHeader from '../components/AppHeader.vue'

const STAGE_LABELS = { booked:'Booked', collected:'Collected', linehaul:'On road', with_driver:'With driver', delivered:'Delivered', confirmed:'Confirmed', failed:'Failed', cancelled:'Cancelled' }
function stageLabel(s) { return STAGE_LABELS[s] || s }
function stageClass(s) { return ['delivered','confirmed'].includes(s) ? 'go' : s==='failed' ? 'owed' : 'accent' }
import EmptyState from '../components/EmptyState.vue'

const router = useRouter()
const toast = inject('toast')
const { profile, signOut } = useAuth()
const { consignments, fetchAll, subscribe, unsubscribe, book } = useConsignments()

const tab = ref('overview')
const carriers = ref([])
const busy = ref(false)
const pub = usePublic()
const lastCode = ref('')
const shopData = ref(null)

async function loadShopOrders() {
  try { const { data } = await pub.myShopOrders(); shopData.value = data } catch (e) {}
}

const f = ref({
  carrierId: '', receiver: '', receiverPhone: '', addr: '', item: '', weight: 1,
  mode: 'prepaid', cod: 0, fee: 0,
})

onMounted(async () => {
  const { data } = await pub.activeCarriers()
  carriers.value = data || []
  if (carriers.value.length) f.value.carrierId = carriers.value[0].id
  await loadMyShipments()
  await loadShopOrders()
})
const myParcels = ref([])
async function loadMyShipments() {
  // sender's own parcels across ALL carriers (RLS: sender_user_id = auth.uid())
  const { data } = await pub.mySenderShipments()
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
    const { data: code, error } = await pub.senderBook({
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
  <AppHeader title="My business" :subtitle="profile?.name || ''">
    <RouterLink to="/my-shop" class="btn btn-accent">My storefront</RouterLink>
    <button class="btn btn-ghost" style="margin-left:8px" @click="logout">Sign out</button>
  </AppHeader>

  <div class="wrap" style="max-width:820px">
    <div class="dtabs">
      <button class="dtab" :class="{on:tab==='overview'}" @click="tab='overview'">Overview</button>
      <button class="dtab" :class="{on:tab==='orders'}" @click="tab='orders'">Orders <span v-if="shopData?.orders?.length" class="tb-count">{{ shopData.orders.length }}</span></button>
      <button class="dtab" :class="{on:tab==='send'}" @click="tab='send'">Send a parcel</button>
      <button class="dtab" :class="{on:tab==='mine'}" @click="tab='mine'">My parcels <span class="tb-count">{{ myParcels.length }}</span></button>
    </div>

    <!-- OVERVIEW: business dashboard -->
    <div v-if="tab==='overview'">
      <template v-if="shopData?.has_shop">
        <div class="biz-stats">
          <button class="biz-stat" @click="tab='orders'"><div class="biz-stat-v">{{ shopData.stats.total }}</div><div class="biz-stat-l">Total orders</div></button>
          <div class="biz-stat"><div class="biz-stat-v">{{ shopData.stats.active }}</div><div class="biz-stat-l">In progress</div></div>
          <div class="biz-stat"><div class="biz-stat-v">{{ shopData.stats.delivered }}</div><div class="biz-stat-l">Delivered</div></div>
          <div class="biz-stat"><div class="biz-stat-v mono">{{ fmtTZS(shopData.stats.revenue) }}</div><div class="biz-stat-l">Revenue</div></div>
        </div>
        <div class="biz-quick">
          <RouterLink to="/my-shop" class="biz-quick-card"><Icon name="box" :size="18" /><div><b>Manage storefront</b><span>Products, sections, carrier</span></div></RouterLink>
          <button class="biz-quick-card" @click="tab='orders'"><Icon name="inbox" :size="18" /><div><b>View orders</b><span>{{ shopData.stats.active }} need fulfilling</span></div></button>
          <button class="biz-quick-card" @click="tab='send'"><Icon name="truck" :size="18" /><div><b>Send a parcel</b><span>Ship directly</span></div></button>
        </div>
      </template>
      <template v-else>
        <div class="panel" style="text-align:center;padding:40px 24px">
          <Icon name="box" :size="32" style="color:var(--accent);margin-bottom:12px" />
          <h2>Open your shop to start selling</h2>
          <p style="color:var(--ink-faint);margin:8px 0 20px">Create a storefront, list products, and receive orders with tracked delivery built in.</p>
          <RouterLink to="/my-shop" class="btn btn-accent btn-lg">Open your storefront</RouterLink>
        </div>
        <div class="biz-quick" style="margin-top:16px">
          <button class="biz-quick-card" @click="tab='send'"><Icon name="truck" :size="18" /><div><b>Send a parcel</b><span>Ship without a shop</span></div></button>
        </div>
      </template>
    </div>

    <!-- ORDERS: incoming orders from the shop -->
    <div v-else-if="tab==='orders'">
      <div class="panel">
        <h2>Orders from your shop</h2>
        <p class="psec-sub" style="margin-bottom:16px">When someone buys from your storefront, it appears here and ships with tracked delivery.</p>
        <EmptyState v-if="!shopData?.orders?.length" icon="inbox" title="No orders yet" hint="Share your shop link to start receiving orders." />
        <div v-else class="biz-orders">
          <RouterLink v-for="o in shopData.orders" :key="o.code" :to="`/track?code=${o.code}`" class="biz-order">
            <div class="biz-order-top">
              <span class="biz-order-code">{{ o.code }}</span>
              <span class="biz-order-stage" :class="'st-'+o.stage">{{ stageLabel(o.stage) }}</span>
              <div class="grow"></div>
              <span v-if="o.amount" class="biz-order-amt mono">{{ fmtTZS(o.amount) }}</span>
            </div>
            <div class="biz-order-body">
              <span class="biz-order-item">{{ o.item }}</span>
              <span class="biz-order-buyer">{{ o.buyer }} · {{ o.dest }}</span>
            </div>
          </RouterLink>
        </div>
      </div>
    </div>

    <!-- SEND -->
    <div v-else-if="tab==='send'">
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

<style scoped>
.biz-stats{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:16px}
.biz-stat{background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:16px;text-align:left;font-family:inherit;box-shadow:var(--shadow-xs)}
button.biz-stat{cursor:pointer;transition:box-shadow .15s ease}
button.biz-stat:hover{box-shadow:var(--shadow-sm)}
.biz-stat-v{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:22px;color:var(--ink);letter-spacing:-.02em;line-height:1}
.biz-stat-l{font-size:12px;color:var(--ink-faint);margin-top:5px}
.biz-quick{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}
.biz-quick-card{display:flex;align-items:center;gap:12px;background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:16px;text-align:left;font-family:inherit;cursor:pointer;text-decoration:none;color:inherit;box-shadow:var(--shadow-xs);transition:box-shadow .15s ease,transform .15s ease}
.biz-quick-card:hover{box-shadow:var(--shadow-sm);transform:translateY(-1px)}
.biz-quick-card :deep(svg){color:var(--accent);flex-shrink:0}
.biz-quick-card b{display:block;font-size:14px;color:var(--ink);margin-bottom:2px}
.biz-quick-card span{font-size:12px;color:var(--ink-faint)}
.biz-orders{display:flex;flex-direction:column;gap:8px}
.biz-order{display:block;background:var(--surface);border:1px solid var(--hairline);border-radius:12px;padding:13px 15px;text-decoration:none;transition:border-color .15s ease,box-shadow .15s ease}
.biz-order:hover{border-color:var(--hairline-2);box-shadow:var(--shadow-xs)}
.biz-order-top{display:flex;align-items:center;gap:9px;margin-bottom:6px}
.biz-order-code{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:14px;color:var(--ink)}
.biz-order-stage{font-size:10.5px;font-weight:650;padding:2px 8px;border-radius:999px;text-transform:uppercase;letter-spacing:.03em;background:var(--accent-soft);color:var(--accent-ink)}
.grow{flex:1}
.biz-order-amt{font-weight:700;font-size:14px;color:var(--ink)}
.biz-order-body{display:flex;justify-content:space-between;gap:10px;font-size:12.5px}
.biz-order-item{color:var(--ink-soft);font-weight:550}
.biz-order-buyer{color:var(--ink-faint);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
@media(max-width:640px){.biz-stats{grid-template-columns:repeat(2,1fr)}.biz-quick{grid-template-columns:1fr}}
</style>
