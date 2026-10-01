# Phase 14 — Business / Human World

Phase 14 changes the public storefront from a seller-profile treatment into a warmer, media-led business environment while preserving every existing storefront, reputation, product and delivery contract.

## Direction

- Business is no longer presented as a dark campaign hero by default.
- Warm paper, clay, product imagery and the storefront's own accent create the atmosphere.
- The hero pairs business identity with **real storefront media**: the saved cover image when present, otherwise a real product object.
- No invented maker portraits or stock people are introduced. The experience only uses media that the business already supplies.
- When a real cover image exists, a featured product can overlap it so the relationship between the business and what it sells becomes the composition.
- Typography is deliberately restrained; imagery, place and business context carry more visual weight.

## Experience structure

1. **Business** — identity, place, trading history, real media and a featured object.
2. **Story** — the business description, what it sells, where it is based and where it reaches.
3. **Collections** — real products remain the central commerce path, with an editorial feature object plus a quieter ledger.
4. **Marketplace record** — tracked deliveries, on-time performance, buyer rating, verified delivery and stated trading history are kept factual and visually separate from brand storytelling.
5. **Buyer notes** — existing storefront delivery feedback is treated editorially, while product reviews remain attached to individual objects.
6. **Continue** — browse, contact, share and tracking remain clear but low-noise.

## Data / contract guardrails

No changes were made to:

- `get_storefront`
- `shop_reputation`
- `storefront_product_ratings`
- product routes
- ordering
- auth / RLS
- Supabase schema or migrations
- delivery / tracking contracts

## Application source changed

- `src/views/StorefrontView.vue`

The view adds only presentation-derived computed state for media fallback, reach summary and broken-image handling.
