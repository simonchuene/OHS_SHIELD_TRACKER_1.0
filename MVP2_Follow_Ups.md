## OHS Shield Tracker — MVP 2 Follow-Up Prompts

Use these prompts sequentially, in one continuous conversation where possible. Each prompt assumes the outputs of all prior prompts have been **reviewed and approved by a human** and are available as context. Approval is an explicit step, not automatic — unread outputs compound errors across the sequence. If starting a fresh conversation mid-sequence, paste **MVP2.md + MVP1_2.md (Master Prompt) + the Decisions Ledger** alongside the prompt rather than every full prior output.

MVP 2 **extends** a live, device-tested MVP 1 (all 11 feature modules, offline-first sync, RLS + `app.*` helpers, 5 Edge Functions). It does **not** redesign it. Every prompt below inherits the MVP 1 design system, security model, and build conventions unchanged, and adds the new enterprise OHS capabilities on top.

### Global Conventions (apply to every prompt below)

- **Extend, never redesign.** Never restate or alter locked MVP 1 domain values (colours, typography, risk bands, status flows, RBAC rank ladder, incident severity, the signature design system Items 1–9). Reference them from MVP1_2.md. New MVP 2 components must inherit the MVP 1 design language exactly and appear under the existing **More** tab navigation, never as a new nav paradigm.
- **Decisions Ledger over full outputs.** After each prompt is approved, update the Decisions Ledger MVP 2 addendum (new table list, capability names, new status enums, new notification triggers, entitlement model). Carry **MVP2.md + MVP1_2.md + the Ledger** into later prompts instead of pasting all prior outputs — this keeps the sequence from drifting or exceeding the context window.
- **Output emission.** Emit code as **one file per block, each prefixed with `// path: lib/...`** (or `-- path: supabase/migrations/...` for SQL) mapping to the established folder structure. Never merge files or omit paths.
- **Self-verification.** Where a prompt has a checkable constraint (capability matrix, `company_id` coverage, status transitions, entitlement gating, RLS scoping), end the output with a short **self-check table** proving it holds — do not just assert compliance in prose.
- **"Production-ready" = review-ready first implementation.** Output is a strong, convention-following starting point that still needs human compilation, integration testing, security review, and real asset/secret wiring before shipping — not a deployable binary.
- **Tenancy is non-negotiable.** Every new tenant-scoped table carries `company_id` and has RLS enabled with `company_id = app.current_company_id()`. Every new locally-cached entity respects the LocalOwner wipe-on-user-switch rule (Ledger §23). RLS is necessary but not sufficient — the cache is part of the trust boundary.
- **Reuse MVP 1 infrastructure.** Attachments → the shared Attachment service (MVP 1 Prompt 6). Audit → `audit_logs` + the **0021-fixed** `audit_row_change()` trigger (jsonb status comparison — never the pre-0021 form, which makes status-less tables insert-only, Ledger §23.2). Notifications → `notify-fanout` (event-driven) or `notify-sweep` (time-based). Offline writes → `OfflineMutationService` + the outbox. Do not invent parallel systems.
- **A module is done when its effect is observed** — on a device that did not originate the data, and (for confidential data) under a role that must NOT see it as well as one that must. This is the hard-won lesson of the MVP 1 build (Ledger §10–§23); do not record a module complete at the layer where its code stops.

---

#### Prompt 0 — Access Model Evolution (BLOCKS ALL MVP 2 MODULES)

Act as a Principal Security Architect and PostgreSQL Architect.
This prompt MUST be completed and approved before any MVP 2 feature module is built. Everything downstream gates on it.

**Context.** MVP 1 enforces access as a strict linear **rank ladder** (employee=1 → supervisor=2 → safety_officer=3 → manager=4 → administrator=5) via `app.user_rank()` / `app.has_min_rank(n)`, with **exact-rank** visibility tiers (own → department → site → enterprise). See Ledger §5, §5a, §22. The seven new MVP 2 roles are **functional and non-hierarchical**, and one requirement is impossible to express as a rank: a rank-2 Occupational Health Practitioner must see medical results that a rank-5 Administrator must **not** (see MVP2.md HEALTH DATA PRIVACY). A rank ladder cannot make a lower rank see *more* than a higher rank.

**Generate:**
- A **capability layer** layered on top of the rank ladder (do NOT remove the ladder — MVP 1 RLS depends on it):
  - `capabilities` reference table (code, description) and `role_capabilities` grant table (company-scoped, `company_id` mandatory).
  - Initial capability set: `health.read_medical`, `health.manage`, `training.manage`, `compliance.manage`, `contractor.manage`, `permit.approve`, `committee.manage_minutes`, `document.control` (+ `licensing.manage` for Prompt 4).
- A new RLS helper `app.has_capability(cap text)` reading the caller's granted capabilities (via their role rows), companion to `app.has_min_rank(n)`. New MVP 2 policies gate on **capability**; MVP 1 policies keep gating on **rank**, unchanged.
- A **confidential data tier** for occupational-health/medical data enforced by `health.read_medical`, **not** by rank — so it is hidden from Manager/Administrator unless explicitly granted.
- Additive role assignment: a user may hold a rank role **and** one or more functional roles at once. `app.user_rank()` still returns the max rank across the user's role rows (unchanged behaviour).
- **Functional roles must not be rows in `roles`** (Addendum DEV-M2-A). `roles.rank` is `NOT NULL UNIQUE` with 1–5 taken, and `app.user_rank()` is `max(roles.rank)` — any functional role given a rank above 5 would make its holder outrank an Administrator. Store functional-role grants separately so `user_rank()` is unchanged by construction, not by a chosen number.
- Client mirror: `AppCapability` / extended `AppRole` affordances (UX only — RLS authoritative per architecture §10).
- Migration(s) extending the schema with the two new tables + helper, forward-only, `company_id`-scoped, RLS-enabled.

**Business Rules:**
- No MVP 1 rank policy may be loosened by this change.
- Capability grants are company-scoped and auditable (attach the 0021 audit trigger).
- Provisioning of functional roles / capabilities is Administrator-only (rank 5), enforced at RLS + Edge Function, mirrored in the UI.

**Self-check (mandatory):** Output (a) a table mapping every new MVP 2 role × every MVP 2 capability to allow/deny, (b) a proof that every existing MVP 1 rank policy is byte-for-byte unchanged or strictly additive — no existing grant widened or narrowed, and (c) a test showing that a rank-1 user granted **all seven** functional roles still has `app.user_rank()` = 1 and fails `app.has_min_rank(2)`.

**Definition of Done:** An Administrator can grant the seven functional roles without changing anyone's rank; a rank-2 user granted `health.read_medical` can read medical data that a rank-5 user without it cannot; and `flutter analyze` + the MVP 1 pgTAP RLS smoke test still pass.

---

#### Prompt 1 — MVP 2 Architecture

Act as a Principal Solution Architect.
Using MVP2.md as the source of truth and the approved access model (Prompt 0), design the complete MVP 2 architecture as an **extension** of MVP 1.

**Generate:**
- Updated Domain Model (new bounded contexts: Occupational Health, Training & Competency, Compliance, Contractor, Permit-to-Work, Safety Committee, Document Management, Advanced Analytics, Licensing).
- Module relationships and the MVP 1 ↔ MVP 2 integration map (Health → Hazards/Risk; Training → Users/Departments/Contractors/Compliance; Compliance gaps → CAPA; Contractor incidents → Incident Management; Permit violations → Hazards/CAPA; Document reviews → Notifications; Committee actions → CAPA).
- Updated ERD (new tables + FKs into MVP 1 tables — never modifying MVP 1 tables destructively).
- Navigation architecture: new destinations under **More** (Health, Training, Compliance, Contractors, Permits, Documents), plus module-entitlement gating (Prompt 4).
- Security architecture delta: where policies gate on **rank** vs **capability**; the confidential medical tier.
- Analytics architecture: MVP 2 descriptive views as a stable contract MVP 3 will consume (not re-implement).
- Migration strategy from MVP 1 (forward-only, no drop/rename of MVP 1 tables).

Document all architectural decisions. Do not write application code. Focus only on architecture.

**Self-check:** List every MVP 1 table and confirm none is dropped, renamed, or has a column removed; list every new MVP 2 table and confirm it carries `company_id`.

---

#### Prompt 2A — Database Schema Extension

Act as a Principal PostgreSQL Architect.
Using the approved MVP 2 architecture, design the complete PostgreSQL **schema extension** (structure only — RLS is Prompt 2B).

**Tables to cover (all new):** occupational_exposures · medical_programs · medical_assessments · health_actions · training_courses · training_records · certifications · competency_matrix · compliance_requirements · compliance_reviews · compliance_evidence · contractors · contractor_employees · contractor_insurance · permits · permit_approvals · permit_closeouts · committee_meetings · committee_actions · documents · document_versions · document_reviews · document_acknowledgements · document_attachments · permit_attachments · training_certificates · medical_documents · contractor_documents — plus `capabilities` · `role_capabilities` (Prompt 0) and the licensing tables (Prompt 4).

**Generate:**
- Relationships, PKs (UUID, `gen_random_uuid()`), FKs into MVP 1 tables where the integration map requires (e.g. `medical_assessments.hazard_id`, `permits.contractor_id`, `compliance_reviews.capa_id`).
- **Mandatory columns on every table:** `id`, `company_id`, `created_at`, `updated_at`, `created_by`, `updated_by`, `status` where applicable, `site_id`/`department_id` where relevant.
- **`created_by` / `updated_by` are set by one shared `BEFORE INSERT/UPDATE` trigger from `auth.uid()`**, never supplied by the client (Addendum M2-2f). No MVP 1 table has them — do not retrofit MVP 1 tables, and do not assume the columns in queries that span MVP 1 and MVP 2.
- New status enums exactly per MVP2.md STATUS GOVERNANCE: training_status, compliance_status, permit_status, document_status, medical_assessment_status.
- Constraints, unique constraints, and **indexes on every `company_id`/`site_id`/`status` column** used in RLS and dashboard filters.
- Document version-history modelling that reuses the MVP 1 `attachment_versions` pattern (never delete history; mark superseded inactive).
- Forward-only migrations, `-- path: supabase/migrations/00NN_*.sql`.

**Self-check:** Produce a table confirming **every** new table carries `company_id` and that each `company_id`/`status` column is indexed. Confirm no MVP 1 table is altered destructively.

Do not write RLS yet. Do not write Flutter code.

---

#### Prompt 2B — Row Level Security & Capability Policies

Act as a Principal PostgreSQL Architect.
Using the approved schema (2A) and the capability layer (Prompt 0), design the complete **RLS and policy layer** for all MVP 2 tables.

**Generate:**
- RLS enabled on **every** new table (name each explicitly; none unsecured), every policy including `company_id = app.current_company_id()`.
- Rank-gated policies where the action maps to the MVP 1 ladder (e.g. create/assign CAPA-linked records = Supervisor+).
- **Capability-gated policies** for functional actions: `training.manage`, `compliance.manage`, `contractor.manage`, `permit.approve`, `committee.manage_minutes`, `document.control`.
- **Confidential medical tier:** `medical_assessments`, `medical_documents`, `health_actions` SELECT restricted to `app.has_capability('health.read_medical')` — explicitly **excluding** Manager/Admin who lack it. Dashboards may read only aggregated, non-identifying health metrics.
- Attach the **0021-fixed** `audit_row_change()` trigger to every new table (jsonb status comparison — status-less tables like documents/contractors must remain updatable, Ledger §23.2).
- Supabase Storage policies for the new attachment paths (medical_documents, permit_attachments, contractor_documents), tenant-isolated by `foldername[1] = company_id`.

**Self-check (mandatory):** A table mapping **every MVP 2 role/capability × every action** on each new table to the specific policy that enforces it, proving (1) no gaps, (2) the medical tier hides data from higher ranks lacking the capability, and (3) no cross-company path exists.

Do not write Flutter code.

---

#### Prompt 3 — UI/UX Extension

Act as a Senior Enterprise UX Architect.
Using the MVP 1 **APPLICATION THEME**, **APPLICATION BRANDING**, and locked signature design system (Items 1–9) exactly, extend the UX for MVP 2 — do not redesign.

**Generate:**
- New screen inventory and navigation flows for the 6 new **More** destinations (Health, Training, Compliance, Contractors, Permits, Documents), role/capability-gated to mirror router guards + RLS.
- Reuse of MVP 1 signature components: Risk Compass, curved hero header, KPI/list-row anatomy, duotone icon badges, floating pill nav, status steppers, RankGatedAction — now also CapabilityGatedAction.
- New component specs only where genuinely required (e.g. Contractor Safety Passport card, Permit QR/signature capture, Document acknowledgement row, Medical assessment form) — inheriting card radius system, colour tokens, tabular numerals.
- Health dashboards show **aggregated** compliance metrics only (no medical detail) per the confidential tier.
- Empty/loading/error/offline states reusing the MVP 1 shimmer skeletons and custom line-art convention.

Create mobile-first layouts (390×844). Do not generate Flutter code. Do not introduce new colours, motifs, or an AI/experimental style.

**Self-check:** For each new component, cite the MVP 1 token/motif it inherits; flag any net-new component and justify why an existing one could not be reused.

---

#### Prompt 4 — Licensing, Seats & Entitlements

Act as a Principal Backend Architect.
Deliver the licensing capability MVP 1 deferred to MVP 2 (Ledger §5a; the invite gate was pre-built to accept a seat check without rework). Build this early so downstream modules can gate on entitlements.

**Generate:**
- Schema: `company_subscriptions` / `entitlements` (plan tier, `seat_limit`, `active_seats`, per-module entitlement flags, billing status) — `company_id`-scoped, RLS-enabled, 0021-audited.
- **Seat enforcement at the existing invite gate:** block activation when `active_seats >= seat_limit`, implemented inside `assertSeatAvailable(companyId)` in the MVP 1 user-admin Edge Function (Ledger §24.3) — it already runs **before** `inviteUserByEmail`; keep it there, so a refusal sends no email and creates no auth user. Do NOT restructure the user model.
- **Decide and record (Addendum M2-3b):** seat consumed at invite (`invited` + `active`) or at activation. Activation happens in the `0020` database trigger, not in user-admin, so an activation-time limit needs its own enforcement point.
- **Module entitlement gating:** a company sees/uses only the MVP 2 modules it is entitled to; enforce at RLS/Edge Function, mirror as a client affordance (UX only). Wire the More-tab destinations (Prompt 3) to entitlement flags.
- `licensing.manage` capability (Prompt 0) governs who edits entitlements (Administrator-only in MVP 1 terms).
- All billing/seat/entitlement mutations run via Edge Function under the service role, never the client.

**Business Rules:** No payment-collection logic required in MVP 2 unless separately scoped — but ship the seat-limit + entitlement **enforcement scaffolding** regardless. If billing is deferred further, record it explicitly.

**Self-check:** Walk through inviting the (seat_limit + 1)th user (blocked) and a user in a company not entitled to a module (module hidden + RLS-denied). Confirm no MVP 1 provisioning path changed shape.

**Definition of Done:** Seat and module-entitlement enforcement demonstrably gate at both RLS and UI, audited, with the MVP 1 invite flow otherwise unchanged.

---

#### Prompt 5 — Document Management (Shared Service — build before its consumers)

Implement the Document Management module. This is a cross-cutting repository consumed by Permits, Training, Compliance, Health, and MVP 1 entities — build it now so those modules integrate against it directly (mirrors the MVP 1 Attachment service ordering).

**Generate:**
- Entities, DTOs, Repositories, Use Cases, Providers, Screens for documents · document_versions · document_reviews · document_acknowledgements · document_attachments.
- Document types (Policies, Procedures, SOPs, Risk Assessments, SDS, Emergency Plans, Training Material); status flow Draft → Under Review → Approved → Published → Archived.
- Version control reusing the MVP 1 attachment_versions pattern; approval workflow; read-acknowledgement tracking; review-date scheduling; search.
- Linkage engine: documents linkable to Hazards, Risk Assessments, Investigations, CAPAs, Inspections, Permits, Training Records, Compliance Requirements (typed FKs).
- Gated by `document.control` capability for control actions; read by entitled company users.
- `document.review_due` / `document.acknowledgement_required` notification triggers (event-driven via notify-fanout; review-due via notify-sweep — see Prompt 13).
- Offline read cache respecting LocalOwner; Unit + Widget tests.

**Self-check:** Show a document moving through its full status flow with an acknowledgement recorded and a version superseded (not deleted); confirm the 0021 audit trigger fires on a **status-less** update path without error.

Do not redesign existing modules.

---

#### Prompt 6 — Occupational Health Surveillance (Confidential Tier)

Implement the Occupational Health Surveillance module. This is the most privacy-sensitive module — it exercises the confidential medical tier (Prompt 0/2B) end to end.

**Generate:**
- Entities, DTOs, Repositories, Use Cases, Providers, Screens for occupational_exposures · medical_programs · medical_assessments · health_actions · medical_documents.
- Exposure categories (Noise, Dust, Chemical, Radiation, Biological, Heat Stress, Ergonomics, Vibration); medical programs (Audiometry, Spirometry, Vision, Medical Exam, Biological Monitoring, Fitness For Work).
- Workflow: Hazard Exposure → Medical Scheduled → Assessment Completed → Results Captured → Intervention → Follow-up → Closure; medical_assessment_status enum.
- Health Dashboard (aggregated, non-identifying only), Exposure Register, Medical Scheduling, Medical Assessment Forms, Exposure Trends, Employee Health Profile.
- Linkage to MVP 1 Hazards and Risk Assessments (typed FKs).
- Medical detail readable only via `health.read_medical`; medical_documents stored via the shared Attachment service under a confidential storage path.
- `medical.assessment_scheduled` / `medical.follow_up_due` triggers (follow-up via notify-sweep, Prompt 13).
- Offline support (LocalOwner-aware); Unit + Widget tests.

**Business Rules:** POPIA data minimisation; no medical result on any general dashboard; follow-up recipients resolved to `health.read_medical` holders only.

**Self-check (mandatory):** Demonstrate a rank-5 Administrator **without** `health.read_medical` being denied a medical result at the RLS layer, while a rank-2 practitioner **with** it succeeds — the requirement a rank ladder cannot express.

**Definition of Done:** A practitioner schedules → completes → captures → follows up → closes a medical assessment, audited throughout, with medical detail invisible to non-capability holders on device and on dashboards.

---

#### Prompt 7 — Contractor Management

Implement the Contractor Management module (build before Training and Permit-to-Work, which reference contractors).

**Generate:**
- Entities/DTOs/Repos/Use Cases/Providers/Screens for contractors · contractor_employees · contractor_insurance · contractor_documents.
- Track companies, employees, insurance, inductions, training, permits, incidents.
- Contractor Profile, Contractor Safety Passport, Contractor Compliance Dashboard (KPIs: Active Contractors, Non-Compliant Contractors, Contractor Incidents, Outstanding Contractor CAPAs).
- Linkage: contractor incidents → MVP 1 Incident Management; contractor CAPAs → MVP 1 CAPA (typed FKs).
- Gated by `contractor.manage`; documents via Document Management (Prompt 5); Offline + tests.

**Self-check:** Show a contractor incident generating an MVP 1 incident and an outstanding CAPA surfacing on the contractor dashboard.

Do not redesign existing modules.

---

#### Prompt 8 — Training & Competency Management

Implement the Training & Competency module.

**Generate:**
- Entities/DTOs/Repos/Use Cases/Providers/Screens for training_courses · training_records · certifications · competency_matrix · training_certificates.
- Categories (Safety Induction, First Aid, Fire Fighting, Working At Heights, Confined Space, Hazardous Chemicals, Forklift); track assignment, attendance, certification, expiry, competency status; training_status enum.
- Compliance Dashboard, Employee Training Matrix, expiry handling.
- Workflow: Assign Course → Attend → Certificate Issued → Compliance Tracking → Renewal.
- Linkage to Users, Departments, Contractors (Prompt 7), Compliance (Prompt 9).
- Gated by `training.manage`; certificates via Attachment/Document services.
- `training.expiring` / `training.expired` / `certification.expiring` triggers via **notify-sweep** (Prompt 13).
- Offline + tests.

**Self-check:** Show a certification approaching expiry producing exactly one `training.expiring` notification per entity per day (idempotent sweep).

Do not redesign existing modules.

---

#### Prompt 9 — Compliance Management

Implement the Compliance Management module.

**Generate:**
- Entities/DTOs/Repos/Use Cases/Providers/Screens for compliance_requirements · compliance_reviews · compliance_evidence.
- Track OHS/Environmental legislation, ISO 45001 clauses, internal standards, client requirements; fields Requirement/Owner/Review Date/Evidence/Status; compliance_status enum.
- Workflow: Requirement → Assessment → Evidence Upload → Compliance Status → Review Cycle; compliance scorecards.
- **Compliance gaps must be able to generate MVP 1 CAPAs** (typed FK, exactly-one-origin extended).
- Gated by `compliance.manage`; evidence via Attachment/Document services.
- `compliance.review_due` trigger via notify-sweep (Prompt 13).
- Offline + tests.

**Self-check:** Show a non-compliant requirement generating a CAPA that closes through the MVP 1 CAPA workflow, traceable both ways.

Do not redesign existing modules.

---

#### Prompt 10 — Permit-to-Work

Implement the Permit-to-Work module.

**Generate:**
- Entities/DTOs/Repos/Use Cases/Providers/Screens for permits · permit_approvals · permit_closeouts · permit_attachments.
- Permit types (Hot Work, Confined Space, Working At Heights, Excavation, Electrical Isolation, LOTO); permit_status enum (Requested → Under Review → Approved → Active → Expired → Closed → Rejected).
- Workflow: Request → Risk Review → Approval → Execution → Closeout; QR codes, digital signatures, expiry monitoring.
- Approval gated by `permit.approve`; permits link to Contractors (Prompt 7).
- **Permit violations must generate MVP 1 Hazards or CAPAs** (typed FK).
- `permit.approval_required` (event-driven, notify-fanout) and `permit.expiring` / `permit.expired` (notify-sweep, Prompt 13).
- Offline capture; signatures/attachments via Attachment service; tests.

**Self-check:** Show the approval gate denying a user without `permit.approve`, and a permit violation generating a hazard.

Do not redesign existing modules.

---

#### Prompt 11 — Safety Committee Management

Implement the Safety Committee module.

**Generate:**
- Entities/DTOs/Repos/Use Cases/Providers/Screens for committee_meetings · committee_actions.
- Meeting scheduling, attendance, action tracking, minutes management, committee dashboard; agendas/minutes/action registers.
- **Committee actions must be able to create MVP 1 CAPAs, be traceable to closure, and appear on committee performance dashboards** (typed FK).
- Minutes gated by `committee.manage_minutes`.
- `committee.meeting_scheduled` (event-driven) / `committee.action_due` (notify-sweep, Prompt 13).
- Offline + tests.

**Self-check:** Show a committee action creating a CAPA and its closure reflected on the committee dashboard.

Do not redesign existing modules.

---

#### Prompt 12 — Advanced Analytics (Descriptive Only)

Implement the Advanced Analytics module. **Scope boundary (locked):** MVP 2 is **descriptive** only — historical trends, aggregations, KPI scorecards, heatmaps, rankings, drilldowns over MVP 1 + MVP 2 data. **No ML, prediction, or natural-language querying** (that is MVP 3, which will consume — not re-implement — these views).

**Generate:**
- Supabase/PostgreSQL analytics **views** as a stable contract for MVP 3: hazard/incident/health-exposure/training/contractor/compliance trends, CAPA closure rate.
- Dashboard data models, aggregation queries, providers, screens reusing MVP 1 chart components (Risk Compass, MiniBarChart, KPI tiles).
- Filters: site, department, date; KPI drilldowns to source records; executive scorecards; leading vs lagging indicator dashboards.
- **Per-role/entitlement scoping via RLS** (same as MVP 1 dashboards); health analytics aggregated/non-identifying only (confidential tier).
- Offline snapshot cache (LocalOwner-aware).

**Self-check:** Confirm every analytics view respects `company_id` isolation and the confidential medical tier; confirm the views are documented as an MVP 3-consumable contract.

Do not redesign existing modules. Do not add predictive features.

---

#### Prompt 13 — Notifications Extension (governed)

Implement the MVP 2 notification triggers, consolidating the hooks stubbed in Prompts 5–11. The `notification_trigger` enum is a **locked, governed list** — each new value is added via migration and recorded in the Ledger (as `capa.verification_due` was, §18). Do not add values ad hoc.

**Generate:**
- Enum + migration for: training.expiring · training.expired · certification.expiring · permit.expiring · permit.expired · permit.approval_required · medical.assessment_scheduled · medical.follow_up_due · compliance.review_due · document.review_due · document.acknowledgement_required · committee.meeting_scheduled · committee.action_due.
- **Routing:** event-driven triggers (permit.approval_required, document.acknowledgement_required, committee.meeting_scheduled, medical.assessment_scheduled) fire immediately via `notify-fanout`. **All time-based *expiring/expired/due* triggers** are raised by the `notify-sweep` cron (Ledger §13) — never from the app — reusing its once-per-entity-per-day idempotency and owner-only recipient rule.
- Recipient resolution respects RBAC **and** the capability tier (medical.* → `health.read_medical` holders only). Actor always filtered out (§16). Deep links to the new module records.
- Extend `notify-sweep` to sweep the new time-based conditions; add its new triggers to the CI deploy list.

**Self-check:** For each trigger, state event-driven vs swept, its recipient set, and (for medical) that non-capability holders are excluded. Confirm idempotency holds for a swept trigger.

---

#### Prompt 14 — Testing

Act as a Principal QA Engineer.
Generate the complete MVP 2 test strategy, extending the MVP 1 suite (do not replace it).

**Generate:**
- Unit/Widget/Integration/Repository test strategy for all 8 modules + licensing + access model.
- **Capability matrix test** (Dart): every functional role × capability × action — the MVP 2 analogue of the MVP 1 RBAC matrix test.
- **pgTAP RLS tests** proving: `company_id` isolation on every new table, the confidential medical tier (higher rank without capability denied), and no MVP 1 policy regressed. Extend the MVP 1 pgTAP suite the same way.
- Entitlement tests (seat gate, module gating). Offline/LocalOwner cross-tenant-switch tests for new cached entities. Notification idempotency tests for swept triggers.
- Accessibility (WCAG 2.1 AA) and performance tests against the MVP 1 targets.

**Self-check:** Confirm coverage of the two hardest cases — the medical confidential tier and cross-tenant cache isolation — with a named test for each.

---

#### Prompt 15 — Deployment & Migration

Act as a Principal DevOps Engineer.
Generate the MVP 2 deployment/migration strategy, extending the MVP 1 CI/CD (do not replace it).

**Generate:**
- Forward-only migration ordering appended after MVP 1's (no drop/rename); `supabase db push` compatibility (respect the §13 migration-tracking discipline — never bootstrap via a combined file on uat/prod).
- CI updates: add MVP 2 pgTAP + capability-matrix tests; add `notify-sweep` new triggers and any new Edge Functions to the deploy list.
- Feature-flag / entitlement rollout so companies enable MVP 2 modules per their subscription.
- Backfill/data-migration notes for existing tenants (default entitlements, capability grants for existing admins).
- Release checklist, rollback (roll-forward) strategy, go-live plan.

**Self-check:** Confirm a tagged release applies only the new migrations, deploys the new/updated functions, and that existing MVP 1 tenants are unaffected until entitled.

---

### Decisions Ledger — MVP 2 Addendum (fill in as each prompt is approved)

Append to the existing ledger; do not edit MVP 1 sections. Carry **MVP2.md + MVP1_2.md + this Ledger** into each prompt.

##### M2-1. Access Model (Prompt 0)
- **Capability table + grant table:** `capabilities`, `role_capabilities` (company-scoped) — ___
- **Helper:** `app.has_capability(cap)` — ___
- **Capability list:** health.read_medical · health.manage · training.manage · compliance.manage · contractor.manage · permit.approve · committee.manage_minutes · document.control · licensing.manage — *(additions)* ___
- **Confidential tier tables:** medical_assessments · medical_documents · health_actions — *(deviations)* ___
- **Proof MVP 1 rank policies unchanged:** ___

##### M2-2. Schema & Tenancy (Prompts 2A/2B)
- **New table list (28+):** *(confirm each carries `company_id` + RLS + 0021 audit trigger)* ___
- **New status enums:** training_status · compliance_status · permit_status · document_status · medical_assessment_status — ___
- **New Storage paths (tenant-isolated):** medical_documents · permit_attachments · contractor_documents — ___

##### M2-3. Licensing (Prompt 4)
- **Entitlement model:** plan tier · seat_limit · active_seats · per-module flags · billing status — ___
- **Seat gate insertion point:** MVP 1 user-admin Edge Function — ___
- **Billing deferred?** (explicit yes/no + scope) — ___

##### M2-4. Cross-cutting Contracts
- **Document service API surface (Prompt 5):** ___
- **New notification triggers + routing (event vs swept) (Prompt 13):** ___
- **Analytics view contract for MVP 3 (Prompt 12):** ___
- **Analytics scope:** MVP 2 = descriptive only; predictive = MVP 3.

##### M2-5. Offline & Tenancy
- **New LocalOwner-aware cached entities:** ___
- **Conflict rule for new offline-writable entities (LWW vs field-merge):** ___

##### M2-6. Open Questions / Deviations
- **M2-OQ1:** POPIA — `user_profiles` is company-wide readable (Ledger §22.2); confirm whether new modules narrow personal-data visibility. ___
- **M2-OQ2:** Escalation threshold for swept expiry triggers (owner-only vs escalate to SO after N days). ___
- **M2-DEV1:** ___

**Governance note:** MVP 1 locked domain values (§2 of the ledger) are inherited unchanged. New MVP 2 domain values (capabilities, new status enums, new triggers) are owned here — if one must change, change it here and re-derive; never let MVP2.md and the Ledger diverge.
