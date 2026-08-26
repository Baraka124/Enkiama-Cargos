-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v11 — authentication hardening
--  Run on top of v1-v10. Makes identity robust:
--   1. Atomic sender signup — a new auth user with sender intent gets a
--      profile via trigger (no more two-step orphan risk)
--   2. Self-service profile update (name, phone) — safe, own-row only
--   3. A guard so a user can never change their own role/carrier
-- ══════════════════════════════════════════════════════════════════

-- ── 1) ATOMIC SENDER SIGNUP ───────────────────────────────────────
-- The claim_invite trigger (v5) already links invited carrier staff.
-- For senders (no invite), we auto-create a sender profile when the
-- new auth user carries sender intent in their metadata.
-- The app sets: options.data = { intent: 'sender', name: '...' }
-- on signUp, so the trigger can read raw_user_meta_data.
create or replace function handle_new_user() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  v_intent text := new.raw_user_meta_data->>'intent';
  v_name   text := coalesce(new.raw_user_meta_data->>'name','');
  inv      carrier_invite%rowtype;
begin
  -- 1) invited carrier staff take priority (claim their invite)
  select * into inv from carrier_invite where email = lower(new.email) and not claimed;
  if found then
    insert into profile (user_id, carrier_id, role, name)
    values (new.id, inv.carrier_id, inv.role, v_name)
    on conflict (user_id) do update set carrier_id = excluded.carrier_id, role = excluded.role;
    update carrier_invite set claimed = true where id = inv.id;
    return new;
  end if;

  -- 2) sender intent → create a sender profile (no carrier)
  if v_intent = 'sender' then
    insert into profile (user_id, role, name)
    values (new.id, 'sender', v_name)
    on conflict (user_id) do nothing;
  end if;

  return new;
end $$;

-- replace the older single-purpose trigger with this unified one
drop trigger if exists trg_claim_invite on auth.users;
drop trigger if exists trg_handle_new_user on auth.users;
create trigger trg_handle_new_user
  after insert on auth.users
  for each row execute function handle_new_user();

-- ── 2) SELF-SERVICE PROFILE UPDATE (own row, safe fields only) ────
-- A user may edit their own name + phone, but NOT their role or
-- carrier (those are set by invites/onboarding only).
create or replace function update_my_profile(p_name text, p_phone text)
  returns void language plpgsql security definer set search_path = public as $$
begin
  update profile set
    name = coalesce(nullif(p_name,''), name),
    phone = coalesce(p_phone, phone)
  where user_id = auth.uid();
end $$;
grant execute on function update_my_profile(text,text) to authenticated;

-- ── 3) GUARD: block self-elevation of role/carrier via direct writes
-- Even though RLS lets a user update their own profile row, this
-- trigger ensures they cannot change their own role or carrier_id.
create or replace function protect_profile_role() returns trigger
  language plpgsql security definer set search_path = public as $$
begin
  -- platform admins and the security-definer functions bypass via
  -- elevated context; this guards ordinary self-updates.
  if auth.uid() = OLD.user_id and not is_platform_admin() then
    if NEW.role is distinct from OLD.role then
      raise exception 'You cannot change your own role';
    end if;
    if NEW.carrier_id is distinct from OLD.carrier_id then
      raise exception 'You cannot change your own carrier';
    end if;
  end if;
  return NEW;
end $$;

drop trigger if exists trg_protect_profile_role on profile;
create trigger trg_protect_profile_role
  before update on profile
  for each row execute function protect_profile_role();

-- ══════════════════════════════════════════════════════════════════
--  After v11:
--   • Sender signup is atomic (auth user + profile via one trigger)
--   • Invited staff still auto-claim on signup (unified trigger)
--   • Users can edit their own name/phone (update_my_profile)
--   • Nobody can self-elevate role or switch their own carrier
--
--  APP CHANGE REQUIRED: sender signUp must pass metadata:
--    supabase.auth.signUp({ email, password,
--      options: { data: { intent: 'sender', name } } })
--  (the new LoginView does this — see doSenderSignup)
-- ══════════════════════════════════════════════════════════════════
