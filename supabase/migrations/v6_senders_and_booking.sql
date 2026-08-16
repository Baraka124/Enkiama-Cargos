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
