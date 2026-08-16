-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v3 — notification outbox
--  ADDITIVE. Run on top of v1 + v2. Does not touch existing data.
--
--  This is the seam for reaching the receiver. Every message that WOULD
--  be sent (WhatsApp/SMS) is written here as a row. Today the app just
--  renders these; later a serverless function reads unsent rows, pushes
--  them via Africa's Talking / Twilio, and flips `sent`. The app code
--  does NOT change when that happens — only the sender does.
-- ══════════════════════════════════════════════════════════════════

do $$ begin
  create type notif_channel as enum ('whatsapp','sms');
exception when duplicate_object then null; end $$;

do $$ begin
  create type notif_event as enum
    ('booked','picked_up','out_for_delivery','delivered','failed','confirmed');
exception when duplicate_object then null; end $$;

create table if not exists notification (
  id             uuid primary key default gen_random_uuid(),
  consignment_id uuid references consignment(id) on delete cascade,
  carrier_id     uuid references carrier(id) on delete cascade,
  to_phone       text not null,
  to_name        text default '',
  channel        notif_channel not null default 'whatsapp',
  event          notif_event not null,
  body           text not null,           -- the exact message text
  track_url      text default '',         -- deep link the receiver taps
  sent           boolean not null default false,   -- flips true when a real provider sends it
  sent_at        timestamptz,
  provider_ref   text default '',         -- provider message id, later
  created_at     timestamptz not null default now()
);
create index if not exists notif_cons_idx on notification(consignment_id, created_at);
create index if not exists notif_unsent_idx on notification(sent) where sent = false;

alter table notification enable row level security;
-- ⚠ TIGHTEN-LATER: per-carrier policy once Auth exists
do $$ begin
  create policy anon_all_notification on notification for all using (true) with check (true);
exception when duplicate_object then null; end $$;

alter publication supabase_realtime add table notification;

-- ══════════════════════════════════════════════════════════════════
--  When you go live, the worker is roughly:
--    select * from notification where sent = false order by created_at;
--    -> POST to Africa's Talking / Twilio
--    -> update notification set sent=true, sent_at=now(), provider_ref=...
--  Nothing in the app needs to change.
-- ══════════════════════════════════════════════════════════════════
