# Phase 17 — Utility + Conversion Surfaces

Phase 17 deliberately reduces visual noise where users perform tasks. Expressive art direction remains in Market, Object, Business, Place and Movement; task surfaces use one quiet interaction grammar.

## Updated
- Global inputs, buttons, modals and operational form primitives
- Access / sign-in and fleet application
- Password reset
- Account settings
- Market filters / sorting / delivery controls
- Product checkout
- Property protected-purchase journey controls
- Operational workspace cards lose unnecessary hover lift / shadow

## Principles
- One strong primary action per task area
- Secondary actions are line/border based
- No gradients or decorative shadows on form controls
- Inline validation remains visible and local
- Mobile inputs remain 16px to prevent zoom
- No backend contracts changed

## Application source changed
- `src/style.css`
- `src/views/LoginView.vue`
- `src/views/ResetView.vue`
- `src/views/AccountView.vue`
- `src/views/MarketplaceView.vue`
- `src/views/ProductDetailView.vue`
- `src/views/PropertyDealView.vue`
