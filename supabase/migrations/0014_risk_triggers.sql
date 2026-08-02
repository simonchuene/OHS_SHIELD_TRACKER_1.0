-- path: supabase/migrations/0014_risk_triggers.sql
-- Prompt 9: audit risk_assessments, and keep hazards.risk_level in sync with the
-- latest assessment's generated band (so the hazard card colour / dashboard
-- heatmap reflect the current risk without a client round-trip).

-- Audit (reuse 0012 trigger function).
create trigger trg_risk_audit
  after insert or update on public.risk_assessments
  for each row execute function public.audit_row_change('risk_assessment');

-- Mirror the newest assessment's band onto the parent hazard.
create or replace function public.sync_hazard_risk_level()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.hazards
     set risk_level = new.risk_band
   where id = new.hazard_id;
  return new;
end;
$$;

create trigger trg_risk_sync_hazard
  after insert on public.risk_assessments
  for each row execute function public.sync_hazard_risk_level();

-- ===========================================================================
-- DOWN MIGRATION:
--   drop trigger if exists trg_risk_sync_hazard on public.risk_assessments;
--   drop function if exists public.sync_hazard_risk_level();
--   drop trigger if exists trg_risk_audit on public.risk_assessments;
-- ===========================================================================
