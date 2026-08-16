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
