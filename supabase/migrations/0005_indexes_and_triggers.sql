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
