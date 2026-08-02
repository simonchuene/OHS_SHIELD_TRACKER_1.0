-- path: supabase/migrations/0002_identity_and_org.sql
-- Migration 0002: Multi-site tenant hierarchy + identity/RBAC tables.
-- Hierarchy: companies -> sites -> departments -> user_profiles(users).
-- No RLS here (Prompt 2B). No sample/company data (DATA QUALITY RULE).

-- ---------------------------------------------------------------------------
-- companies  (D1: tenant root — added vs. Master Prompt table list, OQ1 confirmed)
-- ---------------------------------------------------------------------------
create table public.companies (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  code         text not null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint uq_companies_code unique (code)
);

-- ---------------------------------------------------------------------------
-- sites
-- ---------------------------------------------------------------------------
create table public.sites (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  name         text not null,
  code         text not null,
  timezone     text not null default 'Africa/Johannesburg',
  latitude     double precision,
  longitude    double precision,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint uq_sites_company_code unique (company_id, code)
);

-- ---------------------------------------------------------------------------
-- departments
-- ---------------------------------------------------------------------------
create table public.departments (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  site_id      uuid not null references public.sites(id) on delete restrict,
  name         text not null,
  code         text not null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint uq_departments_site_code unique (site_id, code)
);

-- ---------------------------------------------------------------------------
-- users  (thin mirror/extension of auth.users; kept in sync by a trigger in 0005)
-- ---------------------------------------------------------------------------
create table public.users (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text not null,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint uq_users_email unique (email)
);

-- ---------------------------------------------------------------------------
-- roles  (global reference data — NOT tenant-scoped; seeded in seed.sql)
-- ---------------------------------------------------------------------------
create table public.roles (
  id           uuid primary key default gen_random_uuid(),
  code         role_code not null,
  name         text not null,
  rank         smallint not null,   -- ordering/escalation: employee=1 .. administrator=5
  created_at   timestamptz not null default now(),
  constraint uq_roles_code unique (code),
  constraint uq_roles_rank unique (rank)
);

-- ---------------------------------------------------------------------------
-- user_profiles  (org scoping + minimal personal profile; 1:1 with users)
-- ---------------------------------------------------------------------------
create table public.user_profiles (
  user_id       uuid primary key references public.users(id) on delete cascade,
  company_id    uuid not null references public.companies(id) on delete restrict,
  site_id       uuid references public.sites(id) on delete set null,
  department_id uuid references public.departments(id) on delete set null,
  first_name    text not null,
  last_name     text not null,
  job_title     text,
  phone         text,
  avatar_path   text,          -- Supabase Storage path; icon/assets referenced by path (P5)
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- user_roles  (RBAC assignment, scoped per company; optional site scope)
-- ---------------------------------------------------------------------------
create table public.user_roles (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id) on delete cascade,
  role_id      uuid not null references public.roles(id) on delete restrict,
  company_id   uuid not null references public.companies(id) on delete restrict,
  site_id      uuid references public.sites(id) on delete set null,
  granted_by   uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  constraint uq_user_roles_scope unique (user_id, role_id, company_id, site_id)
);
