# Phase 16 — Movement / Logistics World

Phase 16 rebuilds the receiver-facing logistics experience around route geography, live position, custody and arrival rather than dark poster styling.

## Public tracking

- Replaces the oversized "Where is your parcel?" entrance with a restrained `Follow what moves.` composition.
- The tracking code is integrated as a line-based journey control rather than a large white field.
- A semantic Sender → Carrier → You route field establishes what a tracking code reveals before a parcel is opened.
- The route visual does not invent live data: live-position language is explicitly conditional on an active delivery record.
- The current-state chapter replaces the decorative orbit with a real progress-derived route signal backed by the existing parcel stage.
- The dark Movement chapter now uses illuminated route geometry and meaningful stage nodes.
- The live Leaflet map remains data-backed by the existing `track_live_location` RPC.
- Custody becomes a lighter verification surface to create contrast and make the ledger easier to read.
- Arrival / proof remains warm and quiet.
- The explanatory Movement primer is also lightened so the page does not become one continuous dark wall.

## My Movement

- Receiver phone linking becomes a split composition with an explicit Sender → Carrier → You route model.
- The linked-receiver overview uses a compact route signal plus Active / Arrived / Attention metrics rather than a billboard-scale hero.
- Existing delivery lists, stage progress, attention state and route links remain unchanged functionally.

## Guardrails

No Supabase schema, RPC implementation, RLS policy, authentication contract, tracking contract, dispute/review flow, receipt confirmation flow, live-location contract or receiver-claim contract changed.

Application source changed:

- `src/views/TrackView.vue`
- `src/views/ReceiverView.vue`
