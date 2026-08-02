-- path: supabase/migrations/0009_user_mgmt_reconciliation.sql
-- Prompt 4C: forward delta migration reconciling the existing user tables
-- (built in 2A/2B) with MVP1_2.md -> USER MANAGEMENT & PROVISIONING.
-- Additive & reversible. Does NOT drop/recreate tables that are already correct.
-- RLS changes are in 0010. Down-migration at the bottom (commented).

-- ---------------------------------------------------------------------------
-- 1. user lifecycle status enum
-- ---------------------------------------------------------------------------
create type user_status as enum ('invited', 'active', 'suspended', 'deactivated');

-- ---------------------------------------------------------------------------
-- 2. user_profiles: add status + lifecycle timestamps; backfill from is_active
-- ---------------------------------------------------------------------------
alter table public.user_profiles
  add column status user_status not null default 'active',
  add column invited_at timestamptz,
  add column activated_at timestamptz,
  add column deactivated_at timestamptz;

-- Backfill existing rows: active users stay active, others deactivated.
update public.user_profiles
   set status = case when is_active then 'active'::user_status else 'deactivated'::user_status end,
       activated_at = case when is_active then coalesce(activated_at, created_at) else activated_at end,
       deactivated_at = case when is_active then deactivated_at else coalesce(deactivated_at, now()) end;

comment on column public.user_profiles.is_active is
  'DEPRECATED — superseded by status. Retained for backward compatibility; keep in sync during transition.';
comment on column public.user_profiles.status is
  'User lifecycle: invited -> active -> suspended -> deactivated. Never hard-delete a user.';

create index idx_user_profiles_status on public.user_profiles(status);

-- ---------------------------------------------------------------------------
-- 3. user_roles: make scope-aware (add department_id; already had site_id)
-- ---------------------------------------------------------------------------
alter table public.user_roles
  add column department_id uuid references public.departments(id) on delete set null;

-- Existing rows are company-wide (site_id/department_id NULL) — nothing to backfill.

-- Replace the old scope unique constraint with one that treats NULLs as equal,
-- so duplicate company-wide (or same-scope) assignments are rejected (PG15+).
alter table public.user_roles drop constraint if exists uq_user_roles_scope;
alter table public.user_roles
  add constraint uq_user_roles_scope
  unique nulls not distinct (user_id, role_id, company_id, site_id, department_id);

create index idx_user_roles_site       on public.user_roles(site_id);
create index idx_user_roles_department on public.user_roles(department_id);

-- ===========================================================================
-- DOWN MIGRATION (rollback) — apply in reverse if needed:
-- ---------------------------------------------------------------------------
-- drop index if exists public.idx_user_roles_department;
-- drop index if exists public.idx_user_roles_site;
-- alter table public.user_roles drop constraint if exists uq_user_roles_scope;
-- alter table public.user_roles add constraint uq_user_roles_scope
--   unique (user_id, role_id, company_id, site_id);
-- alter table public.user_roles drop column if exists department_id;
-- drop index if exists public.idx_user_profiles_status;
-- alter table public.user_profiles
--   drop column if exists deactivated_at,
--   drop column if exists activated_at,
--   drop column if exists invited_at,
--   drop column if exists status;
-- drop type if exists user_status;
-- ===========================================================================
