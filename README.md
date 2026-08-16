# Enkiama Cargos

The freight ledger every carrier runs on — a multi-tenant road-freight
platform for Tanzania. Carriers (USIRI and others) run their own book,
their own drivers, their own brand; senders and receivers stay in the
loop, money included.

**Stack:** Vue 3 + Vite - Supabase (Postgres, Auth, Realtime, Edge
Functions) - Leaflet. Deploys as a static site.

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
- Live driver GPS
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
