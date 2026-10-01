# Phase 20 — Resilient Empty, Loading & Error States

Phase 20 treats absence, delay, unavailability and connectivity failure as first-class product states rather than visual exceptions.

## Shared state language

A new `src/components/ExperienceState.vue` provides world-aware states for:
- loading
- empty results
- connection/data errors
- unavailable/sold objects
- offline/resilient messaging

The component adapts its material treatment to Market, Object, Place, Business and Movement rather than using one generic alert card.

## Behavioural corrections

- Market distinguishes a true zero-result search from a failed data request and gives recovery actions.
- Product Detail distinguishes "not published" from "could not load" and keeps sold-out objects readable while closing ordering.
- Property Detail distinguishes withdrawn/unpublished listings from temporary load failure.
- Storefront distinguishes an unpublished business, a network/load failure, and a real business with an empty collection.
- Public Tracking distinguishes an invalid/nonexistent code from a tracking-service failure.
- My Movement distinguishes no deliveries from a failed delivery-list refresh.
- The global offline banner no longer promises background syncing; it accurately warns that live data/actions may be unavailable until reconnection.

## Guardrails

- No Supabase schema, RPC, RLS, auth, order, property-deal or tracking contract changed.
- No package dependency was added.
- Existing business data remains the source of truth.
