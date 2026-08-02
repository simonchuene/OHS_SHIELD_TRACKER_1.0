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
