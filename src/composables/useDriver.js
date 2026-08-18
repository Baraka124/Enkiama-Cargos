// ── Driver operations data-access layer ─────────────────────────────
// Extracted from DriverView: available parcels, claiming, negotiated
// fee, proof-of-delivery photo upload, atomic delivery.
import { supabase } from '../lib/supabase'

export function useDriver() {
  const registerDriver = (name, phone, vehicle) => supabase.rpc('register_driver', { p_name: name, p_phone: phone, p_vehicle: vehicle || null })
  const driverSignup = (name, vehicle) => supabase.rpc('driver_signup', { p_name: name || null, p_vehicle: vehicle || null })
  const mySpace = () => supabase.rpc('my_driver_space')
  const availableParcels = () => supabase.rpc('available_parcels')
  const claimParcel = (code) => supabase.rpc('claim_parcel', { p_code: code })
  const setNegotiatedFee = (code, fee) =>
    supabase.rpc('set_delivery_fee', { p_code: code, p_fee: fee, p_payer: 'receiver_on_delivery', p_note: 'Negotiated by driver' })

  // proof-of-delivery: upload photo to storage, return public URL
  async function uploadPodPhoto(consignmentId, blob) {
    const path = `${consignmentId}-${Date.now()}.jpg`
    const { error } = await supabase.storage.from('pod-photos').upload(path, blob, { contentType: 'image/jpeg', upsert: true })
    if (error) throw error
    return supabase.storage.from('pod-photos').getPublicUrl(path).data.publicUrl
  }
  const attachPodPhoto = (code, url) => supabase.rpc('attach_pod_photo', { p_code: code, p_url: url })
  const deliverParcel = (code, note = 'Delivered', receivedBy = null, relation = null) =>
    supabase.rpc('deliver_parcel_v2', { p_code: code, p_note: note, p_received_by: receivedBy, p_relation: relation })

  return { registerDriver, driverSignup, mySpace, availableParcels, claimParcel, setNegotiatedFee, uploadPodPhoto, attachPodPhoto, deliverParcel }
}
