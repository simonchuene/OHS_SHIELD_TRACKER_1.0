-- OHS Shield Tracker — first company + Administrator bootstrap.
-- RUN THIS ONLY AFTER:
--   1) apply_all.sql has been run (schema + RLS + seed roles), AND
--   2) you created the first user in the Supabase Dashboard:
--        Authentication → Users → Add user → email + password → tick "Auto Confirm User".
--      Then copy that user's UID (User UID column) and paste it below.
--
-- This seeds a company/site/department and marks the user an ACTIVE Administrator,
-- so you can log in on the app. (No open self-registration — Master Prompt.)

do $$
declare
  v_user    uuid := '00000000-0000-0000-0000-000000000000';  -- <<< PASTE the auth user UID
  v_email   text := 'admin@example.com';                     -- <<< the email you created
  v_company uuid := gen_random_uuid();
  v_site    uuid := gen_random_uuid();
  v_dept    uuid := gen_random_uuid();
begin
  insert into public.companies (id, name, code)
    values (v_company, 'My Company', 'MAIN');
  insert into public.sites (id, company_id, name, code)
    values (v_site, v_company, 'Head Office', 'HO');
  insert into public.departments (id, company_id, site_id, name, code)
    values (v_dept, v_company, v_site, 'Safety', 'SAFE');

  -- The auth.users→public.users trigger normally creates this; ensure it exists.
  insert into public.users (id, email) values (v_user, v_email)
    on conflict (id) do nothing;

  insert into public.user_profiles
    (user_id, company_id, site_id, department_id, first_name, last_name, status, activated_at)
    values (v_user, v_company, v_site, v_dept, 'Admin', 'User', 'active', now());

  insert into public.user_roles (user_id, role_id, company_id)
    values (v_user, (select id from public.roles where code = 'administrator'), v_company);
end $$;
