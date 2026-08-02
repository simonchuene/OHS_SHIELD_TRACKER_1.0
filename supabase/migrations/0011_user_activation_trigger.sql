-- path: supabase/migrations/0011_user_activation_trigger.sql
-- Prompt 5A: activate an invited profile once the invitee confirms their email
-- (i.e. accepts the invite and sets a password). Runs server-side so the client
-- never needs write access to user_profiles (which is Administrator-only, 0010).

create or replace function public.handle_user_confirmed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Fires when email_confirmed_at transitions from NULL to a timestamp.
  if old.email_confirmed_at is null and new.email_confirmed_at is not null then
    update public.user_profiles
       set status = 'active',
           activated_at = coalesce(activated_at, now())
     where user_id = new.id
       and status = 'invited';
  end if;
  return new;
end;
$$;

create trigger trg_auth_user_confirmed
  after update on auth.users
  for each row execute function public.handle_user_confirmed();

-- ===========================================================================
-- DOWN MIGRATION:
--   drop trigger if exists trg_auth_user_confirmed on auth.users;
--   drop function if exists public.handle_user_confirmed();
-- ===========================================================================
