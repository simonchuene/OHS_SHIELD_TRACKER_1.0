-- ===========================================================================
-- OHS Shield Tracker — add ONE user, at any role, to an EXISTING company
-- ---------------------------------------------------------------------------
-- Creates the auth user (email + password) *and* the app records
-- (public.users via trigger / user_profiles / user_roles) in a single run.
-- No Dashboard step, no invite email.
--
-- Companion scripts:
--   seed_users_with_login.sql — creates a NEW company plus an admin and one
--                               lower-ranked user. Use that to stand up a tenant.
--   this file                 — adds one more user to a company that exists.
--   seed_employee.sql         — the older path; still needs the auth user created
--                               in the Dashboard first and its UID pasted in.
--                               Superseded by this file for most purposes.
--
-- ⚠️ WRITES DIRECTLY TO auth.users — UNSUPPORTED BY SUPABASE
--   That schema belongs to GoTrue and can change between releases without
--   notice, so an upgrade may break this. Bootstrap and test convenience only,
--   NOT the product path. Real onboarding is More → User & Access
--   Administration → Invite.
--
-- ⚠️ THE PASSWORD BELOW IS PLAIN TEXT
--   Change it before running. It is bcrypt-hashed on insert, but the literal
--   lives in this file and in your SQL editor history. Never commit a real one.
--
-- Re-running for the same email is safe: the profile and role are upserted and
-- the password is RESET, which doubles as a recovery path while the reset email
-- flow depends on SMTP that is rate-limited (Ledger §21.2).
-- ===========================================================================

drop function if exists public.seed_auth_user(text, text);

-- Temporary helper. An auth user needs TWO rows: auth.users and an
-- auth.identities row for the email provider. Without the identity, recent
-- GoTrue refuses to authenticate and reports the generic "Invalid login
-- credentials" — which reads as a wrong password and sends you hunting in the
-- wrong place. Dropped at the end: a SECURITY DEFINER function that can mint
-- authenticated users must not be left in the database.
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
      now(),                       -- pre-confirmed, so sign-in works immediately
      now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      -- Empty strings rather than NULL: some GoTrue versions declare these
      -- NOT NULL without defaults and the insert fails obscurely if omitted.
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
  v_email     text := 'new.user@example.com';
  v_password  text := 'ChangeMe!Once1';
  v_first     text := 'New';
  v_last      text := 'User';

  -- Typed as the role_code ENUM, not text: public.roles.code is that enum and
  -- there is no implicit text -> enum cast (ERROR 42883). Typing it also rejects
  -- a bad value at declaration, before anything is written.
  -- employee | supervisor | safety_officer | manager | administrator
  v_role_code role_code := 'employee';

  v_company_code text := 'MAIN';
  -- --------------------------------------------------------------------------

  v_company uuid;
  v_site    uuid;
  v_dept    uuid;
  v_user    uuid;
  v_role    uuid;
  v_grantor uuid;
begin
  -- The company MUST already exist. Creating one here on a typo'd code would
  -- put the user in a fresh empty tenant: they would sign in successfully and
  -- then see nothing, which reads as corrupted data rather than a wrong code.
  -- RLS is company-scoped (Ledger §22), so this is the whole ballgame.
  select id into v_company from public.companies where code = v_company_code;
  if v_company is null then
    raise exception
      'Company % does not exist. Use seed_users_with_login.sql to create a new tenant.',
      v_company_code;
  end if;

  -- Inherit the company's existing site/department, so scope-based visibility
  -- lines up with the other users in that tenant rather than landing the user
  -- in a second site where Supervisor/Safety Officer scoping would not match.
  select id into v_site from public.sites       where company_id = v_company order by created_at limit 1;
  select id into v_dept from public.departments where company_id = v_company order by created_at limit 1;

  select id into v_role from public.roles where code = v_role_code;
  if v_role is null then
    -- The declaration guarantees a valid enum member, so a miss here means the
    -- roles reference table was never seeded.
    raise exception 'Role % is not present in public.roles — run the schema seed first.', v_role_code;
  end if;

  -- Attribute the grant to an existing administrator of this company where one
  -- exists, so the audit trail shows a grantor instead of a bare seed. NULL is
  -- allowed (granted_by is nullable) and simply means "seeded".
  select ur.user_id into v_grantor
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
   where ur.company_id = v_company and r.code = 'administrator'
   limit 1;

  v_user := public.seed_auth_user(v_email, v_password);

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

  -- Company-wide grant: site_id / department_id left NULL. Populate them
  -- instead to restrict the role to a site or department.
  insert into public.user_roles (user_id, role_id, company_id, granted_by)
  values (v_user, v_role, v_company, v_grantor)
  on conflict do nothing;

  raise notice 'Added % as % in company % (user %)', v_email, v_role_code, v_company_code, v_user;
end $$;

-- Remove the helper. Leaving a SECURITY DEFINER function that can mint
-- authenticated users would be a standing privilege-escalation path.
drop function if exists public.seed_auth_user(text, text);

-- --- verify -----------------------------------------------------------------
select c.code                               as company,
       p.first_name || ' ' || p.last_name   as name,
       u.email,
       r.code                               as role,
       p.status,
       (a.email_confirmed_at is not null)    as can_sign_in
  from public.user_profiles p
  join public.users     u on u.id = p.user_id
  join auth.users       a on a.id = p.user_id
  join public.companies c on c.id = p.company_id
  left join public.user_roles ur on ur.user_id = p.user_id
  left join public.roles      r  on r.id = ur.role_id
 order by c.code, r.code nulls last, u.email;
