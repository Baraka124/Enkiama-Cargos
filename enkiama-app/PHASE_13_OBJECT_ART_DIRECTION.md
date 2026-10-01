# Phase 13 — Object / Product Art Direction

Phase 13 rebuilds Product Detail around the product itself while preserving every existing commerce and Supabase contract.

## Visual direction

- The Product world now uses the Phase 10 porcelain material system instead of a generic light commerce layout.
- The primary image sits on a raised object plinth with restrained physical depth.
- Real product media carries the composition; decorative UI is deliberately reduced.
- Secondary imagery becomes a horizontal image rail instead of a tiny equal-weight thumbnail grid.
- The seller appears before the title as quiet provenance, not as a trust badge stack.
- Product title scale is capped and balanced against the media rather than acting as a billboard.
- Descriptions use the editorial type voice to create contrast with operational commerce text.
- Variant controls, availability, payment terms and tracked fulfilment share one material language.
- The order action is contained in a small commitment surface; it is clear without becoming the visual hero.
- A compact object ledger exposes seller, category, place and fulfilment without creating more cards.
- The Movement chapter remains the deliberate dark contrast, but now uses layered green illumination instead of flat charcoal.
- Provenance uses a warm raised material panel.
- Related products use an asymmetric gallery rhythm instead of three identical cards.

## Mobile

- The primary object remains edge-to-edge.
- Secondary imagery stays swipeable.
- Product information is no longer dependent on a sticky desktop sidebar.
- The purchase action remains clear but is not permanently floating over the content.
- The object ledger becomes a two-column factual grid.
- Related objects use one featured item followed by a compact two-column gallery.

## Contracts preserved

No changes were made to:

- `get_product`
- `delivery_confidence`
- `product_reviews`
- `place_order_v2`
- Supabase schema / migrations / RLS
- checkout arguments
- authentication
- tracking contracts

Application source changed:

- `src/views/ProductDetailView.vue`
