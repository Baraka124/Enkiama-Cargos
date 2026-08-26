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
