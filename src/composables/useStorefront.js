// ── Storefront (seller shop) data-access layer ──────────────────────
// Extracted from StorefrontManageView so the view calls named methods
// instead of raw SQL/storage. One place for shop-management data ops.
import { supabase } from '../lib/supabase'

export function useStorefront() {
  // ---- shop ----
  const myStore = (ownerId) =>
    supabase.from('storefront').select('*').eq('owner_id', ownerId).maybeSingle()
  const upsertStore = (args) => supabase.rpc('upsert_storefront', args)

  // ---- products ----
  const listProducts = (storeId) =>
    supabase.from('product').select('*').eq('storefront_id', storeId).order('created_at')
  const addProduct = (row) => supabase.from('product').insert(row)
  const deleteProduct = (id) => supabase.from('product').delete().eq('id', id)

  // ---- sections ----
  const listSections = (storeId) =>
    supabase.from('shop_section').select('*').eq('storefront_id', storeId).order('sort')
  const addSection = (storeId, name, sort) =>
    supabase.from('shop_section').insert({ storefront_id: storeId, name, sort })
  const deleteSection = (id) => supabase.from('shop_section').delete().eq('id', id)

  // ---- carrier selection ----
  const activeCarriers = () =>
    supabase.from('carrier').select('id,name,slug,mark,accent,region').eq('status', 'active').order('name')
  const selectCarrier = (slug, carrierId) =>
    supabase.rpc('select_storefront_carrier', { p_slug: slug, p_carrier: carrierId })

  return {
    myStore, upsertStore,
    listProducts, addProduct, deleteProduct,
    listSections, addSection, deleteSection,
    activeCarriers, selectCarrier,
  }
}
