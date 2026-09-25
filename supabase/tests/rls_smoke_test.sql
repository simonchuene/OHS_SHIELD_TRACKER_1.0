-- path: supabase/tests/rls_smoke_test.sql
-- Row Level Security, tenant isolation and audit immutability — pgTAP.
-- Run by CI with `supabase test db` after `supabase db reset`.
--
-- WHY THIS WAS REWRITTEN
-- The original suite never switched role, so every assertion ran as the
-- `postgres` role that owns the tables — and a table owner bypasses RLS
-- entirely. It also had no fixture: the users it impersonated did not exist,
-- so auth.uid() pointed at nobody and app.current_company_id() was null.
-- Its three failures were UPDATE/DELETE statements that touched no rows, and
-- its five passes proved nothing about RLS: two passed on constraint errors,
-- two because the database was empty, one was a tautology. (Ledger §24.5.)
--
-- THE RULES THIS SUITE FOLLOWS, SO IT CANNOT FAIL THE SAME WAY
--   1. Fixtures are built as `postgres`; every assertion about access runs
--      under `set local role authenticated`, where RLS actually applies.
--   2. Ground-truth checks run before the role switch, so "sees 0 rows" can
--      never pass because the rows do not exist.
--   3. Identity checks prove each impersonated user resolves to a company and
--      rank, so nothing passes because auth.uid() is unknown.
--   4. Every refusal is paired with a CONTROL — the same action succeeding for
--      a user who is allowed — so a refusal cannot pass for an unrelated
--      reason.
--   5. Refusals assert the exact SQLSTATE 42501. A NOT NULL (23502) or FK
--      (23503) violation is a different code, so it cannot count as a pass.
--
-- TWO POSTGRES BEHAVIOURS THE ASSERTIONS DEPEND ON
--   * UPDATE/DELETE rows that fail a policy's USING clause are SKIPPED, not
--     refused: the statement succeeds and touches nothing. Those cases are
--     asserted with is_empty(... RETURNING ...), not throws_ok.
--   * A row that passes USING but fails WITH CHECK raises 42501. That is why
--     the "cannot close" tests use a caller who can SEE the row — otherwise
--     the refusal would come from invisibility, not from the close rule.
--
-- Everything runs in one transaction and is rolled back.

begin;

-- `supabase test db` enables pgTAP itself; this is a no-op there and makes the
-- file runnable directly with psql.
create extension if not exists pgtap with schema extensions;

select plan(35);

-- ===========================================================================
-- FIXTURE (as postgres — RLS does not apply to the table owner)
-- ===========================================================================
-- Legend
--   companies   A ...000a            B ...000b
--   site        A1 ...05a1           B1 ...05b1
--   department  A1D ...0da1 (in A1)
--   users (A)   a1 employee   a2 supervisor   a3 safety officer
--               a4 manager    a5 administrator
--   users (B)   b3 safety officer
--   hazards     f1 HA  (A, A1/A1D, reported by a1)
--               f2 HA2 (A, A1/A1D, reported by a2)
--               f3 HB  (B, B1,     reported by b3)
--   CAPAs       c1 CA_A  (on HA,  owner a1, site A1)
--               c2 CA_A2 (on HA2, owner a2, site A1)

insert into public.companies (id, name, code) values
  ('00000000-0000-0000-0000-00000000000a', 'pgTAP Company A', 'PGTAP-A'),
  ('00000000-0000-0000-0000-00000000000b', 'pgTAP Company B', 'PGTAP-B');

insert into public.sites (id, company_id, name, code) values
  ('00000000-0000-0000-0000-0000000005a1', '00000000-0000-0000-0000-00000000000a', 'Site A1', 'A1'),
  ('00000000-0000-0000-0000-0000000005b1', '00000000-0000-0000-0000-00000000000b', 'Site B1', 'B1');

insert into public.departments (id, company_id, site_id, name, code) values
  ('00000000-0000-0000-0000-000000000da1', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000005a1', 'Department A1D', 'A1D');

-- public.users is populated from auth.users by trg_auth_user_created (0005).
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'pgtap-a-employee@test.invalid'),
  ('00000000-0000-0000-0000-0000000000a2', 'pgtap-a-supervisor@test.invalid'),
  ('00000000-0000-0000-0000-0000000000a3', 'pgtap-a-safety@test.invalid'),
  ('00000000-0000-0000-0000-0000000000a4', 'pgtap-a-manager@test.invalid'),
  ('00000000-0000-0000-0000-0000000000a5', 'pgtap-a-admin@test.invalid'),
  ('00000000-0000-0000-0000-0000000000b3', 'pgtap-b-safety@test.invalid');

insert into public.user_profiles (user_id, company_id, site_id, department_id, first_name, last_name) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000005a1', '00000000-0000-0000-0000-000000000da1', 'Ann',  'Employee'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000005a1', '00000000-0000-0000-0000-000000000da1', 'Sam',  'Supervisor'),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000005a1', null,                                   'Sara', 'Officer'),
  ('00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-00000000000a',
   null, null,                                                                     'Mike', 'Manager'),
  ('00000000-0000-0000-0000-0000000000a5', '00000000-0000-0000-0000-00000000000a',
   null, null,                                                                     'Ada',  'Admin'),
  ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-00000000000b',
   '00000000-0000-0000-0000-0000000005b1', null,                                   'Ben',  'Officer');

insert into public.user_roles (user_id, role_id, company_id)
select u.user_id, r.id, u.company_id
from (values
  ('00000000-0000-0000-0000-0000000000a1'::uuid, 'employee'::role_code,       '00000000-0000-0000-0000-00000000000a'::uuid),
  ('00000000-0000-0000-0000-0000000000a2'::uuid, 'supervisor'::role_code,     '00000000-0000-0000-0000-00000000000a'::uuid),
  ('00000000-0000-0000-0000-0000000000a3'::uuid, 'safety_officer'::role_code, '00000000-0000-0000-0000-00000000000a'::uuid),
  ('00000000-0000-0000-0000-0000000000a4'::uuid, 'manager'::role_code,        '00000000-0000-0000-0000-00000000000a'::uuid),
  ('00000000-0000-0000-0000-0000000000a5'::uuid, 'administrator'::role_code,  '00000000-0000-0000-0000-00000000000a'::uuid),
  ('00000000-0000-0000-0000-0000000000b3'::uuid, 'safety_officer'::role_code, '00000000-0000-0000-0000-00000000000b'::uuid)
) as u(user_id, code, company_id)
join public.roles r on r.code = u.code;

insert into public.hazards (id, company_id, site_id, department_id, title, category, status, reporter_id) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000005a1', '00000000-0000-0000-0000-000000000da1',
   'HA: guard missing', 'physical', 'submitted', '00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000005a1', '00000000-0000-0000-0000-000000000da1',
   'HA2: spill', 'chemical', 'submitted', '00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-00000000000b',
   '00000000-0000-0000-0000-0000000005b1', null,
   'HB: company B hazard', 'physical', 'submitted', '00000000-0000-0000-0000-0000000000b3');

insert into public.corrective_actions (id, company_id, site_id, description, status, hazard_id, owner_id) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000005a1', 'CA_A: refit the guard', 'in_progress',
   '00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000005a1', 'CA_A2: clean the spill', 'in_progress',
   '00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-0000000000a2');

-- ===========================================================================
-- GROUND TRUTH (still as postgres) — the rows later tests expect NOT to see
-- do exist, so an invisible row is a policy decision, never an empty table.
-- ===========================================================================

select is(
  (select count(*) from public.hazards where id in (
     '00000000-0000-0000-0000-0000000000f1',
     '00000000-0000-0000-0000-0000000000f2',
     '00000000-0000-0000-0000-0000000000f3')),
  3::bigint,
  'fixture: all three hazards exist');

select ok(
  (select count(*) from public.audit_logs
    where company_id = '00000000-0000-0000-0000-00000000000b') > 0,
  'fixture: company B has audit rows (so B-invisibility tests are not vacuous)');

-- ===========================================================================
-- From here on, RLS applies.
-- ===========================================================================
set local role authenticated;

-- ---------------------------------------------------------------------------
-- IDENTITY — impersonated users resolve, so no test passes on a null company
-- ---------------------------------------------------------------------------
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}';

select is(app.current_company_id(), '00000000-0000-0000-0000-00000000000a'::uuid,
  'identity: supervisor resolves to company A');
select is(app.user_rank(), 2::smallint,
  'identity: supervisor has rank 2');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b3';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b3","role":"authenticated"}';

select is(app.current_company_id(), '00000000-0000-0000-0000-00000000000b'::uuid,
  'identity: company B safety officer resolves to company B');

-- ---------------------------------------------------------------------------
-- TENANT ISOLATION — nothing crosses a company boundary at any rank
-- ---------------------------------------------------------------------------

-- Company B's view: sees its own hazard, none of company A's.
select is(
  (select count(*) from public.hazards where id = '00000000-0000-0000-0000-0000000000f3'),
  1::bigint,
  'isolation (control): B safety officer sees B''s own hazard');
select is(
  (select count(*) from public.hazards where company_id = '00000000-0000-0000-0000-00000000000a'),
  0::bigint,
  'isolation: B safety officer sees none of company A''s hazards');

-- Company A's safety officer.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a3';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}';

select is(
  (select count(*) from public.hazards where id = '00000000-0000-0000-0000-0000000000f1'),
  1::bigint,
  'isolation (control): A safety officer sees a hazard on their own site');
select is(
  (select count(*) from public.hazards where id = '00000000-0000-0000-0000-0000000000f3'),
  0::bigint,
  'isolation: A safety officer cannot read B''s hazard by its id');

-- Company A's administrator — the highest rank is still inside the boundary.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a5';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a5","role":"authenticated"}';

select is(
  (select count(*) from public.hazards where id = '00000000-0000-0000-0000-0000000000f3'),
  0::bigint,
  'isolation: A administrator cannot read B''s hazard by its id');

select throws_ok(
  $$ insert into public.hazards (company_id, title, category, reporter_id)
     values ('00000000-0000-0000-0000-00000000000b', 'forged into B', 'physical',
             '00000000-0000-0000-0000-0000000000a5') $$,
  '42501', null,
  'isolation: A administrator cannot insert a hazard into company B');
select lives_ok(
  $$ insert into public.hazards (company_id, title, category, reporter_id)
     values ('00000000-0000-0000-0000-00000000000a', 'reported in A', 'physical',
             '00000000-0000-0000-0000-0000000000a5') $$,
  'isolation (control): the same insert into their own company succeeds');

select is_empty(
  $$ update public.hazards set title = 'tampered'
      where id = '00000000-0000-0000-0000-0000000000f3' returning id $$,
  'isolation: A administrator''s update of B''s hazard touches no rows');
select isnt_empty(
  $$ update public.hazards set title = 'HA: guard missing (edited)'
      where id = '00000000-0000-0000-0000-0000000000f1' returning id $$,
  'isolation (control): the same update on their own company''s hazard succeeds');

-- ---------------------------------------------------------------------------
-- EXACT-RANK VISIBILITY (§22.2) — an employee sees only their own reports
-- ---------------------------------------------------------------------------
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';

select is(
  (select count(*) from public.hazards where id = '00000000-0000-0000-0000-0000000000f1'),
  1::bigint,
  'visibility (control): employee sees the hazard they reported');
select is(
  (select count(*) from public.hazards where id = '00000000-0000-0000-0000-0000000000f2'),
  0::bigint,
  'visibility: employee cannot see a colleague''s hazard in the same department');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}';

select is(
  (select count(*) from public.hazards where id = '00000000-0000-0000-0000-0000000000f1'),
  1::bigint,
  'visibility: supervisor sees a hazard someone else reported in their department');

-- ---------------------------------------------------------------------------
-- RANK GATES
-- ---------------------------------------------------------------------------
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';

select throws_ok(
  $$ insert into public.risk_assessments (company_id, hazard_id, likelihood, severity, assessor_id)
     values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
             3, 3, '00000000-0000-0000-0000-0000000000a1') $$,
  '42501', null,
  'rank: employee cannot perform a risk assessment (Supervisor+)');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a2';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a2","role":"authenticated"}';

select lives_ok(
  $$ insert into public.risk_assessments (company_id, hazard_id, likelihood, severity, assessor_id)
     values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
             3, 3, '00000000-0000-0000-0000-0000000000a2') $$,
  'rank (control): supervisor can perform the same risk assessment');

-- The supervisor can SEE this hazard (same department, proven above), so the
-- refusal below comes from the close rule in WITH CHECK, not from visibility.
select throws_ok(
  $$ update public.hazards set status = 'closed'
      where id = '00000000-0000-0000-0000-0000000000f1' $$,
  '42501', null,
  'rank: supervisor cannot close a hazard (Safety Officer+)');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a3';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}';

select isnt_empty(
  $$ update public.hazards set status = 'closed'
      where id = '00000000-0000-0000-0000-0000000000f1' returning id $$,
  'rank (control): safety officer can close the same hazard');

-- ---------------------------------------------------------------------------
-- AUDIT LOG — scoped reads, and no writes at any rank
-- ---------------------------------------------------------------------------
select ok(
  (select count(*) from public.audit_logs) > 0,
  'audit (control): safety officer can read company A''s audit trail');
select is(
  (select count(*) from public.audit_logs
    where company_id = '00000000-0000-0000-0000-00000000000b'),
  0::bigint,
  'audit: safety officer cannot read company B''s audit trail');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';

select is(
  (select count(*) from public.audit_logs),
  0::bigint,
  'audit: employee cannot read the audit trail (Safety Officer+)');

-- Immutability is a privilege revoke, not a policy, so it binds every rank.
-- Asserted as the Administrator: the strongest caller there is.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a5';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a5","role":"authenticated"}';

select throws_ok(
  $$ update public.audit_logs set action = 'tampered' $$,
  '42501', null,
  'audit: even an administrator cannot UPDATE the audit trail');
select throws_ok(
  $$ delete from public.audit_logs $$,
  '42501', null,
  'audit: even an administrator cannot DELETE from the audit trail');
select throws_ok(
  $$ insert into public.audit_logs (company_id, action, entity_type, entity_id)
     values ('00000000-0000-0000-0000-00000000000a', 'forged', 'hazard',
             '00000000-0000-0000-0000-0000000000f1') $$,
  '42501', null,
  'audit: even an administrator cannot INSERT into the audit trail');

-- ---------------------------------------------------------------------------
-- CAPA OWNER EXCEPTION (0018, §22.3) — the one rule that is not rank-based
-- ---------------------------------------------------------------------------
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}';

select isnt_empty(
  $$ update public.corrective_actions set status = 'verification'
      where id = '00000000-0000-0000-0000-0000000000c1' returning id $$,
  'owner: an employee may submit their own CAPA for verification');
select throws_ok(
  $$ update public.corrective_actions set status = 'closed'
      where id = '00000000-0000-0000-0000-0000000000c1' $$,
  '42501', null,
  'owner: an employee may not close their own CAPA');
select is_empty(
  $$ update public.corrective_actions set status = 'verification'
      where id = '00000000-0000-0000-0000-0000000000c2' returning id $$,
  'owner: the exception covers only the owner — another employee''s CAPA is untouched');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a3';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}';

select isnt_empty(
  $$ update public.corrective_actions set status = 'closed'
      where id = '00000000-0000-0000-0000-0000000000c1' returning id $$,
  'owner (control): a safety officer can close the CAPA the owner could not');

-- ---------------------------------------------------------------------------
-- USER MANAGEMENT (0010) — Administrator-only, within the company, no deletes
-- ---------------------------------------------------------------------------
-- Grants the manager an additional employee role: a lower rank, so it cannot
-- change anyone's effective rank for the rest of the suite.
select throws_ok(
  $$ insert into public.user_roles (user_id, role_id, company_id)
     values ('00000000-0000-0000-0000-0000000000a4',
             (select id from public.roles where code = 'employee'),
             '00000000-0000-0000-0000-00000000000a') $$,
  '42501', null,
  'users: a safety officer cannot grant a role (Administrator only)');

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a5';
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a5","role":"authenticated"}';

select lives_ok(
  $$ insert into public.user_roles (user_id, role_id, company_id)
     values ('00000000-0000-0000-0000-0000000000a4',
             (select id from public.roles where code = 'employee'),
             '00000000-0000-0000-0000-00000000000a') $$,
  'users (control): an administrator can grant the same role');
select throws_ok(
  $$ insert into public.user_roles (user_id, role_id, company_id)
     values ('00000000-0000-0000-0000-0000000000b3',
             (select id from public.roles where code = 'manager'),
             '00000000-0000-0000-0000-00000000000b') $$,
  '42501', null,
  'users: an administrator cannot grant a role in another company');
select throws_ok(
  $$ delete from public.user_roles
      where user_id = '00000000-0000-0000-0000-0000000000a4' $$,
  '42501', null,
  'users: role assignments cannot be deleted at any rank (deactivate instead)');

select * from finish();
rollback;
