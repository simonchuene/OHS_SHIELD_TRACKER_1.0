## OHS Shield Tracker — MVP 3 Follow-Up Prompts

Use these prompts sequentially, in one continuous conversation where possible. Each prompt assumes the outputs of all prior prompts have been **reviewed and approved by a human** and are available as context. Approval is an explicit step, not automatic — unread outputs compound errors across the sequence. If starting a fresh conversation mid-sequence, paste **MVP3.md + MVP2.md + MVP1_2.md (Master Prompt) + the Decisions Ledger** alongside the prompt rather than every full prior output.

MVP 3 is an **intelligence layer** on top of a live, device-tested MVP 1 and an MVP 2 that added the enterprise OHS modules, the capability access layer (`app.has_capability`), the confidential medical tier (`health.read_medical`), licensing/entitlements, and a stable set of descriptive analytics views. MVP 3 **consumes and enriches** all of that. It is **NOT a new platform** and must not redesign or re-implement anything below it.

### Global Conventions (apply to every prompt below)

- **Extend, never redesign.** Never restate or alter locked MVP 1 domain values (colours, typography, risk bands, status flows, rank ladder, incident severity, signature design system Items 1–9) or the MVP 2 capability model. Reference them. AI must feel like a native extension — **no purple AI themes, neon, consumer chatbot styling, or experimental UI**; use Information Blue (#1565C0) with the existing cards, typography, buttons, and navigation (MVP 1 AI Design Rules). New AI destinations live under the existing **More** / navigation framework.
- **Decisions Ledger over full outputs.** After each prompt is approved, update the Decisions Ledger MVP 3 addendum (vector store partitioning, model registry entries, canonical score contract, new tables, new notification triggers, persona configs, audit-import policy). Carry **MVP3.md + MVP2.md + MVP1_2.md + the Ledger** into later prompts instead of pasting all prior outputs.
- **Output emission.** Emit code as **one file per block, each prefixed with `// path: lib/...`** (or `-- path: supabase/migrations/...`, `# path: services/ml/...` for non-Flutter artefacts) mapping to the established structure. Never merge files or omit paths.
- **Self-verification.** Where a prompt has a checkable constraint (tenant isolation, capability/medical tier, canonical-score reconciliation, advisory-only governance, retrieval scoping, file-format policy), end the output with a short **self-check table** proving it holds — do not assert compliance in prose.
- **"Production-ready" = review-ready first implementation.** A strong, convention-following starting point that still needs human compilation, integration testing, security review, model validation, and real asset/secret wiring before shipping — not a deployable binary.
- **Tenancy is non-negotiable — and the AI layer is where it most easily breaks.** Every new tenant-scoped table carries `company_id` with RLS `company_id = app.current_company_id()`. The vector/embedding index is **tenant-partitioned** — RAG must never retrieve another tenant's data even transiently. Every locally-cached AI artefact respects the LocalOwner wipe-on-user-switch rule (Ledger §23). Attach the **0021-fixed** audit trigger to every new table (many are status-less — Ledger §23.2). RLS is necessary but not sufficient; the cache and the vector store are part of the trust boundary.
- **AI is advisory only.** No AI feature may auto-close hazards, approve permits, close CAPAs, or make compliance decisions. Every prediction/recommendation/summary carries confidence, contributing factors, supporting evidence/citations, and traceability, and every AI interaction is written to `audit_logs`. Humans remain responsible.
- **Consume, do not re-implement.** MVP 3 builds on the MVP 2 descriptive analytics views and the MVP 1 SafetyScore heuristic and Reporting pipeline. If an aggregate is missing, extend the MVP 2 view layer rather than computing a private duplicate — one number, one definition across phases.
- **A feature is done when its effect is observed** — on a device that did not originate the data, and under a role/capability that must **not** see confidential data as well as one that must. This is the MVP 1 build's hard-won lesson (Ledger §10–§23).

---

#### Prompt 0 — Unified AI Foundation & Tenant-Partitioned Vector Store (BLOCKS ALL AI MODULES)

Act as a Principal AI Solutions Architect and Security Architect.
This prompt MUST be completed and approved before any AI feature module is built. Every conversational assistant, prediction, insight, retrieval, and summarization depends on it.

**Context.** MVP 3 names four conversational assistants (Safety Copilot, Knowledge Assistant, Mobile Safety Assistant, Executive Copilot). Per MVP3.md these are **one engine with pluggable personas**, not four builds. The single biggest AI-specific risk is cross-tenant retrieval leakage through a shared vector index (Ledger §23 / D-tenant-1 applied to embeddings).

**Generate:**
- The **Unified Conversational AI Framework** core (built once, reused by all personas AND by the Module 11 audit summarizer): RAG pipeline, prompt orchestration, agent framework, conversation memory, citation framework, and AI security controls (prompt-injection defence, agent access controls, hallucination mitigation, audit logging of AI interactions).
- A **persona abstraction**: a persona selects system prompt, tone, prompt library, default scope, and the exposed tool/data surface — but can only ever NARROW, never widen, a user's authorized data access. Define the persona config contract that Prompts 3, 9, 10 will fill in.
- **Tenant-partitioned vector store**: schema/collection design where every embedding row carries `company_id` and retrieval is physically scoped per tenant (partition/namespace per company, or a mandatory `company_id` predicate enforced server-side) — never a shared index filtered after retrieval. Include the embedding pipeline (MVP 1 + MVP 2 data → ETL → chunk → embed → index) and re-embedding/backfill strategy.
- **Retrieval-time authorization**: a retrieval may only return chunks the caller can read directly — respecting `company_id`, RBAC/rank, the MVP 2 capability layer, and the **confidential medical tier** (`health.read_medical`). Medical chunks must be excluded from retrieval for non-holders, not filtered out of the final answer.
- **AI audit + governance scaffolding**: every prompt, retrieval set, model/version, and response logged to `audit_logs` (0021-fixed trigger on all new tables); advisory-only guardrails that structurally prevent an agent from invoking a state-changing action (close/approve/verify).
- Migrations for new tables (`company_id`-scoped, RLS-enabled, 0021 audit trigger), `-- path: supabase/migrations/...`; ML/service scaffolding under `# path: services/ai/...`.

**Self-check (mandatory):** Prove (a) a retrieval for company A can never return company B's chunk (partition-level, not filter-level); (b) a user without `health.read_medical` cannot retrieve a medical chunk under ANY persona; (c) no persona widens access beyond the user's direct RLS grants; (d) the agent framework has no tool that can close/approve/verify an entity.

**Definition of Done:** One shared engine stands up; a persona can be instantiated; tenant isolation and the medical tier hold at retrieval time; every interaction is audited; and `flutter analyze` + MVP 1/2 pgTAP still pass.

---

#### Prompt 1 — MVP 3 Architecture

Act as a Principal Enterprise Architect.
Using MVP3.md as the source of truth and the approved AI foundation (Prompt 0), design the complete MVP 3 architecture as an **intelligence layer** over MVP 1 + MVP 2.

**Generate:**
- Updated domain model and the data-flow: MVP 1 Data → MVP 2 Data → ETL → Embedding Pipeline → Vector DB → Knowledge Hub → Copilot → Executive Decision Support.
- Module map for the 11 MVP 3 modules and how each **enriches an existing workflow** (Hazard classification, predictive risk scoring, similar-incident matching, CAPA prioritisation, exposure forecasting, compliance-gap prediction, semantic document search, external-audit import → summary → report, etc.).
- **Analytics dependency**: which MVP 2 descriptive views each MVP 3 module consumes; where the MVP 2 view layer must be extended rather than duplicated.
- Navigation additions under **More** (AI Copilot, Risk Intelligence, Knowledge Hub, Automation, Digital Twin, Audit Import), entitlement-gated via MVP 2 licensing.
- Security architecture delta for AI: retrieval authorization, the medical tier, advisory-only enforcement, and file-ingestion security (Module 11).
- Updated ERD (new AI/IoT/knowledge/audit-import tables + FKs into MVP 1/2 — never destructive).

Document all architectural decisions. No application code.

**Self-check:** Confirm no MVP 1/2 table or view is dropped/renamed; confirm every new table carries `company_id`; list each MVP 3 module against the MVP 2 view(s) or MVP 1 pipeline it consumes (proving no re-implementation).

---

#### Prompt 2 — Canonical Enterprise Score (shared contract — build before its consumers)

Act as a Principal Data Scientist and Backend Architect.
Deliver the single canonical Enterprise Score that Executive Risk Intelligence (Module 6), Executive Decision Support (Module 10), the Copilot, and board reports all read. There must be exactly ONE score, computed once — Module 10's "Executive Health Score" is a presentation view of this value, never a second calculation (MVP3.md CANONICAL SCORE CONTRACT).

**Generate:**
- One scoring service/Edge Function: a single documented, weighted formula over Open High-Risk Hazards, Incident Frequency, CAPA Overdue Rate, Compliance Gaps, Health Exposure Trends, Training/Contractor Non-Compliance, Permit Risk Events, Repeated Root Causes, and Predictive Risk Forecasts (Module 2, once it exists — until then, a documented placeholder weight).
- It builds on the MVP 1 SafetyScore heuristic and the MVP 2 analytics views; it is the ONLY place raw signals are composited.
- Persistence: one score row per company/site/period (`company_id`-scoped, RLS, 0021 audit), versioned like an MLOps artefact so the formula version is recorded with each value.
- Read API + providers so every consumer reads the same persisted value; a "health/safety" framing (e.g. 100 − risk) is a LABEL over the same number.

- **Retire the MVP 1 client-side SafetyScore as a computation** (Addendum M3-2e). It lives in Dart (`safety_score.dart`), and higher means *safer* — the opposite direction to the Enterprise Risk Score. Re-point the MVP 1 dashboard card at the canonical value (health framing, 100 − risk); the Dart formula's terms become inputs to the canonical formula, not a parallel score.

**Self-check (mandatory):** Show Module 6's Enterprise Risk Score, Module 10's Executive Health Score **and the MVP 1 dashboard Safety Score card** all rendering from the SAME persisted row and reconciling exactly; confirm no second computation path exists — including that `SafetyScore.compute` is no longer called to produce a displayed score.

**Definition of Done:** Three screens, one number — a board member comparing any of them can never see divergent scores; the formula version is auditable.

---

#### Prompt 3 — AI Safety Copilot (Persona 1)

Configure the **Safety Copilot persona** over the Prompt 0 framework — not a standalone engine.

**Generate:**
- Persona config: system prompt, operational-safety prompt library, default scope, tool/data surface.
- Shared chat UI surface (reused by all personas), Suggested Prompts, Entity Search, Report Generation.
- Grounding on MVP 1/2 data via the tenant-partitioned RAG; mandatory citations to source records; conversation memory; advisory-only (may draft a report or suggest an action, may never execute a state change).
- Entitlement-gated (MVP 2 licensing); RBAC/RLS/capability/medical tier inherited from Prompt 0.
- Riverpod providers, screens, Unit + Widget tests.

**Self-check:** Show the Copilot answering a cross-module question with citations, and refusing/omitting medical detail for a user without `health.read_medical`; confirm it cannot invoke a close/approve/verify tool.

Do not build a second chat engine. Do not redesign existing modules.

---

#### Prompt 4 — Predictive Risk Engine + MLOps

Act as a Principal Data Scientist / ML Engineer.
Implement the Predictive Risk Engine and the MLOps backbone it (and the canonical score) depend on.

**Generate:**
- Feature store, training pipelines, model registry, model versioning, model + prediction monitoring, drift detection, rollback strategy.
- Models/outputs: Future Incident Probability, High-Risk Areas, Exposure Predictions, Compliance-Failure Predictions, Safety-Culture Risk Score.
- Inputs consumed from MVP 2 views + MVP 1 data (not re-aggregated); predictions persisted `company_id`-scoped, RLS, audited.
- Predictions API + Risk Forecast Dashboards + Trend Analysis, reusing MVP 1 chart components.
- **Explainable AI**: every prediction carries confidence, key contributing factors, supporting data sources, recommended actions.
- Predictive forecasts feed the canonical Enterprise Score (Prompt 2) — wire the dependency.

**Self-check:** Show a prediction with its explanation payload; confirm predictions are tenant-isolated and never trained/served across companies; confirm medical features honour the confidential tier.

Do not redesign existing modules.

---

#### Prompt 5 — Safety Intelligence Hub

Implement the Safety Intelligence Hub (descriptive-to-connected insight over MVP 1/2/3 data — it CONSUMES MVP 2 views and MVP 3 predictions).

**Generate:**
- Unified Safety Intelligence Dashboard, cross-module analytics, root-cause analytics, site/department comparison, hazard hotspot detection, CAPA effectiveness, risk/compliance/health/training trend analysis.
- Insight cards (title, summary, risk level, affected site/department, supporting evidence, recommended action, confidence, source modules).
- KPI framework (Enterprise Risk Index, Site/Department Risk Index, CAPA Effectiveness, Incident Recurrence, etc.).
- Filtering + drilldown to source records; integration hooks to Copilot / Predictive Engine.
- Health analytics **aggregated / non-identifying only** (confidential tier); tenant-isolated; offline snapshot cache (LocalOwner-aware).

**Self-check:** Confirm every hub query respects `company_id` and the medical tier; confirm insight cards trace to real source records (no fabricated evidence).

Do not re-implement MVP 2 aggregations. Do not redesign existing modules.

---

#### Prompt 6 — Safety Automation Engine

Implement the Safety Automation Engine — advisory/operational automation that never makes a prohibited decision.

**Generate:**
- Workflow builder, trigger engine, condition engine, action engine, audit trail.
- Templates: High-Risk Hazard, Permit Escalation, CAPA Escalation, Compliance Escalation, Health-Surveillance Follow-Up.
- Actions are limited to permitted operations (create a follow-up, notify, escalate, schedule); the engine MUST NOT close hazards, approve permits, verify/close CAPAs, or make compliance decisions (advisory-only guardrail from Prompt 0).
- Reuse notify-fanout / notify-sweep for any notifications; every automation event audited; `company_id`-scoped, capability-aware.

**Self-check:** Enumerate every action the engine can emit and prove none is a prohibited state change; show one template firing end-to-end with an audit trail.

Do not redesign existing modules.

---

#### Prompt 7 — IoT & Smart Device Integration

Implement IoT & Smart Device Integration.

**Generate:**
- Device registry, health monitoring, firmware tracking, device ownership; sensor data pipelines; realtime monitoring dashboard; alert engine.
- Protocols: MQTT, REST, OPC-UA, Modbus, Azure IoT Hub, AWS IoT Core (ingestion adapters).
- Sensor readings and devices `company_id`-scoped, RLS, audited (0021 trigger — sensor readings are status-less); high-volume streams partitioned per tenant.
- **Notification governance**: threshold/leak/offline alerts extend the LOCKED `notification_trigger` enum via migration (recorded in the Ledger, as §18); event-driven → notify-fanout, time-based (calibration/firmware due) → notify-sweep with idempotency; actor filtered out; recipients respect RBAC/capability.
- Example rules (advisory): Noise Threshold Exceeded → create Hazard; Gas Leak Detected → Critical Alert (create, notify — never auto-approve/close).

**Self-check:** Show a device alert creating a hazard + notification via existing infrastructure; confirm no parallel alerting system and no cross-tenant sensor read.

Do not redesign existing modules.

---

#### Prompt 8 — Executive Risk Intelligence (Persona-integrated)

Implement Executive Risk Intelligence, reading the canonical Enterprise Score (Prompt 2) and MVP 2/3 analytics.

**Generate:**
- Executive risk dashboard (large KPI cards, heatmaps, trend charts, priority alerts, drilldown) — mobile-first, executive-friendly, MVP 1 signature components.
- Risk ranking (sites/departments/contractors/permit types/hazard & incident categories/compliance areas), emerging-risk detection, executive alerts (Critical/High/Medium/Low), board-level reporting, executive drilldown to source records.
- Executive Copilot questions ("Why did enterprise risk increase this month?") answered via the **Executive Copilot persona** over the shared framework (see Prompt 10) — do not build a separate assistant here.
- Governance: explainable, evidence-based, role-based, auditable, traceable; advisory-only.

**Self-check:** Confirm every figure (esp. the Enterprise Score) is read from the canonical service, not recomputed; confirm drilldowns respect RLS + the medical tier.

Do not redesign existing modules.

---

#### Prompt 9 — Enterprise Knowledge Management + Knowledge Assistant (Persona 2)

Implement Enterprise Knowledge Management (Module 7) and configure the Knowledge Assistant persona over the shared framework. (The Mobile Safety Assistant persona is built in Prompt 10, alongside its host Module 9 — Advanced Workforce Safety Experience.)

**Generate:**
- Knowledge hub/repository/library, lessons-learned engine, best-practice/safety-alert registers, incident/compliance/health knowledge bases.
- Knowledge graph (Hazards → Incidents → Investigations → Root Causes → CAPAs → Controls → Outcomes → Lessons → Training) with similar-event detection, cause mapping, control-effectiveness analysis; nodes/edges `company_id`-scoped.
- Knowledge recommendation engine + control-effectiveness engine (confidence, evidence, historical success rate).
- Knowledge governance (ownership, lifecycle Draft→Review→Approve→Publish→Review→Archive, version control, audit) — reuse MVP 2 Document Management patterns.
- **Knowledge Assistant persona** (mandatory citations to Incidents/Hazards/CAPAs/Investigations/Documents/Compliance) — configured over Prompt 0's engine, enforcing RBAC/RLS/capability/medical tier and returning only authorized-to-read grounding.

**Self-check:** Show the Knowledge Assistant returning cited answers; prove it does not surface medical detail to a non-holder; confirm it reuses the shared engine (no new chat build).

Do not redesign existing modules.

---

#### Prompt 10 — Digital Twin (Module 8), Workforce Safety Experience + Mobile Safety Assistant (Persona 3) (Module 9) & Executive Decision Support + Executive Copilot (Persona 4) (Module 10)

Implement the remaining conversational modules, including the final two personas. This prompt configures the last of the four personas, so it must end by proving all four share one engine.

**Generate:**
- **Digital Twin & Risk Mapping (Module 8)**: site maps with hazard/incident/permit/contractor/health-exposure/IoT layers, risk heatmaps, emergency route mapping, hazard density, historical playback; site/department filtering; tenant-isolated.
- **Advanced Workforce Safety Experience (Module 9)**: personalized safety home, safety observation program, participation score (non-punitive), professional recognition, microlearning, safety nudges. Privacy & ethics: no punitive scoring, no disciplinary/employment/performance judgments; workforce analytics aggregated for management only.
- **Mobile Safety Assistant persona (Persona 3)** — configured over Prompt 0's engine as part of this module (it is the frontline face of the Workforce Experience): lightweight frontline mode, task/how-to focus, restricted scope, simplified UI. Enforces RBAC/RLS/capability/medical tier; its narrower scope never widens what the user may see. Not a separate chat build.
- **Executive Decision Support (Module 10)**: **Executive Copilot persona (Persona 4)** over the shared framework (strategic prompt library, briefings, decision summaries — reading canonical figures), recommendation engine, scenario planning, safety-investment optimization, executive reporting.
- Decision-support governance: advisory-only (recommend/explain/forecast/prioritize; never approve/close/override/execute).

**Self-check:** Show the Mobile Safety Assistant answering a how-to within a restricted scope without surfacing medical detail to a non-holder; confirm the Executive Copilot is a persona (not a fourth engine) and reads the canonical score; confirm workforce scores cannot drive punitive actions; confirm all FOUR personas (Safety Copilot, Knowledge Assistant, Mobile Safety Assistant, Executive Copilot) now share one engine, memory, citation, and security core.

Do not redesign existing modules.

---

#### Prompt 11 — External Audit Import & Summarization (Module 11)

Act as a Principal Backend Architect, Data Engineer, and Flutter Engineer.
Implement Module 11 — the ONLY capability that consumes an EXTERNAL tabular data source (a spreadsheet audit produced outside the platform), ingests it, summarizes it with AI, and produces a report. Reuse the MVP 1 Reporting pipeline, MVP 2 Document Management / Compliance, and the Prompt 0 Unified AI Framework — do NOT introduce a second reporting engine or a second AI stack.

**File-format decision (build exactly this — see MVP3.md):**
- A SEPARATE, purpose-built ingestion channel for tabular audits. Do NOT reuse or widen the MVP 1 evidence-attachment allow-list (JPG/PNG/PDF stays as-is platform-wide).
- Accept **.xlsx and .csv only.** Explicitly reject **.xls** (legacy binary), **.xlsm** (macro-enabled — attack surface), Google Sheets links, and arbitrary binaries.
- Max import size **20 MB** + a **row cap** (e.g. 50,000); larger files rejected with a clear error.
- **Parse server-side only** (Edge Function / ingestion service) — never in the Flutter client.
- Retain the **original uploaded file immutably** on a tenant-isolated storage path (`foldername[1] = company_id`), distinct from evidence attachments; parsed data + summary are derived artefacts linked to it.
- **Neutralize formula / CSV injection** — values starting with `= + - @` are treated as text, never evaluated.

**Generate:**
- Schema: `audit_imports` · `audit_import_rows` · `audit_import_mappings` · `audit_import_summaries` (names indicative) — each with `company_id`, RLS (`company_id = app.current_company_id()`), and the **0021** audit trigger (imported rows are status-less, so the 0021 form is required — Ledger §23.2).
- Server-side ingestion service: format/size/row validation → parse → column mapping against import templates → row-level validation (surface bad rows for correction/exclusion, never silently drop) → commit as a versioned dataset (re-upload = new version, prior versions retained).
- Column-mapping UI + templates (finding / severity / area / owner / due date / status), mobile-first, inheriting the MVP 1 design system.
- **AI summarization** over the parsed, tenant-scoped rows via the Unified Framework (a summarization task, not a new engine): themes, top findings by severity, repeat/overdue findings, suggested CAPAs — each citing the specific imported row identifiers (shared citation framework; never fabricate a finding). Advisory only.
- **Report generation** via the MVP 1 Reporting module's PDF + CSV export and report history — include the summary, top findings, mapping used, data-quality note (imported/rejected counts), and provenance (source filename, uploader, import version, timestamp in the user's timezone per §13.2). Store the report via MVP 2 Document Management (versioning/approval/acknowledgement/review).
- Optional linkage: raise MVP 1 CAPAs / MVP 2 Compliance findings from audit items (typed FKs), following the existing workflows and RLS — the import cannot bypass those controls.

**RBAC & governance:**
- Gate import + summarization behind a new capability `audit.import` (granted to Compliance Officer / Safety Officer+ / Administrator per company policy) — reuse the MVP 2 capability layer (`app.has_capability`), record the new capability in the Ledger; do NOT invent a new access model.
- If an imported audit contains medical/occupational-health columns, the **confidential medical tier** (`health.read_medical`) applies to those columns and to any summary derived from them.
- Every import, mapping, commit, summary, and export written to `audit_logs`.

**Self-check (mandatory):** Prove (a) a `.xlsm` and a `.xls` are rejected while `.xlsx`/`.csv` are accepted; (b) a CSV cell `=cmd()` is stored/rendered as text, not evaluated; (c) an import in company A is invisible to company B (RLS); (d) parsing occurs server-side only; (e) a medical column in an import is hidden from a summary shown to a user without `health.read_medical`; (f) the report is produced by the MVP 1 Reporting pipeline, not a new exporter.

**Definition of Done:** An authorized user uploads an `.xlsx`/`.csv` external audit → maps columns → commits → receives an AI summary that cites real imported rows → generates a PDF/CSV report stored in Document Management → optionally raises CAPAs — all tenant-isolated, capability-gated, and audited, with unsafe formats and formula injection refused.

Do not redesign existing modules. Do not widen the evidence-attachment allow-list.

---

#### Prompt 12 — AI Governance, Security & Explainability (consolidation)

Act as a Principal AI Governance & Security Engineer.
Consolidate the cross-cutting AI controls stubbed across Prompts 0–11 into one coherent, verifiable framework.

**Generate:**
- AI Governance Framework: advisory-only enforcement, human-in-the-loop, explainability requirements, traceability, model-version accountability.
- AI Security Framework: prompt-injection/agent-access controls, data-access restrictions, hallucination mitigation, RAG security, sensitive-data protection, audit logging of all AI interactions, and **file-ingestion security** (Module 11: reject macro/binary spreadsheets, neutralize formula/CSV injection, server-side parse, size/row caps).
- Explainable-AI contract applied uniformly (confidence, contributing factors, sources, recommended actions).
- AI data privacy: PII/medical/confidential data honour RBAC + RLS + capability tier at retrieval AND generation; the medical tier binds every persona, prediction, and imported-audit summary.

**Self-check:** A matrix mapping each AI module/persona to the governance + security controls it enforces, proving no module bypasses the medical tier, tenant isolation, advisory-only limits, file-ingestion security, or audit logging.

---

#### Prompt 13 — Testing

Act as a Principal QA Engineer.
Generate the MVP 3 test strategy, extending the MVP 1/2 suites (do not replace them).

**Generate:**
- Unit/Widget/Integration/Repository strategy for all 11 modules + the AI foundation + canonical score.
- **AI-specific tests:** tenant-isolation of vector retrieval (company A never retrieves company B — partition-level), medical-tier exclusion at retrieval (non-holder gets no medical chunk under any persona), advisory-only (no agent tool can close/approve/verify), citation integrity (no fabricated sources), canonical-score reconciliation (Modules 6 & 10 identical).
- **Module 11 tests:** format allow/deny (.xlsx/.csv accepted; .xls/.xlsm/binary rejected), formula/CSV-injection neutralization, server-side-only parsing, import tenant isolation (RLS), medical-column suppression in summaries, report produced by the MVP 1 pipeline.
- pgTAP extensions for new AI/IoT/knowledge/audit-import tables (`company_id` isolation, no MVP 1/2 regression); LocalOwner cross-tenant-switch tests for cached AI artefacts and imports; notification idempotency for swept IoT triggers.
- Model evaluation/monitoring tests (drift detection, prediction quality); accessibility (WCAG 2.1 AA) and performance against MVP 1 targets.

**Self-check:** Name the test covering each of the hardest cases — vector tenant isolation, medical tier at retrieval, advisory-only guardrail, canonical-score reconciliation, and audit-import file-format + injection security.

---

#### Prompt 14 — Deployment, MLOps Rollout & Delivery Roadmap

Act as a Principal DevOps / MLOps Engineer.
Generate the MVP 3 deployment strategy and delivery roadmap, extending MVP 1/2 CI/CD.

**Generate:**
- Forward-only migrations appended after MVP 1/2 (no drop/rename); respect the §13 migration-tracking discipline.
- CI/CD updates: MVP 3 pgTAP + AI-isolation + canonical-score + audit-import-security tests; deploy new Edge Functions (incl. the audit-import ingestion service and the scoring service); add new notify-sweep IoT triggers to the deploy list.
- ML deployment: model registry/serving, versioned rollout, monitoring + drift alerts, rollback; vector-store provisioning per environment (tenant partitioning preserved across dev/uat/prod).
- Entitlement-gated feature rollout (companies enable MVP 3 modules per subscription, including `audit.import`); backfill/embedding strategy for existing tenants; go-live plan, rollback (roll-forward), release checklist.
- MVP 3 Delivery Roadmap / sprint plan across the 11 modules.

**Self-check:** Confirm a tagged release applies only new migrations, deploys the scoring + AI + ingestion services, preserves tenant partitioning, and leaves MVP 1/2 tenants unaffected until entitled.

---

### Decisions Ledger — MVP 3 Addendum (fill in as each prompt is approved)

Append to the existing ledger; do not edit MVP 1/2 sections. Carry **MVP3.md + MVP2.md + MVP1_2.md + this Ledger** into each prompt.

##### M3-1. Unified AI Foundation (Prompt 0)
- **Shared engine components:** RAG · prompt orchestration · agent framework · conversation memory · citation framework · AI security — ___
- **Persona contract:** (system prompt · prompt library · scope · tool/data surface; narrows-only) — ___
- **Vector store partitioning:** (namespace/partition per company_id; server-enforced predicate) — ___
- **Retrieval authorization:** company_id + rank + capability + medical tier at retrieval time — ___
- **Advisory-only guardrail:** (agent has no close/approve/verify tool) — ___

##### M3-2. Canonical Enterprise Score (Prompt 2)
- **Single scoring service + formula version:** ___
- **Persistence (one row per company/site/period):** ___
- **Module 10 = view of Module 6 (reconciliation proof):** ___

##### M3-3. Personas (Prompts 3, 9, 10)
- **Safety Copilot config (P3):** ___  · **Knowledge Assistant config (P9):** ___  · **Mobile Safety Assistant config (P10):** ___  · **Executive Copilot config (P10):** ___
- **Confirmation all four share one engine/memory/citation/security core:** ___

##### M3-4. Analytics Dependency
- **MVP 2 views consumed per module (proof of no re-implementation):** ___
- **MVP 2 views EXTENDED by MVP 3 (rather than duplicated):** ___

##### M3-5. New Tables & Tenancy
- **New AI/IoT/knowledge/audit-import tables (each carries company_id + RLS + 0021 audit):** ___
- **New LocalOwner-aware cached AI artefacts:** ___

##### M3-6. Notifications (Prompt 7)
- **New IoT/automation triggers + routing (event vs swept):** ___

##### M3-7. MLOps (Prompt 4)
- **Model registry/versioning/feature store/monitoring/drift/rollback decisions:** ___

##### M3-8. External Audit Import (Prompt 11)
- **New capability:** `audit.import` (grantees) — ___
- **File-format policy:** accept .xlsx/.csv; reject .xls/.xlsm/binary; 20 MB + row cap; server-side parse; formula-injection neutralized — ___
- **Import tables + storage path (tenant-isolated):** ___
- **Report path (reuses MVP 1 Reporting + MVP 2 Document Management):** ___

##### M3-9. Open Questions / Deviations
- **M3-OQ1:** Vector store technology (pgvector vs external) and how tenant partitioning is enforced in the chosen store. ___
- **M3-OQ2:** Conversation-memory retention/erasure under POPIA (memory is personal data). ___
- **M3-OQ3:** Retention policy for imported external-audit source files and derived summaries (POPIA). ___
- **M3-DEV1:** ___

**Governance note:** MVP 1/2 locked values are inherited unchanged. New MVP 3 values (persona configs, canonical-score contract, vector partitioning, new triggers, `audit.import` capability, file-format policy) are owned here — if one must change, change it here and re-derive; never let MVP3.md and the Ledger diverge.
