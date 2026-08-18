-- path: supabase/migrations/0021_fix_audit_status_guard.sql
-- Fix: audit_row_change() raised 42703 on UPDATE for any audited table without
-- a `status` column, making those rows insert-only.
--
-- 0012 tried to guard the status-transition branch with a runtime test:
--
--   if (to_jsonb(new) ? 'status') and (new.status is distinct from old.status)
--
-- The intent is right and the mechanism cannot work. PL/pgSQL hands the whole
-- boolean to the SQL engine as one expression, so `new.status` has to resolve
-- when that expression is planned — before the `?` test it was meant to be
-- protected by ever runs. On a table with no such column it is a plan-time
-- failure, and `and` short-circuiting never gets the chance to help.
--
-- Two tables carry the audit trigger without a `status` column:
--   * inspection_items (0015) — every result a inspector records is an UPDATE,
--     so conducting an inspection failed at the first pass/fail mark.
--   * risk_assessments (0014) — any revision to an assessment failed.
-- Both accepted INSERTs, which is why this survived: records could be created
-- but never edited.
--
-- The fix compares the field through jsonb, so no column reference is compiled
-- against the row type and the guard is genuinely evaluated at runtime. Tables
-- that do have `status` behave exactly as before — ->> returns text on both
-- sides, and `is distinct from` treats a missing key (NULL) correctly.

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
    -- Compared through jsonb so this is safe on tables that have no such
    -- column: referencing new.status directly would fail to plan there.
    if (v_after ? 'status') and (v_after->>'status' is distinct from v_before->>'status') then
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

-- ===========================================================================
-- DOWN MIGRATION:
--   Restore the 0012 body. Doing so reintroduces the 42703 on UPDATE for
--   inspection_items and risk_assessments.
-- ===========================================================================
