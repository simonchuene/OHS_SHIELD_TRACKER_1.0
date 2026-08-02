-- path: supabase/migrations/0010_user_mgmt_rls.sql
-- Prompt 4C: RLS reconciliation for user tables, extending the 2B layer.
-- Tightens user_profiles/user_roles writes to Administrator-only (rank >= 5),
-- scoped to the admin's own company, and removes any hard-DELETE path
-- (deactivation is a status change — mirrors audit immutability).
-- Client never provisions users; invite/activation runs via service-role Edge
-- Functions (Prompt 5A) which bypass RLS.

-- ---------------------------------------------------------------------------
-- Replace the permissive self-insert / self-or-admin-update policies from 2B.
-- ---------------------------------------------------------------------------
drop policy if exists user_profiles_self_insert on public.user_profiles;
drop policy if exists user_profiles_update      on public.user_profiles;

-- SELECT within company retained from 2B (user_profiles_select). Add admin writes:
create policy user_profiles_admin_insert on public.user_profiles
  for insert to authenticated
  with check (company_id = app.current_company_id() and app.has_min_rank(5));

create policy user_profiles_admin_update on public.user_profiles
  for update to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(5))
  with check (company_id = app.current_company_id() and app.has_min_rank(5));

-- ---------------------------------------------------------------------------
-- user_roles: split the 2B FOR ALL admin policy into INSERT + UPDATE only
-- (no DELETE). Role/scope changes are UPDATEs; revocation is a status/role
-- change, not a row delete.
-- ---------------------------------------------------------------------------
drop policy if exists user_roles_admin_manage on public.user_roles;
-- user_roles_select (company scope) retained from 2B.

create policy user_roles_admin_insert on public.user_roles
  for insert to authenticated
  with check (company_id = app.current_company_id() and app.has_min_rank(5));

create policy user_roles_admin_update on public.user_roles
  for update to authenticated
  using (company_id = app.current_company_id() and app.has_min_rank(5))
  with check (company_id = app.current_company_id() and app.has_min_rank(5));

-- ---------------------------------------------------------------------------
-- No hard DELETE on user tables at the grant level (defence in depth).
-- ---------------------------------------------------------------------------
revoke delete on public.user_profiles from authenticated, anon;
revoke delete on public.user_roles    from authenticated, anon;
revoke delete on public.users         from authenticated, anon;

-- ===========================================================================
-- DOWN MIGRATION (rollback):
-- ---------------------------------------------------------------------------
-- drop policy if exists user_roles_admin_update  on public.user_roles;
-- drop policy if exists user_roles_admin_insert  on public.user_roles;
-- create policy user_roles_admin_manage on public.user_roles
--   for all to authenticated
--   using (company_id = app.current_company_id() and app.has_min_rank(5))
--   with check (company_id = app.current_company_id() and app.has_min_rank(5));
-- drop policy if exists user_profiles_admin_update on public.user_profiles;
-- drop policy if exists user_profiles_admin_insert on public.user_profiles;
-- create policy user_profiles_self_insert on public.user_profiles
--   for insert to authenticated with check (user_id = auth.uid() or app.has_min_rank(5));
-- create policy user_profiles_update on public.user_profiles
--   for update to authenticated
--   using (user_id = auth.uid() or (company_id = app.current_company_id() and app.has_min_rank(5)))
--   with check (user_id = auth.uid() or (company_id = app.current_company_id() and app.has_min_rank(5)));
-- (DELETE grants intentionally NOT restored.)
-- ===========================================================================
