# Enkiama Market V7 — Shared Motion & Transition System

Phase 7 connects the V2–V6 public experiences with one motion grammar while keeping commerce and Supabase contracts unchanged.

## Principles

- Motion communicates continuity, hierarchy or state; it is not decoration.
- The closer a user gets to a transaction, the quieter the interface becomes.
- Native browser View Transitions are progressive enhancement only.
- Reduced-motion preferences disable choreography and cursor cues.
- Coarse/touch pointers never receive the desktop action-cursor cue.

## What V7 adds

- Native same-document View Transitions where supported, with CSS fallback elsewhere.
- Shared visual continuity for product objects, property places, shop identity and parcel codes.
- A short readiness handshake (max 380 ms) so data-backed destination elements can exist before a native snapshot is taken.
- Chapter-level IntersectionObserver reveals with bounded stagger delays.
- A small supplemental action cursor cue (`VIEW`, `PLACE`, `ENTER`, `TRACK`, `OPEN`) on fine-pointer devices. The native pointer is never hidden.
- A unified top-edge navigation signal during route changes.
- Router scroll restoration / top reset behavior.
- Route “world” metadata on the root document for Market / Object / Place / Business / Movement.

## Shared continuity paths

- Market collection → Product Detail
- Storefront collection → Product Detail
- Product “More from…” → another Product Detail
- Property collection → Property Detail
- Market business → Storefront identity
- My Movement parcel → Track journey

## New shared files

- `src/lib/motion.js`
- `src/components/MotionCursor.vue`

## Modified shell files

- `src/main.js`
- `src/App.vue`
- `src/router/index.js`
- `src/style.css`

## Modified experience files

- `src/views/MarketplaceView.vue`
- `src/views/ProductDetailView.vue`
- `src/views/PropertyView.vue`
- `src/views/PropertyDetailView.vue`
- `src/views/StorefrontView.vue`
- `src/views/ReceiverView.vue`
- `src/views/TrackView.vue`

No Supabase schema, RPC implementation, RLS policy, authentication contract, order contract, property-deal contract, or tracking data contract was changed.

## Validation performed

- JavaScript syntax validation for all changed `<script setup>` blocks and JS modules.
- Template tag-balance validation for all changed Vue SFCs.
- CSS brace-balance validation for global and changed scoped CSS.
- Full `npm ci` / Vite build could not complete in the execution environment because dependency installation timed out; run `npm ci && npm run build` in the normal project environment for final runtime verification.
