// ══════════════════════════════════════════════════════════════════
//  Enkiama Cargos · momo-webhook  (Supabase Edge Function, Deno)
//
//  THE MOAT. A receiver pays COD via M-Pesa / Tigo Pesa / Airtel Money
//  to the carrier's till, using the parcel CODE as the payment reference.
//  The provider (or an aggregator like Selcom / ClickPesa / Africa's
//  Talking) POSTs a callback here. We match the reference to a parcel
//  and auto-reconcile it — no driver honesty required, no cash to lose.
//
//  Deploy:  supabase functions deploy momo-webhook --no-verify-jwt
//  Then point your provider's callback URL at:
//    https://<project-ref>.functions.supabase.co/momo-webhook
//
//  Security: set a shared secret in your provider + as WEBHOOK_SECRET
//  (supabase secrets set WEBHOOK_SECRET=...). We reject calls without it.
// ══════════════════════════════════════════════════════════════════

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, // service role: bypasses RLS server-side
)
const WEBHOOK_SECRET = Deno.env.get('WEBHOOK_SECRET') ?? ''

// Normalise the many provider payload shapes into one.
function parsePayload(body: any) {
  // Common fields across Tanzanian aggregators; extend as needed.
  const reference =
    body.reference ?? body.transactionReference ?? body.billReference ??
    body.accountReference ?? body.utilityref ?? ''
  const amount = Number(body.amount ?? body.transAmount ?? body.TransAmount ?? 0)
  const providerRef =
    body.transactionId ?? body.transID ?? body.TransID ?? body.id ?? ''
  const provider =
    body.provider ?? body.channel ?? body.paymentProvider ?? 'mobilemoney'
  const payerPhone = body.msisdn ?? body.phone ?? body.payerPhone ?? ''
  return { reference, amount, providerRef, provider, payerPhone }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // shared-secret check (header or query param, provider-dependent)
  const url = new URL(req.url)
  const secret = req.headers.get('x-webhook-secret') ?? url.searchParams.get('secret') ?? ''
  if (WEBHOOK_SECRET && secret !== WEBHOOK_SECRET) {
    return new Response('Unauthorized', { status: 401 })
  }

  let body: any
  try { body = await req.json() } catch { return new Response('Bad JSON', { status: 400 }) }

  const { reference, amount, providerRef, provider, payerPhone } = parsePayload(body)
  if (!reference) return new Response('Missing reference', { status: 400 })

  // find the parcel by its code (the reference the payer used)
  const { data: cons, error: cErr } = await supabase
    .from('consignment')
    .select('id, code, carrier_id')
    .ilike('code', reference.trim())
    .maybeSingle()

  if (cErr) return new Response('DB error', { status: 500 })
  if (!cons) {
    // log the orphan payment so dispatch can reconcile manually
    await supabase.from('notification').insert({
      carrier_id: null, to_phone: payerPhone, channel: 'sms', event: 'confirmed',
      body: `Unmatched mobile-money payment ${providerRef} ref="${reference}" amount=${amount}`,
    })
    return new Response('No matching consignment', { status: 202 })
  }

  // reconcile the payment: mark momo confirmed + state collected
  await supabase.from('payment').update({
    mode: 'mobilemoney',
    state: 'collected',
    momo_provider: provider,
    momo_reference: providerRef,
    momo_confirmed: true,
    updated_at: new Date().toISOString(),
  }).eq('consignment_id', cons.id)

  // record it on the custody log so everyone in the loop sees it
  await supabase.from('custody_event').insert({
    consignment_id: cons.id,
    stage: 'delivered',
    note: `Mobile-money payment confirmed (${provider}, ${amount}) ref ${providerRef}`,
    actor_role: 'system',
    actor_name: 'MoMo',
  })

  return new Response(JSON.stringify({ ok: true, matched: cons.code }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
