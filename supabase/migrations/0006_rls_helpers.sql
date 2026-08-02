-- path: supabase/migrations/0006_rls_helpers.sql
-- Migration 0006: RLS scope helpers (D3).
-- SECURITY DEFINER functions read the caller's scope/role from user_profiles/user_roles
-- keyed on auth.uid(). DEFINER lets them bypass RLS on those tables, which also avoids
-- policy recursion. All are STABLE and expose only scalar scope facts.

create schema if not exists app;

-- Caller's company (tenant root).
create or replace function app.current_company_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select company_id from public.user_profiles where user_id = auth.uid();
$$;

-- Caller's site.
create or replace function app.current_site_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select site_id from public.user_profiles where user_id = auth.uid();
$$;

-- Caller's department.
create or replace function app.current_department_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select department_id from public.user_profiles where user_id = auth.uid();
$$;

-- Caller's highest role rank within their own company
-- (employee=1, supervisor=2, safety_officer=3, manager=4, administrator=5; 0 = none).
create or replace function app.user_rank()
returns smallint
language sql stable security definer set search_path = public
as $$
  select coalesce(max(r.rank), 0)::smallint
  from public.user_roles ur
  join public.roles r on r.id = ur.role_id
  where ur.user_id = auth.uid()
    and ur.company_id = (select company_id from public.user_profiles where user_id = auth.uid());
$$;

-- Convenience threshold check.
create or replace function app.has_min_rank(min_rank smallint)
returns boolean
language sql stable security definer set search_path = public
as $$
  select app.user_rank() >= min_rank;
$$;

grant usage on schema app to authenticated;
grant execute on all functions in schema app to authenticated;
