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
