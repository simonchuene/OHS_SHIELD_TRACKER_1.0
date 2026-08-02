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
