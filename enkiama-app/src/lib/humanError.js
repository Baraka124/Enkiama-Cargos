// Translate raw Supabase/Postgres errors into plain language a user can act on.
// Never let database jargon (constraint names, "violates", null value, etc.) reach the UI.
const RULES = [
  [/chk_discount_valid/i, 'The "compare at" price must be higher than the selling price.'],
  [/chk_fee_agreed_before_delivery/i, 'Agree the delivery fee before marking this delivered.'],
  [/chk_confirmed_has_pod_time/i, 'Add proof of delivery before confirming.'],
  [/chk_driver_required/i, 'Assign a driver before moving this parcel forward.'],
  [/enforce_driver_carrier|belongs to another carrier/i, 'That driver belongs to another carrier and can\'t carry this parcel.'],
  [/enforce_storefront_owner_role|cannot own a storefront/i, 'This account can\'t own a shop — shops need a business account.'],
  [/duplicate key|already exists|unique constraint/i, 'That already exists.'],
  [/null value|not-null|violates not/i, 'Please fill in all required fields.'],
  [/check constraint|violates|invalid input/i, 'Please check the details and try again.'],
  [/permission denied|not authorized|row-level security|rls/i, 'You don\'t have permission to do that.'],
  [/network|fetch failed|timeout|Failed to fetch/i, 'Network problem — check your connection and try again.'],
  [/rate limit|too many/i, 'Too many attempts — please wait a moment and try again.'],
]

export function humanError(err, fallback = 'Something went wrong — please try again') {
  const msg = typeof err === 'string' ? err : (err?.message || err?.error_description || '')
  if (!msg) return fallback
  for (const [re, friendly] of RULES) if (re.test(msg)) return friendly
  // if it still looks like raw DB/technical text, don't show it — use the fallback
  if (/relation|constraint|pg_|postgres|syntax|column .* does not|function .* does not/i.test(msg)) return fallback
  return msg
}
