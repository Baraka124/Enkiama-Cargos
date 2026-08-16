-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v14 — fix profile RLS recursion (500)
--  The v5 profile_admin_manage policy queried `profile` inside its own
--  USING/CHECK clause: (select carrier_id from profile where ...).
--  A policy on profile that reads profile recurses infinitely →
--  Postgres aborts the query with a 500. This hit carrier_admins
--  (like the Enkiama owner) whenever their profile was re-read.
--
--  Fix: use a SECURITY DEFINER helper my_carrier_id() that bypasses
--  RLS, so the policy no longer re-triggers itself.
-- ══════════════════════════════════════════════════════════════════

-- security-definer helpers (bypass RLS; no recursion)
create or replace function my_carrier_id() returns uuid
  language sql stable security definer set search_path = public as $$
  select carrier_id from profile where user_id = auth.uid()
$$;

create or replace function my_role() returns text
  language sql stable security definer set search_path = public as $$
  select role from profile where user_id = auth.uid()
$$;

-- rebuild the policy using the helpers instead of an inline subquery
drop policy if exists profile_admin_manage on profile;

create policy profile_admin_manage on profile for all
  using ( my_role() = 'carrier_admin' and carrier_id = my_carrier_id() )
  with check ( my_role() = 'carrier_admin' and carrier_id = my_carrier_id() );

-- ══════════════════════════════════════════════════════════════════
--  After v14: reading a carrier_admin's profile no longer recurses.
--  The hat-switch (Run Enkiama as carrier) and carrier views load.
-- ══════════════════════════════════════════════════════════════════
