# OHS Shield Tracker — Decisions Ledger Addendum (MVP 2 + MVP 3)

**Companion to `DECISIONS_LEDGER.md`. Does not replace or edit it.**

## How to use this file

- The existing `DECISIONS_LEDGER.md` (§1–§24) is the **MVP 1 build record** and remains **frozen**. Do not rewrite its history, and do not edit its §2 locked domain values — they are restated from `MVP1_2.md`, not owned by the ledger. §24 was appended after this addendum was first drafted, to record MVP 1 work that had landed after §23 (inspection fixes, migration `0022`, the invite-gate reorder); it closes the MVP 1 record. MVP 1 **pre-flight** outcomes (Part E) are still MVP 1 work, so they are appended under §24 as they land (e.g. §24.5, the pgTAP rewrite) — nothing above §24 is edited.
- **Migration numbering:** MVP 1 ends at `0023_explicit_table_grants.sql` (a pre-flight fix, Ledger §24.6). **The first MVP 2 migration is `0024`.** References below to "the 0021 audit trigger" mean the *0021-fixed form* of `audit_row_change()`, not a migration number to reuse.
- This addendum owns the **new** domain values introduced by MVP 2 and MVP 3 (capabilities, new status enums, new notification triggers, entitlement model, persona configs, canonical-score contract, vector partitioning, audit-import policy).
- **Fill a slot only after the relevant prompt's output has been human-approved AND its effect observed.** Blank is honest; pre-filled is the exact failure mode `DECISIONS_LEDGER.md` §10–§23 keeps warning about ("a feature is done when its effect is observed, not when its code exists"). Leave `___` until then.
- Carry into every follow-up prompt: **the relevant Master Prompt (`MVP1_2.md` / `MVP2.md` / `MVP3.md`) + `DECISIONS_LEDGER.md` + this addendum** — not full prior outputs.
- **Governance:** if an MVP 1 locked value must change, change `MVP1_2.md` and re-derive. If an MVP 2/3 value must change, change it **here** and re-derive. Never let a spec file and the ledger diverge.

**Status:** Template issued ___ · **MVP 2 sequence started:** ___ · **MVP 3 sequence started:** ___

---

## PART A — PENDING DEVIATIONS (decisions made at spec time, to be confirmed at build time)

Three decisions were taken during the spec-alignment session and are recorded here **as pending**. Each follows the §18 precedent (`capa.verification_due`): a change to a locked or governed value is written down deliberately, never absorbed silently. Each is confirmed (or amended) when the prompt that implements it is approved.

### DEV-M2-A — The access model gains a capability layer (extends, does not replace, the rank ladder)

- **Status:** PENDING — confirm at MVP 2 Prompt 0.
- **What changes:** `DECISIONS_LEDGER.md` §5 / §5a / §22 describe a purely **rank-based** access model (employee=1 → administrator=5, exact-rank visibility tiers). MVP 2 adds a **capability layer alongside it** (`app.has_capability(cap)` beside `app.has_min_rank(n)`).
- **Why it is unavoidable:** MVP 2's seven functional roles are non-hierarchical, and the health-privacy requirement is **inexpressible as a rank** — a rank-2 Occupational Health Practitioner must see medical results a rank-5 Administrator must not. A ladder cannot make a lower rank see *more* than a higher rank.
- **What must remain true:** the rank ladder is **not removed** (MVP 1 RLS depends on it); `app.user_rank()` behaviour is unchanged; no existing MVP 1 rank policy is loosened.
- **Consequence for the ledger:** §22's as-built matrix becomes **incomplete rather than wrong**. It needs a companion **as-built capability matrix** (slot M2-1e below) once Prompt 0 is approved.
- **Binding constraint — functional roles must not enter the rank ladder.** `public.roles.rank` is `smallint NOT NULL` with `UNIQUE (rank)`, and ranks 1–5 are taken. `app.user_rank()` is `max(roles.rank)` across a user's `user_roles`. So the obvious implementation — adding the seven functional roles as rows in `roles` — forces each a distinct new rank, and **any rank above 5 makes its holder outrank an Administrator**: a Training Coordinator would satisfy `app.has_min_rank(5)`. The exact-rank visibility tiers (§22.2, `app.user_rank() = N`) would shift for any user holding one. Ranks ≤ 0 avoid the escalation but still perturb `user_rank()` for users with no rank role, and encode "not a rank" as a magic number.
  **Recommended:** store functional-role grants outside `roles` / `user_roles` (e.g. `functional_roles` + `user_functional_roles`, or grants directly in `role_capabilities` keyed on a functional-role code), so `app.user_rank()` is unchanged **by construction** rather than by a chosen value. Prompt 0's self-check must include a test that granting every functional role to a rank-1 user leaves `app.user_rank()` = 1. Final choice recorded at M2-1g.
- **Confirmed on:** ___ · **Amendments:** ___

### DEV-M2-B — The notification trigger enum ("D7") gains ~13 MVP 2 values, plus IoT values in MVP 3

- **Status:** PENDING — confirm at MVP 2 Prompt 13 (and MVP 3 Prompt 7).
- **What changes:** `DECISIONS_LEDGER.md` §3 fixed the D7 set at seven names; §18 added an eighth (`capa.verification_due`) as an explicit, documented deviation. MVP 2 adds ~13 more and MVP 3 adds IoT/automation triggers.
- **Why it is deliberate:** the enum is a **governed list**. Adding thirteen at once does not make the governance optional — each value is added by migration and recorded here.
- **MVP 2 additions:** `training.expiring` · `training.expired` · `certification.expiring` · `permit.expiring` · `permit.expired` · `permit.approval_required` · `medical.assessment_scheduled` · `medical.follow_up_due` · `compliance.review_due` · `document.review_due` · `document.acknowledgement_required` · `committee.meeting_scheduled` · `committee.action_due`
- **MVP 3 additions (IoT/automation):** ___ (agreed at MVP 3 Prompt 7)
- **Routing rule (binding):** event-driven → `notify-fanout`; **every time-based *expiring/expired/due* trigger → `notify-sweep` cron** (§13), reusing its once-per-entity-per-day idempotency and owner-only recipient rule. Actor always filtered out (§16). Never raise a time-based trigger from the app.
- **Confirmed on:** ___ · **Amendments:** ___

### DEV-M3-A — A new capability namespace and the `audit.import` ingestion channel

- **Status:** PENDING — confirm at MVP 2 Prompt 0 (namespace) and MVP 3 Prompt 11 (`audit.import`).
- **What changes:** a capability vocabulary now exists alongside the rank ladder: `health.read_medical` · `health.manage` · `training.manage` · `compliance.manage` · `contractor.manage` · `permit.approve` · `committee.manage_minutes` · `document.control` · `licensing.manage` · `audit.import`.
- **File-format deviation (called out deliberately):** MVP 1 restricted the shared Attachment service to **JPG · PNG · PDF (20 MB)** on purpose — attachments are opaque evidence blobs, not parseable data sources. Module 11 requires tabular ingestion, so it uses a **separate, purpose-built channel** and **does not widen the evidence allow-list**. Evidence stays JPG/PNG/PDF platform-wide.
- **Confirmed on:** ___ · **Amendments:** ___

---

## PART B — MVP 2 ADDENDUM (fill in as each MVP 2 prompt is approved)

**Last updated after:** MVP 2 Prompt ___

### M2-1. Access Model (Prompt 0)
- **M2-1a — Capability + grant tables:** `capabilities`, `role_capabilities` (company-scoped, RLS, 0021 audit) — ___
- **M2-1b — Helper:** `app.has_capability(cap)` (companion to `app.has_min_rank(n)`) — ___
- **M2-1c — Capability list:** health.read_medical · health.manage · training.manage · compliance.manage · contractor.manage · permit.approve · committee.manage_minutes · document.control · licensing.manage — *(additions)* ___
- **M2-1d — Confidential medical tier tables:** medical_assessments · medical_documents · health_actions — *(deviations)* ___
- **M2-1e — AS-BUILT CAPABILITY MATRIX** (companion to §22; role × capability × action, as the policies actually enforce it): ___
- **M2-1f — Proof no MVP 1 rank policy was loosened:** ___
- **M2-1g — Functional roles are additive** (a user may hold a rank role + functional roles; `app.user_rank()` unchanged — **see the binding constraint under DEV-M2-A: functional roles cannot be rows in `roles`**). Storage chosen: ___ · Proof `app.user_rank()` unchanged for a rank-1 user holding all seven: ___

### M2-2. Schema & Tenancy (Prompts 2A / 2B)
- **M2-2a — New table list (28 + access-model + licensing):** *(confirm each carries `company_id` + RLS + 0021 audit trigger)* ___
- **M2-2b — New status enums:** training_status · compliance_status · permit_status · document_status · medical_assessment_status — ___
- **M2-2c — Tenant-isolated Storage paths:** medical_documents · permit_attachments · contractor_documents (`foldername[1] = company_id`) — ___
- **M2-2d — 0021 audit trigger attached to status-less tables** (documents, contractors, contractor_insurance, document_versions …) — ___
- **M2-2e — Index coverage on `company_id` / `site_id` / `status`:** ___
- **M2-2f — `created_by` / `updated_by` are populated by trigger, never by the client.** `MVP2.md` mandates both on every new table; **no MVP 1 table has either**, and MVP 1 tables are not retrofitted (no destructive change to MVP 1). Set them in a shared `BEFORE INSERT/UPDATE` trigger from `auth.uid()` — a client-supplied actor is spoofable, and caller-populated columns drift the moment one caller forgets (the reason `0022` put references in a trigger). Service-role writes (edge functions) have no `auth.uid()`; they must pass the acting user explicitly or the column is null, as MVP 1 audit rows already are for seeded data. Cross-module queries must not assume these columns exist on MVP 1 tables. Trigger chosen: ___

### M2-3. Licensing, Seats & Entitlements (Prompt 4)
- **M2-3a — Entitlement model:** plan tier · seat_limit · active_seats · per-module flags · billing status — ___
- **M2-3b — Seat gate insertion point:** `assertSeatAvailable(companyId)` in `supabase/functions/user-admin/index.ts` — added in Ledger §24.3 (§5a promised it; until then it existed only in prose). Always allows in MVP 1; called **before** `inviteUserByEmail`, so a refusal creates no auth user and sends no email. Do not move the check after the invite call.
  **Decide in Prompt 4:** is a seat consumed at **invite** (count `invited` + `active`) or at **activation**? Activation happens in the `0020` database trigger when a password is first set, not in this function — an activation-time limit cannot be enforced from `user-admin` alone, and a trigger that refuses activation leaves the user holding a valid session with an unusable account. Chosen: ___
- **M2-3c — Module entitlement gating** (RLS/Edge Function authoritative; client affordance UX only) — ___
- **M2-3d — Billing deferred?** *(explicit yes/no + scope — must not be silently dropped a second time)* ___

### M2-4. Cross-Cutting Contracts
- **M2-4a — Document service API surface (Prompt 5):** ___
- **M2-4b — New notification triggers + routing (event vs swept) (Prompt 13):** ___ *(see DEV-M2-B)*
- **M2-4c — Analytics view contract consumable by MVP 3 (Prompt 12):** ___
- **M2-4d — Analytics scope boundary:** MVP 2 = **descriptive only**; predictive/prescriptive = MVP 3. MVP 3 consumes/extends these views, never re-implements them.

### M2-5. Offline & Tenancy
- **M2-5a — New LocalOwner-aware cached entities:** ___
- **M2-5b — Conflict rule for new offline-writable entities** (LWW + audit trail vs field-level merge): ___

### M2-6. MVP 2 Open Questions
- **M2-OQ1 — POPIA:** `user_profiles` is company-wide readable at every rank (§22.2). Confirm whether MVP 2 modules narrow personal-data visibility, or whether that stays an accepted, explicit decision. ___
- **M2-OQ2 — Escalation threshold** for swept expiry triggers (owner-only, vs escalate to Safety Officer after N days). §13 rejected default SO escalation as noisy; agree a threshold rather than inheriting silence. ___
- **M2-OQ3 —** ___

---

## PART C — MVP 3 ADDENDUM (fill in as each MVP 3 prompt is approved)

**Last updated after:** MVP 3 Prompt ___

### M3-1. Unified AI Foundation (Prompt 0)
- **M3-1a — Shared engine components:** RAG · prompt orchestration · agent framework · conversation memory · citation framework · AI security — ___
- **M3-1b — Persona contract** (system prompt · prompt library · scope · tool/data surface; **narrows-only, never widens**): ___
- **M3-1c — Vector store technology + partitioning** (namespace/partition per `company_id`, or server-enforced predicate — **never** a shared index filtered post-retrieval): ___
- **M3-1d — Retrieval-time authorization** (`company_id` + rank + capability + medical tier enforced **at retrieval**, not post-filtered): ___
- **M3-1e — Advisory-only guardrail** (agent framework exposes **no** close/approve/verify tool): ___
- **M3-1f — AI interaction audit** (prompt, retrieval set, model/version, response → `audit_logs`): ___

### M3-2. Canonical Enterprise Score (Prompt 2)
- **M3-2a — Single scoring service + formula version:** ___
- **M3-2b — Persistence** (one row per company/site/period; `company_id`, RLS, 0021 audit): ___
- **M3-2c — Module 10 "Executive Health Score" = presentation VIEW of Module 6** — reconciliation proof: ___
- **M3-2d — Confirmation no second computation path exists:** ___
- **M3-2e — The MVP 1 dashboard Safety Score is a third consumer, and today a second computation.** It is computed **client-side in Dart** (`lib/features/dashboard/domain/safety_score.dart`: 100 − 5·highRisk − 4·overdueCapa − 6·seriousIncident30d) and **higher means safer**. The canonical Enterprise Risk Score is computed **server-side** and **higher means riskier**. Left alone, the app shows two 0–100 numbers pointing in opposite directions — exactly the divergence the contract exists to prevent, on the most-viewed screen in the product.
  When Prompt 2 lands: the MVP 1 dashboard card renders the canonical value under the health framing (100 − risk), and the Dart heuristic is **retired as a computation** — its terms become inputs to the canonical formula, not a parallel score. Until then the MVP 1 card is the only score and needs no change. Reconciliation proof (dashboard card = Module 6 = Module 10 for the same company/site/period): ___

### M3-3. Personas (Prompts 3, 9, 10)
- **M3-3a — Safety Copilot (P3):** ___
- **M3-3b — Knowledge Assistant (P9):** ___
- **M3-3c — Mobile Safety Assistant (P10, host Module 9):** ___
- **M3-3d — Executive Copilot (P10, host Module 10):** ___
- **M3-3e — Confirmation all four share ONE engine / memory / citation / security core:** ___

### M3-4. Analytics Dependency
- **M3-4a — MVP 2 views consumed per MVP 3 module** (proof of no re-implementation): ___
- **M3-4b — MVP 2 views EXTENDED by MVP 3** (rather than privately duplicated): ___

### M3-5. New Tables & Tenancy
- **M3-5a — New AI / IoT / knowledge / audit-import tables** (each with `company_id` + RLS + **0021** audit trigger — most are status-less, so the 0021 form is mandatory per §23.2): ___
- **M3-5b — New LocalOwner-aware cached AI artefacts:** ___

### M3-6. Notifications (Prompt 7)
- **M3-6a — New IoT / automation triggers + routing (event vs swept):** ___ *(see DEV-M2-B)*

### M3-7. MLOps (Prompt 4)
- **M3-7a — Model registry · versioning · feature store · monitoring · drift detection · rollback:** ___
- **M3-7b — Explainability payload contract** (confidence · contributing factors · sources · recommended actions): ___

### M3-8. External Audit Import & Summarization (Prompt 11 / Module 11)
- **M3-8a — New capability `audit.import`** + grantees (e.g. Compliance Officer / Safety Officer+ / Administrator): ___
- **M3-8b — File-format policy (LOCKED once approved):** accept **.xlsx / .csv only**; reject **.xls** (legacy binary), **.xlsm** (macro-enabled), sheet links, arbitrary binaries; **20 MB** + row cap (e.g. 50,000); **server-side parse only**; formula/CSV injection neutralized (`= + - @` treated as text). — ___
- **M3-8c — Separate ingestion channel confirmed** — the MVP 1 evidence-attachment allow-list (JPG/PNG/PDF) is **NOT** widened: ___
- **M3-8d — Import tables + tenant-isolated storage path** for the retained original file (`foldername[1] = company_id`): ___
- **M3-8e — Import versioning** (re-upload = new version; prior versions retained, never deleted — mirrors `attachment_versions`): ___
- **M3-8f — Summarization reuses the Unified AI Framework** (not a new engine); cites real imported row identifiers; advisory only: ___
- **M3-8g — Report path reuses the MVP 1 Reporting pipeline** (PDF/CSV + history) and stores via **MVP 2 Document Management**; no new exporter: ___
- **M3-8h — Medical columns in an import honour `health.read_medical`** in both rows and derived summaries: ___

### M3-9. MVP 3 Open Questions
- **M3-OQ1 — Vector store technology** (pgvector vs external) and exactly how tenant partitioning is enforced in the chosen store. ___
- **M3-OQ2 — Conversation-memory retention/erasure under POPIA** (chat memory is personal data). ___
- **M3-OQ3 — Retention policy** for imported external-audit source files and their derived summaries (POPIA). ___
- **M3-OQ4 —** ___

---

## PART D — INHERITED RULES THAT BIND MVP 2 AND MVP 3

Restated for convenience from `DECISIONS_LEDGER.md` — **not editable here.** Change the source, then re-derive.

| Rule | Source | Applies to MVP 2/3 as |
|---|---|---|
| `company_id` on every tenant-scoped table + RLS `= app.current_company_id()` | §5, §22 | Every new table, without exception |
| **Table privileges are declared, never inherited.** The migration that creates a table grants it explicitly: `select, insert, update, delete` to `authenticated` (RLS narrows rows), `all` to `service_role`, nothing to `anon`, and **no `TRUNCATE` for `anon`/`authenticated`**. Platform default privileges are environment state outside the repo; a table relying on them works on one project and is "permission denied" on the next | §24.6 / `0023` | Every new MVP 2/3 table — a missing grant is invisible on a project that has defaults and fatal on one that does not, so the pgTAP suite must exercise each new table as `authenticated` |
| **The cache is part of the trust boundary** — LocalOwner wipe on user switch | §23 / D-tenant-1 | Every new locally-cached entity; RLS alone is insufficient |
| Audit via `audit_logs` + the **0021-fixed** `audit_row_change()` (jsonb status comparison) | §23.2 / D-audit-1 | Mandatory — the pre-0021 form makes **status-less** tables INSERT-ONLY |
| `audit_logs` is INSERT + SELECT only (no UPDATE/DELETE at any rank or capability) | §5, §6 | Unchanged; capabilities do not create a mutation path |
| Time-based notifications come from the `notify-sweep` cron, with once-per-entity-per-day idempotency | §13 | All new *expiring/expired/due* triggers |
| The actor is filtered out of notification recipients | §16 | All new triggers |
| Forward-only migrations; never bootstrap uat/prod from a combined file | §13 / D-env-1 | All MVP 2/3 migrations |
| **Verify at the delivery boundary** — done means *observed*, on a device that did not originate the data | §10, §11, §12 | Every module and every ledger slot above |
| "Production-ready" = review-ready first implementation, not a deployable binary | §6 | All generated output |

---

## PART E — MVP 1 PRE-FLIGHT (open at time of writing)

Not part of MVP 2/3, but **MVP 3 assumes MVP 1 and MVP 2 are deployed**, so these gate the whole programme. Tracked here so they are not lost between phases.

| Item | Source | Status |
|---|---|---|
| CI green end-to-end (it had **never** passed before §19) | §19, §24.5 | **Half done.** The push path is green for the first time — run #27 (`108da01`), `Analyze & test` + `RLS (pgTAP)`. The **tag path has never run**: `Build (Android AAB)` and `Deploy Supabase` execute only on `v*` tags, so the release pipeline is still unexercised — see the release-build row below ___ |
| Release build (`flutter build appbundle --release --flavor prod`) — **never run on any toolchain** | §19 | ___ |
| The 8 pgTAP RLS assertions — **have never executed**; §22 is read from policy source, not observed behaviour | §22.5 → **§24.5** | **Superseded.** The original suite now executes but could not test RLS (ran as table owner, no fixture). Rewritten as 35 assertions with fixtures, role switching and paired controls — **passing in CI** (run #27, `108da01`), and 35/35 against the hosted dev project |
| Migration replay from an empty database | §24.5 | **Observed** — `supabase db reset` passes in CI run #24 (`6f856c4`) |
| A fresh environment can actually use its tables (explicit grants, no reliance on platform defaults) | §24.6 | **Fixed by `0023`** — applied to dev; verified as a no-op for the app there (42 privileges removed, all `TRUNCATE`; none added). **Confirmed in CI**: run #27 (`108da01`) built a fresh database from the migrations and the pgTAP suite passed against it |
| Custom SMTP (built-in allows ~2–4 emails/hour, project-wide) | §21.2 | ___ |
| Android App Link (a custom scheme does not resolve on desktop-opened invites) | §21.2 | ___ |
| Remove the DEBUG-ONLY corporate-CA trust before any release build | MVP1_2.md | ___ |
| Cold-start deep-link path (D-auth-2) — reasoned, **not yet observed** | §21.1 | ___ |
| Canonical MVP 1 follow-up in use (`MVP1_Follow_ups_1.md`, with Prompts 4C/5A) — retire the superseded copy | §CANONICAL | ___ |

---

**Governance note:** MVP 1 locked domain values (`DECISIONS_LEDGER.md` §2) are inherited unchanged and are **not** restated here — consult the source. New MVP 2/3 domain values are owned by this addendum. If one must change, change it **here** and re-derive; never let `MVP2.md` / `MVP3.md` and this addendum diverge.
