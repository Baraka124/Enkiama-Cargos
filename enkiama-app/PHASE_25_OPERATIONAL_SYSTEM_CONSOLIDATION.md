# Phase 25 — Operational System Consolidation

Phase 25 brings the authenticated operating surfaces into the same design system as the public experience without changing backend contracts.

## Covered surfaces

- Dispatch
- Platform / Admin
- Sender / Business workspace
- Driver
- Receiver / My Movement
- Storefront Management
- Join / role entry
- Invited-driver onboarding
- Driver application
- Unassigned-account state

## Design direction

- Operations are denser and calmer rather than more decorative.
- Tabs, metrics, ledgers and working lists use line-based hierarchy instead of stacked SaaS cards.
- Driver remains task-first with stronger next-stop hierarchy and fewer decorative surfaces.
- Seller management behaves as an operational record rather than a marketing dashboard.
- Onboarding uses institutional utility and role context rather than dark promotional gradients.
- Receiver movement remains visually distinct but aligned with the operational system.

## Deliberately unchanged

- Supabase schema and migrations
- authentication contracts
- RPC signatures
- dispatch behavior
- carrier operations
- driver workflows
- storefront commerce behavior
- tracking contracts
- package dependencies

## Validation

The repository GitHub Actions workflow runs `npm ci` and `npm run build` on every push. The combined Phase 25 baseline completed successfully on `main`.
