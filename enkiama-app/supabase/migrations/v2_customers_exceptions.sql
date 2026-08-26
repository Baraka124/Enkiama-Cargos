-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v2 — customers + exceptions + retry
--  ADDITIVE. Safe to run on top of v1. Does not drop existing data.
--  Paste into Supabase SQL Editor and Run.
-- ══════════════════════════════════════════════════════════════════

-- ── 1) extend custody_stage with real exception + delivery states ──
-- Postgres enums can't be altered inside a txn block easily; add values
-- one at a time, IF NOT EXISTS guards make this safe to re-run.
alter type custody_stage add value if not exists 'failed';       -- delivery attempt failed
alter type custody_stage add value if not exists 'returning';    -- coming back to carrier/sender
alter type custody_stage add value if not exists 'cancelled';    -- voided

-- ── 2) CUSTOMER (auto-populated relationship, keyed by phone+carrier) ──
create table if not exists customer (
  id            uuid primary key default gen_random_uuid(),
  carrier_id    uuid not null references carrier(id) on delete cascade,
  phone         text not null,                     -- the identity in TZ
  name          text not null default '',
  kind          text not null default 'sender',    -- 'sender' | 'receiver' | 'both'
  default_addr  text default '',
  -- money relationship: what the carrier owes this customer (COD proceeds
  -- minus fees) vs. what a post-paid business customer owes the carrier
  balance_tzs   integer not null default 0,        -- +ve = carrier owes customer
  credit_limit  integer not null default 0,        -- >0 = allowed to ship post-paid
  is_business   boolean not null default false,
  parcels_count integer not null default 0,
  first_seen    timestamptz not null default now(),
  last_seen     timestamptz not null default now(),
  unique (carrier_id, phone)
);
create index if not exists customer_carrier_idx on customer(carrier_id);

-- ── 3) link consignments to customer rows (nullable; auto-filled) ──
alter table consignment add column if not exists sender_customer_id   uuid references customer(id) on delete set null;
alter table consignment add column if not exists receiver_customer_id uuid references customer(id) on delete set null;

-- ── 4) DELIVERY ATTEMPT (the retry flow lives here) ───────────────
-- Each physical attempt to deliver is a row. Failed attempts capture a
-- REASON; dispatch schedules a retry; the parcel can be attempted again.
do $$ begin
  create type attempt_outcome as enum ('delivered','not_home','refused','no_cash','wrong_address','phone_off','other');
exception when duplicate_object then null; end $$;

create table if not exists delivery_attempt (
  id             uuid primary key default gen_random_uuid(),
  consignment_id uuid not null references consignment(id) on delete cascade,
  attempt_no     integer not null default 1,
  outcome        attempt_outcome not null,
  reason_note    text default '',
  driver_id      uuid references driver(id) on delete set null,
  photo_url      text default '',                  -- POD or proof-of-attempt
  gps_lat        numeric,
  gps_lng        numeric,
  at             timestamptz not null default now()
);
create index if not exists attempt_cons_idx on delivery_attempt(consignment_id, at);

-- track attempts + retry scheduling on the consignment itself for fast lists
alter table consignment add column if not exists attempt_count  integer not null default 0;
alter table consignment add column if not exists last_reason     text default '';     -- why last attempt failed
alter table consignment add column if not exists retry_after     timestamptz;         -- dispatch-scheduled retry time

-- ── 5) RLS for the new tables (MVP-permissive, matches v1) ────────
alter table customer          enable row level security;
alter table delivery_attempt  enable row level security;

-- ⚠ TIGHTEN-LATER (same as v1): swap for per-carrier policies with Auth
do $$ begin
  create policy anon_all_customer on customer for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy anon_all_attempt  on delivery_attempt for all using (true) with check (true);
exception when duplicate_object then null; end $$;

-- realtime for the retry flow + customers
alter publication supabase_realtime add table delivery_attempt;
alter publication supabase_realtime add table customer;

-- ── 6) auto-link customers on booking (trigger) ──────────────────
-- On every new consignment, upsert a sender + receiver customer row for
-- that carrier and link them. Operator never does data entry.
create or replace function link_customers() returns trigger as $$
declare s_id uuid; r_id uuid;
begin
  -- sender (only if we have a phone)
  if coalesce(new.sender_phone,'') <> '' then
    insert into customer (carrier_id, phone, name, kind, last_seen, parcels_count)
    values (new.carrier_id, new.sender_phone, new.sender_name, 'sender', now(), 1)
    on conflict (carrier_id, phone) do update
      set parcels_count = customer.parcels_count + 1,
          last_seen = now(),
          name = case when customer.name = '' then excluded.name else customer.name end,
          kind  = case when customer.kind = 'receiver' then 'both' else customer.kind end
    returning id into s_id;
    new.sender_customer_id := s_id;
  end if;

  -- receiver
  if coalesce(new.receiver_phone,'') <> '' then
    insert into customer (carrier_id, phone, name, kind, default_addr, last_seen, parcels_count)
    values (new.carrier_id, new.receiver_phone, new.receiver_name, 'receiver', new.dest_address, now(), 1)
    on conflict (carrier_id, phone) do update
      set parcels_count = customer.parcels_count + 1,
          last_seen = now(),
          name = case when customer.name = '' then excluded.name else customer.name end,
          kind  = case when customer.kind = 'sender' then 'both' else customer.kind end
    returning id into r_id;
    new.receiver_customer_id := r_id;
  end if;

  return new;
end $$ language plpgsql;

drop trigger if exists consignment_link_customers on consignment;
create trigger consignment_link_customers
  before insert on consignment
  for each row execute function link_customers();

-- ── 7) backfill customers from consignments that already exist ────
-- (re-runs the link logic for v1 seed data so the customer list isn't empty)
update consignment set updated_at = updated_at;  -- no-op to keep timestamps
insert into customer (carrier_id, phone, name, kind, parcels_count, last_seen)
select carrier_id, sender_phone, max(sender_name), 'sender', count(*), now()
from consignment where coalesce(sender_phone,'')<>''
group by carrier_id, sender_phone
on conflict (carrier_id, phone) do nothing;

insert into customer (carrier_id, phone, name, kind, default_addr, parcels_count, last_seen)
select carrier_id, receiver_phone, max(receiver_name), 'receiver', max(dest_address), count(*), now()
from consignment where coalesce(receiver_phone,'')<>''
group by carrier_id, receiver_phone
on conflict (carrier_id, phone) do nothing;

-- link existing consignments to the customers we just made
update consignment c set sender_customer_id = cu.id
from customer cu where cu.carrier_id=c.carrier_id and cu.phone=c.sender_phone and c.sender_customer_id is null;
update consignment c set receiver_customer_id = cu.id
from customer cu where cu.carrier_id=c.carrier_id and cu.phone=c.receiver_phone and c.receiver_customer_id is null;

-- ══════════════════════════════════════════════════════════════════
--  Done. New capabilities unlocked:
--   • customer table auto-fills on every booking (senders & receivers)
--   • delivery_attempt records each try with an outcome + reason
--   • consignment.stage can now be 'failed' / 'returning' / 'cancelled'
--   • retry_after lets dispatch schedule another attempt
--  Verify:  select phone,name,kind,parcels_count from customer order by parcels_count desc;
-- ══════════════════════════════════════════════════════════════════
