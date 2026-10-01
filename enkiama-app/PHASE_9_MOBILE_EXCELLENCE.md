# Phase 9 — Mobile Excellence

This phase treats the public Market experience as a mobile product rather than a compressed desktop layout.

## Scope

No Supabase schema, RPC, RLS, auth, ordering, property deal, storefront data, or tracking contracts changed. The phase is presentation-only.

## What changed

- Mobile safe-area support and dynamic viewport sizing (`svh` / `dvh`).
- Touch-target and iOS form zoom hardening.
- AppHeader account menu becomes a reachable bottom sheet on phones.
- Market discovery gains touch-sized horizontal navigation, snap behavior, and compact ledgers.
- Product gallery becomes edge-to-edge; the buy controls stay thumb-reachable; checkout becomes a safe-area-aware bottom sheet.
- Property category navigation and list/map switch become touch-first; mobile maps use viewport-aware height; listing imagery becomes immersive edge-to-edge.
- Property detail improves gallery, map, action sizing, and lightbox safe areas.
- Storefront hero fills the mobile viewport and product ledgers reflow instead of squeezing prices.
- Movement live map and receiver actions are sized for phone use without hiding the journey.
- My Movement dashboard has a full-height claim state, scroll-safe metrics, and stronger tap targets.

## Files touched

- `src/style.css`
- `src/components/AppHeader.vue`
- `src/views/MarketplaceView.vue`
- `src/views/ProductDetailView.vue`
- `src/views/PropertyView.vue`
- `src/views/PropertyDetailView.vue`
- `src/views/StorefrontView.vue`
- `src/views/TrackView.vue`
- `src/views/ReceiverView.vue`

All application logic in `<script>` blocks remains unchanged in this phase.
