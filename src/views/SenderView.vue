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
import Money from '../components/Money.vue'
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
const insights = ref(null)
const insightsLoading = ref(false)
async function loadInsights() {
  if (insights.value) return
  insightsLoading.value = true
  try { const { data } = await pub.businessInsights(); insights.value = data } catch (e) {}
  insightsLoading.value = false
}
const weekTrend = computed(() => {
  if (!insights.value) return 0
  return (insights.value.this_week || 0) - (insights.value.last_week || 0)
})
function barPct(v, arr) {
  const max = Math.max(...arr.map(x => x.orders), 1)
  return Math.round((v / max) * 100)
}

async function loadShopOrders() {
  try { const { data } = await pub.myShopOrders(); shopData.value = data } catch (e) {}
}
const switchOrder = ref(null)
function openSwitchCarrier(o) { switchOrder.value = o }
async function chooseCarrier(carrierId) {
  try {
    const { data } = await pub.businessSwitchCarrier(switchOrder.value.code, carrierId)
    if (data?.ok) { toast('Carrier updated', 'ok'); await loadShopOrders(); switchOrder.value = null }
    else toast(data?.error || 'Could not switch carrier', 'warn')
  } catch (e) { toast('Could not switch carrier', 'warn') }
}
async function markReady(o) {
  try {
    const { data } = await pub.businessMarkReady(o.code)
    if (data?.ok) { toast('Marked ready — your carrier has been notified', 'ok'); await loadShopOrders() }
    else toast(data?.error || 'Could not mark ready', 'warn')
  } catch (e) { toast('Could not mark ready', 'warn') }
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
    <RouterLink to="/my-shop" class="btn btn-accent">{{ shopData?.has_shop ? 'My storefront' : 'Open storefront' }}</RouterLink>
    <button class="btn btn-ghost" style="margin-left:8px" @click="logout">Sign out</button>
  </AppHeader>

  <div class="wrap" style="max-width:820px">
    <div class="dtabs">
      <button class="dtab" :class="{on:tab==='overview'}" @click="tab='overview'">Overview</button>
      <button class="dtab" :class="{on:tab==='orders'}" @click="tab='orders'">Orders <span v-if="shopData?.orders?.length" class="tb-count">{{ shopData.orders.length }}</span></button>
      <button class="dtab" :class="{on:tab==='insights'}" @click="tab='insights'; loadInsights()">Insights</button>
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
        <div class="biz-onboard">
          <div class="biz-onboard-badge"><Icon name="box" :size="14" /> Your business, online</div>
          <h1 class="biz-onboard-h1">Open your shop and sell <span class="biz-grad">with delivery built in</span></h1>
          <p class="biz-onboard-sub">List your products on the Enkiama marketplace. Every order ships with tracked, door-to-door delivery — you focus on selling, we move the cargo.</p>
          <div class="biz-onboard-cta">
            <RouterLink to="/my-shop" class="btn btn-accent btn-lg">Open your storefront</RouterLink>
            <button class="btn btn-ghost btn-lg" @click="tab='send'">Just send a parcel</button>
          </div>

          <div class="biz-steps">
            <div class="biz-step-c">
              <div class="biz-step-num">1</div>
              <div class="biz-step-t">Set up your storefront</div>
              <div class="biz-step-d">Add your business name, products, photos, and organize them into sections.</div>
            </div>
            <div class="biz-step-c">
              <div class="biz-step-num">2</div>
              <div class="biz-step-t">Share your shop link</div>
              <div class="biz-step-d">Customers browse and order from your storefront on the marketplace.</div>
            </div>
            <div class="biz-step-c">
              <div class="biz-step-num">3</div>
              <div class="biz-step-t">Orders ship & track</div>
              <div class="biz-step-d">Every order flows here as a tracked delivery, door to door.</div>
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- ORDERS: incoming orders from the shop -->
    <div v-else-if="tab==='orders'">
      <div class="panel">
        <h2>Orders from your shop</h2>
        <p class="psec-sub" style="margin-bottom:16px">Prepare each order, choose or switch the carrier, and mark it ready — the carrier collects and delivers with live tracking.</p>
        <EmptyState v-if="!shopData?.orders?.length" icon="inbox" title="No orders yet" hint="Share your shop link to start receiving orders." />
        <div v-else class="biz-orders">
          <div v-for="o in shopData.orders" :key="o.code" class="biz-order">
            <div class="biz-order-top">
              <span class="biz-order-code">{{ o.code }}</span>
              <span v-if="o.ready && o.can_edit" class="biz-order-stage st-ready">Ready · awaiting pickup</span>
              <span v-else class="biz-order-stage" :class="'st-'+o.stage">{{ stageLabel(o.stage) }}</span>
              <div class="grow"></div>
              <span v-if="o.amount" class="biz-order-amt mono">{{ fmtTZS(o.amount) }}</span>
            </div>
            <div class="biz-order-body">
              <span class="biz-order-item">{{ o.item }}</span>
              <span class="biz-order-buyer">{{ o.buyer }} · {{ o.dest }}</span>
            </div>
            <div class="biz-order-carrier">
              <Icon name="truck" :size="13" /> {{ o.carrier_name || 'No carrier chosen' }}
              <button v-if="o.can_edit" class="biz-order-switch" @click="openSwitchCarrier(o)">Switch</button>
            </div>
            <div class="biz-order-actions">
              <RouterLink :to="`/track?code=${o.code}`" class="btn btn-ghost">Track</RouterLink>
              <button v-if="o.can_edit && !o.ready" class="btn btn-accent" @click="markReady(o)">Mark ready for pickup</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- INSIGHTS TAB -->
    <div v-else-if="tab==='insights'">
      <div v-if="insightsLoading" class="panel">
        <div class="ins-grid">
          <div v-for="n in 4" :key="n" class="ins-stat"><div class="skel skel-num"></div><div class="skel skel-lab"></div></div>
        </div>
      </div>
      <template v-else-if="insights?.has_shop">
        <!-- CASH-FLOW BRAIN: money position + plain-language signals -->
        <div class="cfb">
          <div class="cfb-cash">
            <div class="cfb-cash-main">
              <div class="cfb-cash-lab">You're owed</div>
              <div class="cfb-cash-v"><Money :amount="insights.cash.owed_to_you" size="xl" /></div>
              <div class="cfb-cash-sub">cash-on-delivery still to collect</div>
            </div>
            <div class="cfb-cash-side">
              <div class="cfb-mini"><span class="cfb-mini-l">Received</span><span class="cfb-mini-v go-ink"><Money :amount="insights.cash.received" /></span></div>
              <div class="cfb-mini"><span class="cfb-mini-l">In transit</span><span class="cfb-mini-v"><Money :amount="insights.cash.in_transit" /></span></div>
            </div>
          </div>
          <div class="cfb-signals">
            <div v-if="insights.signals.trend_pct != null" class="cfb-sig" :class="insights.signals.trend">
              <Icon :name="insights.signals.trend==='up'?'check':'alert'" :size="16" />
              <span>Orders are <strong>{{ insights.signals.trend }}</strong> {{ Math.abs(insights.signals.trend_pct) }}% vs last week</span>
            </div>
            <div v-if="insights.signals.best_day" class="cfb-sig">
              <Icon name="clock" :size="16" />
              <span><strong>{{ insights.signals.best_day }}</strong> is your busiest day — stock up for it</span>
            </div>
            <div v-if="insights.signals.growth_market" class="cfb-sig">
              <Icon name="pin" :size="16" />
              <span><strong>{{ insights.signals.growth_market }}</strong> is your top market — worth pushing there</span>
            </div>
          </div>
        </div>

        <div class="ins-grid">
          <div class="ins-stat">
            <div class="ins-v">{{ insights.this_week }}</div>
            <div class="ins-l">Orders this week</div>
            <div class="ins-trend" :class="weekTrend >= 0 ? 'up' : 'down'">{{ weekTrend >= 0 ? '▲' : '▼' }} {{ Math.abs(weekTrend) }} vs last week</div>
          </div>
          <div class="ins-stat">
            <div class="ins-v">{{ insights.total_orders }}</div>
            <div class="ins-l">Total orders</div>
          </div>
          <div class="ins-stat">
            <div class="ins-v">{{ insights.delivered }}</div>
            <div class="ins-l">Delivered</div>
          </div>
          <div class="ins-stat">
            <div class="ins-v">{{ insights.success_rate }}%</div>
            <div class="ins-l">Success rate</div>
          </div>
        </div>

        <div class="panel" style="margin-top:16px" v-if="insights.top_items?.length">
          <h2>Best sellers</h2>
          <div class="ins-bars">
            <div v-for="(it,i) in insights.top_items" :key="i" class="ins-bar-row">
              <span class="ins-bar-name">{{ it.name }}</span>
              <div class="ins-bar-track"><div class="ins-bar-fill" :style="{width: barPct(it.orders, insights.top_items) + '%'}"></div></div>
              <span class="ins-bar-val">{{ it.orders }}</span>
            </div>
          </div>
        </div>

        <div class="panel" style="margin-top:16px" v-if="insights.by_dest?.length">
          <h2>Top destinations</h2>
          <div class="ins-dest">
            <div v-for="(d,i) in insights.by_dest" :key="i" class="ins-dest-row">
              <Icon name="pin" :size="14" /> <span class="ins-dest-name">{{ d.dest }}</span> <span class="ins-dest-count">{{ d.orders }} order{{ d.orders===1?'':'s' }}</span>
            </div>
          </div>
        </div>
      </template>
      <EmptyState v-else icon="chart" title="No insights yet" hint="Once orders come in, you'll see trends, best sellers, and destinations here." />
    </div>

    <div v-if="switchOrder" class="modal-back" @click.self="switchOrder=null">
      <div class="modal">
        <h3>Choose carrier — {{ switchOrder.code }}</h3>
        <p class="sub">Pick who transports this order. You can switch any time before it's picked up.</p>
        <div class="carrier-picker">
          <button v-for="c in carriers" :key="c.id" class="carrier-opt" :class="{on: c.id===switchOrder.carrier_id}" @click="chooseCarrier(c.id)">
            <div class="carrier-mk" :style="{background: c.accent || 'var(--accent)'}">{{ (c.name||'?').slice(0,2).toUpperCase() }}</div>
            <div><div class="carrier-nm">{{ c.name }}</div><div class="carrier-rg">{{ c.region || 'Road freight' }}</div></div>
            <Icon v-if="c.id===switchOrder.carrier_id" name="check" :size="16" class="carrier-chk" />
          </button>
        </div>
        <button class="btn btn-ghost btn-block" @click="switchOrder=null" style="margin-top:12px">Done</button>
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
.biz-order-stage{font-size:11px;font-weight:650;padding:2px 8px;border-radius:999px;text-transform:uppercase;letter-spacing:.03em;background:var(--accent-soft);color:var(--accent-ink)}
.grow{flex:1}
.biz-order-amt{font-weight:700;font-size:14px;color:var(--ink)}
.biz-order-body{display:flex;justify-content:space-between;gap:10px;font-size:12px}
.biz-order-item{color:var(--ink-soft);font-weight:550}
.biz-order-buyer{color:var(--ink-faint);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
@media(max-width:640px){.biz-stats{grid-template-columns:repeat(2,1fr)}.biz-quick{grid-template-columns:1fr}}

.biz-order-carrier{display:flex;align-items:center;gap:6px;font-size:12.5px;color:var(--ink-soft);margin-top:10px;padding-top:10px;border-top:1px solid var(--hairline)}
.biz-order-switch{margin-left:6px;background:none;border:none;color:var(--accent-ink);font-weight:650;font-size:12px;cursor:pointer;font-family:inherit;text-decoration:underline}
.biz-order-actions{display:flex;gap:8px;margin-top:12px}
.biz-order-actions .btn{flex:0 0 auto}
.st-ready{background:var(--go-soft) !important;color:var(--go-ink) !important}
.carrier-picker{display:flex;flex-direction:column;gap:8px;margin-top:8px}
.carrier-opt{display:flex;align-items:center;gap:12px;padding:12px;border:1px solid var(--hairline-2);border-radius:12px;background:var(--surface);cursor:pointer;font-family:inherit;text-align:left;transition:all .15s ease}
.carrier-opt:hover{border-color:var(--accent);background:var(--accent-soft)}
.carrier-opt.on{border-color:var(--accent);background:var(--accent-soft)}
.carrier-mk{width:38px;height:38px;border-radius:10px;color:#fff;display:flex;align-items:center;justify-content:center;font-family:"Space Grotesk",sans-serif;font-weight:700;font-size:13px;flex-shrink:0}
.carrier-nm{font-weight:650;font-size:14px;color:var(--ink)}
.carrier-rg{font-size:12px;color:var(--ink-faint)}
.carrier-chk{margin-left:auto;color:var(--accent)}

.ins-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}
.ins-stat{background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:18px;box-shadow:var(--shadow-sm)}
.ins-v{font-family:"Space Grotesk",sans-serif;font-size:28px;font-weight:700;color:var(--ink);letter-spacing:-.02em;font-variant-numeric:tabular-nums}
.ins-l{font-size:12.5px;color:var(--ink-soft);font-weight:600;margin-top:4px}
.ins-trend{font-size:11.5px;font-weight:600;margin-top:8px}
.ins-trend.up{color:var(--go-ink)}
.ins-trend.down{color:var(--owed-ink)}
.ins-bars{display:flex;flex-direction:column;gap:12px;margin-top:8px}
.ins-bar-row{display:flex;align-items:center;gap:12px}
.ins-bar-name{flex:0 0 140px;font-size:13px;font-weight:600;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ins-bar-track{flex:1;height:10px;background:var(--surface-3);border-radius:999px;overflow:hidden}
.ins-bar-fill{height:100%;background:linear-gradient(90deg,var(--accent),var(--accent-ink));border-radius:999px;transition:width .5s ease}
.ins-bar-val{flex:0 0 auto;font-family:"Space Grotesk",sans-serif;font-weight:700;font-size:14px;color:var(--ink);font-variant-numeric:tabular-nums}
.ins-dest{display:flex;flex-direction:column;gap:2px;margin-top:8px}
.ins-dest-row{display:flex;align-items:center;gap:8px;padding:10px 0;border-bottom:1px solid var(--hairline);font-size:13.5px}
.ins-dest-row:last-child{border-bottom:none}
.ins-dest-name{flex:1;color:var(--ink);font-weight:600}
.ins-dest-count{color:var(--ink-faint);font-size:12.5px}
@media(max-width:640px){.ins-grid{grid-template-columns:1fr 1fr}.ins-bar-name{flex-basis:90px}}

.cfb{display:grid;grid-template-columns:1.2fr 1fr;gap:14px;margin-bottom:16px}
.cfb-cash{display:flex;gap:20px;background:linear-gradient(135deg,var(--ink),#2A2620);border-radius:16px;padding:22px;color:#fff}
.cfb-cash-main{flex:1}
.cfb-cash-lab{font-size:12.5px;color:rgba(255,255,255,.6);font-weight:600}
.cfb-cash-v{margin:6px 0 4px;color:#fff}
.cfb-cash-v :deep(.money-cur){color:rgba(255,255,255,.5)}
.cfb-cash-sub{font-size:11.5px;color:rgba(255,255,255,.45)}
.cfb-cash-side{display:flex;flex-direction:column;gap:12px;justify-content:center;border-left:1px solid rgba(255,255,255,.12);padding-left:20px}
.cfb-mini{display:flex;flex-direction:column;gap:2px}
.cfb-mini-l{font-size:11px;color:rgba(255,255,255,.5)}
.cfb-mini-v{font-size:15px;font-weight:700;font-family:"Space Grotesk",sans-serif}
.cfb-mini-v.go-ink{color:#4ADE80}
.cfb-signals{display:flex;flex-direction:column;gap:8px;justify-content:center}
.cfb-sig{display:flex;align-items:center;gap:10px;padding:12px 14px;background:var(--surface);border:1px solid var(--hairline);border-radius:12px;font-size:13px;color:var(--ink-soft)}
.cfb-sig strong{color:var(--ink);text-transform:capitalize}
.cfb-sig :deep(svg){color:var(--accent);flex-shrink:0}
.cfb-sig.up :deep(svg){color:var(--go)}
.cfb-sig.down :deep(svg){color:var(--warn)}
@media(max-width:760px){.cfb{grid-template-columns:1fr}.cfb-cash{flex-direction:column;gap:14px}.cfb-cash-side{border-left:none;border-top:1px solid rgba(255,255,255,.12);padding-left:0;padding-top:14px;flex-direction:row;gap:24px}}
</style>

<style scoped>
.biz-onboard{text-align:center;max-width:820px;margin:0 auto;padding:20px;min-height:calc(100vh - 200px);display:flex;flex-direction:column;align-items:center;justify-content:center}
.biz-onboard-badge{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:650;color:var(--accent-ink);background:var(--accent-soft);padding:6px 14px;border-radius:999px;margin-bottom:20px}
.biz-onboard-h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(28px,5vw,40px);font-weight:700;letter-spacing:-.03em;line-height:1.1;margin-bottom:14px;color:var(--ink)}
.biz-grad{background:linear-gradient(100deg,var(--accent),var(--go));-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.biz-onboard-sub{font-size:16px;color:var(--ink-soft);line-height:1.6;max-width:560px;margin:0 auto 26px}
.biz-onboard-cta{display:flex;gap:12px;justify-content:center;flex-wrap:wrap;margin-bottom:44px}
.biz-steps{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;text-align:left}
.biz-step-c{background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:22px;box-shadow:0 1px 2px rgba(11,14,20,.04),0 2px 6px rgba(11,14,20,.05),0 8px 20px rgba(11,14,20,.03)}
.biz-step-num{width:30px;height:30px;border-radius:9px;background:var(--accent);color:#fff;display:flex;align-items:center;justify-content:center;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:14px;margin-bottom:14px;box-shadow:inset 0 1px 0 rgba(255,255,255,.18),0 2px 6px rgba(11,110,93,.3)}
.biz-step-t{font-weight:700;font-size:15px;color:var(--ink);margin-bottom:6px}
.biz-step-d{font-size:13px;color:var(--ink-faint);line-height:1.55}
@media(max-width:680px){.biz-steps{grid-template-columns:1fr}}

.biz-order-carrier{display:flex;align-items:center;gap:6px;font-size:12.5px;color:var(--ink-soft);margin-top:10px;padding-top:10px;border-top:1px solid var(--hairline)}
.biz-order-switch{margin-left:6px;background:none;border:none;color:var(--accent-ink);font-weight:650;font-size:12px;cursor:pointer;font-family:inherit;text-decoration:underline}
.biz-order-actions{display:flex;gap:8px;margin-top:12px}
.biz-order-actions .btn{flex:0 0 auto}
.st-ready{background:var(--go-soft) !important;color:var(--go-ink) !important}
.carrier-picker{display:flex;flex-direction:column;gap:8px;margin-top:8px}
.carrier-opt{display:flex;align-items:center;gap:12px;padding:12px;border:1px solid var(--hairline-2);border-radius:12px;background:var(--surface);cursor:pointer;font-family:inherit;text-align:left;transition:all .15s ease}
.carrier-opt:hover{border-color:var(--accent);background:var(--accent-soft)}
.carrier-opt.on{border-color:var(--accent);background:var(--accent-soft)}
.carrier-mk{width:38px;height:38px;border-radius:10px;color:#fff;display:flex;align-items:center;justify-content:center;font-family:"Space Grotesk",sans-serif;font-weight:700;font-size:13px;flex-shrink:0}
.carrier-nm{font-weight:650;font-size:14px;color:var(--ink)}
.carrier-rg{font-size:12px;color:var(--ink-faint)}
.carrier-chk{margin-left:auto;color:var(--accent)}

.ins-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}
.ins-stat{background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:18px;box-shadow:var(--shadow-sm)}
.ins-v{font-family:"Space Grotesk",sans-serif;font-size:28px;font-weight:700;color:var(--ink);letter-spacing:-.02em;font-variant-numeric:tabular-nums}
.ins-l{font-size:12.5px;color:var(--ink-soft);font-weight:600;margin-top:4px}
.ins-trend{font-size:11.5px;font-weight:600;margin-top:8px}
.ins-trend.up{color:var(--go-ink)}
.ins-trend.down{color:var(--owed-ink)}
.ins-bars{display:flex;flex-direction:column;gap:12px;margin-top:8px}
.ins-bar-row{display:flex;align-items:center;gap:12px}
.ins-bar-name{flex:0 0 140px;font-size:13px;font-weight:600;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ins-bar-track{flex:1;height:10px;background:var(--surface-3);border-radius:999px;overflow:hidden}
.ins-bar-fill{height:100%;background:linear-gradient(90deg,var(--accent),var(--accent-ink));border-radius:999px;transition:width .5s ease}
.ins-bar-val{flex:0 0 auto;font-family:"Space Grotesk",sans-serif;font-weight:700;font-size:14px;color:var(--ink);font-variant-numeric:tabular-nums}
.ins-dest{display:flex;flex-direction:column;gap:2px;margin-top:8px}
.ins-dest-row{display:flex;align-items:center;gap:8px;padding:10px 0;border-bottom:1px solid var(--hairline);font-size:13.5px}
.ins-dest-row:last-child{border-bottom:none}
.ins-dest-name{flex:1;color:var(--ink);font-weight:600}
.ins-dest-count{color:var(--ink-faint);font-size:12.5px}
@media(max-width:640px){.ins-grid{grid-template-columns:1fr 1fr}.ins-bar-name{flex-basis:90px}}

.cfb{display:grid;grid-template-columns:1.2fr 1fr;gap:14px;margin-bottom:16px}
.cfb-cash{display:flex;gap:20px;background:linear-gradient(135deg,var(--ink),#2A2620);border-radius:16px;padding:22px;color:#fff}
.cfb-cash-main{flex:1}
.cfb-cash-lab{font-size:12.5px;color:rgba(255,255,255,.6);font-weight:600}
.cfb-cash-v{margin:6px 0 4px;color:#fff}
.cfb-cash-v :deep(.money-cur){color:rgba(255,255,255,.5)}
.cfb-cash-sub{font-size:11.5px;color:rgba(255,255,255,.45)}
.cfb-cash-side{display:flex;flex-direction:column;gap:12px;justify-content:center;border-left:1px solid rgba(255,255,255,.12);padding-left:20px}
.cfb-mini{display:flex;flex-direction:column;gap:2px}
.cfb-mini-l{font-size:11px;color:rgba(255,255,255,.5)}
.cfb-mini-v{font-size:15px;font-weight:700;font-family:"Space Grotesk",sans-serif}
.cfb-mini-v.go-ink{color:#4ADE80}
.cfb-signals{display:flex;flex-direction:column;gap:8px;justify-content:center}
.cfb-sig{display:flex;align-items:center;gap:10px;padding:12px 14px;background:var(--surface);border:1px solid var(--hairline);border-radius:12px;font-size:13px;color:var(--ink-soft)}
.cfb-sig strong{color:var(--ink);text-transform:capitalize}
.cfb-sig :deep(svg){color:var(--accent);flex-shrink:0}
.cfb-sig.up :deep(svg){color:var(--go)}
.cfb-sig.down :deep(svg){color:var(--warn)}
@media(max-width:760px){.cfb{grid-template-columns:1fr}.cfb-cash{flex-direction:column;gap:14px}.cfb-cash-side{border-left:none;border-top:1px solid rgba(255,255,255,.12);padding-left:0;padding-top:14px;flex-direction:row;gap:24px}}
</style>
