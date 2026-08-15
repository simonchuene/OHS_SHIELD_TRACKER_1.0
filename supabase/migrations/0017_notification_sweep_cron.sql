-- ===========================================================================
-- 0017  Scheduled notification sweep (capa.overdue / inspection.due)
-- ---------------------------------------------------------------------------
-- Prompt 15 left the sweep for time-based triggers as a deferred cron Edge
-- Function: nothing in the app can raise `capa.overdue` or `inspection.due`,
-- because they are conditions that become true with the passage of time rather
-- than user actions. This schedules `notify-sweep` to run daily.
--
-- The URL and shared secret are NOT stored here -- each environment (dev/uat/
-- prod) is a separate Supabase project with its own function URL and secret, and
-- a migration must stay environment-agnostic and secret-free. They live in
-- Supabase Vault, set per project out of band:
--
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1/notify-sweep', 'sweep_url');
--   select vault.create_secret('<same value as the SWEEP_SECRET function
--     secret>', 'sweep_secret');
--
-- (Vault rather than `alter database ... set`: hosted Supabase does not grant
-- the postgres role superuser, so setting a custom database parameter fails
-- with 42501. Vault is the supported store and encrypts at rest.)
--
-- To rotate later, delete and recreate:
--   delete from vault.secrets where name = 'sweep_secret';
--   select vault.create_secret('<new value>', 'sweep_secret');
--
-- Until both exist the job runs and no-ops with a notice, so applying this
-- migration to an unconfigured project is harmless.
-- ===========================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists supabase_vault;

-- Posts to the Edge Function. SECURITY DEFINER so the cron job can read the
-- Vault secrets and reach pg_net regardless of the caller's privileges.
create or replace function app.run_notification_sweep()
returns void
language plpgsql
security definer
set search_path = public, extensions, net, vault
as $$
declare
  v_url    text;
  v_secret text;
begin
  select decrypted_secret into v_url    from vault.decrypted_secrets where name = 'sweep_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'sweep_secret';

  if v_url is null or v_url = '' or v_secret is null or v_secret = '' then
    raise notice 'notification sweep skipped: vault secrets sweep_url / sweep_secret not configured';
    return;
  end if;

  -- Fire-and-forget. pg_net queues the request; the function is idempotent per
  -- entity per day, so a retry or a double-fire cannot double-notify.
  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type',   'application/json',
                 'x-sweep-secret', v_secret
               ),
    body    := '{}'::jsonb
  );
end;
$$;

revoke all on function app.run_notification_sweep() from public, anon, authenticated;

-- Re-running this migration must not stack duplicate schedules.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'notification-sweep-daily') then
    perform cron.unschedule('notification-sweep-daily');
  end if;
end;
$$;

-- 06:00 UTC daily: early enough that an owner sees an overdue CAPA at the start
-- of the working day in SAST (UTC+2), before the sweep's own day rolls over.
select cron.schedule(
  'notification-sweep-daily',
  '0 6 * * *',
  $$select app.run_notification_sweep();$$
);
