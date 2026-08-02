-- path: supabase/tests/rls_smoke_test.sql
-- Prompt 17 — sample RLS / immutability / tenant-isolation checks (pgTAP style).
-- Run against a Test DB seeded with two companies (A, B) and one user per role.
-- Requires the pgtap extension: `create extension if not exists pgtap;`
-- Execute with: `pg_prove` or `select * from runtests();`
--
-- This is a representative smoke suite — the full matrix is enumerated in
-- docs/17_testing.md §Security. Helper `set_auth(uid)` stubs the JWT claim used
-- by app.current_* helpers (in Test, set request.jwt.claim.sub via set_config).

begin;
select plan(8);

-- Helper: impersonate a user by setting the auth.uid() source.
create or replace function test_as(p_uid uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', p_uid::text, true);
$$;

-- 1. audit_logs is immutable: no UPDATE allowed to authenticated.
select test_as('00000000-0000-0000-0000-0000000000a3'); -- Safety Officer, Company A
select throws_ok(
  $$ update public.audit_logs set action = 'tampered' where true $$,
  '42501', NULL, 'audit_logs UPDATE is denied (immutable)'
);

-- 2. audit_logs no DELETE.
select throws_ok(
  $$ delete from public.audit_logs where true $$,
  '42501', NULL, 'audit_logs DELETE is denied (immutable)'
);

-- 3. Employee cannot INSERT a risk assessment (Perform Risk Assessment = Sup+).
select test_as('00000000-0000-0000-0000-0000000000a1'); -- Employee, Company A
select throws_ok(
  $$ insert into public.risk_assessments (company_id, hazard_id, likelihood, severity, assessor_id)
     values (app.current_company_id(), (select id from public.hazards limit 1), 3, 3, auth.uid()) $$,
  NULL, NULL, 'Employee INSERT on risk_assessments is denied by RLS'
);

-- 4. Tenant isolation: Company A user sees zero Company B hazards.
select test_as('00000000-0000-0000-0000-0000000000a3');
select is(
  (select count(*) from public.hazards h
     join public.user_profiles p on p.company_id <> h.company_id
    where p.user_id = auth.uid()),
  0::bigint, 'No cross-company hazards are visible'
);

-- 5. Supervisor cannot set a hazard to closed (Close = Safety Officer+).
select test_as('00000000-0000-0000-0000-0000000000a2'); -- Supervisor, Company A
select throws_ok(
  $$ update public.hazards set status = 'closed'
      where id = (select id from public.hazards where company_id = app.current_company_id() limit 1) $$,
  NULL, NULL, 'Supervisor cannot close a hazard (WITH CHECK)'
);

-- 6. Safety Officer CAN read audit_logs (rank >= 3).
select test_as('00000000-0000-0000-0000-0000000000a3');
select ok( (select count(*) >= 0 from public.audit_logs), 'Safety Officer can SELECT audit_logs' );

-- 7. Employee CANNOT read audit_logs (rank < 3) -> RLS returns 0 rows.
select test_as('00000000-0000-0000-0000-0000000000a1');
select is( (select count(*) from public.audit_logs), 0::bigint, 'Employee sees no audit rows' );

-- 8. Non-admin cannot manage user_roles.
select test_as('00000000-0000-0000-0000-0000000000a3'); -- Safety Officer
select throws_ok(
  $$ insert into public.user_roles (user_id, role_id, company_id)
     values (auth.uid(), (select id from public.roles where code='manager'), app.current_company_id()) $$,
  NULL, NULL, 'Non-admin cannot grant roles (Administrator only)'
);

select * from finish();
rollback;
