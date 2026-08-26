-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v13 — fix platform_admin RLS recursion
--  The v5 read policy referenced platform_admin from within its own
--  USING clause, creating a self-referential check that blocked the
--  row from ever being read by the app (RLS returned nothing, so
--  is_platform_admin() was false in-app even though the row exists).
--
--  Fix: a platform admin can read their OWN row directly by uid.
-- ══════════════════════════════════════════════════════════════════

drop policy if exists padmin_read on platform_admin;

create policy padmin_read_own on platform_admin for select
  using (user_id = auth.uid());

-- is_platform_admin() is SECURITY DEFINER so it already bypasses RLS;
-- keep it, but ensure it's defined (idempotent).
create or replace function is_platform_admin() returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (select 1 from platform_admin where user_id = auth.uid())
$$;

-- ══════════════════════════════════════════════════════════════════
--  After v13: signing in as a platform admin correctly loads admin
--  status, and you land on the Platform console instead of "welcome".
-- ══════════════════════════════════════════════════════════════════
