// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION DISPATCHER  (infrastructure ready — plug providers in below)
//
// Reads the `notification_outbox` view and delivers each notification over its
// channel: EMAIL (free / cheap), SMS, or WhatsApp. Then calls
// mark_notification_sent() / mark_notification_failed().
//
// Deploy + schedule this (pg_cron / Supabase scheduled functions), e.g. once a
// minute. To GO LIVE, implement a provider below and set the secrets. Nothing
// else changes — every enqueue point already works, and enqueue_notification()
// already prefers EMAIL (free) and falls back to SMS when there's only a phone.
// ─────────────────────────────────────────────────────────────────────────────

import { createClient } from 'jsr:@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

// ── EMAIL PROVIDER (free tiers: Resend 3k/mo, or Supabase SMTP) ───────────────
async function sendEmail(to: string, subject: string, body: string, trackUrl?: string): Promise<string> {
  const html = `
    <div style="font-family:system-ui,sans-serif;max-width:520px;margin:0 auto;padding:24px">
      <h2 style="color:#0B0E14;font-size:18px">${subject}</h2>
      <p style="color:#464E5C;font-size:15px;line-height:1.6">${body}</p>
      ${trackUrl ? `<a href="${trackUrl}" style="display:inline-block;margin-top:12px;background:#3730D9;color:#fff;text-decoration:none;padding:11px 20px;border-radius:10px;font-weight:600">Track it</a>` : ''}
      <p style="color:#8B93A3;font-size:12px;margin-top:24px">Enkiama Cargos · One parcel, one truth.</p>
    </div>`

  // ---- STUB: uncomment Resend (free 3,000 emails/month) when ready ----
  // const res = await fetch('https://api.resend.com/emails', {
  //   method: 'POST',
  //   headers: { 'Authorization': `Bearer ${Deno.env.get('RESEND_API_KEY')}`, 'Content-Type': 'application/json' },
  //   body: JSON.stringify({ from: 'Enkiama <noreply@enkiama.com>', to, subject, html }),
  // })
  // const json = await res.json()
  // if (!res.ok) throw new Error(JSON.stringify(json))
  // return json.id ?? 'sent'

  console.log(`[STUB EMAIL] to ${to}: ${subject}`)
  return 'stub-email-' + crypto.randomUUID().slice(0, 8)
}

// ── SMS / WhatsApp PROVIDER (Africa's Talking = great TZ coverage) ────────────
async function sendSms(to: string, body: string): Promise<string> {
  // ---- STUB: uncomment Africa's Talking / Twilio when ready ----
  // const res = await fetch('https://api.africastalking.com/version1/messaging', {
  //   method: 'POST',
  //   headers: { 'apiKey': Deno.env.get('AT_API_KEY')!, 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
  //   body: new URLSearchParams({ username: Deno.env.get('AT_USERNAME')!, to, message: body, from: 'ENKIAMA' }),
  // })
  // const json = await res.json()
  // if (!res.ok) throw new Error(JSON.stringify(json))
  // return json?.SMSMessageData?.Recipients?.[0]?.messageId ?? 'sent'

  console.log(`[STUB SMS] to ${to}: ${body}`)
  return 'stub-sms-' + crypto.randomUUID().slice(0, 8)
}
// ─────────────────────────────────────────────────────────────────────────────

Deno.serve(async () => {
  const { data: outbox, error } = await supabase.from('notification_outbox').select('*').limit(50)
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 })

  let sent = 0, failed = 0
  for (const n of outbox ?? []) {
    try {
      let ref: string
      if (n.channel === 'email') {
        ref = await sendEmail(n.to_email, n.subject || 'Enkiama update', n.body, n.track_url)
      } else {
        ref = await sendSms(n.to_phone, n.body)
      }
      await supabase.rpc('mark_notification_sent', { p_id: n.id, p_provider_ref: ref })
      sent++
    } catch (e) {
      await supabase.rpc('mark_notification_failed', { p_id: n.id, p_error: String(e) })
      failed++
    }
  }
  return new Response(JSON.stringify({ processed: outbox?.length ?? 0, sent, failed }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
