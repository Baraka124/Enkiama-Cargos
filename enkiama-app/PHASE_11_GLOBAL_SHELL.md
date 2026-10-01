# Phase 11 — Brand + Global Shell

## Purpose

Phase 11 gives Enkiama one coherent product frame across Market, Object, Place, Business, Movement and the operational workspaces.

This phase does not redesign the individual page compositions. It replaces the fragmented header/footer layer so later art-direction phases are built inside one mature brand shell.

## What changed

### One header system
`src/components/AppHeader.vue` is now route-aware and material-aware.

- one Enkiama logo treatment
- Market / Property / Track primary navigation
- route/world context next to the brand
- contextual subtitles where useful
- quiet sign-in treatment instead of a generic bright CTA
- authenticated identity chip and workspace menu
- carrier identity remains supported for carrier workspaces
- Movement receives the dark-shell variant; all other worlds inherit their material canvas
- mobile uses a compact Explore sheet instead of compressing desktop navigation
- account controls remain a reachable bottom sheet on narrow screens

### One footer system
`src/components/SiteFooter.vue` is new.

It gives public Enkiama experiences a common ending with:

- Enkiama lockup
- concise brand line
- Market / Property / Track navigation
- business / driver / sign-in pathways
- route-aware light/dark material behavior
- safe-area-aware mobile spacing

### Fragmented public headers removed
The independent Landing, Market and Login header treatments are no longer rendered. They now use the same AppHeader as Product, Property, Storefront and Movement.

### Public-world footer consolidation
The common SiteFooter is now used by:

- Landing
- Market
- Product Detail
- Property
- Property Detail
- Storefront
- Tracking / Movement

## Changed application files

- `src/components/AppHeader.vue`
- `src/components/SiteFooter.vue` (new)
- `src/views/LandingView.vue`
- `src/views/LoginView.vue`
- `src/views/MarketplaceView.vue`
- `src/views/ProductDetailView.vue`
- `src/views/PropertyView.vue`
- `src/views/PropertyDetailView.vue`
- `src/views/StorefrontView.vue`
- `src/views/TrackView.vue`

## Contracts intentionally untouched

- Supabase schema and migrations
- RLS
- authentication contracts
- marketplace/product RPCs
- property RPCs
- checkout/order contracts
- live tracking RPCs
- receiver actions
- storefront data contracts

## Design rules established

1. The logo is never floating randomly inside each page composition.
2. Global navigation is quiet text navigation, not a row of dashboard buttons.
3. A page may have its own atmosphere, but not its own unrelated navigation system.
4. Movement may use a dark shell; darkness is still not the default Enkiama identity.
5. Mobile navigation is designed as a reachable interaction rather than a squeezed desktop header.
6. Public experiences end in one consistent Enkiama footer rather than bespoke taglines.

Next: **Phase 12 — Market Art Direction**.
