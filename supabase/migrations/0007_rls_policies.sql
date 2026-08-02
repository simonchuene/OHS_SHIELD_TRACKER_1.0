-- path: supabase/migrations/0007_rls_policies.sql
-- Migration 0007: enable RLS on EVERY table + per-action policies aligned to the
-- Master Prompt RBAC matrix, with Company -> Site -> Department scoping (D3 helpers).
-- Rank thresholds: employee=1, supervisor=2, safety_officer=3, manager=4, administrator=5.
-- Default is deny: a table with RLS on and no matching policy rejects the operation.

-- ===========================================================================
-- 1. ENABLE RLS ON EVERY TABLE (none left unsecured)
-- ===========================================================================
alter table public.companies            enable row level security;
alter table public.sites                enable row level security;
alter table public.departments          enable row level security;
alter table public.users                enable row level security;
alter table public.roles                enable row level security;
alter table public.user_roles           enable row level security;
alter table public.user_profiles        enable row level security;
alter table public.hazards              enable row level security;
alter table public.risk_assessments     enable row level security;
alter table public.incidents            enable row level security;
alter table public.investigations       enable row level security;
alter table public.corrective_actions   enable row level security;
alter table public.inspections          enable row level security;
alter table public.inspection_items     enable row level security;
alter table public.notifications        enable row level security;
alter table public.device_tokens        enable row level security;
alter table public.attachments          enable row level security;
alter table public.attachment_versions  enable row level security;
alter table public.audit_logs           enable row level security;
alter table public.sync_queue           enable row level security;

-- ===========================================================================
-- 2. ORGANISATION / REFERENCE
-- ===========================================================================

-- roles: global reference, readable by all authenticated; no client writes.
create policy roles_select on public.roles
  for select to authenticated using (true);

-- companies: read own company; writes admin-only.
create policy companies_select on public.companies
  for select to authenticated using (id = app.current_company_id());
create policy companies_admin_write on public.companies
  for all to authenticated
  using (id = app.current_company_id() and app.has_min_rank(5))
  with check (id = app.current_company_id() and app.has_min_rank(5));

-- sites / departments: read within company; writes admin-only.
create policy sites_select on public.sites
  for select to authenticated using (company_id = app.current_company_id());
create policy sites_admin_write on public.sites
  for all to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(5))
  with check (company_id = app.current_company_id() and app.has_min_rank(5));

create policy departments_select on public.departments
  for select to authenticated using (company_id = app.current_company_id());
create policy departments_admin_write on public.departments
  for all to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(5))
  with check (company_id = app.current_company_id() and app.has_min_rank(5));

-- ===========================================================================
-- 3. IDENTITY / RBAC
-- ===========================================================================

-- users: readable within same company (for name display); writes via trigger/service role.
create policy users_select on public.users
  for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from public.user_profiles p
      where p.user_id = public.users.id
        and p.company_id = app.current_company_id()
    )
  );

-- user_profiles: read within company; self-update; admin manages any in company.
create policy user_profiles_select on public.user_profiles
  for select to authenticated
  using (company_id = app.current_company_id());
create policy user_profiles_self_insert on public.user_profiles
  for insert to authenticated
  with check (user_id = auth.uid() or app.has_min_rank(5));
create policy user_profiles_update on public.user_profiles
  for update to authenticated
  using (user_id = auth.uid() or (company_id = app.current_company_id() and app.has_min_rank(5)))
  with check (user_id = auth.uid() or (company_id = app.current_company_id() and app.has_min_rank(5)));

-- user_roles: "Manage Users & Roles" = Administrator only. Read within company.
create policy user_roles_select on public.user_roles
  for select to authenticated
  using (company_id = app.current_company_id());
create policy user_roles_admin_manage on public.user_roles
  for all to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(5))
  with check (company_id = app.current_company_id() and app.has_min_rank(5));

-- ===========================================================================
-- 4. HAZARDS
--    View: own (all) / dept (sup) / site (SO) / enterprise (mgr, admin)
--    Report: all roles. Close (status='closed'): Safety Officer+.
-- ===========================================================================
create policy hazards_select on public.hazards
  for select to authenticated
  using (
    company_id = app.current_company_id() and (
      app.has_min_rank(4)
      or (app.user_rank() = 3 and site_id = app.current_site_id())
      or (app.user_rank() = 2 and department_id = app.current_department_id())
      or reporter_id = auth.uid()
    )
  );
create policy hazards_insert on public.hazards
  for insert to authenticated
  with check (company_id = app.current_company_id() and reporter_id = auth.uid() and app.has_min_rank(1));
create policy hazards_update on public.hazards
  for update to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(2))
  with check (
    company_id = app.current_company_id()
    and (status <> 'closed' or app.has_min_rank(3))   -- Close Hazard = SO+
  );

-- ===========================================================================
-- 5. RISK ASSESSMENTS  (Perform = Supervisor+; own-hazard reporters may view)
-- ===========================================================================
create policy risk_select on public.risk_assessments
  for select to authenticated
  using (
    company_id = app.current_company_id() and (
      app.has_min_rank(2)
      or exists (select 1 from public.hazards h where h.id = hazard_id and h.reporter_id = auth.uid())
    )
  );
create policy risk_insert on public.risk_assessments
  for insert to authenticated
  with check (company_id = app.current_company_id() and assessor_id = auth.uid() and app.has_min_rank(2));
create policy risk_update on public.risk_assessments
  for update to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(2))
  with check (company_id = app.current_company_id() and app.has_min_rank(2));

-- ===========================================================================
-- 6. INCIDENTS  (Report: all. Close: Safety Officer+.)
-- ===========================================================================
create policy incidents_select on public.incidents
  for select to authenticated
  using (
    company_id = app.current_company_id() and (
      app.has_min_rank(4)
      or (app.user_rank() = 3 and site_id = app.current_site_id())
      or (app.user_rank() = 2 and department_id = app.current_department_id())
      or reporter_id = auth.uid()
    )
  );
create policy incidents_insert on public.incidents
  for insert to authenticated
  with check (company_id = app.current_company_id() and reporter_id = auth.uid() and app.has_min_rank(1));
create policy incidents_update on public.incidents
  for update to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(2))
  with check (
    company_id = app.current_company_id()
    and (status <> 'closed' or app.has_min_rank(3))   -- Close Incident = SO+
  );

-- ===========================================================================
-- 7. INVESTIGATIONS  (Conduct = Supervisor+; supervisor/SO scoped to site)
-- ===========================================================================
create policy invest_select on public.investigations
  for select to authenticated
  using (
    company_id = app.current_company_id() and (
      app.has_min_rank(4)
      or (app.has_min_rank(2) and site_id = app.current_site_id())
      or investigator_id = auth.uid()
    )
  );
create policy invest_insert on public.investigations
  for insert to authenticated
  with check (company_id = app.current_company_id() and investigator_id = auth.uid() and app.has_min_rank(2));
create policy invest_update on public.investigations
  for update to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(2))
  with check (company_id = app.current_company_id() and app.has_min_rank(2));

-- ===========================================================================
-- 8. CORRECTIVE ACTIONS (CAPA)
--    Create/Assign = Supervisor+. Verify & Close (status in verification/closed) = SO+.
-- ===========================================================================
create policy capa_select on public.corrective_actions
  for select to authenticated
  using (
    company_id = app.current_company_id() and (
      app.has_min_rank(4)
      or (app.has_min_rank(2) and site_id = app.current_site_id())
      or owner_id = auth.uid()
    )
  );
create policy capa_insert on public.corrective_actions
  for insert to authenticated
  with check (company_id = app.current_company_id() and app.has_min_rank(2));
create policy capa_update on public.corrective_actions
  for update to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(2))
  with check (
    company_id = app.current_company_id()
    and (status not in ('verification','closed') or app.has_min_rank(3))  -- Verify & Close CAPA = SO+
  );

-- ===========================================================================
-- 9. INSPECTIONS + ITEMS  (Conduct = Supervisor+)
-- ===========================================================================
create policy inspections_select on public.inspections
  for select to authenticated
  using (
    company_id = app.current_company_id() and (
      app.has_min_rank(4)
      or (app.user_rank() = 3 and site_id = app.current_site_id())
      or (app.user_rank() = 2 and department_id = app.current_department_id())
      or inspector_id = auth.uid()
    )
  );
create policy inspections_insert on public.inspections
  for insert to authenticated
  with check (company_id = app.current_company_id() and inspector_id = auth.uid() and app.has_min_rank(2));
create policy inspections_update on public.inspections
  for update to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(2))
  with check (company_id = app.current_company_id() and app.has_min_rank(2));

create policy insp_items_select on public.inspection_items
  for select to authenticated
  using (
    company_id = app.current_company_id() and exists (
      select 1 from public.inspections i
      where i.id = inspection_id and (
        app.has_min_rank(4)
        or (app.user_rank() = 3 and i.site_id = app.current_site_id())
        or (app.user_rank() = 2 and i.department_id = app.current_department_id())
        or i.inspector_id = auth.uid()
      )
    )
  );
create policy insp_items_write on public.inspection_items
  for all to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(2))
  with check (company_id = app.current_company_id() and app.has_min_rank(2));

-- ===========================================================================
-- 10. NOTIFICATIONS + DEVICE TOKENS
--     Inserts are server-side (service role bypasses RLS); recipient reads/updates own.
-- ===========================================================================
create policy notifications_select on public.notifications
  for select to authenticated using (recipient_id = auth.uid());
create policy notifications_update_own on public.notifications
  for update to authenticated
  using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

create policy device_tokens_rw on public.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and company_id = app.current_company_id());

-- ===========================================================================
-- 11. ATTACHMENTS + VERSIONS  (company-scoped; create any authenticated; soft-delete SO+)
-- ===========================================================================
create policy attachments_select on public.attachments
  for select to authenticated using (company_id = app.current_company_id());
create policy attachments_insert on public.attachments
  for insert to authenticated
  with check (company_id = app.current_company_id() and app.has_min_rank(1));
create policy attachments_update on public.attachments
  for update to authenticated
  using (company_id = app.current_company_id() and (created_by = auth.uid() or app.has_min_rank(3)))
  with check (company_id = app.current_company_id());

create policy attach_versions_select on public.attachment_versions
  for select to authenticated using (company_id = app.current_company_id());
create policy attach_versions_insert on public.attachment_versions
  for insert to authenticated
  with check (company_id = app.current_company_id() and app.has_min_rank(1));
create policy attach_versions_update on public.attachment_versions
  for update to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(1))
  with check (company_id = app.current_company_id());

-- ===========================================================================
-- 12. AUDIT LOGS  (immutable — SELECT for SO/Manager/Admin; NO insert/update/delete policy)
--     Writes happen via SECURITY DEFINER triggers / Edge Functions (service role).
-- ===========================================================================
create policy audit_select on public.audit_logs
  for select to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(3));

-- Belt-and-braces immutability at the grant level (defence in depth):
revoke insert, update, delete on public.audit_logs from authenticated, anon;
grant  select on public.audit_logs to authenticated;

-- ===========================================================================
-- 13. SYNC QUEUE  (each user owns their outbox rows)
-- ===========================================================================
create policy sync_queue_rw on public.sync_queue
  for all to authenticated
  using (user_id = auth.uid() and company_id = app.current_company_id())
  with check (user_id = auth.uid() and company_id = app.current_company_id());
