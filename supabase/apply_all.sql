-- OHS Shield Tracker — combined schema apply (RESET + migrations 0001-0015 + seed).
-- Paste this WHOLE file into the Supabase SQL Editor and Run. Safe to re-run on a fresh project.

-- ==================== RESET (clears any partial prior run) ====================
drop trigger if exists trg_auth_user_created on auth.users;
drop trigger if exists trg_auth_user_confirmed on auth.users;
drop policy if exists attachments_read on storage.objects;
drop policy if exists attachments_upload on storage.objects;
drop policy if exists attachments_modify on storage.objects;
drop policy if exists attachments_delete on storage.objects;
drop schema if exists app cascade;
drop schema if exists public cascade;
create schema public;
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all privileges on schema public to postgres, service_role;
alter default privileges in schema public grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on routines to postgres, anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to postgres, anon, authenticated, service_role;

-- ==================== migrations/0001_types_and_helpers.sql ====================
-- path: supabase/migrations/0001_types_and_helpers.sql
-- OHS Shield Tracker — MVP1 schema (Prompt 2A). Structure only; RLS added in Prompt 2B.
-- Migration 0001: extensions, shared helper functions, and locked-domain ENUM types.
-- Locked domain values are owned by MVP1_1.md (Master Prompt); enum members mirror them verbatim.

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto";      -- gen_random_uuid()

-- ---------------------------------------------------------------------------
-- Shared trigger function: maintain updated_at on row change
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Optimistic-concurrency helper: bump version on every update
-- (used by offline-writable tables for LWW / field-merge base_version checks)
-- ---------------------------------------------------------------------------
create or replace function public.bump_version()
returns trigger
language plpgsql
as $$
begin
  new.version := coalesce(old.version, 0) + 1;
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- ENUM TYPES (mirror Master Prompt locked values)
-- ---------------------------------------------------------------------------

-- Identity / RBAC
create type role_code as enum
  ('employee', 'supervisor', 'safety_officer', 'manager', 'administrator');

-- Hazard
create type hazard_category as enum
  ('physical', 'chemical', 'biological', 'ergonomic',
   'psychosocial', 'noise', 'radiation', 'environmental');

create type hazard_status as enum
  ('draft', 'submitted', 'assessment', 'investigation',
   'capa', 'verification', 'closed');

-- Risk
create type risk_band as enum ('low', 'medium', 'high', 'critical');

-- Incident
create type incident_type as enum
  ('near_miss', 'first_aid', 'medical_treatment',
   'lost_time_injury', 'property_damage', 'environmental_incident');

create type incident_severity as enum ('minor', 'moderate', 'serious', 'critical');

create type incident_status as enum
  ('reported', 'investigated', 'capa', 'verified', 'closed');

-- Investigation
create type investigation_method as enum ('five_whys', 'fishbone');

create type investigation_status as enum
  ('open', 'in_progress', 'pending_review', 'completed');

-- CAPA
create type capa_priority as enum ('critical', 'high', 'medium', 'low');

create type capa_status as enum
  ('created', 'assigned', 'in_progress', 'verification', 'closed');

-- Inspections
create type inspection_type as enum
  ('housekeeping', 'fire_safety', 'ppe', 'vehicle', 'equipment');

create type inspection_status as enum
  ('draft', 'in_progress', 'submitted', 'closed');

create type inspection_item_result as enum ('pass', 'fail', 'na');

-- Cross-cutting
create type attachment_owner_type as enum
  ('hazard', 'incident', 'investigation', 'corrective_action', 'inspection');

create type notification_trigger as enum
  ('hazard_created', 'incident_created', 'risk_assessed',
   'capa_assigned', 'capa_overdue', 'investigation_due', 'inspection_due');

create type notification_priority as enum ('low', 'normal', 'high', 'critical');

create type device_platform as enum ('ios', 'android', 'web');

create type sync_operation as enum ('insert', 'update', 'delete');

create type sync_status as enum ('pending', 'syncing', 'synced', 'failed');

-- ==================== migrations/0002_identity_and_org.sql ====================
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

-- ==================== migrations/0003_safety_core.sql ====================
-- path: supabase/migrations/0003_safety_core.sql
-- Migration 0003: Safety Operations Core.
-- Tables: hazards, risk_assessments, incidents, investigations,
--         corrective_actions, inspections, inspection_items.
-- Linkage (D2): typed nullable FKs + CHECK (exactly one origin). No RLS here.
-- `version` columns support offline conflict resolution (D4) via bump_version() (0005).

-- ===========================================================================
-- hazards
-- ===========================================================================
create table public.hazards (
  id                 uuid primary key default gen_random_uuid(),
  company_id         uuid not null references public.companies(id) on delete restrict,
  site_id            uuid references public.sites(id) on delete set null,
  department_id      uuid references public.departments(id) on delete set null,
  reference          text,                       -- human-readable "Hazard ID", assigned on submit
  title              text not null,
  description        text,
  category           hazard_category not null,
  status             hazard_status not null default 'draft',
  risk_level         risk_band,                  -- mirror of latest risk_assessment band
  source_incident_id uuid,                       -- FK added below (hazards<->incidents cycle)
  reporter_id        uuid not null references public.users(id) on delete restrict,
  latitude           double precision,
  longitude          double precision,
  location_text      text,
  reported_at        timestamptz not null default now(),
  closed_at          timestamptz,
  version            integer not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint uq_hazards_company_reference unique (company_id, reference)
);

-- ===========================================================================
-- incidents  (first-class; links to an originating hazard, if any)
-- ===========================================================================
create table public.incidents (
  id                 uuid primary key default gen_random_uuid(),
  company_id         uuid not null references public.companies(id) on delete restrict,
  site_id            uuid references public.sites(id) on delete set null,
  department_id      uuid references public.departments(id) on delete set null,
  reference          text,
  incident_type      incident_type not null,
  severity           incident_severity not null,
  status             incident_status not null default 'reported',
  occurred_at        timestamptz not null,
  location_text      text,
  latitude           double precision,
  longitude          double precision,
  description        text,
  witnesses          jsonb not null default '[]'::jsonb,   -- D9: POPIA-minimal, [{name, contact?, statement?}]
  injured_party      jsonb,                                 -- D9: POPIA-minimal, nullable
  source_hazard_id   uuid references public.hazards(id) on delete set null,
  reporter_id        uuid not null references public.users(id) on delete restrict,
  verified_by        uuid references public.users(id) on delete set null,
  verified_at        timestamptz,
  closed_at          timestamptz,
  version            integer not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint uq_incidents_company_reference unique (company_id, reference)
);

-- Close the hazards<->incidents cycle now that incidents exists.
alter table public.hazards
  add constraint fk_hazards_source_incident
  foreign key (source_incident_id) references public.incidents(id) on delete set null;

-- ===========================================================================
-- risk_assessments  (owned by a hazard; score + band are generated)
-- ===========================================================================
create table public.risk_assessments (
  id                   uuid primary key default gen_random_uuid(),
  company_id           uuid not null references public.companies(id) on delete restrict,
  hazard_id            uuid not null references public.hazards(id) on delete cascade,
  likelihood           smallint not null,
  severity             smallint not null,
  risk_score           integer generated always as (likelihood * severity) stored,
  risk_band            risk_band generated always as (
                         case
                           when likelihood * severity between 1  and 5  then 'low'::risk_band
                           when likelihood * severity between 6  and 12 then 'medium'::risk_band
                           when likelihood * severity between 13 and 17 then 'high'::risk_band
                           else 'critical'::risk_band            -- 18..25
                         end
                       ) stored,
  current_controls     text,
  required_controls    text,
  residual_likelihood  smallint,
  residual_severity    smallint,
  assessor_id          uuid not null references public.users(id) on delete restrict,
  review_date          date,
  assessed_at          timestamptz not null default now(),
  version              integer not null default 0,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint ck_risk_likelihood       check (likelihood between 1 and 5),
  constraint ck_risk_severity         check (severity   between 1 and 5),
  constraint ck_risk_res_likelihood   check (residual_likelihood is null or residual_likelihood between 1 and 5),
  constraint ck_risk_res_severity     check (residual_severity   is null or residual_severity   between 1 and 5)
);

-- ===========================================================================
-- inspections
-- ===========================================================================
create table public.inspections (
  id               uuid primary key default gen_random_uuid(),
  company_id       uuid not null references public.companies(id) on delete restrict,
  site_id          uuid references public.sites(id) on delete set null,
  department_id    uuid references public.departments(id) on delete set null,
  reference        text,
  inspection_type  inspection_type not null,
  inspector_id     uuid not null references public.users(id) on delete restrict,
  status           inspection_status not null default 'draft',
  scheduled_date   date,
  conducted_at     timestamptz,
  score            numeric(5,2),               -- % pass, computed by app/edge
  version          integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint uq_inspections_company_reference unique (company_id, reference)
);

-- ===========================================================================
-- inspection_items  (a fail auto-creates a hazard + a CAPA — FKs added below)
-- ===========================================================================
create table public.inspection_items (
  id                   uuid primary key default gen_random_uuid(),
  company_id           uuid not null references public.companies(id) on delete restrict,
  inspection_id        uuid not null references public.inspections(id) on delete cascade,
  position             integer not null default 0,
  prompt               text not null,
  result               inspection_item_result,
  notes                text,
  generated_hazard_id  uuid,                    -- FK added below
  generated_capa_id    uuid,                    -- FK added below
  version              integer not null default 0,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- ===========================================================================
-- investigations  (originates from a hazard OR an incident — exactly one)
-- ===========================================================================
create table public.investigations (
  id                    uuid primary key default gen_random_uuid(),
  company_id            uuid not null references public.companies(id) on delete restrict,
  site_id               uuid references public.sites(id) on delete set null,
  hazard_id             uuid references public.hazards(id) on delete cascade,
  incident_id           uuid references public.incidents(id) on delete cascade,
  method                investigation_method,
  immediate_cause       text,
  contributing_factors  text,
  root_cause            text,
  recommendations       text,
  analysis              jsonb,                   -- 5-Whys chain / fishbone structure
  investigator_id       uuid not null references public.users(id) on delete restrict,
  status                investigation_status not null default 'open',
  opened_at             timestamptz not null default now(),
  completed_at          timestamptz,
  version               integer not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint ck_investigations_one_source check (
    (case when hazard_id  is not null then 1 else 0 end)
  + (case when incident_id is not null then 1 else 0 end) = 1
  )
);

-- ===========================================================================
-- corrective_actions (CAPA) — source is exactly one of 4 origins (D2)
-- ===========================================================================
create table public.corrective_actions (
  id                   uuid primary key default gen_random_uuid(),
  company_id           uuid not null references public.companies(id) on delete restrict,
  site_id              uuid references public.sites(id) on delete set null,
  action_code          text,
  description          text not null,
  priority             capa_priority not null default 'medium',
  owner_id             uuid references public.users(id) on delete set null,
  due_date             date,
  status               capa_status not null default 'created',
  hazard_id            uuid references public.hazards(id) on delete cascade,
  incident_id          uuid references public.incidents(id) on delete cascade,
  investigation_id     uuid references public.investigations(id) on delete cascade,
  inspection_item_id   uuid references public.inspection_items(id) on delete cascade,
  verified_by          uuid references public.users(id) on delete set null,
  verified_at          timestamptz,
  verification_notes   text,
  closed_at            timestamptz,
  version              integer not null default 0,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint uq_capa_company_action_code unique (company_id, action_code),
  constraint ck_capa_one_source check (
    (case when hazard_id          is not null then 1 else 0 end)
  + (case when incident_id        is not null then 1 else 0 end)
  + (case when investigation_id   is not null then 1 else 0 end)
  + (case when inspection_item_id is not null then 1 else 0 end) = 1
  )
);

-- Close inspection_items -> hazards / corrective_actions links.
alter table public.inspection_items
  add constraint fk_inspection_items_gen_hazard
  foreign key (generated_hazard_id) references public.hazards(id) on delete set null;

alter table public.inspection_items
  add constraint fk_inspection_items_gen_capa
  foreign key (generated_capa_id) references public.corrective_actions(id) on delete set null;

-- ==================== migrations/0004_cross_cutting.sql ====================
-- path: supabase/migrations/0004_cross_cutting.sql
-- Migration 0004: Cross-cutting services.
-- Tables: notifications, device_tokens, attachments, attachment_versions,
--         audit_logs, sync_queue. No RLS here (Prompt 2B).

-- ===========================================================================
-- device_tokens  (FCM registration, per user + device)
-- ===========================================================================
create table public.device_tokens (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id) on delete cascade,
  company_id   uuid not null references public.companies(id) on delete restrict,
  token        text not null,
  platform     device_platform not null,
  is_active    boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  constraint uq_device_tokens_token unique (token)
);

-- ===========================================================================
-- notifications  (in-app; push fan-out delivered via device_tokens)
-- ===========================================================================
create table public.notifications (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete restrict,
  recipient_id  uuid not null references public.users(id) on delete cascade,
  trigger_type  notification_trigger not null,
  priority      notification_priority not null default 'normal',
  title         text not null,
  body          text,
  entity_type   text,                 -- deep-link target table (e.g. 'hazard','corrective_action')
  entity_id     uuid,                 -- deep-link target row
  is_read       boolean not null default false,
  read_at       timestamptz,
  created_at    timestamptz not null default now()
);

-- ===========================================================================
-- attachments  (logical file; versions in attachment_versions)
-- ===========================================================================
create table public.attachments (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete restrict,
  owner_type     attachment_owner_type not null,
  owner_id       uuid not null,        -- polymorphic parent (owner_type + owner_id)
  file_name      text not null,
  content_type   text not null,        -- image/jpeg | image/png | application/pdf
  is_active      boolean not null default true,   -- logical (soft) delete
  created_by     uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint ck_attachments_content_type
    check (content_type in ('image/jpeg', 'image/png', 'application/pdf'))
);

-- ===========================================================================
-- attachment_versions  (app-layer version history; Storage has none natively)
-- ===========================================================================
create table public.attachment_versions (
  id             uuid primary key default gen_random_uuid(),
  attachment_id  uuid not null references public.attachments(id) on delete cascade,
  company_id     uuid not null references public.companies(id) on delete restrict,
  version_no     integer not null,
  storage_path   text not null,        -- object path within the attachments bucket
  file_size      bigint not null,      -- bytes; app enforces <= 20MB
  content_type   text not null,
  is_active      boolean not null default true,   -- false = superseded (never deleted)
  uploaded_by    uuid references public.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  constraint uq_attachment_versions_no unique (attachment_id, version_no),
  constraint uq_attachment_versions_path unique (storage_path),
  constraint ck_attachment_versions_size check (file_size > 0 and file_size <= 20971520),
  constraint ck_attachment_versions_content_type
    check (content_type in ('image/jpeg', 'image/png', 'application/pdf'))
);

-- ===========================================================================
-- audit_logs  (immutable — INSERT+SELECT only; grants enforced in Prompt 2B)
-- No updated_at: rows are write-once.
-- ===========================================================================
create table public.audit_logs (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete restrict,
  actor_id      uuid references public.users(id) on delete set null,
  action        text not null,        -- e.g. 'hazard.created', 'capa.closed'
  entity_type   text not null,
  entity_id     uuid,
  before_state  jsonb,
  after_state   jsonb,
  created_at    timestamptz not null default now()
);

-- ===========================================================================
-- sync_queue  (server-side mirror of the client outbox; Drift mirror in 4B)
-- ===========================================================================
create table public.sync_queue (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete restrict,
  user_id       uuid not null references public.users(id) on delete cascade,
  entity_type   text not null,        -- 'hazard' | 'incident' | 'inspection' | 'corrective_action'
  entity_id     uuid not null,
  operation     sync_operation not null,
  payload       jsonb not null,
  base_version  integer,              -- client's known version for conflict detection (D4)
  status        sync_status not null default 'pending',
  attempts      integer not null default 0,
  last_error    text,
  created_at    timestamptz not null default now(),
  processed_at  timestamptz
);

-- ==================== migrations/0005_indexes_and_triggers.sql ====================
-- path: supabase/migrations/0005_indexes_and_triggers.sql
-- Migration 0005: performance indexes + triggers.
-- Indexes cover every company_id / site_id / department_id / status column
-- (RLS + dashboard filters) plus FKs and common list/sort columns.

-- ===========================================================================
-- INDEXES
-- ===========================================================================

-- Organisation
create index idx_sites_company              on public.sites(company_id);
create index idx_departments_company        on public.departments(company_id);
create index idx_departments_site           on public.departments(site_id);

-- Identity / RBAC
create index idx_user_profiles_company      on public.user_profiles(company_id);
create index idx_user_profiles_site         on public.user_profiles(site_id);
create index idx_user_profiles_department   on public.user_profiles(department_id);
create index idx_user_roles_user            on public.user_roles(user_id);
create index idx_user_roles_role            on public.user_roles(role_id);
create index idx_user_roles_company         on public.user_roles(company_id);

-- Hazards
create index idx_hazards_company            on public.hazards(company_id);
create index idx_hazards_site               on public.hazards(site_id);
create index idx_hazards_department         on public.hazards(department_id);
create index idx_hazards_status             on public.hazards(status);
create index idx_hazards_reporter           on public.hazards(reporter_id);
create index idx_hazards_source_incident    on public.hazards(source_incident_id);
create index idx_hazards_risk_level         on public.hazards(risk_level);
create index idx_hazards_created_at         on public.hazards(created_at desc);

-- Risk assessments
create index idx_risk_company               on public.risk_assessments(company_id);
create index idx_risk_hazard                on public.risk_assessments(hazard_id);
create index idx_risk_assessor              on public.risk_assessments(assessor_id);
create index idx_risk_band                  on public.risk_assessments(risk_band);

-- Incidents
create index idx_incidents_company          on public.incidents(company_id);
create index idx_incidents_site             on public.incidents(site_id);
create index idx_incidents_department       on public.incidents(department_id);
create index idx_incidents_status           on public.incidents(status);
create index idx_incidents_severity         on public.incidents(severity);
create index idx_incidents_reporter         on public.incidents(reporter_id);
create index idx_incidents_source_hazard    on public.incidents(source_hazard_id);
create index idx_incidents_occurred_at      on public.incidents(occurred_at desc);

-- Investigations
create index idx_invest_company             on public.investigations(company_id);
create index idx_invest_site                on public.investigations(site_id);
create index idx_invest_hazard              on public.investigations(hazard_id);
create index idx_invest_incident            on public.investigations(incident_id);
create index idx_invest_investigator        on public.investigations(investigator_id);
create index idx_invest_status              on public.investigations(status);

-- Corrective actions (CAPA)
create index idx_capa_company               on public.corrective_actions(company_id);
create index idx_capa_site                  on public.corrective_actions(site_id);
create index idx_capa_status                on public.corrective_actions(status);
create index idx_capa_owner                 on public.corrective_actions(owner_id);
create index idx_capa_due_date              on public.corrective_actions(due_date);
create index idx_capa_priority              on public.corrective_actions(priority);
create index idx_capa_hazard                on public.corrective_actions(hazard_id);
create index idx_capa_incident              on public.corrective_actions(incident_id);
create index idx_capa_investigation         on public.corrective_actions(investigation_id);
create index idx_capa_inspection_item       on public.corrective_actions(inspection_item_id);

-- Inspections
create index idx_inspections_company        on public.inspections(company_id);
create index idx_inspections_site           on public.inspections(site_id);
create index idx_inspections_department     on public.inspections(department_id);
create index idx_inspections_status         on public.inspections(status);
create index idx_inspections_inspector      on public.inspections(inspector_id);
create index idx_inspections_scheduled      on public.inspections(scheduled_date);

-- Inspection items
create index idx_insp_items_company         on public.inspection_items(company_id);
create index idx_insp_items_inspection      on public.inspection_items(inspection_id);
create index idx_insp_items_result          on public.inspection_items(result);
create index idx_insp_items_gen_hazard      on public.inspection_items(generated_hazard_id);
create index idx_insp_items_gen_capa        on public.inspection_items(generated_capa_id);

-- Device tokens / notifications
create index idx_device_tokens_user         on public.device_tokens(user_id);
create index idx_device_tokens_company      on public.device_tokens(company_id);
create index idx_notifications_company      on public.notifications(company_id);
create index idx_notifications_recipient    on public.notifications(recipient_id);
create index idx_notifications_unread       on public.notifications(recipient_id, is_read);
create index idx_notifications_created_at   on public.notifications(created_at desc);
create index idx_notifications_entity       on public.notifications(entity_type, entity_id);

-- Attachments
create index idx_attachments_company        on public.attachments(company_id);
create index idx_attachments_owner          on public.attachments(owner_type, owner_id);
create index idx_attachments_active         on public.attachments(is_active);
create index idx_attach_versions_attachment on public.attachment_versions(attachment_id);
create index idx_attach_versions_company    on public.attachment_versions(company_id);
create index idx_attach_versions_active     on public.attachment_versions(is_active);

-- Audit logs
create index idx_audit_company              on public.audit_logs(company_id);
create index idx_audit_actor                on public.audit_logs(actor_id);
create index idx_audit_entity               on public.audit_logs(entity_type, entity_id);
create index idx_audit_created_at           on public.audit_logs(created_at desc);
create index idx_audit_action               on public.audit_logs(action);

-- Sync queue
create index idx_sync_company               on public.sync_queue(company_id);
create index idx_sync_user                  on public.sync_queue(user_id);
create index idx_sync_status                on public.sync_queue(status);
create index idx_sync_entity                on public.sync_queue(entity_type, entity_id);

-- ===========================================================================
-- TRIGGERS: updated_at (non-versioned) and bump_version (offline-writable)
-- ===========================================================================

-- updated_at only
create trigger trg_companies_updated     before update on public.companies       for each row execute function public.set_updated_at();
create trigger trg_sites_updated         before update on public.sites           for each row execute function public.set_updated_at();
create trigger trg_departments_updated   before update on public.departments     for each row execute function public.set_updated_at();
create trigger trg_users_updated         before update on public.users           for each row execute function public.set_updated_at();
create trigger trg_user_profiles_updated before update on public.user_profiles   for each row execute function public.set_updated_at();
create trigger trg_attachments_updated   before update on public.attachments     for each row execute function public.set_updated_at();

-- version + updated_at (offline-writable / conflict-managed, D4)
create trigger trg_hazards_version       before update on public.hazards            for each row execute function public.bump_version();
create trigger trg_incidents_version     before update on public.incidents          for each row execute function public.bump_version();
create trigger trg_risk_version          before update on public.risk_assessments   for each row execute function public.bump_version();
create trigger trg_invest_version        before update on public.investigations     for each row execute function public.bump_version();
create trigger trg_capa_version          before update on public.corrective_actions for each row execute function public.bump_version();
create trigger trg_inspections_version   before update on public.inspections        for each row execute function public.bump_version();
create trigger trg_insp_items_version    before update on public.inspection_items   for each row execute function public.bump_version();

-- ===========================================================================
-- TRIGGER: mirror new auth.users into public.users
-- (profile row + role assignment are created by the app during onboarding)
-- ===========================================================================
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger trg_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- ==================== migrations/0006_rls_helpers.sql ====================
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

-- Convenience threshold check. Parameter is `integer` so callers can pass plain
-- integer literals (e.g. app.has_min_rank(5)) — Postgres won't implicitly narrow
-- integer -> smallint during function resolution.
create or replace function app.has_min_rank(min_rank integer)
returns boolean
language sql stable security definer set search_path = public
as $$
  select app.user_rank() >= min_rank;
$$;

grant usage on schema app to authenticated;
grant execute on all functions in schema app to authenticated;

-- ==================== migrations/0007_rls_policies.sql ====================
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
  using (
    company_id = app.current_company_id()
    and (app.has_min_rank(2) or owner_id = auth.uid())  -- owner may start work on their own CAPA (0016)
  )
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

-- ==================== migrations/0008_storage_policies.sql ====================
-- path: supabase/migrations/0008_storage_policies.sql
-- Migration 0008: Supabase Storage bucket + access policies for attachments.
-- Object path convention: <company_id>/<owner_type>/<owner_id>/<version_uuid>.<ext>
-- First path segment = company_id, giving tenant isolation on storage.objects.

-- Private bucket (no public URLs; access via signed URLs from the app).
insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', false)
on conflict (id) do nothing;

-- Read: any authenticated user within the owning company.
create policy attachments_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = app.current_company_id()::text
  );

-- Upload: any authenticated user within their own company (rank >= 1).
create policy attachments_upload on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = app.current_company_id()::text
    and app.has_min_rank(1)
  );

-- Update (overwrite/metadata): uploader-or-SO+ within company.
create policy attachments_modify on storage.objects
  for update to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = app.current_company_id()::text
    and (owner = auth.uid() or app.has_min_rank(3))
  );

-- Physical delete: Safety Officer+ only. (Logical delete is app-layer via
-- attachments.is_active; version history is never destroyed.)
create policy attachments_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = app.current_company_id()::text
    and app.has_min_rank(3)
  );

-- ==================== migrations/0009_user_mgmt_reconciliation.sql ====================
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

-- ==================== migrations/0010_user_mgmt_rls.sql ====================
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

-- ==================== migrations/0011_user_activation_trigger.sql ====================
-- path: supabase/migrations/0011_user_activation_trigger.sql
-- Prompt 5A: activate an invited profile once the invitee confirms their email
-- (i.e. accepts the invite and sets a password). Runs server-side so the client
-- never needs write access to user_profiles (which is Administrator-only, 0010).

create or replace function public.handle_user_confirmed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Fires when email_confirmed_at transitions from NULL to a timestamp.
  if old.email_confirmed_at is null and new.email_confirmed_at is not null then
    update public.user_profiles
       set status = 'active',
           activated_at = coalesce(activated_at, now())
     where user_id = new.id
       and status = 'invited';
  end if;
  return new;
end;
$$;

create trigger trg_auth_user_confirmed
  after update on auth.users
  for each row execute function public.handle_user_confirmed();

-- ===========================================================================
-- DOWN MIGRATION:
--   drop trigger if exists trg_auth_user_confirmed on auth.users;
--   drop function if exists public.handle_user_confirmed();
-- ===========================================================================

-- ==================== migrations/0012_audit_triggers.sql ====================
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

-- ==================== migrations/0013_incident_capa_audit.sql ====================
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

-- ==================== migrations/0014_risk_triggers.sql ====================
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

-- ==================== migrations/0015_inspection_audit.sql ====================
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

-- ==================== seed.sql ====================
-- path: supabase/seed.sql
-- Reference data ONLY. Per the Master Prompt DATA QUALITY RULE, no sample
-- companies, users, hazards, incidents, or inspections are seeded.
-- Only the five locked RBAC roles are inserted (global reference data).

insert into public.roles (code, name, rank) values
  ('employee',       'Employee',       1),
  ('supervisor',     'Supervisor',     2),
  ('safety_officer', 'Safety Officer', 3),
  ('manager',        'Manager',        4),
  ('administrator',  'Administrator',  5)
on conflict (code) do nothing;
