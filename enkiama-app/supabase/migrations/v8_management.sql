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
