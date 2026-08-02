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
