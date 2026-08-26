-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v4 — real accounts + tenant isolation
--  Run on top of v1+v2+v3. This is the security wall: it replaces the
--  wide-open MVP policies with real per-carrier / per-driver rules.
--
--  AFTER running this, the anon key can no longer read everything.
--  You must be signed in (Supabase Auth) with a matching profile row.
-- ══════════════════════════════════════════════════════════════════

-- ── PROFILE: links an auth user to ONE carrier + role ─────────────
create table if not exists profile (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  carrier_id  uuid references carrier(id) on delete set null,
  role        text not null default 'dispatch',   -- 'dispatch' | 'driver'
  driver_id   uuid references driver(id) on delete set null,
  name        text default '',
  created_at  timestamptz not null default now()
);
alter table profile enable row level security;

-- a user can read/update only their own profile row
do $$ begin
  create policy profile_self_read  on profile for select using (user_id = auth.uid());
exception when duplicate_object then null; end $$;
do $$ begin
  create policy profile_self_write on profile for update using (user_id = auth.uid()) with check (user_id = auth.uid());
exception when duplicate_object then null; end $$;
do $$ begin
  create policy profile_self_insert on profile for insert with check (user_id = auth.uid());
exception when duplicate_object then null; end $$;

-- helper: the caller's carrier_id (security definer so policies can use it)
create or replace function my_carrier_id() returns uuid
  language sql stable security definer set search_path = public as $$
  select carrier_id from profile where user_id = auth.uid()
$$;

create or replace function my_role() returns text
  language sql stable security definer set search_path = public as $$
  select role from profile where user_id = auth.uid()
$$;

create or replace function my_driver_id() returns uuid
  language sql stable security definer set search_path = public as $$
  select driver_id from profile where user_id = auth.uid()
$$;

-- ── drop the open MVP policies from v1/v2/v3 ──────────────────────
drop policy if exists anon_all_carrier      on carrier;
drop policy if exists anon_all_driver       on driver;
drop policy if exists anon_all_consignment  on consignment;
drop policy if exists anon_all_payment      on payment;
drop policy if exists anon_all_custody      on custody_event;
drop policy if exists anon_all_customer     on customer;
drop policy if exists anon_all_attempt      on delivery_attempt;
drop policy if exists anon_all_notification on notification;

-- ── CARRIER: anyone signed-in can read the carrier list (for branding/
--    the gate), but only see their own for writes ────────────────
create policy carrier_read_all on carrier for select using (auth.uid() is not null);

-- ── CONSIGNMENT: carrier staff see their carrier's rows; a driver sees
--    only rows assigned to them ──────────────────────────────────
create policy cons_carrier_read on consignment for select
  using (carrier_id = my_carrier_id());
create policy cons_driver_read on consignment for select
  using (driver_id = my_driver_id());
create policy cons_carrier_write on consignment for all
  using (carrier_id = my_carrier_id())
  with check (carrier_id = my_carrier_id());

-- ── DRIVER rows: readable within the carrier ──────────────────────
create policy driver_carrier_all on driver for all
  using (carrier_id = my_carrier_id())
  with check (carrier_id = my_carrier_id());

-- ── PAYMENT / CUSTODY / ATTEMPT / NOTIFICATION: scoped through the
--    parent consignment's carrier ────────────────────────────────
create policy pay_by_carrier on payment for all
  using (consignment_id in (select id from consignment where carrier_id = my_carrier_id()))
  with check (consignment_id in (select id from consignment where carrier_id = my_carrier_id()));

create policy custody_by_carrier on custody_event for all
  using (consignment_id in (select id from consignment where carrier_id = my_carrier_id()))
  with check (consignment_id in (select id from consignment where carrier_id = my_carrier_id()));

create policy attempt_by_carrier on delivery_attempt for all
  using (consignment_id in (select id from consignment where carrier_id = my_carrier_id()))
  with check (consignment_id in (select id from consignment where carrier_id = my_carrier_id()));

create policy notif_by_carrier on notification for all
  using (carrier_id = my_carrier_id())
  with check (carrier_id = my_carrier_id());

create policy customer_by_carrier on customer for all
  using (carrier_id = my_carrier_id())
  with check (carrier_id = my_carrier_id());

-- ══════════════════════════════════════════════════════════════════
--  RECEIVER TRACKING stays account-less: receivers never log in.
--  They read ONE consignment via this SECURITY DEFINER function that
--  takes a code (and returns only that row) — so a tracking code can't
--  be used to enumerate the table. Called via supabase.rpc('track_parcel').
-- ══════════════════════════════════════════════════════════════════
create or replace function track_parcel(p_code text)
  returns table (
    code text, receiver_name text, dest_address text, item text,
    weight_kg numeric, stage custody_stage, driver_name text,
    carrier_name text, carrier_accent text,
    pay_mode pay_mode, pay_state pay_state, cod_amount int, fee_amount int
  )
  language sql stable security definer set search_path = public as $$
  select c.code, c.receiver_name, c.dest_address, c.item, c.weight_kg, c.stage,
         d.name, ca.name, ca.accent,
         p.mode, p.state, p.cod_amount, p.fee_amount
  from consignment c
  join carrier ca on ca.id = c.carrier_id
  left join driver d on d.id = c.driver_id
  left join payment p on p.consignment_id = c.id
  where upper(c.code) = upper(p_code)
  limit 1
$$;
-- allow anonymous (not-logged-in) receivers to call it
grant execute on function track_parcel(text) to anon, authenticated;

-- receiver confirming receipt, also account-less, by code:
create or replace function confirm_receipt(p_code text)
  returns void language plpgsql security definer set search_path = public as $$
declare cid uuid; pmode pay_mode;
begin
  select c.id, p.mode into cid, pmode
  from consignment c left join payment p on p.consignment_id=c.id
  where upper(c.code)=upper(p_code) and c.stage='delivered';
  if cid is null then raise exception 'not deliverable'; end if;
  update consignment set stage='confirmed' where id=cid;
  update payment set state='settled' where consignment_id=cid;
  insert into custody_event(consignment_id,stage,note,actor_role,actor_name)
    values (cid,'confirmed','Confirmed by receiver','receiver','');
end $$;
grant execute on function confirm_receipt(text) to anon, authenticated;

-- ══════════════════════════════════════════════════════════════════
--  Bootstrap: create a profile for yourself after you sign up.
--  Replace the email, then run once you have an auth user:
--
--    insert into profile (user_id, carrier_id, role, name)
--    select u.id, (select id from carrier where slug='usiri'), 'dispatch', 'Baraka'
--    from auth.users u where u.email = 'you@example.com'
--    on conflict (user_id) do update set carrier_id=excluded.carrier_id, role=excluded.role;
-- ══════════════════════════════════════════════════════════════════
