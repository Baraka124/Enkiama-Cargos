# Enkiama Market — Phase 8: Checkout & Conversion

Phase 8 makes the transactional moment the quietest part of the Market experience.

## Flow

1. **Choose** — variants/options and quantity.
2. **Who** — receiver name and operational phone number.
3. **Where** — delivery address or meeting point.
4. **Confirm** — one final review, fixed cash-on-delivery contract, and total due.
5. **Movement** — successful orders expose the real tracking code and carry it into the existing tracking experience through the V7 shared-transition system.

## Guardrails

- `place_order_v2` and every existing RPC argument remain unchanged.
- No new payment method is invented. The UI reflects the existing cash-on-delivery workflow.
- No Supabase schema, RLS, auth, delivery or tracking contract changed.
- Validation is inline and step-specific rather than relying on transient toast messages.
- Quantity is normalized and constrained to known tracked stock when available.
- Zero tracked stock is treated as unavailable in the product UI.
- Mobile checkout uses a single vertical flow with a sticky continuation/confirmation action.
- Reduced-motion users do not receive checkout step animation.

## Application source changed

- `src/views/ProductDetailView.vue`

The rest of the V7 application remains unchanged.
