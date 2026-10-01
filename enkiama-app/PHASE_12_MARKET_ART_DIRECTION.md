# Phase 12 — Market Art Direction

Phase 12 recomposes the public Market experience around real marketplace media, useful objects, and restrained editorial hierarchy.

## Design correction

The previous Market arrival relied too heavily on a dark canvas, oversized centered typography, decorative orbit geometry, and small floating labels. Phase 12 removes that composition entirely.

The new arrival uses:

- a warm parchment / mineral canvas rather than a dark stage;
- a two-column editorial composition on wide screens;
- controlled display typography with a smaller maximum scale;
- actual Supabase product imagery as the dominant visual material;
- a real storefront cue loaded from the existing public storefront RPC;
- a geographic Property cue using a restrained contour treatment rather than fake stock imagery;
- integrated line-based search;
- Goods, Businesses, and Property as explicit navigable market worlds;
- meaningful secondary information instead of decorative circles.

## Real data, not staged imagery

The hero product images are taken from the same product results already used by Market. The storefront cue uses `browseStorefrontsV2`, which already powers the existing business discovery view. No new database contract, table, RPC, or migration was introduced.

If product imagery is temporarily unavailable, the hero has a designed material fallback rather than a broken image or an empty gap.

## Discovery layer

The existing product, category, corridor, storefront, filtering, sorting, search, and navigation behavior is retained. Phase 12 also reduces the scale of the delivery-network and collection headings, gives featured imagery more physical depth, and turns the business conversion area into a warm material panel.

## Responsive behavior

The desktop collage becomes a deliberate stacked media composition on tablets and mobile. Product photography remains visible on mobile rather than being removed to make the layout fit.

## Scope

Application source change:

- `src/views/MarketplaceView.vue`

No changes were made to:

- Supabase migrations or functions;
- RLS;
- auth;
- ordering;
- tracking;
- Property transactions;
- storefront contracts;
- product search contracts.

The only additional public call is an existing `browseStorefrontsV2` read used to give the Market arrival a real business identity cue.
