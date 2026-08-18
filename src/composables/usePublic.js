// ── Public / buyer-facing data-access layer ─────────────────────────
// Tracking, marketplace, storefront browsing, ordering, receiver, and
// sender booking. All anon-or-authenticated RPCs.
import { supabase } from '../lib/supabase'

export function usePublic() {
  // tracking + receiver actions
  const track = (code) => supabase.rpc('track_parcel', { p_code: code })
  const confirmReceipt = (code, last4) => supabase.rpc('confirm_receipt_verified', { p_code: code, p_last4: last4 })
  const leaveReview = (args) => supabase.rpc('leave_review', args)
  const reschedule = (code, when, note) => supabase.rpc('receiver_reschedule', { p_code: code, p_when: when, p_note: note || null })
  const report = (code, issue) => supabase.rpc('receiver_report', { p_code: code, p_issue: issue })

  // receiver deliveries
  const myDeliveries = () => supabase.rpc('my_deliveries')
  const claimReceiverPhone = (phone) => supabase.rpc('claim_receiver_phone', { p_phone: phone })

  // marketplace + storefront
  const browseStorefronts = (corridor) => supabase.rpc('browse_storefronts', { p_corridor: corridor || null })
  const browseStorefrontsV2 = (corridor, search, sort) =>
    supabase.rpc('browse_storefronts_v2', { p_corridor: corridor || null, p_search: search || null, p_sort: sort || 'recommended' })
  const searchProducts = (search, category, corridor) =>
    supabase.rpc('search_products', { p_search: search || null, p_category: category || null, p_corridor: corridor || null })
  const productCategories = () => supabase.rpc('product_categories')
  const getStorefront = (slug) => supabase.rpc('get_storefront', { p_slug: slug })
  const placeOrder = (args) => supabase.rpc('place_order', args)

  // sender
  const activeCarriers = () => supabase.from('carrier').select('*').eq('status', 'active').order('name')
  const senderBook = (args) => supabase.rpc('sender_book', args)
  const applyAsCarrier = (args) => supabase.rpc('apply_as_carrier', args)
  const mySenderShipments = () =>
    supabase.from('consignment').select('*, payment(*), driver(name,vehicle), carrier(name,accent,slug,mark)').order('created_at', { ascending: false })

  return {
    track, confirmReceipt, leaveReview, reschedule, report,
    myDeliveries, claimReceiverPhone,
    browseStorefronts, browseStorefrontsV2, searchProducts, productCategories, getStorefront, placeOrder,
    activeCarriers, senderBook, mySenderShipments, applyAsCarrier,
  }
}
