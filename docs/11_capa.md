# OHS Shield Tracker — CAPA (Prompt 11)

> Corrective/Preventive Actions. Consumes attachments (evidence), sync, audit (0013). Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `pub get`, `build_runner`).

## Files
- domain: `entities/{capa_enums, corrective_action}.dart`, `capa_workflow.dart`, `capa_escalation.dart`, `repositories/capa_repository.dart`
- data: `capa_dto.dart`, `capa_repository_impl.dart`
- application: `capa_use_cases.dart`
- presentation: `providers/capa_providers.dart`, `widgets/capa_ui.dart`, `screens/{capa_board, capa_detail}_screen.dart`
- wiring: Actions tab `/capa` (Kanban+List) + `/capa/:id`; created from hazard/incident/investigation (+ inspection in Prompt 12)
- tests: `capa_workflow_test.dart`, `capa_escalation_test.dart`

## 1. Views
- **Kanban** — columns per status (Created · Assigned · In Progress · Verification · Closed), cards grouped by column; **List** toggle in the app bar. Cards show description, priority pill, due date, and an overdue flag.

## 2. Workflow, assignment, verification, closure
`CapaWorkflow` (pure): Created → Assigned → In Progress → Verification → Closed, forward-only.
- **Create/Assign = Supervisor+**; **Verification & Closed = Safety Officer+** (aligned to the RLS `capa_update` WITH CHECK, 2B).
- **Assign** requires an owner; **Close** requires **verification evidence** (≥1 active attachment) — checked in the workflow guard; RLS enforces the role authoritatively. Closing stamps `verified_by`/`verified_at`/`closed_at`. Close needs connectivity (to verify evidence); other steps work offline via the outbox.
- Owner assignment + due date set from the detail screen (owner picker uses company `user_profiles`).

## 3. Source linkage (all four back-references)
`CapaSourceRef` enforces **exactly one** of hazard / incident / investigation / inspection_item (mirrors the DB CHECK). Created from hazard detail, incident detail (8A), investigation detail (10), and failed inspection items (Prompt 12). `source` getter resolves the origin for display.

## 4. Escalation
`CapaEscalationRules.evaluate` (due-date based): closed → none; critical priority → critical; past due → overdue; within 2 days → due-soon. Overdue/critical → `capa.overdue` notification (stub; Prompt 15). Assignment fires `capa.assigned`.

## 5. Offline & audit
Create/update via the offline outbox (entity `corrective_action`); audited by the `0013` trigger (`corrective_action.*`). Board/detail merge server + cache.

## 6. Self-Check
| Rule | Enforced / test |
|---|---|
| Assignment requires owner | `CapaWorkflow` + `capa_workflow_test` |
| Verification & Closed = SO+ | `minRankFor` + RLS; test |
| Close requires evidence | guard + `capa_workflow_test` |
| Priority default from risk band | `RiskCalculator.defaultCapaPriority` (Prompt 9), used when creating from hazard risk |
| Source = exactly one | `CapaSourceRef.isValid` + DB CHECK |
| Escalation (overdue/critical) | `capa_escalation_test` |

## 7. Ledger note (pending approval)
- CAPA module at `lib/features/capa`; `CapaWorkflow` (assign⇒owner; verification/closed⇒SO+; close⇒evidence); `CapaSourceRef` four-way linkage; Kanban+List board on the Actions tab; `capa.assigned`/`capa.overdue` triggers.

**End of Prompt 11 deliverable.**
