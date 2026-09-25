You are a Principal Enterprise Architect, AI Solutions Architect, OHS Industry Expert, Data Scientist, Staff Flutter Engineer, and Product Strategist.
You are building MVP 3 of an enterprise Occupational Health & Safety Performance Management Platform.
MVP 1 and MVP 2 are already deployed.
DO NOT redesign existing modules.
Extend the existing platform into an AI-powered Risk Intelligence and Operational Safety platform.
The solution should rival products such as:
- Enablon
- Intelex
- Cority
- VelocityEHS
- EcoOnline
- Dataminr Pulse
- ServiceNow Risk
- Microsoft Security Copilot (conceptually)

-------------------------------------------------
MVP 3 OBJECTIVE
-------------------------------------------------
Transform the application into an OHS Intelligence Platform capable of:
- Predicting risk
- Detecting trends
- Recommending actions
- Automating workflows
- Providing executive insights
- Acting as an AI Safety Copilot
The platform must become proactive rather than reactive.

-------------------------------------------------
MVP 3 DELIVERABLES
-------------------------------------------------
Generate:
1. MVP 3 Architecture
2. AI Architecture
3. RAG Architecture
4. Knowledge Graph Design
5. Vector Database Design
6. Updated ERD
7. Flutter Architecture Updates
8. AI Copilot Design
9. Predictive Risk Engine Design
10. Safety Intelligence Hub Design
11. Executive Risk Intelligence Design
12. Enterprise Knowledge Management Design
13. Digital Twin Design
14. Workforce Experience Design
15. Executive Decision Support Design
16. External Audit Import & Summarization Design
17. MLOps Strategy
18. AI Governance Framework
19. AI Security Framework
20. Deployment Strategy
21. MVP 3 Delivery Roadmap

-------------------------------------------------
NEW MVP 3 MODULES
-------------------------------------------------
1. AI Safety Copilot
2. Predictive Risk Engine
3. Safety Intelligence Hub
4. Safety Automation Engine
5. IoT & Smart Device Integration
6. Executive Risk Intelligence
7. Enterprise Knowledge Management
8. Digital Twin & Risk Mapping
9. Advanced Workforce Safety Experience
10. Executive Decision Support
11. External Audit Import & Summarization

-------------------------------------------------
DESIGN SYSTEM CONTINUITY
-------------------------------------------------
MVP 3 must inherit:
- APPLICATION THEME
- APPLICATION BRANDING
- Navigation
- Typography
- Colors
- Cards
- Forms
- Dashboards
- Accessibility Standards
- Mobile-First Design
Do not create an independent AI interface.
AI functionality must appear as a natural
extension of the existing application.
Copilot, Predictions, Recommendations,
and Executive Insights must use the same
design system established in MVP 1.

-------------------------------------------------
UNIFIED CONVERSATIONAL AI FRAMEWORK (ONE ASSISTANT, MANY PERSONAS)
-------------------------------------------------
MVP 3 names four conversational assistants — AI Safety
Copilot (Module 1), AI Knowledge Assistant (Module 7),
Mobile Safety Assistant (Module 9), and Executive Copilot
(Module 10). These are NOT four separate builds. Building
four chat engines would duplicate the RAG pipeline, prompt
orchestration, conversation memory, citation logic, and
security controls four times, and would drift apart — a
direct violation of "do not create an independent AI
interface".

Build ONE conversational AI framework with pluggable
PERSONAS / MODES:
- A single shared core: RAG pipeline, vector retrieval,
  prompt orchestration, agent framework, conversation
  memory, citation framework, and AI security controls
  (see AI ARCHITECTURE / AI SECURITY). Built once.
- PERSONAS select system prompt, tone, prompt library,
  default scope, and the tool/data surface exposed:
  * Safety Copilot (Module 1) — operational safety Q&A,
    reports, entity search.
  * Knowledge Assistant (Module 7) — lessons-learned /
    semantic retrieval with mandatory citations.
  * Mobile Safety Assistant (Module 9) — lightweight
    frontline persona, task/how-to focus, restricted scope.
  * Executive Copilot (Module 10) — strategic persona,
    executive prompt library, board-level summaries.
- Every persona enforces the SAME RBAC + Row Level Security
  + capability tier + data classification. A persona narrows
  what a user can ask/see; it never widens it. The medical
  confidential tier (MVP 2 health.read_medical) applies to
  ALL personas identically — no persona may surface medical
  detail to a user lacking the capability.
- Conversation memory, citations, and audit logging of AI
  interactions are implemented once and reused by every
  persona.
- The Module 11 audit-summarization capability reuses this
  same shared engine (it is a summarization task over an
  ingested document, not a new AI stack).

Each of Modules 1, 7, 9, 10 therefore specifies a PERSONA
configuration over this shared framework — not a new engine.

-------------------------------------------------
MVP 1 & MVP 2 INTEGRATION RULE
-------------------------------------------------
All MVP 3 capabilities must consume
existing MVP 1 and MVP 2 data.
Do not create isolated AI features.
AI outputs must enrich:
- Hazards
- Risk Assessments
- Investigations
- CAPAs
- Health Surveillance
- Compliance
- Training
- Contractors
- Permits
- Documents

-------------------------------------------------
TENANCY & DATA ISOLATION (NON-NEGOTIABLE — APPLIES TO EVERY NEW MVP 3 DATA STORE)
-------------------------------------------------
MVP 3 introduces many NEW data stores — vector/embedding
indexes, prediction tables, feature store, IoT sensor streams,
device registry, conversation memory, knowledge-graph nodes/
edges, automation logs, and imported external-audit datasets
(Module 11). Each is a fresh opportunity to reintroduce the
cross-company data leak documented in the Decisions Ledger
(§23 / D-tenant-1). Therefore:
- EVERY new tenant-scoped MVP 3 table carries company_id and
  has RLS enabled with company_id = app.current_company_id().
  No AI output, prediction, embedding, IoT reading, imported
  audit row, or conversation crosses a company boundary at any
  rank or capability, Administrator included.
- The VECTOR DATABASE / embedding index MUST be tenant-
  partitioned. A retrieval query may only return vectors for
  the caller's company_id. A shared, unpartitioned index that
  filters "after the fact" is prohibited — RAG must never
  retrieve another tenant's document even transiently, because
  the LLM would then be able to surface it.
- RAG retrieval additionally respects RBAC, RLS, the MVP 2
  medical confidential tier (health.read_medical), and data
  classification — a user may only ever be grounded on data
  they are authorized to read directly.
- Any MVP 3 entity cached on-device (e.g. Offline AI
  Recommendations, cached insights) respects the LocalOwner
  wipe-on-user-switch rule (Ledger §23). RLS is necessary but
  not sufficient — the cache is part of the trust boundary.
- Reuse the MVP 1 app.* RLS helpers and the MVP 2 capability
  layer (app.has_capability). Do not invent a parallel access
  model for AI.
- AUDIT: attach the existing MVP 1 audit_logs + the 0021-FIXED
  audit_row_change() trigger (jsonb status comparison) to every
  new MVP 3 table. Many MVP 3 tables are STATUS-LESS
  (embeddings, feature-store rows, sensor readings, predictions,
  knowledge-graph nodes/edges, conversation memory, imported
  audit rows) -- the pre-0021 trigger compiled a new.status
  field reference and made any status-less audited table
  INSERT-ONLY (Ledger §23.2 / D-audit-1). Use only the 0021
  form so these tables remain updatable while still audited.
  Never create a parallel audit table.

-------------------------------------------------
MVP 1 & MVP 2 CONTINUITY RULE
-------------------------------------------------
MVP 3 must extend and enhance the capabilities
delivered by MVP 1 and MVP 2.
MVP 3 is NOT a new platform.
MVP 3 is an intelligence layer built on top of
MVP 1 and MVP 2.
Every MVP 3 capability must provide value
to an existing workflow.

-------------------------------------------------
MVP 1 & MVP 2 ANALYTICS DEPENDENCY (CONSUME, DO NOT RE-IMPLEMENT)
-------------------------------------------------
MVP 2 delivered DESCRIPTIVE analytics as a set of stable
Supabase/PostgreSQL views (trends, aggregations, KPI
scorecards, rankings — the "MVP 3-consumable contract" in
MVP2.md Module 8). MVP 3 is the PREDICTIVE / PRESCRIPTIVE
layer and MUST build on those views:
- The Safety Intelligence Hub (Module 3), Predictive Risk
  Engine (Module 2), Executive Risk Intelligence (Module 6),
  and Executive Decision Support (Module 10) CONSUME the MVP 2
  analytics views. They do NOT re-derive raw aggregations that
  MVP 2 already produces.
- If MVP 3 needs an aggregate MVP 2 does not expose, EXTEND
  the MVP 2 view layer (a new/updated view) rather than
  computing a private duplicate inside an MVP 3 module — so
  one number has one definition across both phases.
- The canonical Enterprise Score (Module 6) reads these views
  plus the MVP 1 SafetyScore heuristic; it is the only place
  raw signals are combined into a composite.
- Every consuming query respects company_id isolation and the
  MVP 2 medical confidential tier (aggregated, non-identifying
  health data only) exactly as the underlying views do.
Boundary restated: MVP 2 = descriptive; MVP 3 = predictive/
prescriptive built ON descriptive. No re-implementation.

-------------------------------------------------
AI GOVERNANCE
-------------------------------------------------
AI recommendations must be advisory only.
The system must:
- Explain recommendations
- Show supporting evidence
- Provide confidence levels
- Provide traceability
Users must remain responsible for decisions.
AI must not automatically close hazards,
approve permits, close CAPAs, or make
compliance decisions.
All AI-generated outputs must be auditable.

-------------------------------------------------
MLOPS REQUIREMENTS
-------------------------------------------------
Generate:
- Model Registry
- Model Versioning
- Feature Store
- Training Pipelines
- Model Monitoring
- Prediction Monitoring
- Drift Detection
- Model Rollback Strategy

-------------------------------------------------
MODULE 1
AI SAFETY COPILOT
-------------------------------------------------
Configure the "Safety Copilot" PERSONA over the Unified
Conversational AI Framework (above) — do not build a
standalone engine. This persona must understand natural
language, query enterprise data, generate reports, explain
trends, suggest actions, and draft safety communications.
Create (as persona configuration + shared UI):
- Copilot Chat Interface (the shared chat surface)
- Suggested Prompts (Safety Copilot prompt library)
- Entity Search
- Report Generation
Inherits the shared RAG, memory, citation, and security
controls; enforces RBAC/RLS/capability tier unchanged.

-------------------------------------------------
MODULE 2
PREDICTIVE RISK ENGINE
-------------------------------------------------
Build machine learning powered risk prediction.
Inputs: Hazards, Incidents, CAPAs, Inspections,
Training, Compliance, Medical Data, Contractor
Performance.
Outputs: Future Incident Probability, High Risk
Areas, Exposure Predictions, Compliance Failure
Predictions, Safety Culture Risk Score.
Generate: Risk Forecast Dashboards, Trend Analysis,
Risk Scoring Engine, Predictions API.

-------------------------------------------------
MODULE 3
SAFETY INTELLIGENCE HUB
-------------------------------------------------
Create a centralized intelligence hub that brings
together safety, risk, compliance, health, training,
contractor, permit, inspection, and CAPA data into
one unified operational intelligence experience.
Generate:
- Unified Safety Intelligence Dashboard
- Cross-Module Analytics
- Root Cause Analytics
- Site/Department Comparison Analytics
- Hazard Hotspot Detection
- CAPA Effectiveness Analytics
- Risk/Compliance/Health/Training Trend Analysis
- Insight Cards (title, summary, risk level, evidence,
  recommended action, confidence score, source modules)
- KPI Framework (Enterprise Risk Index, Site Risk Index,
  CAPA Effectiveness Score, etc.)
- Filtering and drilldown to source records
- AI integration (Copilot, Predictive Risk Engine,
  Executive Risk Intelligence, Knowledge Management)

-------------------------------------------------
MODULE 4
SAFETY AUTOMATION ENGINE
-------------------------------------------------
Automate safety workflows.
Generate: Workflow Builder, Trigger Engine, Condition
Engine, Action Engine, Audit Trail.
Workflow Templates: High Risk Hazard, Permit Escalation,
CAPA Escalation, Compliance Escalation, Health
Surveillance Follow-Up.

-------------------------------------------------
MODULE 5
IOT & SMART DEVICE INTEGRATION
-------------------------------------------------
Support: Noise Meters, Dust Monitors, Gas Monitors,
Telematics, Wearables, Environmental Sensors.
Protocols: MQTT, REST, OPC-UA, Modbus, Azure IoT Hub,
AWS IoT Core.
Device Management: Registration, Health Monitoring,
Firmware Tracking, Device Ownership.
Generate: Realtime Monitoring Dashboard, Alert Engine,
Device Registry, Sensor Data Pipelines.

NOTIFICATION GOVERNANCE: IoT and automation alerts that
notify users (e.g. threshold-exceeded, gas-leak, device-
offline) extend the LOCKED notification_trigger enum via
migration, each recorded in the Decisions Ledger (as
capa.verification_due was, §18) — never ad hoc. Event-driven
device alerts fire through notify-fanout; time-based
conditions (e.g. device-firmware-due, calibration-due) are
raised by the notify-sweep cron (Ledger §13) with its once-
per-entity-per-day idempotency. Recipients respect RBAC and
the capability tier; the actor is filtered out (§16). Reuse
the existing MVP 1/MVP 2 notification infrastructure — do not
build a parallel alerting system.

-------------------------------------------------
MODULE 6
EXECUTIVE RISK INTELLIGENCE
-------------------------------------------------
Provide executive leadership with a consolidated,
strategic view of enterprise OHS risk across all sites,
departments, business units, contractors, and
operational activities.

ENTERPRISE RISK SCORE (THE SINGLE CANONICAL ENTERPRISE SCORE)
Generate ONE composite Enterprise Risk Score. This is the
platform's single source of truth for enterprise-level OHS
standing. Module 10's "Executive Health Score" is NOT a
second score — it is a presentation VIEW of this same value
(see Module 10). Do not compute two independent 0-100 scores
from the same inputs; they will diverge and destroy board
trust.
Score range: 0 - 100 (0 = Very Low Risk, 100 = Extreme Risk).
Derived from: Open High-Risk Hazards, Incident Frequency,
CAPA Overdue Rate, Compliance Gaps, Health Exposure Trends,
Training Non-Compliance, Contractor Non-Compliance, Permit
Risk Events, Repeated Root Causes, Predictive Risk Forecasts.
Output: Enterprise Risk Score, Score Trend, Risk Category,
Top Contributing Factors, Recommended Executive Actions.

CANONICAL SCORE CONTRACT (governs Modules 6 and 10):
- Compute the score in exactly ONE place — a single scoring
  service/Edge Function with one documented formula and one
  set of weighted inputs, versioned like any MLOps artefact
  (Model Registry / versioning above).
- Persist it once per company/site/period so every consumer
  (Executive Risk Intelligence, Executive Decision Support,
  Copilot, board reports) reads the SAME number.
- It builds on the MVP 1 SafetyScore heuristic and the MVP 2
  descriptive analytics views — it does not re-derive raw
  aggregates already produced by MVP 2 (see MVP 1 & MVP 2
  ANALYTICS DEPENDENCY above).
- Any "Safety Score" / "Health Score" wording elsewhere is a
  LABEL for this canonical value, not a new calculation.
- THIS INCLUDES THE MVP 1 DASHBOARD SAFETY SCORE, which today
  IS a separate calculation: computed client-side in Dart
  (safety_score.dart), where HIGHER = SAFER -- the opposite
  direction to the Enterprise Risk Score. When the canonical
  service lands, the MVP 1 dashboard card must render the
  canonical value (health framing, 100 - risk) and the Dart
  heuristic is retired as a computation; its terms become
  inputs to the canonical formula. Otherwise the most-viewed
  screen in the product shows a second 0-100 number that
  disagrees with the board dashboards. See Addendum M3-2e.

RISK RANKING, EMERGING RISK DETECTION, EXECUTIVE ALERTS,
BOARD-LEVEL REPORTING, EXECUTIVE DRILLDOWN, AI INTEGRATION,
GOVERNANCE RULES, DELIVERABLES — as specified. All figures,
especially the Enterprise Score, are read from the canonical
scoring service, never recomputed.

-------------------------------------------------
MODULE 7
ENTERPRISE KNOWLEDGE MANAGEMENT
-------------------------------------------------
Create a centralized enterprise knowledge layer that
transforms historical OHS information into searchable,
reusable organizational intelligence.
Includes: Knowledge Hub, Search Capabilities (natural
language, semantic, similar-incident), Lessons Learned
Engine, Knowledge Graph, AI Knowledge Assistant,
Knowledge Recommendation Engine, Control Effectiveness
Engine, Knowledge Governance, Knowledge Analytics.

AI KNOWLEDGE ASSISTANT
Configure the "Knowledge Assistant" PERSONA over the Unified
Conversational AI Framework — reuse its RAG pipeline, memory,
citation, and security core; do not build a separate engine.
This persona helps users retrieve, understand, and apply
organizational safety knowledge. All responses must provide
citations back to Incidents, Hazards, CAPAs, Investigations,
Documents, Compliance Records where available (the shared
citation framework, mandatory for this persona).
Multi-turn conversation memory and role-based intelligence
(RBAC, RLS, department/site access, and the MVP 2 medical
confidential tier) are inherited from the shared framework,
not re-implemented.

-------------------------------------------------
MODULE 8
DIGITAL TWIN & RISK MAPPING
-------------------------------------------------
Provide visual risk intelligence across sites.
Capabilities: Site Maps, Hazard/Incident/Permit/
Contractor/Health Exposure/IoT Sensor Layers.
Generate: Digital Twin Dashboard, Interactive Site Maps,
Risk Heatmaps, Emergency Route Mapping, Hazard Density
Mapping. Support site/department filtering and historical
playback.

-------------------------------------------------
MODULE 9
ADVANCED WORKFORCE SAFETY EXPERIENCE
-------------------------------------------------
Improve worker safety engagement through intelligent
mobile experiences.
Core Capabilities: Personalized Safety Home, My Safety
Tasks/CAPAs/Training/Permit Alerts, Safety Observation
Program, Safety Participation Score, Safety Recognition,
Microlearning, Safety Nudges, Mobile Safety Assistant.

MOBILE SAFETY ASSISTANT
Configure the "Mobile Safety Assistant" PERSONA over the
Unified Conversational AI Framework — a lightweight frontline
mode, NOT a separate engine. "Separate from the executive
Copilot" means a distinct PERSONA (restricted scope, task/
how-to focus, simplified UI), not a distinct codebase. Users
ask "How do I report a hazard?", "What actions are assigned
to me?", etc. The persona answers using approved platform
knowledge and the shared role-based access controls; its
narrower scope never widens what the user may see.

PRIVACY AND ETHICS
Workforce safety scores and engagement analytics must not be
used for punitive employee management. AI must not generate
employment decisions, disciplinary recommendations, or
performance judgments about individuals.

-------------------------------------------------
MODULE 10
EXECUTIVE DECISION SUPPORT
-------------------------------------------------
Provide leadership teams with AI-assisted decision
intelligence for safety, risk, compliance, operational
resilience, and workforce protection.

EXECUTIVE COPILOT
Configure the "Executive Copilot" PERSONA over the Unified
Conversational AI Framework — a strategic mode over the same
shared engine, not a fourth chat build. Executives ask "Which
sites require intervention?", "What are the top enterprise
risks?", etc.
Generate (as persona configuration): the Executive persona,
Executive Prompt Library, Executive Briefings, Executive
Decision Summaries. All strategic figures (including the
Enterprise Score) are read from the canonical scoring service,
not recomputed.

EXECUTIVE HEALTH SCORE (A VIEW OF THE CANONICAL ENTERPRISE SCORE)
Do NOT compute a second 0-100 score. The "Executive Health
Score" is the executive-facing PRESENTATION of the single
canonical Enterprise Risk Score defined in Module 6. Read
the same persisted value; do not re-derive it from raw data.
Executives may see it framed positively (a "health"/safety
score = 100 minus risk, or the same value with executive
labelling and narrative), but it MUST reconcile exactly to
Module 6 at all times — a board member comparing the two
dashboards must never see two different numbers.
Output: the canonical Enterprise Score (presented as a
0-100 health/safety framing), Trend Direction, Risk Forecast,
Recommended Actions — all sourced from the Module 6 scoring
service, versioned identically.

BOARD RISK DASHBOARD, RECOMMENDATION ENGINE, SCENARIO
PLANNING, SAFETY INVESTMENT OPTIMIZATION, EXECUTIVE
REPORTING, DECISION SUPPORT AI GOVERNANCE — as specified.

-------------------------------------------------
MODULE 11
EXTERNAL AUDIT IMPORT & SUMMARIZATION
-------------------------------------------------
Purpose:
Allow authorized users to upload an EXTERNAL audit produced
outside the platform — typically a spreadsheet from a third-
party auditor, a client, a regulator, or a legacy system —
have the platform ingest and structure it, summarize it with
AI, and generate a report. This is the only MVP 1/2/3
capability that consumes an EXTERNAL tabular data source; all
other reporting/summarization operates on data already inside
the platform. It closes that gap explicitly.

Positioning:
This module is an INTELLIGENCE + INGESTION capability, so it
lives in MVP 3. It reuses — never replaces — the MVP 1
Reporting/PDF pipeline, the MVP 2 Document Management and
Compliance modules, and the MVP 3 Unified Conversational AI
Framework (for the summarization step). It must NOT introduce
a second reporting engine or a second AI stack.

-------------------------------------------------
FILE-FORMAT DECISION (CALLED OUT EXPLICITLY)
-------------------------------------------------
MVP 1 deliberately restricted the shared Attachment service to
JPG · PNG · PDF (max 20 MB) — Excel/CSV were intentionally NOT
accepted, because attachments are treated as opaque evidence
blobs, not as data sources to be parsed. This module requires
a DIFFERENT path and must not simply widen the Attachment
allow-list.

Decision:
- Introduce a SEPARATE, PURPOSE-BUILT ingestion channel for
  tabular audit files — it does NOT reuse the evidence-
  attachment allow-list, and does NOT loosen it. Evidence
  attachments stay JPG/PNG/PDF platform-wide.
- Accepted import formats: .xlsx and .csv ONLY (the two
  formats an external audit realistically arrives in).
  Explicitly NOT accepted: .xls (legacy binary), .xlsm
  (macro-enabled — refuse, macros are an attack surface),
  Google Sheets links, or arbitrary binaries.
- Maximum import size: 20 MB (consistent with the platform
  attachment cap) and a row cap (e.g. 50,000 rows) to bound
  parsing cost; larger files are rejected with a clear error.
- Parsing is SERVER-SIDE ONLY (an Edge Function / ingestion
  service), never in the Flutter client — a spreadsheet parser
  in the client is both a performance and a security risk.
- The original uploaded file is retained (immutable) as the
  source-of-record for the import via a dedicated storage path,
  separate from evidence attachments and tenant-isolated by
  foldername[1] = company_id. The parsed data and the summary
  are derived artefacts linked back to it.
- The parser rejects formula injection / CSV injection (values
  beginning with = + - @ are treated as text, never evaluated).

-------------------------------------------------
WORKFLOW
-------------------------------------------------
Upload
  -> Format & size validation (xlsx/csv, <=20MB, row cap)
  -> Server-side parse into structured rows
  -> Column mapping & validation (map external columns to a
     template; flag unmapped/invalid columns for user review)
  -> Persist as a structured, tenant-scoped import dataset
  -> AI summarization (Unified Framework) over the parsed rows
  -> Generate report (MVP 1 Reporting pipeline: PDF + CSV)
  -> Optional: raise CAPAs / Compliance findings from audit
     items (typed FK into MVP 1 CAPA / MVP 2 Compliance)
  -> Store report in Document Management with review workflow

-------------------------------------------------
STRUCTURED IMPORT & MAPPING
-------------------------------------------------
- Provide import TEMPLATES for common external audit shapes
  (e.g. finding / severity / area / owner / due date / status)
  and a mapping UI so a user maps the uploaded columns to the
  template fields before commit.
- Validation surfaces bad rows (missing required fields,
  invalid dates, unknown severity) for correction or exclusion
  BEFORE the dataset is committed — never silently drop rows.
- Committed datasets are versioned (a re-upload creates a new
  version; prior versions are retained, never deleted — mirrors
  the MVP 1 attachment_versions / "never delete history" rule).

-------------------------------------------------
AI SUMMARIZATION
-------------------------------------------------
- Summarization runs over the PARSED, TENANT-SCOPED rows via
  the Unified Conversational AI Framework — it is a
  summarization task, not a new AI engine.
- The summary is ADVISORY (per AI GOVERNANCE): it highlights
  themes, top findings by severity, repeat findings, overdue
  items, and suggested CAPAs, each with supporting references
  back to the specific imported rows (the shared citation
  framework — cite row identifiers, never fabricate).
- The summary must never invent findings not present in the
  uploaded data; if the data is ambiguous, say so.
- Confidential-tier rule: if an imported audit contains
  medical/occupational-health columns, the medical
  confidential tier (health.read_medical) applies to those
  columns and to any summary derived from them.

-------------------------------------------------
REPORT GENERATION
-------------------------------------------------
- Reuse the MVP 1 Reporting module's PDF + CSV export and
  report-history mechanisms — do NOT build a new exporter.
- The generated report includes: the AI summary, the top
  findings, the mapping used, a data-quality note (rows
  imported / rejected), and provenance (source filename,
  uploader, import version, timestamp in the user's timezone
  per the §13.2 date rule).
- The report is stored via Document Management (Module 7 of
  MVP 2) so it inherits versioning, approval, acknowledgement,
  and review-date workflow.

-------------------------------------------------
RBAC & GOVERNANCE
-------------------------------------------------
- Gate import + summarization behind a capability, e.g.
  audit.import (granted to Compliance Officer / Safety Officer+
  / Administrator per company policy) — reuse the MVP 2
  capability layer (app.has_capability), do NOT invent a new
  access model.
- Every import, mapping decision, commit, summary generation,
  and report export is written to audit_logs (0021 trigger).
- Any CAPA/Compliance finding raised from an imported item is
  a normal MVP 1/2 record and follows the existing workflow and
  RLS — the import cannot bypass those controls.

-------------------------------------------------
TENANCY (RESTATED FOR THIS MODULE)
-------------------------------------------------
- New tables (audit_imports, audit_import_rows,
  audit_import_summaries, audit_import_mappings — names
  indicative) all carry company_id, have RLS with
  company_id = app.current_company_id(), and the 0021 audit
  trigger. Imported rows are STATUS-LESS by nature, so the
  0021 form is required (Ledger §23.2).
- The uploaded source file is stored on a tenant-isolated path
  (foldername[1] = company_id), distinct from evidence
  attachments.
- Any on-device caching of an import or its summary respects
  the LocalOwner wipe-on-user-switch rule (Ledger §23).

-------------------------------------------------
MODULE 11 DELIVERABLES
-------------------------------------------------
Generate:
- Ingestion architecture (server-side parser + validation)
- File-format & security policy (as decided above)
- Import schema (audit_imports and related tables)
- Column-mapping UI + templates
- AI summarization design (over the Unified Framework)
- Report generation via the MVP 1 Reporting pipeline
- CAPA / Compliance linkage design (typed FKs)
- Flutter screen specifications (mobile-first)
- Security & tenancy model
- Auditability model

-------------------------------------------------
AI ARCHITECTURE
-------------------------------------------------
Generate:
- RAG Architecture
- Vector Database Design
- Embedding Strategy
- Knowledge Graph
- Prompt Orchestration
- Agent Framework
- Conversation Memory
- Citation Framework
Architecture:
MVP 1 Data -> MVP 2 Data -> ETL Layer -> Embedding Pipeline
-> Vector Database -> Knowledge Hub -> AI Safety Copilot ->
Executive Decision Support

-------------------------------------------------
EXPLAINABLE AI
-------------------------------------------------
Every prediction and recommendation must provide:
- Confidence Score
- Key Contributing Factors
- Supporting Data Sources
- Recommended Actions
Users must understand why an output was generated.

-------------------------------------------------
AI DATA PRIVACY
-------------------------------------------------
Personally identifiable information, medical assessment
details, and confidential employee information must not be
exposed through Copilot without appropriate authorization.
AI responses must respect RBAC and Row Level Security.

CONFIDENTIAL MEDICAL TIER (binding on ALL AI features and
personas): medical/occupational-health data is governed by
the MVP 2 capability health.read_medical, NOT by rank — so a
rank-5 Administrator WITHOUT it must not receive medical
detail from any Copilot, Knowledge Assistant, prediction,
insight card, RAG retrieval, embedding, or imported-audit
summary (Module 11). Enforce this at retrieval time (the
vector store must not surface medical chunks to a non-holder)
AND at generation time, not merely by post-filtering the
answer. Aggregated, non-identifying health metrics remain
permissible per the MVP 2 dashboards rule.

-------------------------------------------------
AI SECURITY
-------------------------------------------------
Generate:
- Prompt Security Controls
- Agent Access Controls
- Data Access Restrictions
- Hallucination Mitigation Strategy
- RAG Security Controls
- Sensitive Data Protection
- Audit Logging of AI Interactions
- File-Ingestion Security (Module 11): reject macro-enabled /
  binary spreadsheets, neutralize formula/CSV injection,
  parse server-side only, cap size and row count.
All AI responses must respect RBAC, Row Level Security,
and Data Classification Policies.
