# Phase 6 — Shops & Business Identity

Phase 6 turns the public storefront into a distinct business environment while preserving the marketplace data contracts established in earlier phases.

## Experience structure

1. **Identity** — brand accent, cover, logo, region, trading history and a featured object establish the business before commerce controls appear.
2. **Business story** — what the business sells, where it is based and where it delivers are presented editorially.
3. **Collections** — existing shop sections become alternating curated collections with a hero object and a quieter product ledger.
4. **Provenance** — existing shop reputation data is surfaced as marketplace record: tracked deliveries, on-time fulfilment, buyer rating, verified delivery and stated trading history.
5. **Continue** — product exploration, contact, sharing and order tracking remain clear, low-noise actions.

## Hardening

- Storefront route changes now reload/reset shop-specific data instead of retaining stale state.
- Broken product imagery is reset between storefronts.
- The legacy embedded quick-order modal was removed because it had no active trigger and duplicated the Phase 3 Product Detail purchase journey.
- Product links continue to use `/shop/:slug/product/:id` as the single buyer purchase path.
- `get_storefront`, `shop_reputation`, `storefront_product_ratings`, auth, RLS, ordering and delivery contracts were not modified.
- `prefers-reduced-motion` is respected.

## Application source changed

- `src/views/StorefrontView.vue`
