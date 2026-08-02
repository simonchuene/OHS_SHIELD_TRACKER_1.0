# OHS Shield Tracker — MVP 1 Deployment Strategy (Prompt 18)

> Enterprise deployment plan (Principal DevOps). Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Final prompt of the MVP1 sequence.

## Artifacts
- [.github/workflows/ci.yml](../.github/workflows/ci.yml) — analyze/test/RLS + build + deploy
- [config/env/*.json.example](../config/env/) — per-env `--dart-define-from-file` templates (no secrets)
- [.gitignore](../.gitignore) — excludes real env configs, generated code, Firebase files

## 1. Environment architecture
Four isolated environments, each a **separate Supabase project + Firebase project** (hard isolation; no shared data):

| Env | Purpose | Supabase | Firebase | Distribution |
|---|---|---|---|---|
| **Dev** | daily development | dev project | dev | local / emulator |
| **Test** | automated CI (pgTAP, integration) | ephemeral `supabase start` / test project | — | CI only |
| **UAT** | business acceptance | uat project | uat | Firebase App Distribution / TestFlight |
| **Prod** | live | prod project | prod | Play Store / App Store |

Same migration set + code promote across all; only config (URL/anon key/flavor/Firebase files) differs.

## 2. Supabase deployment
- **Migrations** are forward-only (`supabase/migrations/0001…0015`, + `0006–0008` RLS, + user-mgmt/audit/trigger migrations). Promote with `supabase db push`; never edit an applied migration — add a new one.
- **Edge Functions**: `user-admin`, `workflow-transition`, `inspection-item-fail`, `notify-fanout` → `supabase functions deploy`.
- **Function secrets** (per env, out-of-band, never in git): `supabase secrets set FCM_SERVER_KEY=…` (+ the service-role key is provided to functions by Supabase automatically as `SUPABASE_SERVICE_ROLE_KEY`).
- **Storage**: private `attachments` bucket created by migration `0008`.
- **Seed**: `seed.sql` (roles only). **Bootstrap** the first company + first Administrator per env via a one-off service-role script (see §10) — the client can't self-provision (4C/5A).

## 3. CI/CD pipeline (GitHub Actions)
- **PR / push→main**: `flutter pub get` → `build_runner` → `flutter analyze` → `flutter test --coverage`; **RLS job** runs `supabase db reset` + `supabase test db` (pgTAP).
- **Tag `v*`**: build Android AAB (prod flavor, `--dart-define-from-file`), then `deploy_supabase` (`db push` + `functions deploy`). iOS build added on macOS runner when signing certs are provisioned.
- Secrets: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF_PROD`, `PROD_ENV_JSON`, signing keys.

## 4. Flutter flavors (per environment)
- Config via **`--dart-define-from-file=config/env/<env>.json`** (`AppConfig.fromEnvironment()` reads `FLAVOR`/`SUPABASE_URL`/`SUPABASE_ANON_KEY`). Real files gitignored; `.example` committed.
- Native flavors give distinct app IDs + icons/names so all four can coexist on a device:
  - Android `productFlavors` (dev/uat/prod) → `applicationIdSuffix` `.dev`/`.uat`, launcher icon from `assets/branding/app_icon.svg` (via `flutter_launcher_icons`, wired to the real asset — Item 1a).
  - iOS schemes/configs (Dev/UAT/Prod) with matching bundle IDs.
- Build: `flutter build appbundle --release --flavor prod --dart-define-from-file=config/env/prod.json`.

## 5. Firebase / FCM (per environment)
- One Firebase project per env; add `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) at build time (gitignored, injected by CI or provisioning).
- APNs key (iOS) uploaded to the env's Firebase project. `FCM_SERVER_KEY` set as a Supabase function secret so `notify-fanout` can push. Push stays inactive (gracefully) until these are wired.

## 6. Monitoring
- **App**: Firebase Crashlytics + Analytics (per env); Sentry optional for Dart errors.
- **Backend**: Supabase dashboard (Postgres logs, API/Edge Function logs, slow-query insights); alert on Edge Function error rate and auth failures.
- **Product**: track the Master Prompt performance targets (dashboard <3 s, search <2 s, nav <300 ms) via analytics timings; alert on regressions.

## 7. Backup strategy
- Supabase **automated daily backups** (Pro plan; PITR where available) on the Prod project; verify retention (≥7 days) and periodically test restore into a scratch project.
- **Storage** (attachments): rely on Supabase Storage durability; for compliance, schedule periodic export of the bucket + `attachment_versions` metadata.
- **Audit integrity**: `audit_logs` is append-only (immutable) — backups preserve the full trail (POPIA/ISO 45001 evidence).

## 8. Disaster recovery
- **RPO** ≤ 24 h (daily backup; tighter with PITR). **RTO** ≤ 4 h.
- Runbook: provision a new Supabase project → apply migrations (`db push`) → restore latest backup → re-deploy Edge Functions + secrets → repoint app config (`SUPABASE_URL`/anon key) via a hot-fix build or remote config → validate with the smoke suite.
- Offline-first design cushions outages: field writes queue locally (outbox) and sync when the backend returns.

## 9. Release checklist
- [ ] Version bumped (`pubspec.yaml`), changelog updated, tag `vX.Y.Z`.
- [ ] CI green (analyze, unit/widget, pgTAP RLS, integration).
- [ ] Migrations reviewed (forward-only, reversible notes) + applied to UAT, verified.
- [ ] Edge Functions deployed; function secrets set (FCM key).
- [ ] Firebase config present per platform; push tested on UAT.
- [ ] Env config correct (no dev/UAT URLs in prod build); **no secrets in the bundle** (service-role never client-side).
- [ ] A11y + performance targets validated; UAT sign-off obtained.
- [ ] Backup/restore verified on prod project.

## 10. Rollback strategy
- **App**: staged rollout (Play/App Store phased release); halt/roll back to the previous store build on error-rate spike.
- **Edge Functions**: redeploy the previous version (git-tagged) with `functions deploy`.
- **Database**: migrations are forward-only — roll *forward* with a compensating migration (documented down-scripts exist per migration for emergencies); avoid destructive rollbacks on live data. Restore from backup only as a last resort.

## 11. Go-live plan
1. Provision Prod Supabase + Firebase; set secrets.
2. `supabase db push` + `functions deploy`; run `seed.sql`.
3. **Bootstrap**: run the service-role script to create the first `companies` row + first Administrator (invite that admin); thereafter all provisioning is in-app (5A).
4. Configure Storage bucket policies (0008) + backups + monitoring/alerts.
5. Phased store rollout; onboard a pilot site; monitor Crashlytics + Supabase logs + performance dashboards.
6. Expand rollout after the pilot passes UAT criteria.

## 12. Ledger note (pending approval)
- Deployment at `docs/18_deployment.md`; CI/CD `.github/workflows/ci.yml`; per-env config via `--dart-define-from-file` (`config/env/*.json`, gitignored). Four envs = separate Supabase + Firebase projects; forward-only migrations; roll-forward DB strategy; first company/admin bootstrapped out-of-band via service role. **MVP1 build sequence complete (Prompts 1–18 + 4C/5A/8A).**

**End of Prompt 18 deliverable — MVP1 complete.**
