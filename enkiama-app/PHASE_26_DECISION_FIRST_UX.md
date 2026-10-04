# Phase 26 — Decision-First UX Refinement

Phase 26 is a screenshot-driven usability refinement focused on the moments where users search, compare, list, enquire and commit.

## Market

- Discovery is now results-first: controls lead directly into products/businesses instead of forcing users through a large narrative logistics chapter first.
- Destination filtering is always available beside discovery controls.
- Added an explicit All Tanzania destination state.
- Delivery-network storytelling now follows the useful inventory rather than blocking it.
- Missing business cover media uses a composed material fallback rather than error-like placeholder copy.
- Missing remote media retains intentional contextual labels.

## Property browse

- Category controls show real inventory counts instead of decorative sequence numbers.
- Collection/map controls remain visible while browsing.
- Property language distinguishes reviewed listings from independent legal verification.
- Public, detail and listing maps use OpenStreetMap tiles without a provider API-key dependency.

## Property listing

- Long-form listing UI is constrained to the viewport with internal scrolling.
- Dialog supports focus trapping and Escape dismissal.
- Sticky header and sticky submission controls keep orientation/actions reachable.
- Listing readiness shows Place, Photo, Lister and Declaration completion.
- Submission stays disabled until the minimum review-ready record is complete.
- Map code is lazy-loaded to preserve initial application performance.

## Property detail

- Buyers can enquire or begin a recorded purchase journey from the primary place identity area rather than hunting at the bottom.
- Mobile keeps decision actions reachable.
- Location/context maps use the same map provider as the rest of Property.
- Existing verification and due-diligence hierarchy remains explicit.

## Property transaction record

- Removed language that could imply Enkiama itself guarantees escrow, legal title verification or transaction protection where the underlying service may not.
- The experience now describes a recorded purchase process and preserves independent due-diligence responsibility.

## Deliberately unchanged

- Supabase schema
- RLS
- authentication
- marketplace RPCs
- property RPC signatures
- listing submission contract
- property deal contract
- package dependencies

## Validation

The GitHub Actions production build completed successfully after the combined Phase 26 changes.
