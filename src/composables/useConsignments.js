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
  const pay = row.payment || {}
  const drv = row.driver || null
  return {
    id: row.id, code: row.code, carrierId: row.carrier_id,
    sender: row.sender_name, senderPhone: row.sender_phone,
    receiver: row.receiver_name, receiverPhone: row.receiver_phone,
    addr: row.dest_address, item: row.item, weight: Number(row.weight_kg),
    stage: row.stage, driver: drv ? `${drv.name} (${drv.vehicle || 'driver'})` : null,
    driverId: row.driver_id,
    payMode: pay.mode || 'prepaid', payState: pay.state || 'none',
    cod: pay.cod_amount || 0, fee: pay.fee_amount || 0,
    momoConfirmed: !!pay.momo_confirmed,
    attemptCount: row.attempt_count || 0, lastReason: row.last_reason || '',
  }
}

async function fetchAll() {
  loading.value = true
  const { data, error } = await supabase
    .from('consignment')
    .select('*, payment(*), driver(name,vehicle)')
    .order('created_at', { ascending: false })
  if (!error && data) consignments.value = data.map(shape)
  loading.value = false
}

function subscribe() {
  if (channel) return
  channel = supabase.channel('cargos-live')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'consignment' }, fetchAll)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'payment' }, fetchAll)
    .subscribe()
}
function unsubscribe() { if (channel) { supabase.removeChannel(channel); channel = null } }

// ── mutations ──────────────────────────────────────────────────────
async function advance(p, toStage, note) {
  // optimistic: update local state immediately
  const target = consignments.value.find(c => c.id === p.id)
  const prevStage = target?.stage
  if (target) target.stage = toStage
  try {
    const { error } = await supabase.from('consignment').update({ stage: toStage }).eq('id', p.id)
    if (error) throw error
    await logCustody(p.id, toStage, note)
    await fetchAll()
  } catch (e) {
    // rollback on failure
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
  await supabase.from('consignment').update({ stage: 'with_driver', driver_id: driverId }).eq('id', p.id)
  await logCustody(p.id, 'with_driver', 'Assigned to driver')
  await fetchAll()
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
