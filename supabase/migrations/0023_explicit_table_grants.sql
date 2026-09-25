-- path: supabase/migrations/0023_explicit_table_grants.sql
-- Declare table privileges in the migrations instead of inheriting them.
--
-- 0001–0022 never GRANT table access to `authenticated` or `service_role`.
-- The only table grant is SELECT on audit_logs (0007); everything else in the
-- repo is a REVOKE. The hosted project works only because Supabase applied its
-- default privileges when each table was created — state that lives outside
-- the repo. A database built fresh from these migrations does not get them:
-- CI's `supabase db reset` produced one where `authenticated` could not read a
-- single table, and the pgTAP suite failed on its first query with
-- "permission denied for table hazards" (Ledger §24.6).
--
-- D-env-1 requires uat/prod to be built by `supabase db push` from scratch, so
-- without this migration whether the app works there would depend on platform
-- defaults at the moment each project is created. Edge functions run as
-- `service_role`, and BYPASSRLS does not bypass table privileges, so they would
-- fail the same way.
--
-- ON THE HOSTED PROJECT THIS IS A NO-OP FOR EVERYTHING THE APP DOES. The grants
-- below mirror its existing SELECT/INSERT/UPDATE/DELETE privileges exactly; RLS
-- still decides which rows. The single removal is TRUNCATE:
--
--   `authenticated` and `anon` held TRUNCATE on every table — including
--   audit_logs, which 0007 made "immutable" by revoking only INSERT/UPDATE/
--   DELETE. TRUNCATE ignores RLS and would empty a table across every company.
--   It was unreachable in practice (PostgREST cannot issue TRUNCATE), which
--   meant the audit trail's immutability rested on the API layer rather than
--   the database. The app never truncates; removing it changes no behaviour.
--
-- `anon` is deliberately granted nothing: every policy targets `authenticated`,
-- so anon has no rows to see anyway, and a fresh environment should not hand it
-- privileges it cannot use. Its existing hosted grants are left as they are,
-- apart from TRUNCATE.
--
-- Rule from here on (Addendum Part D): every migration that creates a table
-- declares that table's grants in the same migration.

-- ---------------------------------------------------------------------------
-- authenticated — DML on the app's tables; RLS narrows every row.
-- ---------------------------------------------------------------------------
grant select, insert, update, delete on table
  public.companies,
  public.sites,
  public.departments,
  public.users,
  public.roles,
  public.user_profiles,
  public.user_roles,
  public.hazards,
  public.risk_assessments,
  public.incidents,
  public.investigations,
  public.corrective_actions,
  public.inspections,
  public.inspection_items,
  public.notifications,
  public.device_tokens,
  public.attachments,
  public.attachment_versions,
  public.sync_queue,
  public.reference_counters
to authenticated;

grant select on table public.audit_logs to authenticated;

-- ---------------------------------------------------------------------------
-- Re-assert the restrictions 0007 and 0010 made, AFTER the grants above, so a
-- broad grant can never quietly undo them.
-- ---------------------------------------------------------------------------
-- The audit trail is write-once: only the SECURITY DEFINER audit trigger
-- writes to it (0012, 0021).
revoke insert, update, delete on table public.audit_logs from authenticated, anon;

-- Users are never hard-deleted; deactivation is a status change (Ledger §5a).
revoke delete on table public.users, public.user_profiles, public.user_roles
  from authenticated, anon;

-- ---------------------------------------------------------------------------
-- No TRUNCATE for client roles, on any table.
-- ---------------------------------------------------------------------------
revoke truncate on all tables in schema public from authenticated, anon;

-- ---------------------------------------------------------------------------
-- service_role — Edge Functions (user-admin, notify-fanout, notify-sweep,
-- workflow-transition, inspection-item-fail). Matches hosted.
-- ---------------------------------------------------------------------------
grant all on table
  public.companies,
  public.sites,
  public.departments,
  public.users,
  public.roles,
  public.user_profiles,
  public.user_roles,
  public.hazards,
  public.risk_assessments,
  public.incidents,
  public.investigations,
  public.corrective_actions,
  public.inspections,
  public.inspection_items,
  public.notifications,
  public.device_tokens,
  public.attachments,
  public.attachment_versions,
  public.audit_logs,
  public.sync_queue,
  public.reference_counters
to service_role;

-- ===========================================================================
-- DOWN MIGRATION:
--   Restoring TRUNCATE is the only reversible change on hosted:
--     grant truncate on all tables in schema public to authenticated, anon;
--   Revoking the grants above would reintroduce the dependency on platform
--   default privileges this migration exists to remove.
-- ===========================================================================
