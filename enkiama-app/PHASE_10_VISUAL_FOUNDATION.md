# Phase 10 — Visual Direction Reset

## Purpose

Phase 10 replaces the previous assumption that “premium” means a single dark canvas with oversized typography. It establishes the visual foundation that Phases 11–23 will use.

No marketplace, Supabase, authentication, order, property, storefront, delivery, or tracking contracts are changed in this phase.

## Principle

**Dark is an atmosphere, not the brand.**

Enkiama now has one design system with five route-aware material worlds:

- **Market — Parchment:** warm commerce/discovery canvas, deep forest ink, muted gold highlight.
- **Object — Porcelain:** clean product/object space with restrained warmth and low visual noise.
- **Place — Limestone:** land/geography atmosphere with earth, moss and limestone neutrals.
- **Business — Paper / Clay:** human, maker and storefront identity with warmer material tones.
- **Movement — Night:** the only deliberately dark world, using illuminated signal-teal and warm route highlights.

Operational/core screens use a neutral warm-stone foundation.

## Global typography

- Utility/body: Inter
- Display: Space Grotesk
- Editorial accent: Cormorant Garamond
- Codes/data: Spline Sans Mono

The V10 scale caps flagship typography below the previous extreme values. Future page redesigns should use `--t-hero`, `--t-display`, and the `.en-display` / `.en-title` primitives instead of inventing page-specific 150px+ headings.

## Material/depth model

V10 introduces:

- warm canvas and surface levels
- low-contrast material borders
- object and floating depth shadows
- image/media surfaces
- restrained glass only where context requires it
- quieter solid actions instead of glossy SaaS gradients
- reduced corner radii and less card-heavy framing

## Foundation primitives

New global classes include:

- `.en-page`
- `.en-shell`
- `.en-section`
- `.en-kicker`
- `.en-display`
- `.en-editorial`
- `.en-title`
- `.en-copy`
- `.en-material`
- `.en-media`
- `.en-float`
- `.en-object`
- `.en-action-line`
- `.en-grid-12`
- `.en-empty-composition`

These are composition primitives, not a new card library.

## Route-aware browser chrome

The existing `data-en-world` route system now drives the V10 color worlds. The mobile/browser `theme-color` is also updated on navigation so browser chrome follows Market, Product, Property, Business and Movement rather than remaining permanently dark.

## Changed files

- `src/style.css`
- `src/router/index.js`
- `index.html`
- `PHASE_10_VISUAL_FOUNDATION.md`

## Intentionally not redesigned yet

Phase 10 does **not** yet replace the hard-coded art direction inside Market, Product, Property, Storefront or Movement. Those screens retain their V9 composition until their dedicated correction phases. This avoids another uncontrolled “change everything at once” pass.

Next: **Phase 11 — Brand + Global Shell**.

## V10B — Foundation Enforcement

The first V10 established tokens. V10B applies them against the remaining V9 hard-coded flagship art direction before the global-shell redesign begins.

### Enforced now
- Market entrance is warm parchment / ivory rather than a flat black-green stage.
- Market display scale is capped and the serif accent is subordinate to the composition.
- Decorative orbits/grid are pushed into the background instead of acting as the primary visual idea.
- Market search is integrated into the material surface rather than behaving like an isolated bright form field.
- Property entrance is limestone / land-led; dark is no longer its default canvas.
- Empty property collections no longer reserve a large dead vertical block before Verification.
- Business storefront fallbacks are paper/clay when no cover photograph exists; real photography may still support a darker image overlay.
- Movement intentionally remains nocturnal, but receives layered illumination, route energy, reduced headline scale and a transparent line-based tracking field.
- Product/Object remains porcelain-led; dark is confined to Movement and checkout chapters.
- Mobile hero typography is separately capped to prevent billboard-scale headings from returning through old scoped rules.

### Still intentionally deferred
Phase 10B does not redesign page architecture, the global header, navigation model or media-slot architecture. Those belong to later phases. This pass exists to make the design foundation materially visible in the current application before those redesigns begin.
