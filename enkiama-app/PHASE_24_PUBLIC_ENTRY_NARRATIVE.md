# Phase 24 — Public Entry + Narrative

Phase 24 redesigns the public homepage so the entry experience finally matches the visual and conceptual quality established across Market, Object, Business, Property and Movement.

## What changed

- Replaced the legacy dark-gradient marketing hero and SaaS-style cards with an editorial front door.
- Reframed Enkiama around three public worlds:
  - Market — commerce and objects
  - Property — geography and place
  - Movement — custody and delivery
- Removed invented parcel/customer examples from the homepage.
- Added a structured experience index instead of generic feature cards.
- Introduced dedicated material chapters for Market, Property and Movement using the same visual language established in later phases.
- Rewrote the trust section around identity, context, custody and proof rather than promotional claims.
- Reworked participation paths for businesses, carriers, drivers and property.
- Added responsive art direction for large desktop, laptop, tablet, phone and compact phone.
- Reused the existing reveal system and global shell rather than introducing a new motion framework.

## Deliberately unchanged

- Supabase schema and migrations
- RLS policies
- auth contracts
- marketplace RPCs
- storefront RPCs
- tracking RPCs
- property-deal RPCs
- package dependencies
- routing structure

## Source-of-truth workflow

From Phase 24 onward, GitHub `main` is the canonical project baseline. Changes are committed directly to `Baraka124/Enkiama-Cargos`; ZIP handoff is no longer the default workflow.
