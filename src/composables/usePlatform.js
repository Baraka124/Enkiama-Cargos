// ── Platform data-access layer ──────────────────────────────────────
// Extracted from PlatformView so the view calls named methods instead of
// raw SQL. One place to change how platform data is fetched/mutated.
import { supabase } from '../lib/supabase'

export function usePlatform() {
  // ---- reads ----
  const listCarriers = () =>
    supabase.from('carrier').select('*').order('created_at', { ascending: true })

  const listConsignmentsLite = () =>
    supabase.from('consignment').select('id,stage,carrier_id')

  const listPaymentsLite = () =>
    supabase.from('payment').select('consignment_id,mode,state,cod_amount')

  const listDrivers = () =>
    supabase.from('driver').select('id,name,vehicle,active,carrier_id')

  const listProfiles = () =>
    supabase.from('profile').select('user_id,name,role,carrier_id')

  const listApplications = () =>
    supabase.from('carrier_application').select('*').order('created_at', { ascending: false })

  const listConsignmentsFull = () =>
    supabase.from('consignment').select('id,code,stage,carrier_id,receiver_name,dest_address,created_at')

  const revenue = () => supabase.rpc('platform_revenue')

  // drill-down: one carrier's full operation
  const carrierDrill = (carrierId) => Promise.all([
    supabase.from('consignment').select('*').eq('carrier_id', carrierId).order('created_at', { ascending: false }),
    supabase.from('driver').select('*').eq('carrier_id', carrierId),
    supabase.from('payment').select('consignment_id,mode,state,cod_amount'),
  ])

  // ---- mutations (all gated server-side by is_platform_admin) ----
  const createCarrier = (args) => supabase.rpc('create_carrier_with_admin', args)
  const flagConsignment = (id, note) => supabase.rpc('admin_flag_consignment', { p_consignment: id, p_note: note, p_flag: true })
  const approveApplication = (args) => supabase.rpc('approve_carrier_application', args)
  const rejectApplication = (appId, reason) => supabase.rpc('reject_carrier_application', { p_app: appId, p_reason: reason || null })
  const setBilling = (carrierId, plan, monthly) => supabase.rpc('set_carrier_billing', { p_carrier: carrierId, p_plan: plan, p_monthly: monthly })
  const recordPayment = (carrierId) => supabase.rpc('record_carrier_payment', { p_carrier: carrierId })
  const findParcel = (code) => supabase.rpc('admin_find_parcel', { p_code: code })
  const intervene = (code, note) => supabase.rpc('admin_intervene', { p_code: code, p_note: note })
  const updateCarrier = (args) => supabase.rpc('update_carrier', args)
  const setCarrierStatus = (carrierId, status) => supabase.rpc('set_carrier_status', { p_carrier: carrierId, p_status: status })

  return {
    listCarriers, listConsignmentsLite, listPaymentsLite, listDrivers, listProfiles,
    listApplications, listConsignmentsFull, revenue, carrierDrill,
    createCarrier, flagConsignment, approveApplication, rejectApplication,
    setBilling, recordPayment, findParcel, intervene, updateCarrier, setCarrierStatus,
  }
}
