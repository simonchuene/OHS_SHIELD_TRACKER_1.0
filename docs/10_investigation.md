# OHS Shield Tracker — Investigation (Prompt 10)

> Root-cause analysis originating from a Hazard OR an Incident. Consumes shared attachments/sync. Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `pub get`, `build_runner`; audit trigger already added in 0013).

## Files
- domain: `entities/{investigation_enums, investigation_analysis, investigation}.dart`, `investigation_workflow.dart`, `repositories/investigation_repository.dart`
- data: `investigation_dto.dart`, `investigation_repository_impl.dart`
- application: `investigation_use_cases.dart`
- presentation: `providers/investigation_providers.dart`, `widgets/{five_whys_editor, fishbone_editor, investigation_timeline}.dart`, `screens/{investigation_list, investigation_detail}_screen.dart`
- wiring: routes `/investigations`, `/investigations/:id`; hazard detail "Start investigation"; incident detail already generates one (8A)
- tests: `investigation_workflow_test.dart`, `investigation_analysis_test.dart`

## 1. Domain
- **Methods**: 5 Whys · Fishbone. **Status**: Open → In Progress → Pending Review → Completed.
- **Analysis** (JSONB): a 5-Whys chain and a Fishbone 6M category map, both persisted; the method chooses which the UI edits.
- **Origin**: exactly one of `hazard_id` / `incident_id` (DB CHECK); `create` rejects zero-or-both.

## 2. Components
- **5 Whys editor**: ordered, drill-down "Why?" steps (add/remove).
- **Fishbone editor**: causes grouped by People/Process/Equipment/Environment/Materials/Management.
- **Timeline**: derived from the investigation's own timestamps + status (no `audit_logs` read — that's SO+ and lives in the Audit Viewer, Prompt 16).
- **Evidence**: shared `AttachmentField` (owner = investigation).

## 3. Workflow & business rules
- Forward-only, adjacent; **conducting = Supervisor+**. **Completing requires a root cause AND recommendations** (enforced in `InvestigationWorkflow.canTransition`; the detail screen saves edits first so the guard sees the latest text, and disables editing once Completed).
- **Ownership**: `investigator_id` (set on create).
- **CAPA generation**: `generateCapa` inserts a `corrective_actions` row with `investigation_id` (typed FK; managed fully in Prompt 11).
- **Hazard & Incident linkage**: both back-references supported; created from hazard detail or via incident `generateInvestigation` (8A).

## 4. Offline & audit
Create/update/advance go through the offline outbox (entity `investigation`) — LWW on reconnect. Every write is audited via the `0013` trigger (`investigation.*`).

## 5. Self-Check
| Rule | Enforced / test |
|---|---|
| Origin = exactly one (hazard/incident) | repo `create` guard + DB CHECK |
| Root cause mandatory to complete | `InvestigationWorkflow` + `investigation_workflow_test` |
| Recommendations mandatory to complete | same |
| Conduct = Supervisor+ | workflow rank gate + RLS |
| Analysis persists (5 Whys + Fishbone) | `investigation_analysis_test` (round-trip) |
| CAPA generation support | `generateCapa` (typed FK) |

## 6. Ledger note (pending approval)
- Investigation module at `lib/features/investigations`; `InvestigationWorkflow` (complete guard: root cause + recommendations); analysis JSONB (5 Whys + Fishbone). Reuses `TransitionCheck`. Timeline is entity-derived (audit timeline is Audit Viewer, Prompt 16).

**End of Prompt 10 deliverable.**
