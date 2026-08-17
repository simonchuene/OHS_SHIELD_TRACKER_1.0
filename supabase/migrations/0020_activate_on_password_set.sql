-- ===========================================================================
-- 0020  Activate an invited profile when the PASSWORD is set, not on email
--       confirmation
-- ---------------------------------------------------------------------------
-- 0011 activated an invited profile the moment `email_confirmed_at` was set.
-- That fires as soon as the invite link is opened — before the invitee has
-- chosen a password. The profile flipped to 'active' while the account still
-- had no password, so:
--
--   * nothing distinguished "invited, mid-onboarding" from "fully set up", and
--   * the user got a working session once, then was locked out on next launch
--     because there was no password to sign in with.
--
-- Activation now waits for the password itself. `status = 'invited'` becomes a
-- reliable server-side signal that onboarding is incomplete, which is what the
-- app uses to route an invitee to the set-password screen — rather than trying
-- to infer it from an auth event, where an invite is indistinguishable from an
-- ordinary sign-in.
--
-- Still server-side (SECURITY DEFINER), for the reason 0011 gave: the client
-- must never need write access to user_profiles, which is Administrator-only
-- (0010). A user cannot activate themselves by any route the app exposes.
--
-- Password RESET for an already-active user is unaffected: the update is
-- guarded on `status = 'invited'`, so it is a no-op for everyone else.
-- ===========================================================================

drop trigger if exists trg_auth_user_confirmed on auth.users;
drop function if exists public.handle_user_confirmed();

create or replace function public.handle_user_password_set()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- An invited user starts with no password at all, so the first non-empty
  -- encrypted_password is the moment onboarding completes. Comparing old to new
  -- (rather than checking for NULL) also covers a re-invite that resets it.
  if (old.encrypted_password is distinct from new.encrypted_password)
     and coalesce(new.encrypted_password, '') <> '' then
    update public.user_profiles
       set status       = 'active',
           activated_at = coalesce(activated_at, now())
     where user_id = new.id
       and status  = 'invited';
  end if;
  return new;
end;
$$;

create trigger trg_auth_user_password_set
  after update on auth.users
  for each row execute function public.handle_user_password_set();

-- ===========================================================================
-- DOWN MIGRATION:
--   drop trigger if exists trg_auth_user_password_set on auth.users;
--   drop function if exists public.handle_user_password_set();
--   -- then re-create 0011's handle_user_confirmed() + trg_auth_user_confirmed
-- ===========================================================================
