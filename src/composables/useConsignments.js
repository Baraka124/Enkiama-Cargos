import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import { useAuth } from './useAuth'

const consignments = ref([])
const loading = ref(false)
let channel = null

const STAGE_CAP = {
  booked: 'Booked', collected: 'Carrier has it', linehaul: 'On road',
  with_driver: 'With driver', delivered: 'Delivered', confirmed: 'Confirmed',
  failed: 'Failed', returning: 'Returning', cancelled: 'Cancelled',
}
const STAGE_ORDER = ['booked', 'collected', 'linehaul', 'with_driver', 'delivered', 'confirmed']

function shape(row) {
  const pay = Array.isArray(row.payment) ? (row.payment[0] || {}) : (row.payment || {})
  const drv = Array.isArray(row.driver) ? (row.driver[0] || null) : (row.driver || null)
  return {
    id: row.id, code: row.code, carrierId: row.carrier_id,
    sender: row.sender_name, senderPhone: row.sender_phone,
    receiver: row.receiver_name, receiverPhone: row.receiver_phone,
    addr: row.dest_address, item: row.item, weight: Number(row.weight_kg),
    stage: row.stage, driver: drv ? `${drv.name} (${drv.vehicle || 'driver'})` : null,
    driverId: row.driver_id,
    payMode: pay.mode || 'prepaid', payState: pay.state || 'none',
    cod: pay.cod_amount || 0, fee: pay.fee_amount || 0,
    deliveryFee: row.delivery_fee || 0, feePayer: row.fee_payer || 'sender_prepaid', feeStatus: row.fee_status || 'agreed',
    momoConfirmed: !!pay.momo_confirmed,
    attemptCount: row.attempt_count || 0, lastReason: row.last_reason || '',
    createdAt: row.created_at || null, updatedAt: row.updated_at || null,
  }
}

async function fetchAll() {
  loading.value = true
  const { profile, isPlatformAdmin, hat } = useAuth()
  let q = supabase
    .from('consignment')
    .select('*, payment(*), driver(name,vehicle)')
    .order('created_at', { ascending: false })
    .limit(500)   // cap the live fetch — a busy carrier could have thousands;
                  // the board only needs recent/active parcels, not full history.
  const activeCarrier = profile.value?.carrier_id
  if (activeCarrier && !(isPlatformAdmin.value && hat.value === 'platform')) {
    q = q.eq('carrier_id', activeCarrier)
  }
  const { data, error } = await q
  if (error) { console.warn('[fetchAll]', error.message); loading.value = false; return }
  consignments.value = (data || []).map(shape)
  loading.value = false
}

let pollTimer = null
function subscribe() {
  if (channel) return
  let realtimeWorking = false
  channel = supabase.channel('cargos-live')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'consignment' }, () => { realtimeWorking = true; fetchAll() })
    .on('postgres_changes', { event: '*', schema: 'public', table: 'payment' }, fetchAll)
    .subscribe((status) => { if (status === 'SUBSCRIBED') realtimeWorking = true })
  // Fallback: if realtime isn't delivering (WebSocket blocked, etc.), poll so
  // the board stays live without the user having to refresh the page.
  if (pollTimer) clearInterval(pollTimer)
  pollTimer = setInterval(() => { if (document.visibilityState === 'visible') fetchAll() }, 8000)
}
function unsubscribe() {
  if (channel) { supabase.removeChannel(channel); channel = null }
  if (pollTimer) { clearInterval(pollTimer); pollTimer = null }
}

// ── mutations ──────────────────────────────────────────────────────
async function advance(p, toStage, note) {
  // optimistic: update local state immediately
  const target = consignments.value.find(c => c.id === p.id)
  const prevStage = target?.stage
  if (target) target.stage = toStage
  try {
    if (toStage === 'delivered') {
      // atomic: stage + POD + cash-collected + custody log in one transaction
      const { error } = await supabase.rpc('deliver_parcel', { p_code: p.code, p_note: note || 'Delivered' })
      if (error) throw error
    } else {
      const { error } = await supabase.from('consignment').update({ stage: toStage }).eq('id', p.id)
      if (error) throw error
      await logCustody(p.id, toStage, note)
    }
    await fetchAll()
  } catch (e) {
    // rollback optimistic state on failure
    if (target && prevStage) target.stage = prevStage
    throw e
  }
}
async function logCustody(consId, stage, note) {
  const { profile } = useAuth()
  await supabase.from('custody_event').insert({
    consignment_id: consId, stage, note: note || '',
    actor_role: profile.value?.role || 'system', actor_name: profile.value?.name || '',
  })
}
async function assignDriver(p, driverId) {
  const { data, error } = await supabase.rpc('assign_driver_to_parcel', { p_code: p.code, p_driver_id: driverId })
  if (error) return { error }
  if (data && !data.ok) return { error: { message: data.error } }
  await fetchAll()
  return { error: null }
}
async function markDelivered(p) {
  await supabase.from('consignment').update({ stage: 'delivered' }).eq('id', p.id)
  if (p.payMode === 'cash') await supabase.from('payment').update({ state: 'collected' }).eq('consignment_id', p.id)
  await logCustody(p.id, 'delivered', 'Delivered' + (p.payMode === 'cash' ? ' · cash collected' : ''))
  await fetchAll()
}
async function reportFailed(p, outcome, reason) {
  const n = (p.attemptCount || 0) + 1
  await supabase.from('delivery_attempt').insert({ consignment_id: p.id, attempt_no: n, outcome, reason_note: reason })
  await supabase.from('consignment').update({ stage: 'failed', attempt_count: n, last_reason: reason }).eq('id', p.id)
  await logCustody(p.id, 'failed', 'Attempt failed: ' + reason)
  await fetchAll()
}
async function scheduleRetry(p) {
  await supabase.from('consignment').update({ stage: 'with_driver' }).eq('id', p.id)
  await logCustody(p.id, 'with_driver', `Retry scheduled (attempt ${(p.attemptCount || 1) + 1})`)
  await fetchAll()
}
async function remitCash(p) {
  const { error } = await supabase.rpc('remit_cash', { p_consignment: p.id })
  if (error) throw error
  await fetchAll()
}
async function confirmMomo(p, provider = 'M-Pesa') {
  const { error } = await supabase.rpc('confirm_momo_manual', { p_consignment: p.id, p_provider: provider, p_reference: '' })
  if (error) throw error
  await fetchAll()
}

// Book via the server-side function so dispatch AND senders use the
// exact same enforced path. Returns the new consignment code.
async function book({ carrierId, receiver, receiverPhone, addr, item, weight, mode, cod, fee, senderName, senderPhone }) {
  const { data, error } = await supabase.rpc('book_consignment', {
    p_carrier_id: carrierId,
    p_receiver: receiver,
    p_receiver_ph: receiverPhone,
    p_addr: addr || '',
    p_item: item || 'Parcel',
    p_weight: weight || 1,
    p_mode: mode,
    p_cod: mode === 'cod' ? (cod || 0) : 0,
    p_fee: fee || 0,
    p_sender_name: senderName || 'Walk-in',
    p_sender_ph: senderPhone || '',
  })
  if (error) throw error
  await fetchAll()
  return data  // the code
}

export function useConsignments() {
  return {
    consignments, loading, STAGE_CAP, STAGE_ORDER,
    fetchAll, subscribe, unsubscribe,
    advance, assignDriver, markDelivered, reportFailed, scheduleRetry, remitCash, confirmMomo, book,
  }
}
