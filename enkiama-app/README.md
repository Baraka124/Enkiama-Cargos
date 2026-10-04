# Enkiama Cargos — Phase 23 Final Production Hardening

This cumulative project includes all experience work through Phase 23. The final Market, Object, Business, Property and Movement art direction now includes route fallbacks, defensive formatting, stale-session hardening, map/data guards, proof-media governance, compact-screen protection and final release QA. See `PHASE_23_FINAL_PRODUCTION_HARDENING.md`.

# Enkiama Cargos

The freight ledger every carrier runs on — a multi-tenant road-freight
platform for Tanzania. Carriers (USIRI and others) run their own book,
their own drivers, their own brand; senders and receivers stay in the
loop, money included.

**Stack:** Vue 3 + Vite - Supabase (Postgres, Auth, Realtime, Edge
Functions) - Leaflet. Deploys as a static site.

---

## Current experience build

**V26 — Decision-First UX Refinement**

The cumulative experience includes the visual foundation, global shell, Market, Object, Business, Property, Movement, utility/conversion refinement, governed media, spatial motion, resilient states, responsive art direction, and accessibility/performance hardening. See the phase notes through `PHASE_24_PUBLIC_ENTRY_NARRATIVE.md`.

---

## 1 - Push to GitHub

    git init
    git add .
    git commit -m "Enkiama Cargos"
    git branch -M main
    git remote add origin https://github.com/<you>/enkiama-cargos.git
    git push -u origin main

`.env` is git-ignored on purpose — your Supabase keys never go to
GitHub. `.env.example` is committed as a template.

## 2 - Run locally

    npm install
    cp .env.example .env     # Windows: copy .env.example .env
    # put your Supabase URL + anon key in .env
    npm run dev              # http://localhost:5173

## 3 - Deploy (GitHub -> Vercel)

GitHub stores the code; a host runs it. Vercel is the quickest:

1. Go to vercel.com -> New Project -> import your GitHub repo.
2. Framework preset: Vite (auto-detected). Build: `npm run build`,
   output: `dist` (auto-filled).
3. Add two Environment Variables (same names as your `.env`):
   - VITE_SUPABASE_URL
   - VITE_SUPABASE_ANON_KEY
4. Deploy. Every future `git push` redeploys automatically.

Netlify and Cloudflare Pages work identically — `netlify.toml` and
`vercel.json` in this repo handle SPA routing so deep links like
`/track/USR-4471` don't 404.

---

## Database (Supabase SQL Editor, run in order)

Migration files are in `supabase/migrations/` plus the schema files.
v1-v3 you may already have; v4 is the accounts + security layer.

1. schema.sql        — tables (v1)
2. schema-v2.sql     — customers, exceptions, retry
3. schema-v3.sql     — notification outbox
4. supabase/migrations/v4_auth_and_rls.sql — accounts + real RLS

After v4, you must be signed in with a profile row to see data.

### First account
1. In the app: Office / Dispatch -> Create account (email + password,
   6+ chars). In Supabase -> Authentication -> Providers -> Email:
   enable it and turn OFF "Confirm email" for testing.
2. Link your account to a carrier (SQL Editor):

    insert into profile (user_id, carrier_id, role, name)
    select u.id, (select id from carrier where slug='usiri'), 'dispatch', 'You'
    from auth.users u where u.email = 'you@example.com'
    on conflict (user_id) do update
      set carrier_id = excluded.carrier_id, role = excluded.role;

3. Sign in -> USIRI dispatch console.

If signed in but you see an "Almost there" screen, your account isn't
linked yet — run the SQL above with your email.

## Routes
- /login        — email (dispatch) / phone-OTP (driver)
- /dispatch     — operations console (dispatch role)
- /driver       — driver map + run (driver role)
- /track/:code  — public receiver tracking (no account)

## Mobile money (the moat)
supabase/functions/momo-webhook/ auto-reconciles a parcel when a
receiver pays COD by M-Pesa / Tigo Pesa / Airtel, using the tracking
code as the payment reference.

    supabase functions deploy momo-webhook --no-verify-jwt
    supabase secrets set WEBHOOK_SECRET=your-shared-secret

Point your payment aggregator's callback at:
https://<project-ref>.functions.supabase.co/momo-webhook

## What's next
- SMS provider (Twilio / Africa's Talking) for driver OTP + notifications
- PWA (installable on phones)

---

## v5 · Platform layer (multi-tenant)

Migration `supabase/migrations/v5_platform_layer.sql` adds the platform
tier. Run it in the Supabase SQL Editor after v1-v4.

It creates:
- `platform_admin` — who operates Enkiama the platform (seeds YOU)
- `carrier_admin` role + team management
- `create_carrier_with_admin()` — one-call carrier onboarding
- driver-must-match-carrier enforcement
- Enkiama as a carrier + a driver (Salum) + 2 test consignments
  addressed to +34659447627 so you can walk the whole loop

After running it:
- You log in and land on the **Platform console** (`/platform`) — onboard
  and oversee carriers.
- **↔ Run Enkiama as carrier** switches you into the carrier console.
- **↔ Platform console** (in the carrier view) switches you back.
- Onboard a carrier → its admin claims the spot by signing up with the
  invited email (the `claim_invite_on_signup` trigger links them).

### Roles
- **platform_admin** — Enkiama; sees all carriers; onboards them
- **carrier_admin** — runs one carrier; manages its drivers + staff + board
- **dispatch** — runs the board for one carrier
- **driver** — their own run only
- senders/receivers — account-less, phone + code
> **Current visual baseline:** V15 — Market, Object, Business and Property now have dedicated art direction built on the V10 material system. Property is landscape/geography-led; Movement alone retains a nocturnal atmosphere.

## Phase 13 — Object / Product Art Direction

Product Detail is now image-led and materially aligned with the Object world: porcelain staging, restrained typography, quieter commerce controls, a compact object ledger, richer media treatment, and asymmetric related-object discovery. Commerce/Supabase contracts remain unchanged.


## Phase 14 — Business / Human World

Public storefronts are now warm, media-led business environments rather than generic seller profiles. Real business cover media, logo, region, story, products, delivery reach and marketplace reputation drive the composition. When no cover exists, a real product becomes the visual anchor instead of a dark fallback hero. No storefront, ordering, auth, reputation or Supabase contracts changed.


## Phase 15 — Property / Geographic World

Property is now a light earth-toned geographic environment: landscape-led arrival, integrated mapping, composed empty states, place/context hierarchy, light verification, and calmer terms. Real listing data and the existing property RPC/deal contracts are unchanged.


## Phase 17 — Utility + Conversion Surfaces
Task-oriented controls now use a quiet common system across search/filtering, access, account, checkout and protected purchase flows. Backend contracts remain unchanged.


## Phase 18 — Governed Media System

The flagship public experience now shares one media renderer for stable loading, crop/fit, fallbacks, transition continuity and reduced-motion-safe skeletons. Product, business and property uploads also receive purpose-aware quality guidance. See `PHASE_18_MEDIA_SYSTEM.md`.

## Phase 19 — Spatial Depth + Motion

The public experience now uses one restrained spatial grammar: shared media depth, reveal variants, object/place continuity and state-driven logistics motion. Fine-pointer depth is disabled on touch devices and for reduced-motion users. Utility and transactional surfaces remain intentionally still. See `PHASE_19_SPATIAL_DEPTH_MOTION.md`.

## Phase 20 — Resilient states
Loading, zero-result, sold/unavailable, missing-record, connectivity and offline states now use one world-aware recovery language instead of generic spinners, broken empty pages or conflating network failure with "not found".


## Phase 21 — Responsive Art Direction

Large desktop, laptop, tablet, phone and compact-phone layouts now have deliberate composition rules rather than simple scale-down behavior. The public shell and all flagship Market worlds share device-tier spacing, media scale, stacking, and touch behavior without changing data or commerce contracts. See `PHASE_21_RESPONSIVE_ART_DIRECTION.md`.


## Phase 22 — Accessibility + Performance

Keyboard focus, route announcements, modal focus management, contrast, reduced-motion/data behavior, lazy public maps, background polling suspension and below-fold rendering are now part of the production baseline. Backend/data contracts remain unchanged. See `PHASE_22_ACCESSIBILITY_PERFORMANCE.md`.


## Phase 23 — Final Production Hardening

The cumulative release now includes a designed 404 route, defensive number/date formatting, map-coordinate guards, governed proof media, auth-header hydration hardening, long-content overflow protection, compact/wide-screen stress protection and final release QA. Backend/data contracts remain unchanged. See `PHASE_23_FINAL_PRODUCTION_HARDENING.md`.


## Phase 24 — Public Entry + Narrative

The homepage is now an editorial index into Market, Property and Movement rather than a legacy SaaS-style marketing page. The entry experience uses the same material worlds, typography, restrained motion and trust language as the redesigned public product. No backend contracts changed. See `PHASE_24_PUBLIC_ENTRY_NARRATIVE.md`.


## Phase 25 — Operational System Consolidation

Authenticated workspaces now follow the same visual discipline as the public system: denser operational hierarchy, line-based tabs and ledgers, task-first driver surfaces, calmer seller management, and unified role onboarding. Backend contracts remain unchanged. See `PHASE_25_OPERATIONAL_SYSTEM_CONSOLIDATION.md`.


## Phase 26 — Decision-First UX Refinement

Screenshot-driven refinement now prioritizes useful inventory and decisions: Market results appear before logistics storytelling, destination filtering stays available, Property uses real category counts, listing readiness is explicit, buyer actions are reachable earlier, map behavior is consistent, and transaction language avoids overstating platform guarantees. See `PHASE_26_DECISION_FIRST_UX.md`.
