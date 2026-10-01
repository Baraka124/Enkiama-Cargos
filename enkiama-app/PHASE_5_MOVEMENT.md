# Enkiama Market V5 — Movement Experience

Phase 5 redesigns the receiver-facing parcel journey without changing backend contracts.

Changed application files:
- `src/views/TrackView.vue`
- `src/views/ReceiverView.vue`

Core experience:
- Now → Movement → Live position → Custody → Arrival
- visual stage journey backed by existing parcel stages
- full custody/event ledger with actor, timestamp and notes when available
- existing live GPS surfaced as a dedicated movement chapter
- proof-of-delivery and confirmation moved into the arrival chapter
- reschedule/report/dispute retained as receiver agency controls
- My Deliveries redesigned as an active/completed movement dashboard
- route change hardening clears stale live-map/event state
- reduced-motion treatment included

No schema, RPC, auth, RLS, order contract, product, market, or property logic was changed.
