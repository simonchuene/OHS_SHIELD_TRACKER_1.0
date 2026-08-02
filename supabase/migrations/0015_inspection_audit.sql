-- path: supabase/migrations/0015_inspection_audit.sql
-- Prompt 12: audit inspections + inspection_items (reuse 0012 trigger fn).

create trigger trg_inspections_audit
  after insert or update on public.inspections
  for each row execute function public.audit_row_change('inspection');

create trigger trg_inspection_items_audit
  after insert or update on public.inspection_items
  for each row execute function public.audit_row_change('inspection_item');

-- ===========================================================================
-- DOWN MIGRATION:
--   drop trigger if exists trg_inspection_items_audit on public.inspection_items;
--   drop trigger if exists trg_inspections_audit on public.inspections;
-- ===========================================================================
