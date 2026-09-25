You are a Principal Software Architect, Senior Flutter Engineer, PostgreSQL Architect, Enterprise UX Designer, and ISO 45001 Occupational Health & Safety Consultant.
You are building MVP 2 of an enterprise Occupational Health & Safety Performance Management Platform.
MVP 1 already exists and contains:
- Authentication
- Dashboard
- Hazard Management
- Risk Assessments
- Incident Management
- Investigations
- Corrective Actions (CAPA)
- Inspections
- Notifications
- Reporting
DO NOT redesign MVP 1.
Extend MVP 1 by implementing additional enterprise OHS capabilities.
Maintain compatibility with all existing functionality.

### GOAL OF MVP 2

Transform the system from a Safety Management System into a complete Occupational Health & Safety Management System aligned with:
- ISO 45001
- Occupational Health Legislation
- Enterprise Risk Management
- Contractor Safety Management
- Leading Indicator Tracking

### DESIGN SYSTEM CONTINUITY

MVP 2 must inherit the APPLICATION THEME,
APPLICATION BRANDING, navigation structure,
color system, typography, spacing, cards,
forms, charts, accessibility rules, and mobile-first
design patterns established in MVP 1.
Do not redesign the UI.
Only extend the existing design system with new
components where required.

### MOBILE-FIRST RULE

MVP 2 must remain mobile-first.
Do not generate desktop layouts.
Tablet views may be responsive enhancements.
All screens must be designed for field-ready mobile
use first.

### TECHNOLOGY STACK

Frontend:
- Flutter
- Material 3
- Riverpod
- GoRouter
Backend:
- Supabase
Database:
- PostgreSQL
Architecture:
- Clean Architecture

### MVP 1 INTEGRATION RULE

All MVP 2 modules must integrate with existing MVP 1
modules where relevant.
Examples:
- Health Surveillance must link to Hazards and Risk Assessments.
- Training must link to Users, Departments, Contractors, and Compliance.
- Compliance gaps must be able to generate CAPAs.
- Contractor incidents must link to Incident Management.
- Permit violations must generate Hazards or CAPAs.
- Document reviews must generate notifications.
- Committee actions must link to CAPA.
- Advanced Analytics must consume MVP 1 and MVP 2 data.
- Committee actions must be able to create CAPAs.
- Committee actions must be traceable to closure.
- Committee recommendations must appear on committee performance dashboards.

### MIGRATION RULE

Extend the existing MVP 1 database using controlled
PostgreSQL migrations.
Do not drop or rename existing MVP 1 tables.
Do not break existing MVP 1 relationships.
All new MVP 2 tables must include:
- id
- company_id (MANDATORY on every tenant-scoped table --
  this is the single most important isolation column;
  omitting it reintroduces the cross-company data leak
  documented in Decisions Ledger section 23 / D-tenant-1)
- created_at
- updated_at
- created_by  } set by a BEFORE INSERT/UPDATE trigger
- updated_by  } from auth.uid() -- never client-supplied.
  No MVP 1 table has these; do not retrofit MVP 1 tables
  and do not assume them in cross-module queries.
  See Addendum M2-2f.
- status where applicable
- site_id where applicable
- department_id where applicable
- audit trail support

Every new MVP 2 table MUST have RLS enabled with a
policy that includes `company_id = app.current_company_id()`,
exactly as MVP 1 does. No table may cross a company boundary
at any rank or capability, Administrator included.

OFFLINE CACHE TENANCY: any new MVP 2 entity that is cached
locally (Drift) must respect the LocalOwner wipe-on-user-switch
mechanism from Decisions Ledger section 23. RLS alone does not
stop cross-tenant leakage through a stale local cache -- the
cache is part of the trust boundary.

### MVP 2 MODULES

Build the following new modules:
- Occupational Health Surveillance
- Training & Competency Management
- Compliance Management
- Contractor Management
- Permit-to-Work
- Safety Committee Management
- Document Management
- Advanced Analytics

### ACCESS MODEL EVOLUTION (BUILD THIS FIRST — BLOCKS ALL MVP 2 MODULES)

MVP 1 enforces access as a strict linear RANK LADDER
(employee=1 -> supervisor=2 -> safety_officer=3 ->
manager=4 -> administrator=5) via app.user_rank() /
app.has_min_rank(n), with EXACT-RANK visibility tiers
(own -> department -> site -> enterprise). See the
Decisions Ledger sections 5, 5a and 22.

The seven new MVP 2 roles below are FUNCTIONAL /
NON-HIERARCHICAL. They do not fit a 1-5 ladder, and
one requirement is impossible to express as a rank:
a rank-2 Occupational Health Practitioner must see
medical results that a rank-5 Administrator must NOT
(see HEALTH DATA PRIVACY). A rank ladder cannot make
a lower rank see MORE than a higher rank.

Therefore MVP 2 MUST evolve the access model BEFORE
any feature module is built. This is a dedicated,
first prompt in the MVP 2 follow-up sequence.

Requirements:
- Introduce a CAPABILITY / PERMISSION layer alongside
  the existing rank ladder. Do NOT remove the ladder
  (MVP 1 RLS depends on it) -- layer capabilities on top.
- Model capabilities as (role -> capability) grants,
  e.g. health.read_medical, training.manage,
  compliance.manage, contractor.manage,
  permit.approve, committee.manage_minutes,
  document.control. Store in a new
  role_capabilities table (company-scoped).
- Extend app.* RLS helpers with app.has_capability(cap)
  reading the caller's granted capabilities, so new
  MVP 2 policies gate on CAPABILITY, and MVP 1 policies
  keep gating on RANK unchanged.
- Introduce a CONFIDENTIAL DATA TIER for medical /
  occupational-health data enforced by capability
  (health.read_medical), NOT by rank -- so it can be
  hidden from Manager/Administrator unless explicitly
  granted. This directly satisfies HEALTH DATA PRIVACY.
- The seven new roles are additive: an existing MVP 1
  user may hold a new functional role WITHOUT changing
  their rank. app.user_rank() still returns the max
  rank across a user's role rows (unchanged).
- FUNCTIONAL ROLES MUST NOT BE ROWS IN `roles`.
  roles.rank is NOT NULL and UNIQUE, ranks 1-5 are
  taken, and app.user_rank() is max(roles.rank). A
  functional role stored there needs a distinct new
  rank -- and any rank above 5 makes its holder
  OUTRANK an Administrator (a Training Coordinator
  would pass app.has_min_rank(5)). Store functional-
  role grants outside roles/user_roles so user_rank()
  is unchanged by construction. See Addendum DEV-M2-A.
- Mirror every capability as a client-side affordance
  (AppRole/AppCapability), but keep RLS authoritative
  per architecture section 10. A client capability check
  is UX only.
- Self-check (mandatory): output a table mapping every
  new MVP 2 role x every MVP 2 capability to allow/deny,
  AND prove no MVP 1 rank policy is loosened by the change.

### ADDITIONAL MVP 2 ROLES (functional, capability-driven)

Extend RBAC to support the following functional roles.
Each is defined by the CAPABILITIES it is granted (above),
NOT by a position on the rank ladder:
- Occupational Health Practitioner (health.read_medical, health.manage)
- Training Coordinator (training.manage)
- Compliance Officer (compliance.manage)
- Contractor Manager (contractor.manage)
- Permit Approver (permit.approve)
- Committee Secretary (committee.manage_minutes)
- Document Controller (document.control)
Maintain compatibility with existing MVP 1 roles and the
rank ladder. A user may hold both a rank role and one or
more functional roles simultaneously.

### LICENSING, SEATS & ENTITLEMENTS (deferred FROM MVP 1 -- now owned by MVP 2)

MVP 1 explicitly DEFERRED licensing, seats, subscriptions,
plan tiers and module entitlements to MVP 2, and pre-built
the invite/provisioning gate so a single seat-entitlement
check could be inserted at the invite gate without rework
(see MVP 1 USER MANAGEMENT & PROVISIONING and Decisions
Ledger section 5a). MVP 2 must now deliver it.

Build:
- A company_subscriptions / entitlements model: plan tier,
  seat_limit, active_seats, module entitlements (which of
  the MVP 2 modules a company has purchased), billing status.
- SEAT ENFORCEMENT AT THE INVITE GATE: block user activation
  when active users >= seat_limit. Insert this at the existing
  invite gate the MVP 1 Edge Function already reserved --
  assertSeatAvailable(companyId) in user-admin, which runs
  BEFORE inviteUserByEmail so a refusal sends no email and
  creates no auth user (Ledger section 24.3). Do NOT
  restructure the user model. Decide whether a seat is
  consumed at invite or at activation (activation happens in
  the 0020 DB trigger, not in user-admin) -- Addendum M2-3b.
- MODULE ENTITLEMENT GATING: a company only sees / can use the
  MVP 2 modules it is entitled to. Enforce at RLS / Edge
  Function, mirrored as a client affordance (UX only).
- Enforce all billing/seat/entitlement logic at the
  RLS / Edge-Function layer using the service role, never
  from the Flutter client.
- Keep seat / entitlement state company-scoped
  (company_id) and auditable like every other change.

If the product decision is to defer billing further, that
MUST be recorded EXPLICITLY here rather than silently dropped
(the gap this fix closes). At minimum, ship the seat_limit +
module-entitlement enforcement scaffolding even if payment
collection is deferred.

### STATUS GOVERNANCE

Training Status:
Assigned
Completed
Expired
Renewal Due
Compliance Status:
Compliant
Partially Compliant
Non-Compliant
Under Review
Permit Status:
Requested
Under Review
Approved
Active
Expired
Closed
Rejected
Document Status:
Draft
Under Review
Approved
Published
Archived
Medical Assessment Status:
Scheduled
Completed
Follow-Up Required
Closed

### HEALTH DATA PRIVACY

Occupational Health records may contain sensitive
employee health information.
Implement strict access controls.
Medical assessment details must only be accessible to:
- Occupational Health Practitioner
- Authorized Safety Officer
- Authorized Manager
- Administrator where legally permitted
Do not expose detailed medical results on general
dashboards.
Dashboards should show aggregated health compliance
metrics only.

### MODULE 1
OCCUPATIONAL HEALTH SURVEILLANCE

Purpose:
Track employee exposure to occupational hazards.
Exposure Categories:
- Noise
- Dust
- Chemical
- Radiation
- Biological
- Heat Stress
- Ergonomics
- Vibration
Medical Programs:
- Audiometry
- Spirometry
- Vision Screening
- Medical Examination
- Biological Monitoring
- Fitness For Work
Workflow:
Hazard Exposure
Medical Scheduled
Assessment Completed
Results Captured
Intervention
Follow-up
Closure
Create:
- Health Dashboard
- Exposure Register
- Medical Scheduling
- Medical Assessment Forms
- Exposure Trends
- Employee Health Profile
Build complete UI flows.

### MODULE 2
TRAINING & COMPETENCY

Purpose:
Track workforce competency.
Training Categories:
- Safety Induction
- First Aid
- Fire Fighting
- Working At Heights
- Confined Space Entry
- Hazardous Chemicals
- Forklift Operations
Requirements:
Track:
- Training Assignment
- Attendance
- Certification
- Expiry Dates
- Competency Status
Generate:
- Compliance Dashboard
- Expiry Notifications
- Employee Training Matrix
Workflow:
Assign Course
Attend Course
Certificate Issued
Compliance Tracking
Renewal

### MODULE 3
COMPLIANCE MANAGEMENT

Purpose:
Maintain legal compliance.
Track:
- OHS Legislation
- Environmental Legislation
- ISO 45001 Clauses
- Internal Standards
- Client Requirements
Fields:
Requirement
Owner
Review Date
Evidence
Status
Workflow:
Requirement
Assessment
Evidence Upload
Compliance Status
Review Cycle
Generate compliance scorecards.

### MODULE 4
CONTRACTOR MANAGEMENT

Purpose:
Manage contractor OHS performance.
Track:
- Contractor Companies
- Employees
- Insurance
- Inductions
- Training
- Permits
- Incidents
Dashboard KPIs:
Active Contractors
Non-Compliant Contractors
Contractor Incidents
Outstanding Contractor CAPAs
Build:
Contractor Profile
Contractor Safety Passport
Contractor Compliance Dashboard

### MODULE 5
PERMIT-TO-WORK

Purpose:
Manage high-risk work authorization.
Permit Types:
- Hot Work
- Confined Space
- Working At Heights
- Excavation
- Electrical Isolation
- LOTO
Workflow:
Request
Risk Review
Approval
Execution
Closeout
Features:
QR Codes
Digital Signatures
Permit Expiry Monitoring

### MODULE 6
SAFETY COMMITTEE

Purpose:
Support legal consultation requirements.
Features:
Meeting Scheduling
Attendance Tracking
Action Tracking
Minutes Management
Committee Dashboard
Generate:
Meeting Agendas
Meeting Minutes
Action Registers

### MODULE 7
DOCUMENT MANAGEMENT

Purpose:
Centralized OHS document repository.
Document Types:
- Policies
- Procedures
- SOPs
- Risk Assessments
- SDS Documents
- Emergency Plans
- Training Material
Features:
Version Control
Approval Workflow
Read Acknowledgement
Review Dates
Search
Documents must be linkable to:
- Hazards
- Risk Assessments
- Investigations
- CAPAs
- Inspections
- Permits
- Training Records
- Compliance Requirements
Workflow:
Draft
Review
Approve
Publish
Periodic Review

### MODULE 8
ADVANCED ANALYTICS

Build advanced executive reporting.

SCOPE BOUNDARY (resolves the MVP1/MVP2/MVP3 overlap):
MVP 1's evolution table listed "Advanced Analytics" under
MVP 3, but it is delivered HERE in MVP 2. To avoid building
it twice, the boundary is:
- MVP 2 Module 8 = DESCRIPTIVE analytics only: historical
  trends, aggregations, KPI scorecards, heatmaps, rankings,
  drilldowns over MVP 1 + MVP 2 data. No ML, no prediction,
  no natural-language querying.
- MVP 3 = PREDICTIVE / PRESCRIPTIVE intelligence (Safety
  Intelligence Hub, Predictive Risk Engine, Executive Risk
  Intelligence, Copilot). MVP 3 CONSUMES and EXTENDS the
  MVP 2 analytics views -- it must not re-implement them.
Design the MVP 2 aggregation views so MVP 3 can build on
them directly (stable view contracts), not replace them.

Analytics:
- Hazard Trends
- Incident Trends
- Health Exposure Trends
- Training Compliance
- Contractor Performance
- Compliance Performance
- CAPA Closure Rate
Advanced Analytics must consume data
from both MVP 1 and MVP 2 modules.
Analytics must support:
- Site filtering
- Department filtering
- Date filtering
- KPI drilldowns
- Executive scorecards
Provide:
Heatmaps
Trend Graphs
Department Performance Rankings
Leading Indicator Dashboards
Lagging Indicator Dashboards

### DATABASE EXTENSION

Extend existing MVP1 schema.
Create new tables:
occupational_exposures
medical_programs
medical_assessments
health_actions
training_courses
training_records
certifications
competency_matrix
compliance_requirements
compliance_reviews
compliance_evidence
contractors
contractor_employees
contractor_insurance
permits
permit_approvals
permit_closeouts
committee_meetings
committee_actions
documents
document_versions
document_reviews
document_acknowledgements
document_attachments
permit_attachments
training_certificates
medical_documents
contractor_documents

### API DESIGN

Generate:
REST APIs
Validation Rules
DTOs
Repository Interfaces
Endpoints
Error Handling
Audit Logging

### AUDIT LOGGING

All MVP 2 modules must support immutable audit logs.
REUSE the existing MVP 1 audit_logs table and the
audit_row_change() trigger in its 0021-FIXED form
(jsonb-based status comparison), NOT a new audit table.

CRITICAL: many MVP 2 tables have NO status column
(documents, contractors, contractor_insurance,
document_versions, etc.). The ORIGINAL audit trigger
compiled a `new.status` field reference and therefore
made any status-less audited table INSERT-ONLY -- this
is Decisions Ledger section 23.2 / D-audit-1. Attach only
the 0021 form (compares v_after->>'status' vs
v_before->>'status' through jsonb, no row-type field
reference) so status-less MVP 2 tables remain fully
updatable while still audited.

Track:
- User
- Action
- Timestamp
- Before State
- After State
- Site
- Department
Audit logs remain INSERT + SELECT only (no UPDATE/DELETE
at any rank or capability), exactly as MVP 1.

### NOTIFICATIONS EXTENSION (governed)

MVP 2 adds several new notification triggers. The MVP 1
notification_trigger enum (the "D7" set) is a LOCKED,
governed list -- extending it requires a documented
deviation in the Decisions Ledger, exactly as
capa.verification_due was added (Ledger section 18). Do
not add trigger values ad hoc.

New MVP 2 triggers (add to the enum via migration, each
recorded in the Ledger):
- training.expiring / training.expired
- certification.expiring
- permit.expiring / permit.expired
- permit.approval_required
- medical.follow_up_due
- medical.assessment_scheduled
- compliance.review_due
- document.review_due
- document.acknowledgement_required
- committee.meeting_scheduled / committee.action_due

ROUTING RULE (reuse MVP 1 infrastructure, do not invent
a parallel system):
- EVENT-DRIVEN triggers (something a user just did, e.g.
  permit.approval_required, document.acknowledgement_required)
  fire immediately through the existing notify-fanout
  Edge Function.
- TIME-BASED triggers (something that becomes true with the
  passage of time -- every *expiring/expired/due* trigger
  above) MUST be raised by the notify-sweep scheduled cron
  (Ledger section 13), NOT from the app. Reuse its
  once-per-entity-per-day idempotency guard and owner-only
  recipient rule; agree an escalation threshold explicitly
  rather than fanning out to Safety Officers by default.
- The actor is always filtered out of recipients (Ledger
  section 16). Respect RBAC + the new capability tier when
  resolving recipients (e.g. medical.* to health.read_medical
  holders only).

### MOBILE REQUIREMENTS

Support:
Offline Mode
Photo Uploads
GPS
QR Code Scanning
Digital Signatures
Push Notifications
Dark Mode
Tablet Layouts

### DELIVERABLES

Generate:
- Complete MVP 2 Architecture
- Updated ERD
- Updated Database Schema
- API Specifications
- Flutter Folder Structure
- Riverpod Providers
- Repositories
- Use Cases
- Screen Wireframes
- Navigation Flows
- Security Model
- Test Strategy
- Sprint Plan
- Migration Strategy From MVP1
- Deployment Strategy
Do not generate placeholder examples.
Generate production-ready enterprise design outputs.
