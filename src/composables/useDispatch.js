// ── Dispatch (carrier operations) data-access layer ─────────────────
// Extracted from DispatchView. Core consignment logic still lives in
// useConsignments; this covers the surrounding ops: drivers, cash
// ledger, notifications, customers, custody events, delivery fee.
import { supabase } from '../lib/supabase'

export function useDispatch() {
  // ---- drivers & staff ----
  const listDrivers = (carrierId) =>
    supabase.from('driver').select('*').eq('carrier_id', carrierId)
  const addDriver = (row) => supabase.from('driver').insert(row)
  const createDriverInvite = (name, phone) => supabase.rpc('create_driver_invite', { p_name: name || null, p_phone: phone || null })
  const setDriverActive = (driverId, active) =>
    supabase.rpc('set_driver_active', { p_driver: driverId, p_active: active })
  const inviteStaff = (email) => supabase.rpc('invite_staff', { p_email: email, p_role: 'dispatch' })

  // ---- cash ----
  const cashLedger = () => supabase.rpc('my_cash_ledger')
  const settleDriverCash = (driverId) => supabase.rpc('settle_driver_cash', { p_driver: driverId })

  // ---- notifications ----
  const notifications = () => supabase.rpc('my_notifications')
  const markNotificationsRead = () => supabase.rpc('mark_notifications_read')

  // ---- customers ----
  const customers = () => supabase.rpc('my_customers')

  // ---- custody events (parcel timeline) ----
  const custodyEvents = (consignmentId) =>
    supabase.from('custody_event').select('*').eq('consignment_id', consignmentId).order('at', { ascending: true })

  // ---- delivery fee ----
  const setDeliveryFee = (code, fee, payer, note = null) =>
    supabase.rpc('set_delivery_fee', { p_code: code, p_fee: fee, p_payer: payer, p_note: note })

  return {
    listDrivers, addDriver, createDriverInvite, setDriverActive, inviteStaff,
    cashLedger, settleDriverCash,
    notifications, markNotificationsRead,
    customers, custodyEvents, setDeliveryFee,
  }
}
