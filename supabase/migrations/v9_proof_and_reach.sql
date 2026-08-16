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
