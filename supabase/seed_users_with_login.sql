-- ===========================================================================
-- OHS Shield Tracker — create sign-in-ready users entirely in SQL
-- ---------------------------------------------------------------------------
-- Creates BOTH the auth user (email + password) and the app records
-- (public.users / user_profiles / user_roles) for one Administrator and one
-- lower-ranked user, in a single run. No Dashboard step, no invite email.
--
-- WHY THIS EXISTS
--   bootstrap_admin.sql and seed_employee.sql both require creating the auth
--   user in the Dashboard first and pasting its UID. The invite email flow is
--   currently unusable: its link points at the project's default Site URL
--   (http://localhost:3000) and the app registers no deep link to receive it.
--   This unblocks testing and first-run setup until that is built.
--
-- ⚠️ WRITES DIRECTLY TO auth.users — UNSUPPORTED BY SUPABASE
--   That schema belongs to GoTrue and can change between releases without
--   notice, so a future upgrade may break this script. It is a bootstrap and
--   test convenience, NOT the product path. Real deployments onboard through
--   More → User & Access Administration → Invite once the redirect is fixed.
--
-- ⚠️ PASSWORDS APPEAR IN PLAIN TEXT BELOW
--   Change them before running. They are bcrypt-hashed on insert, but the
--   literals live in this file and in your SQL editor history. Never commit
--   real credentials.
--
-- PREREQUISITES
--   Migrations (or apply_all.sql) applied, with roles seeded. An existing
--   company/site/department is reused; otherwise one is created. Re-running is
--   safe — users are matched by email, and re-running RESETS their password.
--
-- HANDLED FOR YOU BY EXISTING TRIGGERS
--   trg_auth_user_created (0005) mirrors auth.users → public.users.
--   trg_auth_user_confirmed (0011) activates an 'invited' profile on
--   confirmation — not needed here, as these users are created already
--   confirmed and already 'active'.
-- ===========================================================================

-- --- temporary helper -------------------------------------------------------
-- Creating an auth user needs two rows, not one: auth.users AND an
-- auth.identities row for the email provider. Recent GoTrue versions refuse to
-- authenticate a user with no identity, and the failure surfaces as the
-- generic "Invalid login credentials" — which looks like a wrong password and
-- sends you hunting in the wrong place.
--
-- SECURITY DEFINER, so it is DROPPED at the end of this script. A function that
-- mints arbitrary authenticated users must not be left sitting in the database.
create or replace function public.seed_auth_user(p_email text, p_password text)
returns uuid
language plpgsql
security definer
set search_path = public, auth, extensions
as $fn$
declare
  v_id uuid;
begin
  select id into v_id from auth.users where email = p_email;

  if v_id is null then
    v_id := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated',
      p_email, extensions.crypt(p_password, extensions.gen_salt('bf')),
      now(),            -- pre-confirmed, so sign-in works immediately
      now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      -- Empty strings rather than NULL: some GoTrue versions declare these
      -- NOT NULL without defaults, and the insert fails obscurely if omitted.
      '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_id, v_id::text,
      jsonb_build_object('sub', v_id::text, 'email', p_email, 'email_verified', true),
      'email', now(), now(), now()
    );
  else
    -- Idempotent re-run: reset the password and ensure the user is confirmed.
    update auth.users
       set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
           email_confirmed_at = coalesce(email_confirmed_at, now()),
           updated_at         = now()
     where id = v_id;
  end if;

  return v_id;
end;
$fn$;

do $$
declare
  -- <<< EDIT THESE >>> -------------------------------------------------------
  v_admin_email    text := 'admin@example.com';
  v_admin_password text := 'ChangeMe!Admin1';
  v_admin_first    text := 'Admin';
  v_admin_last     text := 'User';

  v_user_email     text := 'employee@example.com';
  v_user_password  text := 'ChangeMe!User1';
  v_user_first     text := 'Test';
  v_user_last      text := 'Employee';
  -- Typed as the role_code ENUM, not text: public.roles.code is that enum, and
  -- there is no implicit text -> enum cast (ERROR 42883). Declaring it typed also
  -- rejects a bad value immediately, before anything is written, with Postgres's
  -- own "invalid input value for enum role_code" rather than a late failure.
  -- employee | supervisor | safety_officer | manager | administrator
  v_user_role_code role_code := 'employee';

  v_company_name   text := 'My Company';
  v_company_code   text := 'MAIN';
  -- --------------------------------------------------------------------------

  v_company uuid;
  v_site    uuid;
  v_dept    uuid;
  v_admin   uuid;
  v_user    uuid;
  v_role    uuid;
begin
  -- --- org scaffolding: reuse if present, else create ------------------------
  -- RLS is company-scoped, so both users must land in the SAME company or they
  -- will sign in successfully and then see nothing at all.
  select id into v_company from public.companies where code = v_company_code;
  if v_company is null then
    v_company := gen_random_uuid();
    insert into public.companies (id, name, code) values (v_company, v_company_name, v_company_code);
  end if;

  select id into v_site from public.sites where company_id = v_company order by created_at limit 1;
  if v_site is null then
    v_site := gen_random_uuid();
    insert into public.sites (id, company_id, name, code) values (v_site, v_company, 'Head Office', 'HO');
  end if;

  select id into v_dept from public.departments where company_id = v_company order by created_at limit 1;
  if v_dept is null then
    v_dept := gen_random_uuid();
    insert into public.departments (id, company_id, site_id, name, code)
      values (v_dept, v_company, v_site, 'Safety', 'SAFE');
  end if;

  -- --- auth users -----------------------------------------------------------
  v_admin := public.seed_auth_user(v_admin_email, v_admin_password);
  v_user  := public.seed_auth_user(v_user_email,  v_user_password);

  -- --- profiles -------------------------------------------------------------
  insert into public.user_profiles
    (user_id, company_id, site_id, department_id, first_name, last_name, status, activated_at)
  values (v_admin, v_company, v_site, v_dept, v_admin_first, v_admin_last, 'active', now())
  on conflict (user_id) do update
    set company_id = excluded.company_id, site_id = excluded.site_id,
        department_id = excluded.department_id, first_name = excluded.first_name,
        last_name = excluded.last_name, status = 'active',
        activated_at = coalesce(public.user_profiles.activated_at, now());

  insert into public.user_profiles
    (user_id, company_id, site_id, department_id, first_name, last_name, status, activated_at)
  values (v_user, v_company, v_site, v_dept, v_user_first, v_user_last, 'active', now())
  on conflict (user_id) do update
    set company_id = excluded.company_id, site_id = excluded.site_id,
        department_id = excluded.department_id, first_name = excluded.first_name,
        last_name = excluded.last_name, status = 'active',
        activated_at = coalesce(public.user_profiles.activated_at, now());

  -- --- roles (company-wide: site_id / department_id left NULL) ---------------
  insert into public.user_roles (user_id, role_id, company_id, granted_by)
  values (v_admin, (select id from public.roles where code = 'administrator'), v_company, v_admin)
  on conflict do nothing;

  select id into v_role from public.roles where code = v_user_role_code;
  if v_role is null then
    -- The value is a valid enum member (the declaration guarantees that), so a
    -- miss here means the roles reference table was never seeded.
    raise exception 'Role % is not present in public.roles — run the schema seed first.', v_user_role_code;
  end if;

  insert into public.user_roles (user_id, role_id, company_id, granted_by)
  values (v_user, v_role, v_company, v_admin)
  on conflict do nothing;

  raise notice 'company=% | administrator=% (%) | %=% (%)',
    v_company_code, v_admin_email, v_admin, v_user_role_code, v_user_email, v_user;
end $$;

-- Remove the helper. Leaving a SECURITY DEFINER function that can mint
-- authenticated users would be a standing privilege-escalation path.
drop function if exists public.seed_auth_user(text, text);

-- --- verify -----------------------------------------------------------------
select p.first_name || ' ' || p.last_name as name,
       u.email,
       r.code                              as role,
       p.status,
       (a.email_confirmed_at is not null)  as can_sign_in
  from public.user_profiles p
  join public.users        u on u.id = p.user_id
  join auth.users          a on a.id = p.user_id
  left join public.user_roles ur on ur.user_id = p.user_id
  left join public.roles      r  on r.id = ur.role_id
 order by r.code nulls last, u.email;
