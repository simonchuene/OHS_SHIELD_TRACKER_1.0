# OHS Shield Tracker — MVP 1 Follow-Up Prompts

> Use these prompts sequentially, in one continuous conversation where possible. Each prompt assumes the outputs of all prior prompts have been **reviewed and approved by a human** and are available as context. Approval is an explicit step, not automatic — unread outputs compound errors across the sequence. If starting a fresh conversation mid-sequence, paste **MVP1.md + the Decisions Ledger** (see below) alongside the prompt rather than every full prior output.

---

## Global Conventions (apply to every prompt below)

- **Decisions Ledger over full outputs.** After each prompt is approved, update the Decisions Ledger (naming conventions, chosen conflict-resolution rule, severity/status enums, the Attachment API surface, notification trigger names, etc.). Carry **MVP1.md + the Ledger** into later prompts instead of pasting all prior outputs — this keeps Prompts 12–18 from drifting or exceeding the context window.
- **Output emission.** Emit code as **one file per block, each prefixed with `// path: lib/...`** mapping to the Flutter folder structure from Prompt 4. Never merge files or omit paths.
- **Self-verification.** Where a prompt has a checkable constraint (risk bands, RBAC matrix, status transitions, severity enum), end the output with a short **self-check table** proving it holds — do not just assert compliance in prose.
- **"Production-ready" = review-ready first implementation.** Output is a strong, convention-following starting point that still needs human compilation, integration testing, security review, and real asset/secret wiring before shipping — not a deployable binary.
- **Assets are placeholders.** Reference the supplied icon/brand assets by path (e.g. `assets/branding/app_icon.svg`); never hallucinate, redraw, or inline-approximate the icon (see Master Prompt Item 1a).
- **No redesign.** Never restate or alter locked domain values (colours, typography, risk bands, status flows, RBAC matrix, incident severity) — reference them from MVP1.md.

---

### Prompt 1 — Architecture

Act as a Principal Solution Architect.

Using the **MVP1 Master Prompt** as the source of truth, design the complete MVP 1 architecture.

**Generate:**
- Domain Model
- Core Business Processes
- Bounded Contexts
- Module Relationships
- System Architecture Diagram
- Layered Architecture
- Entity Relationships
- ERD
- Navigation Architecture
- API Strategy (PostgREST contracts + Edge Functions)
- Security Architecture
- RBAC Model (reference the permission matrix in the Master Prompt)
- Offline Synchronization Architecture (Drift + sync_queue)
- Notification Architecture
- Attachment Architecture (including version history approach)
- Audit Logging Architecture
- Multi-Site Architecture

Document all architectural decisions. Do not write application code. Focus only on architecture.

---

### Prompt 2A — Database Schema

Act as a Principal PostgreSQL Architect.

Using the approved MVP 1 architecture, design the complete PostgreSQL **schema** (structure only — RLS is handled separately in Prompt 2B, to avoid overloading a single turn across 19 tables).

**Tables to cover:** `users` · `roles` · `user_roles` · `user_profiles` · `sites` · `departments` · `hazards` · `risk_assessments` · `incidents` · `investigations` · `corrective_actions` · `inspections` · `inspection_items` · `notifications` · `device_tokens` · `attachments` · `attachment_versions` · `audit_logs` · `sync_queue`

**Generate:**
- Relationships, Primary Keys, Foreign Keys
- Constraints, Unique Constraints
- Indexes (including all `company_id`/`site_id`/`status` columns used in RLS policies and dashboard filters)
- Notifications Schema (linked to `device_tokens`)
- Attachment Schema (including `attachment_versions` for version history, since Supabase Storage does not natively version files)
- Sync Queue Schema
- Multi-Site Schema (Company → Site → Department → User)
- User & Role Schema
- Audit Logging Tables (structure only; immutability grants enforced in Prompt 2B)

**Also generate:** ERD · SQL Schema · Migration Strategy · Database Naming Standards

**Self-check:** Confirm every tenant-scoped table carries `company_id` (and `site_id` where relevant) and that each such column is indexed.

Design for production use. Do not write Flutter code. Do not write RLS policies yet.

---

### Prompt 2B — Row Level Security & Policies

Act as a Principal PostgreSQL Architect.

Using the approved schema from Prompt 2A, design the complete **Row Level Security and policy layer**.

**Generate:**
- RLS enabled on **every** table (name each table explicitly; none may be left unsecured)
- Row Level Security Policies enforcing **Company → Site → Department** scoping, reading the authenticated user's claims from `user_profiles`/`user_roles`
- Per-action policies (SELECT/INSERT/UPDATE/DELETE) aligned to the Master Prompt RBAC matrix
- Audit Logging immutability: **no UPDATE/DELETE grants** on `audit_logs` at the database level
- Supabase Storage access policies for attachments (secure file access per role)
- Supabase Policies (auth, service-role boundaries)

**Self-check:** Produce a table mapping **every role × every action** in the Master Prompt permission matrix to the specific policy that enforces it — proving no gaps and no unintended grants. Confirm `audit_logs` exposes no mutation path.

Design for production use. Do not write Flutter code.

---

### Prompt 3 — UI/UX

Act as a Senior Enterprise UX Architect.

Using the Master Prompt's **APPLICATION THEME** and **APPLICATION BRANDING** sections exactly, create the complete MVP 1 user experience.

**Generate:**
- Screen Inventory
- Navigation Flows
- User Journeys
- Wireframes
- Screen Specifications
- Component Library
- Design Tokens
- Form Specifications
- Empty States, Loading States, Error States
- Offline States (sync pending/failed indicators)
- Notification States

Create detailed mobile-first layouts. Do not generate Flutter code. Focus on user experience and interface specifications.

---

### Prompt 4A — Flutter Foundation

Act as a Principal Flutter Architect.

Using the approved architecture and design system, generate the complete Flutter foundation (project scaffolding — the offline sync engine is built separately in Prompt 4B).

**Technology Stack:** Flutter · Riverpod (`riverpod_generator`) · GoRouter · Supabase · Drift (SQLite, for offline persistence) · Clean Architecture

**Generate:**
- Folder Structure
- Feature Structure
- Dependency Injection Strategy
- State Management Pattern
- Repository Pattern
- DTO Strategy
- Error Handling Strategy
- Logging Strategy
- Theming Strategy (Light + Dark, per Master Prompt color tokens)
- Navigation Strategy
- Shared Component Strategy

Do not implement business features yet. Do not build the offline sync engine yet. Focus only on project foundation.

---

### Prompt 4B — Offline Sync Engine

Act as a Principal Flutter Architect.

Using the foundation from Prompt 4A, build the **offline synchronization engine** as a dedicated subsystem (it is substantial enough to warrant its own turn).

**Generate:**
- Drift local tables mirroring the server-side `sync_queue` schema
- Sync orchestration (detect connectivity, drain the queue, reconcile with Supabase)
- **Conflict Resolution Strategy** — implement the rule chosen in the architecture (last-write-wins with audit trail, or field-level merge for non-conflicting fields). State which entities use which rule and **record the choice in the Decisions Ledger**.
- Retry Logic (exponential backoff — specify base delay, max retries, cap)
- Sync Status model surfaced per record in the UI: pending / syncing / synced / failed
- Offline queueing hooks that Hazard, Incident, Inspection, and CAPA modules will consume

**Self-check:** Walk through one create, one update, and one conflicting-update scenario end-to-end, showing the resulting queue state and final resolved record.

Do not implement business features yet. Focus only on the sync engine.

---

### Prompt 5 — Authentication

Using the approved architecture and Flutter foundation, implement the Authentication Module.

**Generate:**
- Domain Entities, DTOs
- Repository Interfaces & Implementations
- Use Cases
- Riverpod Providers
- Login Screen, Forgot Password Screen
- Session Management
- Supabase Auth Integration
- RBAC Integration
- Secure Storage Strategy
- Unit Tests, Widget Tests

**Business Rules:**
- Session persistence
- Secure logout
- Password reset
- Role-based access (per the Master Prompt permission matrix)
- Mobile-first UX

Do not redesign existing architecture.

---

### Prompt 6 — Attachment & Media Management (Shared Service)

Implement the shared Attachment & Media Management service. This is a cross-cutting service consumed by Hazard, Incident, Investigation, CAPA, and Inspection modules — build it now so those modules can integrate against it directly.

**Generate:**
- Entities & DTOs for `attachments` and `attachment_versions`
- Repository Interfaces & Implementations
- Use Cases: Upload, Preview, Download, Delete, List Version History
- Supabase Storage integration (max 20MB, JPG/PNG/PDF)
- Version history logic: each new upload to an existing attachment creates a new `attachment_versions` row and marks prior versions inactive — never delete history
- Camera capture + GPS metadata capture components (for reuse across Hazard/Incident/Inspection forms)
- Offline queuing for uploads made without connectivity
- Unit Tests, Widget Tests

Expose this as a reusable shared widget/component so downstream feature modules only need to call a single upload/preview API.

Do not redesign existing architecture.

---

### Prompt 7 — Hazard Management

Implement the Hazard Management Module.

**Generate:**
- Entities, DTOs, Repositories, Use Cases, Providers
- Screens, Forms, Validation Logic
- Photo Upload & GPS Capture (using the shared Attachment service from Prompt 6)
- Offline Support
- Supabase Integration
- Audit Logging
- Tests

**Business Rules:**
- Hazard lifecycle compliance
- Risk linkage, Investigation linkage, CAPA linkage
- Multi-site support

Do not redesign existing modules.

---

### Prompt 8 — Hazard Workflow

Implement the complete Hazard Lifecycle Engine.

**Workflow:** Hazard Reported → Risk Assessment → Investigation → CAPA → Verification → Closure

**Generate:**
- Workflow Design & State Machine
- Status Models & Transition Rules
- Escalation Rules
- Notification Triggers (stubs — full Notification module built in Prompt 15)
- Audit Events
- Lifecycle Diagrams

All business rules must be enforceable in code (e.g., block transition to "Closed" without verification evidence). Do not redesign modules.

---

### Prompt 8A — Incident Management

Implement the Incident Management Module.

Incidents are a **separate first-class entity from Hazards** (per the Master Prompt's Domain Model Rule). A Hazard may lead to an Incident; an Incident may generate Investigations, CAPAs, or follow-up Hazards. Build the bidirectional linkage accordingly. This prompt is placed here because Incidents must exist before Investigation (Prompt 10) and CAPA (Prompt 11) can build linkage against them; it depends only on the shared Attachment service (Prompt 6).

**Generate:**
- Entities, DTOs, Repositories, Use Cases, Providers
- Screens, Forms, Validation Logic
- Incident Type selection (Near Miss · First Aid · Medical Treatment · Lost Time Injury · Property Damage · Environmental Incident)
- Severity capture using the **locked Severity Scale** defined in the Master Prompt INCIDENT MANAGEMENT section (Minor / Moderate / Serious / Critical → colour tokens)
- Date · Time · Location fields, with GPS Capture (shared components from Prompt 6)
- Witness capture (minimised per POPIA — see Business Rules)
- Photo & Evidence Capture (via the shared Attachment service from Prompt 6)
- Offline Support (offline incident reporting; consume the sync engine from Prompt 4B)
- Supabase Integration (PostgREST for `incidents`; Edge Functions only where CRUD + RLS is insufficient)
- Audit Logging (create / modify / status-change written with before/after state)
- Workflow & State Machine: Reported → Investigated → CAPA → Verified → Closed
- Linkage Engine (Hazard ↔ Incident, Incident → Investigation, Incident → CAPA)
- Notification Hooks (stubs — consolidated in Prompt 15; trigger: New Incident)
- Unit Tests, Widget Tests

**Business Rules:**
- **Incident/Hazard separation** — distinct tables, entities, and workflows, linked where appropriate.
- **Severity enum** — use the Master Prompt's locked scale; do not invent a per-module scale.
- **POPIA data minimisation** — capture only operationally necessary personal information for witnesses/injured parties; restrict visibility via RLS.
- **Linkage integrity** — an Incident links to zero or one originating Hazard and may generate zero or more Investigations/CAPAs; enforce referential integrity.
- **Multi-site support** — scope by `company_id`/`site_id`; support Site, Department, and Enterprise filtering.
- **RBAC (per the Master Prompt permission matrix)** — all roles may Report an Incident; only Safety Officer, Manager, and Administrator may Close one. Conditionally render per role; enforce at the RLS layer.

**Self-check:** Show the incident status state machine with each transition's guard condition, and confirm Close is blocked unless verification evidence exists and linked CAPAs are closed.

**Definition of Done:** A user with the appropriate role can report an incident of any of the six types, attach photo/evidence and GPS, capture witnesses within POPIA limits, link the incident to a hazard and/or generate an investigation and CAPA, transition it through every workflow status, and close it — audit-logged throughout, offline-capable. Satisfies Success Criteria #7 and #8.

Do not redesign existing modules.

---

### Prompt 9 — Risk Assessment

Implement the Risk Assessment Module.

**Generate:**
- Entities, DTOs, Repositories, Use Cases, State Management
- Screens, Risk Calculator, Risk Matrix
- Validation Rules, Residual Risk Logic
- Notification Hooks (stubs)
- Offline Draft Support
- Tests

**Risk Formula:** Risk Score = Likelihood (1–5) × Severity (1–5)

**Risk Levels (must match exactly — no gaps):**

| Score | Level |
|---|---|
| 1 – 5 | Low |
| 6 – 12 | Medium |
| 13 – 17 | High |
| 18 – 25 | Critical |

The calculator must compute the score live and map it to the correct color token (Green/Amber/Red-High/Red-Critical) with no undefined scores across the full 1–25 range.

**Self-check:** Output a table listing every **reachable** Likelihood × Severity product (both 1–5, giving 14 distinct values: 1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 15, 16, 20, 25 — the values 7, 11, 13, 14, 17, 18, 19, 21, 22, 23, 24 can never occur) mapped to its band and colour token, proving each reachable score resolves to exactly one level with no gaps or overlaps.

Generate complete production-ready design and implementation specifications.

---

### Prompt 10 — Investigation

Implement the Investigation Module.

**Generate:**
- Entities, DTOs, Repositories, Use Cases, State Management
- Screens, Root Cause Components, 5 Whys Components
- Evidence Capture & Attachment Support (via shared Attachment service)
- Timeline Components
- Notification Hooks (stubs)
- Tests

**Business Rules:**
- Investigation ownership
- Root cause mandatory
- Recommendations mandatory
- CAPA generation support
- Hazard & Incident linkage — an investigation may originate from either a Hazard or an Incident (per Prompt 8A); support both back-references

Generate production-ready outputs.

---

### Prompt 11 — CAPA

Implement the CAPA Module.

**Generate:**
- Entities, DTOs, Repositories, Use Cases, State Management
- Screens, Kanban View, List View
- Verification Workflow, Evidence Management (via shared Attachment service)
- Escalation Logic
- Notification Hooks (stubs)
- Tests

**Business Rules:** Assignment · Ownership · Verification · Closure · Escalation · Source linkage (a CAPA may originate from a Hazard, Incident, Investigation, or failed Inspection item — support all four back-references)

Generate production-ready outputs.

---

### Prompt 12 — Inspections

Implement the Inspections Module.

**Generate:**
- Entities, DTOs, Repositories, Use Cases, Providers
- Checklist Engine
- Mobile Inspection UX
- Photo Capture (via shared Attachment service)
- Offline Support
- Scoring Logic
- Hazard Generation Logic (auto-create Hazard on failed item)
- CAPA Generation Logic (auto-create CAPA on failed item)
- Tests

Ensure inspections integrate with Hazards, CAPAs, and Dashboard Metrics.

---

### Prompt 13 — Dashboard

Implement the Dashboard Module.

**Generate:**
- Dashboard Data Models, KPI Strategy, Aggregation Queries
- Dashboard Providers
- Screens, KPI Cards, Trend Charts, Heat Maps
- Drill-Down Screens, Filters
- Mobile Dashboard UX
- Offline Dashboard Support (cached last-known values)

**Generate dashboards scoped per role, per the Master Prompt RBAC matrix — do not give every role the same view:**

| Role | Dashboard Scope |
|---|---|
| Employee | Personal contributions only (hazards/incidents I reported, their status) |
| Supervisor | Department-level view |
| Safety Officer | Site-level view, full KPI set |
| Manager | Site + Enterprise aggregation |
| Administrator | Full Enterprise view + system health |

---

### Prompt 14 — Reporting

Implement the Reporting Module.

**Generate:**
- Report Models, Reporting Repositories, Reporting Use Cases
- Report Screens, Filters
- PDF Export, CSV Export
- Report History
- RBAC Visibility Rules (reports must respect the same scoping as Prompt 13's dashboards)
- Offline Access (cached reports)

Generate all MVP 1 reports. Exclude MVP 2 and MVP 3 reporting capabilities.

---

### Prompt 15 — Notifications

Implement the Notifications Module (this consolidates the notification hooks stubbed in Prompts 8–12, including Prompt 8A / Incidents).

**Generate:**
- Notification Models, DTOs, Repositories, Use Cases
- In-App Notifications
- Push Notifications via FCM, registered against the `device_tokens` table
- Notification Center screen
- Deep Linking (tap notification → relevant record)
- Escalation Rules
- Preference Management
- Offline Notification Support (queue while offline, deliver on reconnect)
- Tests

**Support triggers for:** Hazards · Incidents · Risk Assessments · Investigations · CAPAs · Inspections · Reports

---

### Prompt 16 — Audit Log Viewer

Implement the Audit Log Viewer Module.

**Generate:**
- Read-only Entities/DTOs for `audit_logs`
- Repository & Use Cases (read-only, no write/update/delete exposed at the UI or API layer)
- Screens: filterable/searchable log list (by user, action, date range, entity type)
- Detail view showing Before State / After State diff
- RBAC Visibility: restrict access to Safety Officer, Manager, and Administrator roles only, per the Master Prompt permission matrix
- Tests

This module exists purely for compliance visibility — it must never expose any mutation capability against `audit_logs`.

---

### Prompt 17 — Testing

Act as a Principal QA Engineer.

Generate the complete MVP 1 testing strategy.

**Generate:**
- Unit Test Strategy, Widget Test Strategy, Integration Test Strategy
- Repository Test Strategy
- RBAC Test Matrix (validate every role/action combination in the permission matrix)
- Offline Sync Tests (including conflict resolution scenarios)
- Accessibility Tests (WCAG 2.1 AA)
- Security Tests (RLS bypass attempts, auth edge cases)
- Performance Tests (against the Master Prompt's performance targets)
- UAT Scenarios
- Regression Checklist

Produce implementation-ready test plans.

---

### Prompt 18 — Deployment

Act as a Principal DevOps Engineer.

Generate the complete MVP 1 deployment strategy.

**Generate:**
- Environment Architecture: Dev, Test, UAT, Production
- Supabase Deployment Strategy
- CI/CD Pipeline
- Flutter Flavors (per environment)
- Firebase Configuration (FCM per environment)
- Monitoring Strategy
- Backup Strategy
- Disaster Recovery Strategy
- Release Checklist
- Rollback Strategy
- Go-Live Plan

Prepare MVP 1 for enterprise production deployment.

---

## Decisions Ledger Template

> **How to use it.** After each prompt's output is approved, fill in the relevant slots and keep this updated. Then, instead of pasting full prior outputs into the next prompt, paste **MVP1.md + this Ledger**. It carries the stable, must-not-contradict decisions forward in a fraction of the tokens, keeping later prompts (12–18) from drifting or exceeding the context window. Leave a slot blank until the prompt that decides it has run.

### OHS Shield Tracker — Build Decisions Ledger

**Last updated after:** Prompt ___  ·  **Flutter SDK pinned to:** ___  ·  **Supabase project ref:** ___

#### 1. Naming & Structure (set in Prompts 2A & 4A)
- **Table naming convention:** ___ (e.g. snake_case plural)
- **Confirmed table list:** users, roles, user_roles, user_profiles, sites, departments, hazards, risk_assessments, incidents, investigations, corrective_actions, inspections, inspection_items, notifications, device_tokens, attachments, attachment_versions, audit_logs, sync_queue — *(additions)* ___
- **Flutter folder root pattern:** `lib/{core, shared, features, services, repositories}` — *(deviations)* ___
- **Feature folder internal structure:** ___ (e.g. `feature/{data, domain, presentation}`)
- **Provider naming convention:** ___
- **DTO ↔ Entity mapping convention:** ___

#### 2. Locked Domain Values (restated from MVP1.md — do not redefine here)
- **Roles:** Employee, Supervisor, Safety Officer, Manager, Administrator
- **Risk bands:** 1–5 Low · 6–12 Medium · 13–17 High · 18–25 Critical
- **Incident severity:** Minor · Moderate · Serious · Critical
- **Hazard status:** Draft → Submitted → Assessment → Investigation → CAPA → Verification → Closed
- **Incident status:** Reported → Investigated → CAPA → Verified → Closed
- **CAPA status:** Created → Assigned → In Progress → Verification → Closed
- **Investigation status:** Open → In Progress → Pending Review → Completed
- **Inspection status:** Draft → In Progress → Submitted → Closed
- **Colour tokens:** Green `#2E7D32` · Amber `#F9A825` · Red `#C62828` · Blue `#1565C0` (brand accent `#923357` is non-semantic only)

#### 3. Cross-Cutting Contracts (set in Prompts 1, 6, 15)
- **Attachment service API surface (Prompt 6):** upload(___) · preview(___) · download(___) · delete(___) · listVersions(___)
- **Reusable camera + GPS capture widget:** ___ (name/path)
- **Notification trigger hook names (stubbed 8–12 incl. 8A, consolidated 15):** ___
- **Audit event helper signature:** ___

#### 4. Offline & Sync Decisions (set in Prompts 1 & 4B)
- **Conflict resolution rule:** ___ (last-write-wins + audit trail *or* field-level merge — state which, for which entities)
- **Retry/backoff policy:** ___ (base delay, max retries, cap)
- **Sync status states in UI:** pending · syncing · synced · failed — *(deviations)* ___
- **Local Drift tables mirroring `sync_queue`:** ___

#### 5. Security, RBAC & User Management (set in Prompts 1, 2B, 5, and the User & Access Administration work)
- **RLS scoping claim source:** ___ (e.g. `user_profiles`/`user_roles` claims in JWT)
- **Multi-site isolation columns:** `company_id` on all tenant tables; `site_id` where relevant — *(exceptions)* ___
- **User identity model:** `auth.users` ↔ `user_profiles` (1:1 by id) ↔ `user_roles` (scope-aware) — *(confirmed shape / deviations)* ___
- **user_roles scoping:** `(user_id, role_id, site_id NULL, department_id NULL)`; NULL scope = company-wide — *(deviations)* ___
- **Provisioning model:** invite-based, Administrator-provisioned via Edge Function (service role); open self-registration disabled — *(who may invite; delegation to Managers?)* ___
- **User lifecycle states:** invited → active → suspended → deactivated; soft-deactivate only, never hard-delete — *(deviations)* ___
- **Licensing:** **DEFERRED to MVP2** — no billing / seats / entitlements in MVP1; invite gate built to accept a future seat-limit check without rework
- **Audit-viewer access roles:** Safety Officer, Manager, Administrator (read-only)
- **Secure storage mechanism (Prompt 5):** ___

#### 6. Output & Handoff Conventions (set once, applied everywhere)
- **Code emission format:** one file per block, prefixed `// path: lib/...`
- **Icon/asset handling:** source SVG treated as a fixed binary reference/placeholder for a human to wire in (MVP1.md Item 1a) — never hallucinated or redrawn
- **"Production-ready" interpretation:** review-ready first implementation requiring human compile + integration test before shipping

#### 7. Open Questions / Deviations Log
- ___
- ___

**Governance note:** Section 2 values are copied from MVP1.md for convenience — *restated, not editable here*. If any must change, change MVP1.md and re-derive; never let the Ledger and MVP1.md diverge.
