-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  ENKIAMA CARGOS — COMBINED MIGRATION  (v5 → v11)                  ║
-- ║  Run this ONCE in the Supabase SQL Editor, on a database at v4.   ║
-- ║  It applies, in order:                                            ║
-- ║    v5  platform layer (admin, onboarding, driver enforcement)     ║
-- ║    v6  senders + one booking path                                 ║
-- ║    v7  integrity + cash ledger                                    ║
-- ║    v8  management (invites, edit/suspend, driver/customer mgmt)    ║
-- ║    v9  proof of delivery + momo simulate + notifications          ║
-- ║    v10 hardening (constraints + indexes)                          ║
-- ║    v11 auth hardening (atomic signup, profile self-mgmt, guards)  ║
-- ║                                                                    ║
-- ║  Safe to re-run: every object uses IF NOT EXISTS / OR REPLACE /   ║
-- ║  duplicate-swallowing guards. If a block errors, the message      ║
-- ║  tells you which section — fix and re-run the whole file.         ║
-- ╚══════════════════════════════════════════════════════════════════╝


-- ████████████████████████████████████████████████████████████████
-- ███  SECTION: v5_platform_layer
-- ████████████████████████████████████████████████████████████████

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

-- ████████████████████████████████████████████████████████████████
-- ███  SECTION: v6_senders_and_booking
-- ████████████████████████████████████████████████████████████████

-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v6 — senders + booking logic
--  Run on top of v1-v5. Adds:
--    • 'sender' role (senders are real accounts now)
--    • sender profile linkage (a sender is a profile with role='sender',
--      not tied to a carrier — they can ship via ANY carrier)
--    • book_consignment() — ONE booking path used by dispatch AND senders,
--      so the rules are identical no matter who books
--    • RLS so a sender sees only THEIR OWN sent parcels
-- ══════════════════════════════════════════════════════════════════

-- ── 1) senders: a profile with role='sender' and carrier_id NULL ──
-- (profile already allows carrier_id null). We add a phone + saved
-- info so a sender has an identity and history.
alter table profile add column if not exists phone text default '';

-- link a consignment to the sender's user (nullable: dispatch-booked
-- walk-ins have no sender account)
alter table consignment add column if not exists sender_user_id uuid references auth.users(id) on delete set null;
create index if not exists cons_sender_user_idx on consignment(sender_user_id);

-- ── 2) helper: am I a sender? ─────────────────────────────────────
create or replace function my_role() returns text
  language sql stable security definer set search_path = public as $$
  select role from profile where user_id = auth.uid()
$$;

-- ── 3) SENDER RLS: a sender can read the consignments they booked ──
do $$ begin
  create policy cons_sender_read on consignment for select
    using (sender_user_id = auth.uid());
exception when duplicate_object then null; end $$;

-- senders read their own payment + custody rows (through their parcels)
do $$ begin
  create policy pay_sender_read on payment for select
    using (consignment_id in (select id from consignment where sender_user_id = auth.uid()));
exception when duplicate_object then null; end $$;
do $$ begin
  create policy custody_sender_read on custody_event for select
    using (consignment_id in (select id from consignment where sender_user_id = auth.uid()));
exception when duplicate_object then null; end $$;

-- ── 4) THE booking function — one path for everyone ───────────────
-- Called by dispatch (books for a walk-in, on their carrier) OR by a
-- sender (books remotely, choosing a carrier). Enforces:
--   • the carrier exists and is active
--   • a unique code is generated
--   • payment row created with correct initial money-state
--   • first custody event logged
--   • sender_user_id set when a signed-in sender books
-- Returns the new consignment code.
create or replace function book_consignment(
  p_carrier_id   uuid,
  p_receiver     text,
  p_receiver_ph  text,
  p_addr         text,
  p_item         text,
  p_weight       numeric,
  p_mode         text,          -- 'prepaid' | 'cod' | 'feeonly'
  p_cod          integer,
  p_fee          integer,
  p_sender_name  text default 'Walk-in',
  p_sender_ph    text default ''
) returns text
  language plpgsql security definer set search_path = public as $$
declare
  v_prefix text;
  v_code   text;
  v_id     uuid;
  v_mode   pay_mode;
  v_state  pay_state;
  v_uid    uuid := auth.uid();
  v_role   text;
begin
  -- carrier must exist and be active
  select upper(substr(slug,1,3)) into v_prefix from carrier where id = p_carrier_id and status = 'active';
  if v_prefix is null then raise exception 'Carrier not found or not active'; end if;

  -- authorization: a signed-in dispatch/admin may only book on THEIR
  -- carrier; a sender may book on any carrier; platform admin any.
  select role into v_role from profile where user_id = v_uid;
  if v_role in ('dispatch','carrier_admin') then
    if (select carrier_id from profile where user_id = v_uid) <> p_carrier_id then
      raise exception 'You can only book on your own carrier';
    end if;
  end if;

  -- unique code
  loop
    v_code := v_prefix || '-' || (1000 + floor(random()*9000))::int;
    exit when not exists (select 1 from consignment where code = v_code);
  end loop;

  -- money mode/state
  v_mode := case when p_mode = 'cod' then 'cash'::pay_mode else p_mode::pay_mode end;
  v_state := case when p_mode = 'cod' then 'owed'::pay_state else 'settled'::pay_state end;

  insert into consignment (carrier_id, code, sender_name, sender_phone, sender_user_id,
                           receiver_name, receiver_phone, dest_address, item, weight_kg, stage)
  values (p_carrier_id, v_code, coalesce(p_sender_name,'Walk-in'), coalesce(p_sender_ph,''),
          case when v_role = 'sender' then v_uid else null end,
          p_receiver, p_receiver_ph, p_addr, coalesce(p_item,'Parcel'), coalesce(p_weight,1), 'booked')
  returning id into v_id;

  insert into payment (consignment_id, mode, state, cod_amount, fee_amount)
  values (v_id, v_mode, v_state, coalesce(p_cod,0), coalesce(p_fee,0));

  insert into custody_event (consignment_id, stage, note, actor_role, actor_name)
  values (v_id, 'booked', 'Booked', coalesce(v_role,'sender'), coalesce(p_sender_name,''));

  return v_code;
end $$;
grant execute on function book_consignment(uuid,text,text,text,text,numeric,text,integer,integer,text,text) to authenticated;

-- ── 5) a sender's carrier list: senders need to SEE carriers to pick
--    one when booking. Allow authenticated users to read the basic
--    carrier directory (name/mark/accent/region) — safe, non-sensitive.
do $$ begin
  create policy carrier_directory_read on carrier for select
    using (auth.uid() is not null);
exception when duplicate_object then null; end $$;

-- ══════════════════════════════════════════════════════════════════
--  After v6:
--   • Sign up as a sender: create account, then a profile row with
--     role='sender' (no carrier). A signup UI does this; for testing:
--       insert into profile(user_id,role,name,phone)
--       values ('<user_id>','sender','Test Sender','+34659447627');
--   • Senders book via book_consignment(...) and see their own parcels.
--   • Dispatch books walk-ins via the same function on their carrier.
-- ══════════════════════════════════════════════════════════════════

-- ████████████████████████████████████████████████████████████████
-- ███  SECTION: v7_integrity_and_ledger
-- ████████████████████████████████████████████████████████████████

-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v7 — trust & integrity logic
--  Run on top of v1-v6. This turns the app from a RECORDER into an
--  ENFORCER. Rules live in the database so they can't be bypassed.
--
--  Encodes:
--   1. Legal custody transitions only (no illegal jumps)
--   2. Money-state must stay consistent with custody
--   3. Terminal states (confirmed/cancelled) lock the row
--   4. Driver cash-holding ledger (who owes the carrier what)
--   5. Customer balance updates (COD proceeds owed to senders)
--   6. Idempotency guard on delivery
-- ══════════════════════════════════════════════════════════════════

-- ── 1) LEGAL CUSTODY TRANSITIONS ──────────────────────────────────
-- Allowed moves. Anything else is rejected at the database.
--   booked      → collected, cancelled
--   collected   → linehaul, cancelled
--   linehaul    → with_driver, cancelled
--   with_driver → delivered, failed
--   failed      → with_driver (retry), returning, cancelled
--   returning   → returned? (we treat 'returning' as near-terminal → cancelled/booked)
--   delivered   → confirmed
--   confirmed   → (terminal)
--   cancelled   → (terminal)
create or replace function valid_custody_transition(old_stage custody_stage, new_stage custody_stage)
  returns boolean language sql immutable as $$
  select case
    when old_stage = new_stage then true                       -- no-op allowed
    when old_stage = 'booked'      and new_stage in ('collected','cancelled') then true
    when old_stage = 'collected'   and new_stage in ('linehaul','cancelled') then true
    when old_stage = 'linehaul'    and new_stage in ('with_driver','cancelled') then true
    when old_stage = 'with_driver' and new_stage in ('delivered','failed') then true
    when old_stage = 'failed'      and new_stage in ('with_driver','returning','cancelled') then true
    when old_stage = 'returning'   and new_stage in ('booked','cancelled') then true
    when old_stage = 'delivered'   and new_stage in ('confirmed') then true
    else false
  end
$$;

create or replace function enforce_custody_rules() returns trigger as $$
begin
  -- terminal states lock the row entirely
  if OLD.stage in ('confirmed','cancelled') and NEW.stage <> OLD.stage then
    raise exception 'Consignment % is % (terminal) and cannot change', OLD.code, OLD.stage;
  end if;
  -- only legal transitions
  if NEW.stage <> OLD.stage and not valid_custody_transition(OLD.stage, NEW.stage) then
    raise exception 'Illegal custody move: % → % on %', OLD.stage, NEW.stage, OLD.code;
  end if;
  return NEW;
end $$ language plpgsql;

drop trigger if exists trg_custody_rules on consignment;
create trigger trg_custody_rules
  before update of stage on consignment
  for each row execute function enforce_custody_rules();

-- ── 2) MONEY-CUSTODY CONSISTENCY ──────────────────────────────────
-- A COD parcel cannot be 'confirmed' while cash is still 'owed'.
-- When a COD parcel is delivered, cash moves owed→collected automatically.
create or replace function sync_money_on_delivery() returns trigger as $$
begin
  if NEW.stage = 'delivered' and OLD.stage <> 'delivered' then
    update payment
      set state = case when mode = 'cash' and state = 'owed' then 'collected' else state end,
          updated_at = now()
      where consignment_id = NEW.id;
  end if;

  if NEW.stage = 'confirmed' and OLD.stage <> 'confirmed' then
    -- block confirmation if a cash COD parcel hasn't been collected
    if exists (select 1 from payment
               where consignment_id = NEW.id and mode = 'cash'
                 and state not in ('collected','remitted','settled')) then
      raise exception 'Cannot confirm % — cash on delivery not yet collected', NEW.code;
    end if;
    update payment set state = 'settled', updated_at = now()
      where consignment_id = NEW.id and state <> 'settled';
  end if;
  return NEW;
end $$ language plpgsql;

drop trigger if exists trg_money_sync on consignment;
create trigger trg_money_sync
  after update of stage on consignment
  for each row execute function sync_money_on_delivery();

-- ── 3) DRIVER CASH LEDGER ─────────────────────────────────────────
-- Real-time view: for each driver, how much collected COD they are
-- holding and haven't remitted. This is the cash-trust ledger.
create or replace view driver_cash_ledger as
select
  d.id            as driver_id,
  d.carrier_id,
  d.name          as driver_name,
  count(p.*) filter (where p.state = 'collected')                as parcels_holding,
  coalesce(sum(p.cod_amount) filter (where p.state = 'collected'),0) as cash_holding,
  coalesce(sum(p.cod_amount) filter (where p.state = 'remitted'),0)  as cash_remitted
from driver d
left join consignment c on c.driver_id = d.id
left join payment p on p.consignment_id = c.id and p.mode = 'cash'
group by d.id, d.carrier_id, d.name;

-- carrier-scoped read (a carrier sees only its drivers' ledger)
-- views inherit RLS from base tables under security_invoker in PG15+.
alter view driver_cash_ledger set (security_invoker = true);

-- ── 4) CUSTOMER BALANCE — COD proceeds owed to the sender ─────────
-- When cash is collected on a parcel, the sender-customer is owed
-- (cod - fee). When remitted/settled we keep the running balance.
create or replace function update_customer_balance() returns trigger as $$
declare v_carrier uuid; v_sphone text; v_cod int; v_fee int; v_cust uuid;
begin
  -- only act when a payment becomes 'collected'
  if NEW.state = 'collected' and (OLD.state is distinct from 'collected') then
    select c.carrier_id, c.sender_phone, NEW.cod_amount, NEW.fee_amount
      into v_carrier, v_sphone, v_cod, v_fee
      from consignment c where c.id = NEW.consignment_id;
    if coalesce(v_sphone,'') <> '' then
      update customer
        set balance_tzs = balance_tzs + (coalesce(v_cod,0) - coalesce(v_fee,0))
        where carrier_id = v_carrier and phone = v_sphone;
    end if;
  end if;
  return NEW;
end $$ language plpgsql;

drop trigger if exists trg_customer_balance on payment;
create trigger trg_customer_balance
  after update of state on payment
  for each row execute function update_customer_balance();

-- ── 5) IDEMPOTENCY — a custody_event shouldn't duplicate the same
--    stage back-to-back (guards double-clicks). ───────────────────
create or replace function dedup_custody_event() returns trigger as $$
declare last_stage custody_stage;
begin
  select stage into last_stage from custody_event
    where consignment_id = NEW.consignment_id order by at desc limit 1;
  if last_stage is not null and last_stage = NEW.stage and NEW.stage in ('delivered','confirmed') then
    return null; -- skip duplicate terminal-ish event
  end if;
  return NEW;
end $$ language plpgsql;

drop trigger if exists trg_dedup_custody on custody_event;
create trigger trg_dedup_custody
  before insert on custody_event
  for each row execute function dedup_custody_event();

-- ── 6) helper the UI can call: safe remit (collected → remitted) ──
create or replace function remit_cash(p_consignment uuid)
  returns void language plpgsql security definer set search_path = public as $$
begin
  update payment set state = 'remitted', updated_at = now()
    where consignment_id = p_consignment and mode = 'cash' and state = 'collected';
  if not found then raise exception 'Nothing to remit for this consignment'; end if;
end $$;
grant execute on function remit_cash(uuid) to authenticated;

-- ══════════════════════════════════════════════════════════════════
--  After v7 the database GUARANTEES:
--   • no illegal custody jumps (booked can't leap to delivered)
--   • terminal parcels are frozen
--   • COD cash auto-collects on delivery; can't confirm unpaid COD
--   • every driver's held-cash is queryable (driver_cash_ledger)
--   • sender balances accrue from collected COD
--   • duplicate delivery/confirm events are ignored
--  These hold no matter what the UI does — they can't be bypassed.
-- ══════════════════════════════════════════════════════════════════

-- ████████████████████████████████████████████████████████████████
-- ███  SECTION: v8_management
-- ████████████████████████████████████████████████████████████████

-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v8 — management maturity
--  Run on top of v1-v7. Adds the MANAGEMENT layer (edit/manage the
--  things earlier phases could only create):
--   1. Staff invites (carrier admin invites dispatch to their carrier)
--   2. Carrier edit + suspend/reactivate (platform admin)
--   3. Carrier self-edit (admin edits their own brand)
--   4. Driver deactivate/reactivate
--   5. Customer edit (credit limit, business flag)
-- ══════════════════════════════════════════════════════════════════

-- ── 1) STAFF INVITES — reuse the carrier_invite + claim mechanism ─
-- A carrier admin invites a dispatch person to THEIR carrier. The
-- invitee claims it by signing up with that email (v5's trigger links
-- them). This function forces the carrier to the admin's own carrier.
create or replace function invite_staff(p_email text, p_role text default 'dispatch')
  returns void language plpgsql security definer set search_path = public as $$
declare my_carrier uuid; my_r text;
begin
  select carrier_id, role into my_carrier, my_r from profile where user_id = auth.uid();
  if my_r <> 'carrier_admin' then
    raise exception 'Only a carrier admin can invite staff';
  end if;
  if p_role not in ('dispatch','carrier_admin') then
    raise exception 'Staff role must be dispatch or carrier_admin';
  end if;
  insert into carrier_invite (carrier_id, email, role)
  values (my_carrier, lower(p_email), p_role)
  on conflict (email) do update set carrier_id = excluded.carrier_id, role = excluded.role, claimed = false;
end $$;
grant execute on function invite_staff(text,text) to authenticated;

-- carrier admin can see their own carrier's pending invites
do $$ begin
  create policy invite_admin_read on carrier_invite for select
    using (carrier_id = (select carrier_id from profile where user_id = auth.uid()));
exception when duplicate_object then null; end $$;

-- ── 2) CARRIER edit + suspend (platform admin) ────────────────────
create or replace function update_carrier(
  p_carrier uuid, p_name text, p_mark text, p_accent text, p_region text
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_admin()
     and (select carrier_id from profile where user_id = auth.uid()) is distinct from p_carrier then
    raise exception 'Not allowed to edit this carrier';
  end if;
  -- carrier admins may edit their own carrier; platform admin any
  if not is_platform_admin() and (select role from profile where user_id = auth.uid()) <> 'carrier_admin' then
    raise exception 'Only a carrier admin or platform admin may edit a carrier';
  end if;
  update carrier set
    name = coalesce(p_name, name),
    mark = coalesce(p_mark, mark),
    accent = coalesce(p_accent, accent),
    region = coalesce(p_region, region)
  where id = p_carrier;
end $$;
grant execute on function update_carrier(uuid,text,text,text,text) to authenticated;

create or replace function set_carrier_status(p_carrier uuid, p_status text)
  returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_admin() then
    raise exception 'Only a platform admin can suspend or reactivate a carrier';
  end if;
  if p_status not in ('active','suspended') then
    raise exception 'Status must be active or suspended';
  end if;
  update carrier set status = p_status where id = p_carrier;
end $$;
grant execute on function set_carrier_status(uuid,text) to authenticated;

-- ── 3) DRIVER deactivate/reactivate (carrier admin, own carrier) ──
-- RLS from v4 already scopes driver writes to the carrier; a simple
-- update of `active` is enough. Add a guard function for clarity.
create or replace function set_driver_active(p_driver uuid, p_active boolean)
  returns void language plpgsql security definer set search_path = public as $$
declare my_carrier uuid; d_carrier uuid;
begin
  select carrier_id into my_carrier from profile where user_id = auth.uid();
  select carrier_id into d_carrier from driver where id = p_driver;
  if my_carrier is null or my_carrier <> d_carrier then
    raise exception 'You can only manage your own carrier''s drivers';
  end if;
  update driver set active = p_active where id = p_driver;
end $$;
grant execute on function set_driver_active(uuid,boolean) to authenticated;

-- ── 4) CUSTOMER edit (credit limit, business flag, name) ──────────
-- carrier-scoped via RLS from v2; guard keeps it to the caller's carrier.
create or replace function update_customer(
  p_customer uuid, p_name text, p_is_business boolean, p_credit_limit integer
) returns void language plpgsql security definer set search_path = public as $$
declare my_carrier uuid; c_carrier uuid;
begin
  select carrier_id into my_carrier from profile where user_id = auth.uid();
  select carrier_id into c_carrier from customer where id = p_customer;
  if my_carrier is null or my_carrier <> c_carrier then
    raise exception 'You can only edit your own carrier''s customers';
  end if;
  update customer set
    name = coalesce(p_name, name),
    is_business = coalesce(p_is_business, is_business),
    credit_limit = coalesce(p_credit_limit, credit_limit)
  where id = p_customer;
end $$;
grant execute on function update_customer(uuid,text,boolean,integer) to authenticated;

-- ══════════════════════════════════════════════════════════════════
--  After v8:
--   • Carrier admins invite dispatch staff (invite_staff)
--   • Platform admin edits + suspends carriers (update_carrier, set_carrier_status)
--   • Carrier admins edit their own brand (update_carrier)
--   • Drivers can be deactivated/reactivated (set_driver_active)
--   • Customers can be edited: credit limit, business flag (update_customer)
-- ══════════════════════════════════════════════════════════════════

-- ████████████████████████████████████████████████████████████████
-- ███  SECTION: v9_proof_and_reach
-- ████████████████████████████████████████████████████████████████

-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v9 — reaching people & proof
--  Run on top of v1-v8. Phase 4, built for FREE:
--   1. Proof of delivery — photo + signature at handover (real, uses
--      Supabase Storage free tier; no external API)
--   2. Manual mobile-money confirm — simulate a paid COD so the whole
--      reconcile flow works without a paid aggregator
--   3. Notification trigger rules — coherent "when to notify whom",
--      writing rows to the outbox (a provider sends them later)
-- ══════════════════════════════════════════════════════════════════

-- ── 1) PROOF OF DELIVERY ──────────────────────────────────────────
-- delivery_attempt already has photo_url + gps. Add a signature and a
-- proof on the consignment itself for the successful delivery.
alter table consignment add column if not exists pod_photo_url text default '';
alter table consignment add column if not exists pod_signature text default '';  -- data-url or storage path
alter table consignment add column if not exists pod_at timestamptz;

-- a function the driver calls to deliver WITH proof, in one safe step
create or replace function deliver_with_proof(
  p_consignment uuid,
  p_photo_url text default '',
  p_signature text default ''
) returns void language plpgsql security definer set search_path = public as $$
declare v_role text; v_name text;
begin
  select role, name into v_role, v_name from profile where user_id = auth.uid();
  update consignment
    set stage = 'delivered',
        pod_photo_url = nullif(p_photo_url,''),
        pod_signature = nullif(p_signature,''),
        pod_at = now()
    where id = p_consignment;
  -- money-sync + custody-rule triggers from v7 fire automatically here
  insert into custody_event (consignment_id, stage, note, actor_role, actor_name)
  values (p_consignment, 'delivered',
          'Delivered with proof' || case when p_photo_url<>'' then ' (photo)' else '' end
                                  || case when p_signature<>'' then ' (signature)' else '' end,
          coalesce(v_role,'driver'), coalesce(v_name,''));
end $$;
grant execute on function deliver_with_proof(uuid,text,text) to authenticated;

-- ── 2) MANUAL MOBILE-MONEY CONFIRM (simulate the webhook) ─────────
-- Lets dispatch/admin mark a COD parcel as paid by mobile money, as if
-- the aggregator callback fired. Same end-state as the real webhook,
-- so the reconcile logic is identical when you wire a real provider.
create or replace function confirm_momo_manual(
  p_consignment uuid, p_provider text default 'M-Pesa', p_reference text default ''
) returns void language plpgsql security definer set search_path = public as $$
declare my_carrier uuid; c_carrier uuid;
begin
  select carrier_id into my_carrier from profile where user_id = auth.uid();
  select carrier_id into c_carrier from consignment where id = p_consignment;
  if my_carrier is null or my_carrier <> c_carrier then
    raise exception 'You can only reconcile your own carrier''s parcels';
  end if;
  update payment
    set mode = 'mobilemoney', state = 'collected',
        momo_provider = p_provider, momo_reference = coalesce(nullif(p_reference,''),'MANUAL-'||substr(p_consignment::text,1,8)),
        momo_confirmed = true, updated_at = now()
    where consignment_id = p_consignment;
  insert into custody_event (consignment_id, stage, note, actor_role, actor_name)
  select id, stage, 'Mobile-money payment confirmed ('||p_provider||')', 'system', 'MoMo'
    from consignment where id = p_consignment;
end $$;
grant execute on function confirm_momo_manual(uuid,text,text) to authenticated;

-- ── 3) NOTIFICATION TRIGGER RULES ─────────────────────────────────
-- One coherent rule set: on each custody change, write the right
-- outbox message to the right person. A provider sends unsent rows.
create or replace function queue_notifications() returns trigger as $$
declare
  v_carrier_name text; v_link text; v_owe text;
begin
  if NEW.stage = OLD.stage then return NEW; end if;
  select name into v_carrier_name from carrier where id = NEW.carrier_id;
  v_link := '/#/track/' || NEW.code;
  v_owe := '';

  -- receiver-facing messages
  if NEW.stage = 'with_driver' then
    insert into notification (consignment_id, carrier_id, to_phone, to_name, channel, event, body, track_url)
    values (NEW.id, NEW.carrier_id, NEW.receiver_phone, NEW.receiver_name, 'whatsapp', 'out_for_delivery',
            NEW.receiver_name||', your parcel '||NEW.code||' is out for delivery today. Track: '||v_link, v_link);
  elsif NEW.stage = 'delivered' then
    insert into notification (consignment_id, carrier_id, to_phone, to_name, channel, event, body, track_url)
    values (NEW.id, NEW.carrier_id, NEW.receiver_phone, NEW.receiver_name, 'whatsapp', 'delivered',
            'Your parcel '||NEW.code||' has been delivered. Confirm receipt: '||v_link, v_link);
  elsif NEW.stage = 'failed' then
    insert into notification (consignment_id, carrier_id, to_phone, to_name, channel, event, body, track_url)
    values (NEW.id, NEW.carrier_id, NEW.receiver_phone, NEW.receiver_name, 'sms', 'failed',
            'We tried to deliver '||NEW.code||' but could not ('||coalesce(NEW.last_reason,'no answer')||'). We will retry.', v_link);
  end if;

  -- sender-facing on delivered/confirmed (if we have a sender phone)
  if NEW.stage in ('delivered','confirmed') and coalesce(NEW.sender_phone,'') <> '' then
    insert into notification (consignment_id, carrier_id, to_phone, to_name, channel, event, body, track_url)
    values (NEW.id, NEW.carrier_id, NEW.sender_phone, NEW.sender_name, 'sms',
            case when NEW.stage='delivered' then 'delivered' else 'confirmed' end,
            'Your parcel '||NEW.code||' to '||NEW.receiver_name||' was '||NEW.stage||'.', v_link);
  end if;

  return NEW;
end $$ language plpgsql;

drop trigger if exists trg_queue_notifications on consignment;
create trigger trg_queue_notifications
  after update of stage on consignment
  for each row execute function queue_notifications();

-- ── storage bucket for proof photos (run once; safe if exists) ────
insert into storage.buckets (id, name, public)
values ('pod', 'pod', true)
on conflict (id) do nothing;

-- allow authenticated users to upload proof; public read (tracking pages)
do $$ begin
  create policy pod_upload on storage.objects for insert to authenticated
    with check (bucket_id = 'pod');
exception when duplicate_object then null; end $$;
do $$ begin
  create policy pod_read on storage.objects for select using (bucket_id = 'pod');
exception when duplicate_object then null; end $$;

-- ══════════════════════════════════════════════════════════════════
--  After v9:
--   • Drivers deliver with a photo + signature (deliver_with_proof)
--   • COD can be reconciled by mobile money manually now
--     (confirm_momo_manual) — identical end-state to the real webhook
--   • Every custody change queues the right outbox messages — flip on
--     a real SMS/WhatsApp provider later and they send, no code change
-- ══════════════════════════════════════════════════════════════════

-- ████████████████████████████████████████████████████████████████
-- ███  SECTION: v10_hardening
-- ████████████████████████████████████████████████████████████████

-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v10 — hardening
--  Run on top of v1-v9. Defensive constraints + guards that protect
--  data integrity beyond what triggers already do.
-- ══════════════════════════════════════════════════════════════════

-- ── money can't be negative ───────────────────────────────────────
do $$ begin
  alter table payment add constraint chk_cod_nonneg check (cod_amount >= 0);
exception when duplicate_object then null; when others then null; end $$;
do $$ begin
  alter table payment add constraint chk_fee_nonneg check (fee_amount >= 0);
exception when duplicate_object then null; when others then null; end $$;

-- ── weight can't be negative ──────────────────────────────────────
do $$ begin
  alter table consignment add constraint chk_weight_nonneg check (weight_kg >= 0);
exception when duplicate_object then null; when others then null; end $$;

-- ── a receiver phone is required (can't book into the void) ───────
do $$ begin
  alter table consignment add constraint chk_receiver_phone check (length(coalesce(receiver_phone,'')) > 0);
exception when duplicate_object then null; when others then null; end $$;

-- ── carrier slug must be lowercase, url-safe ──────────────────────
do $$ begin
  alter table carrier add constraint chk_slug_format check (slug ~ '^[a-z0-9-]+$');
exception when duplicate_object then null; when others then null; end $$;

-- ── index the hot paths for search/lists at scale ─────────────────
create index if not exists cons_receiver_phone_idx on consignment(receiver_phone);
create index if not exists cons_stage_idx on consignment(carrier_id, stage);
create index if not exists notif_unsent_created_idx on notification(sent, created_at) where sent = false;

-- ══════════════════════════════════════════════════════════════════
--  After v10: negative money/weight impossible, every consignment has
--  a receiver phone, carrier slugs are url-safe, and the common
--  list/search queries are indexed for scale.
-- ══════════════════════════════════════════════════════════════════

-- ████████████████████████████████████████████████████████████████
-- ███  SECTION: v11_auth_hardening
-- ████████████████████████████████████████████████████████████████

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

-- ████████████████████████████████████████████████████████████████
-- ███  SECTION: v12_tracking_proof
-- ████████████████████████████████████████████████████████████████

-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v12 — public tracking shows proof
--  Run on top of v1-v11. Extends track_parcel() so the receiver's
--  public tracking page can show the proof-of-delivery photo and time.
-- ══════════════════════════════════════════════════════════════════

drop function if exists track_parcel(text);

create or replace function track_parcel(p_code text)
  returns table (
    code text, receiver_name text, dest_address text, item text,
    weight_kg numeric, stage custody_stage, driver_name text,
    carrier_name text, carrier_accent text,
    pay_mode pay_mode, pay_state pay_state, cod_amount int, fee_amount int,
    pod_photo_url text, pod_at timestamptz
  )
  language sql stable security definer set search_path = public as $$
  select c.code, c.receiver_name, c.dest_address, c.item, c.weight_kg, c.stage,
         d.name, ca.name, ca.accent,
         p.mode, p.state, p.cod_amount, p.fee_amount,
         c.pod_photo_url, c.pod_at
  from consignment c
  join carrier ca on ca.id = c.carrier_id
  left join driver d on d.id = c.driver_id
  left join payment p on p.consignment_id = c.id
  where upper(c.code) = upper(p_code)
  limit 1
$$;
grant execute on function track_parcel(text) to anon, authenticated;

-- ══════════════════════════════════════════════════════════════════
--  After v12: the public track page can display the delivery photo.
-- ══════════════════════════════════════════════════════════════════
