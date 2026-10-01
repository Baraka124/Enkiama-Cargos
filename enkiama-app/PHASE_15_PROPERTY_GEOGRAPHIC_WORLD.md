# Phase 15 — Property / Geographic World

Phase 15 turns Property into a landscape-, geography-, and verification-led environment rather than a product catalogue with a map attached.

## Direction

- Property uses a dedicated limestone / sand / muted clay / forest-ink material language.
- Dark is removed from the Property journey, including the verification chapter.
- Real listing photography remains the primary visual material; no stock imagery is introduced.
- Geography is visible from the first screen and continues through collection, map, detail, verification and terms.

## Property browse

- Replaces the old dark arrival with a light landscape stage.
- Featured places carry location and size directly over real listing media.
- Listing collections receive stronger landscape depth and quieter typography.
- The map inherits the Property palette and subdued cartography treatment.
- Price markers and selected-place cards are integrated into the same geographic material system.
- Empty collections no longer create dead white space: they become a compact terrain composition with useful next actions.
- Verification is presented on a warm earth material rather than a generic trust block.

## Property detail

- Place media is larger and more landscape-led.
- Location precision (pinned / approximate / unavailable) is surfaced directly in the place identity.
- Context becomes Ground / Context and gives the map more visual weight.
- Map tiles are visually subdued so listing geography reads as part of the art direction rather than a third-party widget.
- Verification stays light and separates the physical place from the legal claim.
- Terms remain the quietest chapter.

## Backend / contract guardrails

No Supabase schema, RLS, auth, property RPC, deal RPC, or transaction contract changed. Existing calls remain unchanged:

- `browse_properties`
- `property_map`
- `my_properties`
- `withdraw_property`
- `property_detail`
- `start_property_deal`

## Application source changed

- `src/style.css`
- `src/views/PropertyView.vue`
- `src/views/PropertyDetailView.vue`

## Validation

- JavaScript syntax checked for both changed Vue scripts.
- Vue template tag structure checked for both changed views.
- CSS brace structure checked for global and scoped Phase 15 CSS.
- Cumulative and patch ZIP archives integrity-tested after packaging.
