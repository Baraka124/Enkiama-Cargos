-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v5 — the platform layer
--  Run on top of v1-v4. This makes it a real multi-tenant PLATFORM:
--    • platform_admin  = Enkiama (you) — sits above all carriers
--    • carrier_admin   = the person a carrier is handed to
--    • carriers are sealed; only platform admin sees across them
--    • drivers are carrier-owned and only assignable within the carrier
--    • create_carrier_with_admin() = one-call onboarding
--
--  Roles now: platform_admin (separate table) + profile.role in
--    ('carrier_admin','dispatch','driver')
-- ══════════════════════════════════════════════════════════════════

-- ── 1) PLATFORM ADMIN — who can operate Enkiama the platform ──────
create table if not exists platform_admin (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  name       text default '',
  created_at timestamptz not null default now()
);
alter table platform_admin enable row level security;

-- a platform admin can see the platform_admin list; others cannot
do $$ begin
  create policy padmin_read on platform_admin for select
    using (exists (select 1 from platform_admin pa where pa.user_id = auth.uid()));
exception when duplicate_object then null; end $$;

-- helper: am I a platform admin?
create or replace function is_platform_admin() returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (select 1 from platform_admin where user_id = auth.uid())
$$;

-- ── 2) carrier gains a couple of onboarding-status columns ────────
alter table carrier add column if not exists status text not null default 'active'; -- 'active' | 'suspended'
alter table carrier add column if not exists created_by uuid; -- platform admin who onboarded them

-- ── 3) PLATFORM-WIDE READ: platform admins can see everything ─────
-- (added alongside the existing per-carrier policies from v4; a row is
--  visible if EITHER your carrier matches OR you're a platform admin)
do $$ begin
  create policy carrier_platform_all on carrier for all
    using (is_platform_admin()) with check (is_platform_admin());
exception when duplicate_object then null; end $$;

do $$ begin
  create policy cons_platform_read on consignment for select using (is_platform_admin());
exception when duplicate_object then null; end $$;
do $$ begin
  create policy driver_platform_read on driver for select using (is_platform_admin());
exception when duplicate_object then null; end $$;
do $$ begin
  create policy profile_platform_read on profile for select using (is_platform_admin());
exception when duplicate_object then null; end $$;

-- ── 4) CARRIER ADMIN can manage staff + drivers in THEIR carrier ──
-- profile.role can now be 'carrier_admin'. A carrier admin may insert/
-- update profiles and drivers, but only within their own carrier.
create or replace function my_role() returns text
  language sql stable security definer set search_path = public as $$
  select role from profile where user_id = auth.uid()
$$;

-- carrier admin manages their carrier's staff profiles
do $$ begin
  create policy profile_admin_manage on profile for all
    using (
      my_role() = 'carrier_admin'
      and carrier_id = (select carrier_id from profile where user_id = auth.uid())
    )
    with check (
      my_role() = 'carrier_admin'
      and carrier_id = (select carrier_id from profile where user_id = auth.uid())
    );
exception when duplicate_object then null; end $$;

-- ── 5) DRIVER must belong to the same carrier as the consignment ──
-- enforce at write time with a trigger (RLS covers read isolation).
create or replace function enforce_driver_carrier() returns trigger as $$
declare d_carrier uuid;
begin
  if new.driver_id is not null then
    select carrier_id into d_carrier from driver where id = new.driver_id;
    if d_carrier is null or d_carrier <> new.carrier_id then
      raise exception 'Driver % does not belong to carrier %', new.driver_id, new.carrier_id;
    end if;
  end if;
  return new;
end $$ language plpgsql;

drop trigger if exists trg_driver_carrier on consignment;
create trigger trg_driver_carrier
  before insert or update of driver_id on consignment
  for each row execute function enforce_driver_carrier();

-- ── 6) ONBOARDING: create a carrier + invite its admin in one call ─
-- Platform-admin-only. Creates the carrier, then a placeholder profile
-- keyed by the invited admin's email. When that person signs up with
-- the same email, a trigger (below) links their auth user to this
-- profile — so they land as carrier_admin of the new carrier.
create table if not exists carrier_invite (
  id          uuid primary key default gen_random_uuid(),
  carrier_id  uuid not null references carrier(id) on delete cascade,
  email       text not null,
  role        text not null default 'carrier_admin',
  claimed     boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (email)
);
alter table carrier_invite enable row level security;
do $$ begin
  create policy invite_platform_all on carrier_invite for all
    using (is_platform_admin()) with check (is_platform_admin());
exception when duplicate_object then null; end $$;

create or replace function create_carrier_with_admin(
  p_slug text, p_name text, p_mark text, p_accent text, p_region text,
  p_admin_email text
) returns uuid
  language plpgsql security definer set search_path = public as $$
declare new_carrier uuid;
begin
  if not is_platform_admin() then
    raise exception 'Only a platform admin can onboard carriers';
  end if;
  insert into carrier (slug, name, mark, accent, region, created_by)
  values (p_slug, p_name, p_mark, p_accent, p_region, auth.uid())
  returning id into new_carrier;
  -- record the invite; the admin claims it by signing up with this email
  insert into carrier_invite (carrier_id, email, role)
  values (new_carrier, lower(p_admin_email), 'carrier_admin')
  on conflict (email) do update set carrier_id = excluded.carrier_id, role = excluded.role, claimed = false;
  return new_carrier;
end $$;
grant execute on function create_carrier_with_admin(text,text,text,text,text,text) to authenticated;

-- ── 7) AUTO-LINK: when a new auth user appears, if there's an invite
--    for their email, create their profile and claim the invite. ───
create or replace function claim_invite_on_signup() returns trigger
  language plpgsql security definer set search_path = public as $$
declare inv carrier_invite%rowtype;
begin
  select * into inv from carrier_invite where email = lower(new.email) and not claimed;
  if found then
    insert into profile (user_id, carrier_id, role, name)
    values (new.id, inv.carrier_id, inv.role, '')
    on conflict (user_id) do update set carrier_id = excluded.carrier_id, role = excluded.role;
    update carrier_invite set claimed = true where id = inv.id;
  end if;
  return new;
end $$;

drop trigger if exists trg_claim_invite on auth.users;
create trigger trg_claim_invite
  after insert on auth.users
  for each row execute function claim_invite_on_signup();

-- ══════════════════════════════════════════════════════════════════
--  8) TEST SCAFFOLD — Enkiama as a carrier + you as platform admin,
--     a driver, a dummy sender, and consignments addressed to your
--     number so you can walk the whole loop and watch the outbox.
--
--  Your user_id (barakaaloyce750@gmail.com): 136583ba-a628-47e6-a2c8-0065a8692d0a
--  Your test number (receiver): +34659447627
-- ══════════════════════════════════════════════════════════════════

-- make you a platform admin
insert into platform_admin (user_id, name)
values ('136583ba-a628-47e6-a2c8-0065a8692d0a', 'Baraka')
on conflict (user_id) do nothing;

-- Enkiama as a carrier (if not already present)
insert into carrier (slug, name, mark, accent, region, status)
values ('enkiama', 'Enkiama', 'EN', '#C08A2D', 'Dar es Salaam · own fleet', 'active')
on conflict (slug) do nothing;

-- point your profile at Enkiama as its carrier_admin (so you can run it too)
update profile
  set carrier_id = (select id from carrier where slug='enkiama'),
      role = 'carrier_admin', name = 'Baraka'
  where user_id = '136583ba-a628-47e6-a2c8-0065a8692d0a';

-- an Enkiama driver
insert into driver (carrier_id, name, phone, vehicle)
select id, 'Salum', '+255713000900', 'bajaji' from carrier where slug='enkiama'
on conflict do nothing;

-- seed a couple of Enkiama consignments addressed to YOUR number,
-- at different stages, so the board and driver run have life.
do $$
declare c_id uuid; d_id uuid; cons1 uuid; cons2 uuid;
begin
  select id into c_id from carrier where slug='enkiama';
  select id into d_id from driver where carrier_id=c_id and name='Salum' limit 1;

  -- only seed if Enkiama has no consignments yet
  if not exists (select 1 from consignment where carrier_id=c_id) then
    insert into consignment (carrier_id, code, sender_name, sender_phone, receiver_name, receiver_phone, dest_address, item, weight_kg, stage, driver_id)
    values (c_id, 'ENK-1001', 'Enkiama Test Sender', '+255755123456', 'Baraka (test)', '+34659447627', 'Mikocheni, Dar es Salaam', 'Documents', 1.0, 'with_driver', d_id)
    returning id into cons1;
    insert into payment (consignment_id, mode, state, cod_amount, fee_amount)
    values (cons1, 'cash', 'owed', 30000, 5000);
    insert into custody_event (consignment_id, stage, note, actor_role, actor_name)
    values (cons1, 'with_driver', 'Seeded — out with Salum', 'system', 'Seed');

    insert into consignment (carrier_id, code, sender_name, sender_phone, receiver_name, receiver_phone, dest_address, item, weight_kg, stage)
    values (c_id, 'ENK-1002', 'Enkiama Test Sender', '+255755123456', 'Baraka (test)', '+34659447627', 'Msasani, Dar es Salaam', 'Spare parts', 4.0, 'booked')
    returning id into cons2;
    insert into payment (consignment_id, mode, state, cod_amount, fee_amount)
    values (cons2, 'prepaid', 'settled', 0, 8000);
    insert into custody_event (consignment_id, stage, note, actor_role, actor_name)
    values (cons2, 'booked', 'Seeded — awaiting pickup', 'system', 'Seed');
  end if;
end $$;

-- ══════════════════════════════════════════════════════════════════
--  Done. After this runs:
--   • You are a platform_admin AND carrier_admin of Enkiama.
--   • Login should route you to the platform console, with a hat-
--     switcher to run Enkiama as a carrier.
--   • Enkiama has a driver (Salum) and two consignments to your number.
--   • Onboard a new carrier via create_carrier_with_admin(...), or the
--     platform console UI. The invited admin claims their spot by
--     signing up with the invited email.
-- ══════════════════════════════════════════════════════════════════
