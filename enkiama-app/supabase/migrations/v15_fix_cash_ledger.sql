-- ══════════════════════════════════════════════════════════════════
--  ENKIAMA CARGOS · migration v15 — fix driver_cash_ledger (blank board)
--  The view was set security_invoker=true, so its joins over driver/
--  consignment/payment were evaluated under the caller's RLS — which
--  triggered the same recursive-policy failure and 500'd the query,
--  blanking the dispatch board.
--
--  Fix: back it with a SECURITY DEFINER function that bypasses RLS but
--  scopes results to the caller's own carrier (safe + no recursion).
-- ══════════════════════════════════════════════════════════════════

-- turn off invoker so the view no longer re-checks caller RLS per row
alter view driver_cash_ledger set (security_invoker = false);

-- a definer function that returns only the caller's carrier ledger
create or replace function my_cash_ledger()
  returns table (
    driver_id uuid, carrier_id uuid, driver_name text,
    parcels_holding bigint, cash_holding numeric, cash_remitted numeric
  )
  language sql stable security definer set search_path = public as $$
  select d.id, d.carrier_id, d.name,
    count(p.*) filter (where p.state = 'collected'),
    coalesce(sum(p.cod_amount) filter (where p.state = 'collected'),0),
    coalesce(sum(p.cod_amount) filter (where p.state = 'remitted'),0)
  from driver d
  left join consignment c on c.driver_id = d.id
  left join payment p on p.consignment_id = c.id and p.mode = 'cash'
  where d.carrier_id = my_carrier_id()   -- caller's carrier only
  group by d.id, d.carrier_id, d.name
$$;
grant execute on function my_cash_ledger() to authenticated;

-- ══════════════════════════════════════════════════════════════════
--  After v15: the dispatch board's cash ledger loads via my_cash_ledger()
--  without recursion. (Frontend updated to call this RPC.)
-- ══════════════════════════════════════════════════════════════════
