-- OHS Shield Tracker — seed an additional app user at a chosen role.
--
-- SUPERSEDED for most purposes by seed_user.sql, which creates the auth user
-- too and so needs no Dashboard step. Keep using this one only if the auth user
-- already exists and you have its UID.
--
-- Use this to create test users of any rank (employee, supervisor,
-- safety_officer, manager, administrator) without going through the invite
-- email flow. The in-app path (More → User & Access Administration → Invite,
-- Administrator-only) is the *product* flow and is what real deployments use;
-- this script is a test/bootstrap convenience.
--
-- RUN THIS ONLY AFTER:
--   1) apply_all.sql has been run, AND bootstrap_admin.sql has seeded the
--      company/site/department + first Administrator, AND
--   2) you created the auth user in the Supabase Dashboard:
--        Authentication → Users → Add user → email + password
--        → tick "Auto Confirm User"   (so they can sign in immediately)
--      Then copy that user's UID (User UID column) into v_user below.
--
-- The new user joins the SAME company/site/department as the reference admin —
-- RLS is company-scoped, so a user in another company would see nothing.
-- Re-running for the same user is safe (profile + role are upserted).

do $$
declare
  -- <<< EDIT THESE >>>
  v_user      uuid := '00000000-0000-0000-0000-000000000000';  -- new auth user UID
  v_email     text := 'employee@example.com';                  -- same email you created
  v_first     text := 'Test';
  v_last      text := 'Employee';
  v_role_code text := 'employee';   -- employee | supervisor | safety_officer | manager | administrator

  -- Reference admin whose company/site/department the new user inherits.
  v_ref_admin uuid := 'b599024a-8ea5-4b25-b465-99551f6bb292';

  v_company uuid;
  v_site    uuid;
  v_dept    uuid;
  v_role    uuid;
begin
  select company_id, site_id, department_id
    into v_company, v_site, v_dept
    from public.user_profiles
   where user_id = v_ref_admin;

  if v_company is null then
    raise exception 'Reference admin % has no profile — run bootstrap_admin.sql first.', v_ref_admin;
  end if;

  select id into v_role from public.roles where code = v_role_code;
  if v_role is null then
    raise exception 'Unknown role code: %', v_role_code;
  end if;

  -- The auth.users→public.users trigger normally creates this; ensure it exists.
  insert into public.users (id, email) values (v_user, v_email)
    on conflict (id) do nothing;

  insert into public.user_profiles
    (user_id, company_id, site_id, department_id, first_name, last_name, status, activated_at)
    values (v_user, v_company, v_site, v_dept, v_first, v_last, 'active', now())
  on conflict (user_id) do update
    set company_id    = excluded.company_id,
        site_id       = excluded.site_id,
        department_id = excluded.department_id,
        first_name    = excluded.first_name,
        last_name     = excluded.last_name,
        status        = 'active',
        activated_at  = coalesce(public.user_profiles.activated_at, now());

  -- Company-wide grant (site_id/department_id NULL). Populate those columns
  -- instead if you want the role restricted to a site/department.
  insert into public.user_roles (user_id, role_id, company_id, granted_by)
    values (v_user, v_role, v_company, v_ref_admin)
  on conflict do nothing;

  raise notice 'Seeded % as % in company %', v_email, v_role_code, v_company;
end $$;
