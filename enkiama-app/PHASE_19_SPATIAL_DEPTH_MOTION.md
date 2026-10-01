# Phase 19 — Spatial Depth + Motion

Phase 19 turns the established Enkiama visual worlds into a restrained spatial system. Motion is permitted only when it communicates depth, continuity, or state. Utility and transactional surfaces remain motion-neutral.

## Motion principles

- Static composition remains primary.
- Media, not typography or controls, carries most spatial depth.
- Pointer depth is intentionally tiny (generally 2–14 px).
- Touch/coarse-pointer devices do not receive pointer-following depth.
- `prefers-reduced-motion` disables depth, route animation, reveal choreography, and long shared transitions.
- Checkout, forms, account, filters, and operational utilities are explicitly excluded from spatial motion.

## Shared system

### `v-depth`
A new global Vue directive driven by one shared requestAnimationFrame controller. It combines subtle pointer response and viewport-relative scroll depth without attaching a separate animation loop to every object.

### Reveal variants
`v-reveal` now supports four variants:
- `copy` — restrained copy rise / focus
- `media` — image-led uncover
- `line` — horizontal extension
- `section` — quiet chapter entrance

### Shared continuity
Existing native View Transition names remain the continuity layer for products, property, business identity, and parcel codes. Phase 19 lengthens named-object continuity while keeping the root exposure transition calm.

## World-specific choreography

### Market
- Main product, secondary product, and business media occupy different depth planes.
- Real marketplace media responds subtly to pointer/scroll position.
- Property contour lines react only on intentional hover.
- Search and filters remain motion-neutral.

### Object / Product
- The porcelain object plinth gains restrained physical depth.
- Product information reveals independently from the object.
- Delivery-route lines and nodes resolve when the Movement chapter enters view.
- Related objects receive only very light media depth.

### Business
- Business cover and featured object occupy separate spatial planes.
- Story imagery reveals as media rather than generic sections.
- Collection feature imagery receives small depth without moving product ledgers.

### Property
- Featured and collection landscape media receives slower, horizontal-feeling depth.
- Property Detail lead photography shares the same spatial behavior.
- Maps remain functional and mostly static; they only receive a tiny hover lift on fine-pointer devices.

### Movement
- Route dashes move in the direction of travel.
- Current-stage signals use a slow pulse that represents live state.
- Movement progress keeps its existing real stage percentages.
- No fake location motion is created.

## Application source changed

- `src/main.js`
- `src/lib/motion.js`
- `src/style.css`
- `src/views/MarketplaceView.vue`
- `src/views/ProductDetailView.vue`
- `src/views/StorefrontView.vue`
- `src/views/PropertyView.vue`
- `src/views/PropertyDetailView.vue`
- `src/views/TrackView.vue`
- `src/views/ReceiverView.vue`

No Supabase schema, RPC, RLS, authentication, ordering, payment, property-deal, storefront-data, or tracking-data contract changed.
