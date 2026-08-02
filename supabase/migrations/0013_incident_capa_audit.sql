-- path: supabase/migrations/0013_incident_capa_audit.sql
-- Prompt 8A: attach the reusable audit trigger (0012) to incidents, and to the
-- entities an incident can generate via linkage (investigations, corrective_actions)
-- so those writes are audited from the moment they exist.

create trigger trg_incidents_audit
  after insert or update on public.incidents
  for each row execute function public.audit_row_change('incident');

create trigger trg_investigations_audit
  after insert or update on public.investigations
  for each row execute function public.audit_row_change('investigation');

create trigger trg_capa_audit
  after insert or update on public.corrective_actions
  for each row execute function public.audit_row_change('corrective_action');

-- ===========================================================================
-- DOWN MIGRATION:
--   drop trigger if exists trg_capa_audit on public.corrective_actions;
--   drop trigger if exists trg_investigations_audit on public.investigations;
--   drop trigger if exists trg_incidents_audit on public.incidents;
-- ===========================================================================
