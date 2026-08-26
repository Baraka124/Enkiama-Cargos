-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · Freight Ledger — database schema (MVP)
--  Paste this whole file into your Supabase project's SQL Editor
--  (project ref: tzjujhtsunxnsgnlcnct) and Run.
--
--  Design spine:
--    carrier  ──<  consignment  >── (sender + receiver, phone-identified)
--    carrier  ──<  driver  ──<  assigned consignments
--    consignment ──< custody_event (append-only tracking log)
--    consignment ──1  payment (cash | mobilemoney | prepaid)
--
--  MVP auth stance: no real logins yet. Dispatch/driver/sender/receiver
--  are chosen in-app. RLS is written PERMISSIVE for the anon key now,
--  but the table shape + a carrier_id on every row means we can tighten
--  to real per-carrier / per-driver policies later WITHOUT reshaping data.
--  Search for  ⚠ TIGHTEN-LATER  to find every spot that changes when
--  you add Supabase Auth.
-- ══════════════════════════════════════════════════════════════════

-- Clean re-run support (safe to run repeatedly during development)
drop table if exists custody_event cascade;
drop table if exists payment cascade;
drop table if exists consignment cascade;
drop table if exists driver cascade;
drop table if exists carrier cascade;

-- ── enums ─────────────────────────────────────────────────────────
do $$ begin
  create type custody_stage as enum
    ('booked','collected','linehaul','with_driver','delivered','confirmed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type pay_mode as enum ('prepaid','cash','mobilemoney','feeonly');
exception when duplicate_object then null; end $$;

do $$ begin
  create type pay_state as enum ('none','owed','collected','remitted','settled');
exception when duplicate_object then null; end $$;

-- ── carrier (the transporting company = platform tenant) ──────────
create table carrier (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,            -- 'usiri'
  name        text not null,                   -- 'USIRI'
  mark        text not null default '',        -- 'US'  (2-letter badge)
  accent      text not null default '#3E5BD6', -- brand colour (white-label)
  region      text default '',                 -- 'Dar es Salaam · road freight'
  created_at  timestamptz not null default now()
);

-- ── driver (belongs to a carrier; does the last mile) ─────────────
create table driver (
  id          uuid primary key default gen_random_uuid(),
  carrier_id  uuid not null references carrier(id) on delete cascade,
  name        text not null,                   -- 'Juma'
  phone       text not null,                   -- '0712...'
  vehicle     text default '',                 -- 'toctoc' | 'piki' | 'truck'
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
create index on driver(carrier_id);

-- ── consignment (the parcel — the sender→receiver loop) ───────────
create table consignment (
  id             uuid primary key default gen_random_uuid(),
  carrier_id     uuid not null references carrier(id) on delete cascade,
  code           text unique not null,          -- 'USR-4471' (shareable tracking code)

  -- the loop: sender and receiver are phone-identified parties, no accounts
  sender_name    text not null default '',
  sender_phone   text not null default '',
  receiver_name  text not null,
  receiver_phone text not null,
  dest_address   text default '',

  -- parcel
  item           text default 'Parcel',
  weight_kg      numeric(10,2) default 1,

  -- custody (denormalised current stage for fast lists;
  --          the truth/history lives in custody_event)
  stage          custody_stage not null default 'booked',
  driver_id      uuid references driver(id) on delete set null,

  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index on consignment(carrier_id);
create index on consignment(code);
create index on consignment(driver_id);

-- ── payment (one per consignment) ────────────────────────────────
create table payment (
  consignment_id uuid primary key references consignment(id) on delete cascade,
  mode           pay_mode  not null default 'prepaid',
  state          pay_state not null default 'none',
  cod_amount     integer not null default 0,    -- TZS to collect on delivery
  fee_amount     integer not null default 0,    -- carrier's delivery fee (TZS)

  -- mobile-money rail (used when mode = 'mobilemoney')
  momo_provider  text default '',               -- 'M-Pesa' | 'Tigo Pesa' | 'Airtel'
  momo_reference text default '',               -- transaction ref that reconciles it
  momo_confirmed boolean not null default false,

  updated_at     timestamptz not null default now()
);

-- ── custody_event (append-only tracking log = the chain of custody) ─
create table custody_event (
  id             uuid primary key default gen_random_uuid(),
  consignment_id uuid not null references consignment(id) on delete cascade,
  stage          custody_stage not null,
  note           text default '',               -- 'Assigned to Juma (toctoc)'
  actor_role     text default '',               -- 'dispatch' | 'driver' | 'receiver'
  actor_name     text default '',
  at             timestamptz not null default now()
);
create index on custody_event(consignment_id, at);

-- ── keep consignment.updated_at fresh ─────────────────────────────
create or replace function touch_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end $$ language plpgsql;
create trigger consignment_touch before update on consignment
  for each row execute function touch_updated_at();

-- ══════════════════════════════════════════════════════════════════
--  ROW-LEVEL SECURITY
--  MVP: permissive (anon key can read/write) so the app works with no
--  login. Every table already carries carrier_id (directly or via FK),
--  so tightening later is policy-only, not a reshape.
-- ══════════════════════════════════════════════════════════════════
alter table carrier        enable row level security;
alter table driver         enable row level security;
alter table consignment    enable row level security;
alter table payment        enable row level security;
alter table custody_event  enable row level security;

-- ⚠ TIGHTEN-LATER: these four "anon full access" policies are the MVP
-- shortcut. When you add Supabase Auth, replace each with per-carrier /
-- per-driver rules (examples at the bottom of this file, commented out).
create policy anon_all_carrier       on carrier       for all using (true) with check (true);
create policy anon_all_driver        on driver        for all using (true) with check (true);
create policy anon_all_consignment   on consignment   for all using (true) with check (true);
create policy anon_all_payment       on payment       for all using (true) with check (true);
create policy anon_all_custody       on custody_event for all using (true) with check (true);

-- ── realtime: let clients subscribe to live changes ───────────────
alter publication supabase_realtime add table consignment;
alter publication supabase_realtime add table payment;
alter publication supabase_realtime add table custody_event;

-- ══════════════════════════════════════════════════════════════════
--  SEED — three carriers + a few consignments so the app has life
-- ══════════════════════════════════════════════════════════════════
insert into carrier (slug,name,mark,accent,region) values
  ('usiri', 'USIRI',        'US','#3E5BD6','Dar es Salaam · road freight'),
  ('sumry', 'Sumry Cargo',  'SC','#137A5E','Mbeya corridor · long-haul'),
  ('kimoto','Kimoto Lines', 'KM','#B4472B','Arusha · northern routes');

-- drivers for USIRI
insert into driver (carrier_id,name,phone,vehicle)
select id,'Juma','0712 000 111','toctoc' from carrier where slug='usiri';
insert into driver (carrier_id,name,phone,vehicle)
select id,'Neema','0713 000 222','piki'  from carrier where slug='usiri';

-- a helper to insert a full consignment + payment + first custody event
create or replace function seed_consignment(
  p_slug text, p_code text, p_sender text, p_sphone text,
  p_recv text, p_rphone text, p_addr text, p_item text, p_wt numeric,
  p_stage custody_stage, p_mode pay_mode, p_state pay_state,
  p_cod int, p_fee int, p_driver text
) returns void as $$
declare c_id uuid; d_id uuid; cons_id uuid;
begin
  select id into c_id from carrier where slug=p_slug;
  select id into d_id from driver where carrier_id=c_id and name=p_driver;
  insert into consignment
    (carrier_id,code,sender_name,sender_phone,receiver_name,receiver_phone,
     dest_address,item,weight_kg,stage,driver_id)
  values (c_id,p_code,p_sender,p_sphone,p_recv,p_rphone,p_addr,p_item,p_wt,p_stage,d_id)
  returning id into cons_id;
  insert into payment (consignment_id,mode,state,cod_amount,fee_amount)
  values (cons_id,p_mode,p_state,p_cod,p_fee);
  insert into custody_event (consignment_id,stage,note,actor_role,actor_name)
  values (cons_id,p_stage,'Seeded at stage '||p_stage,'dispatch','System');
end $$ language plpgsql;

select seed_consignment('usiri','USR-4471','Aisha Traders','0755 111 000',
  'Grace Mwangi','0712 345 678','Mikocheni B, Dar es Salaam','Documents',1.5,
  'with_driver','cash','owed',25000,4000,'Juma');
select seed_consignment('usiri','USR-8823','Aisha Traders','0755 111 000',
  'Peter Otieno','0755 900 111','Kariakoo Market','Spare parts',6,
  'linehaul','prepaid','settled',0,6000,null);
select seed_consignment('usiri','USR-1290','Aisha Traders','0755 111 000',
  'Neema Joseph','0733 222 888','Msasani Peninsula','Gift box',0.8,
  'delivered','feeonly','settled',0,3500,'Neema');
select seed_consignment('sumry','SMY-3301','Mbeya Millers','0762 100 200',
  'John Mkwawa','0762 100 200','Uyole, Mbeya','Maize sacks',40,
  'linehaul','mobilemoney','owed',80000,15000,null);

drop function seed_consignment(text,text,text,text,text,text,text,text,numeric,custody_stage,pay_mode,pay_state,int,int,text);

-- ══════════════════════════════════════════════════════════════════
--  ⚠ TIGHTEN-LATER — real multi-tenant RLS (KEEP COMMENTED for MVP)
--  When you add Supabase Auth + a profile table linking auth.uid()
--  to a carrier_id and role, drop the anon_all_* policies above and
--  use policies like these instead:
--
--  -- assumes a table:  profile(user_id uuid, carrier_id uuid, role text, driver_id uuid)
--
--  create policy carrier_reads_own on consignment for select
--    using (carrier_id in (select carrier_id from profile where user_id = auth.uid()));
--
--  create policy driver_reads_assigned on consignment for select
--    using (driver_id in (select driver_id from profile where user_id = auth.uid()));
--
--  create policy dispatch_writes_own on consignment for all
--    using (carrier_id in (select carrier_id from profile
--                          where user_id = auth.uid() and role = 'dispatch'))
--    with check (carrier_id in (select carrier_id from profile
--                               where user_id = auth.uid() and role = 'dispatch'));
--
--  Receivers stay account-less: they read ONE consignment via a public
--  RPC that takes (code + receiver_phone) and returns only that row —
--  so a tracking code alone can't enumerate the table.
-- ══════════════════════════════════════════════════════════════════
