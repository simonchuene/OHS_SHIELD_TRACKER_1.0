-- path: supabase/migrations/0012_audit_triggers.sql
-- Prompt 7: server-side audit logging via a reusable trigger. Writes an
-- immutable audit_logs row (before/after) for every business write. Runs as
-- SECURITY DEFINER so it can insert into audit_logs (client INSERT is denied, 2B)
-- while still reading auth.uid() from the caller's JWT context.
-- Each module attaches this trigger to its table (hazards here; others in their prompts).

create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entity   text := tg_argv[0];              -- e.g. 'hazard'
  v_company  uuid;
  v_entityid uuid;
  v_before   jsonb;
  v_after    jsonb;
  v_action   text;
begin
  if (tg_op = 'INSERT') then
    v_after := to_jsonb(new); v_company := new.company_id; v_entityid := new.id;
    v_action := v_entity || '.created';
  elsif (tg_op = 'UPDATE') then
    v_before := to_jsonb(old); v_after := to_jsonb(new);
    v_company := new.company_id; v_entityid := new.id;
    -- Surface status transitions distinctly when a `status` column changed.
    if (to_jsonb(new) ? 'status') and (new.status is distinct from old.status) then
      v_action := v_entity || '.status_changed';
    else
      v_action := v_entity || '.updated';
    end if;
  else -- DELETE (not expected for business tables; captured for completeness)
    v_before := to_jsonb(old); v_company := old.company_id; v_entityid := old.id;
    v_action := v_entity || '.deleted';
  end if;

  insert into public.audit_logs (company_id, actor_id, action, entity_type, entity_id, before_state, after_state)
  values (v_company, auth.uid(), v_action, v_entity, v_entityid, v_before, v_after);

  return coalesce(new, old);
end;
$$;

-- Attach to hazards (INSERT/UPDATE). Status transitions are refined in Prompt 8.
create trigger trg_hazards_audit
  after insert or update on public.hazards
  for each row execute function public.audit_row_change('hazard');

-- ===========================================================================
-- DOWN MIGRATION:
--   drop trigger if exists trg_hazards_audit on public.hazards;
--   drop function if exists public.audit_row_change();
-- ===========================================================================
