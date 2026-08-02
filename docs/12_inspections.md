# OHS Shield Tracker — Inspections (Prompt 12)

> Checklist-based inspections; a failed item auto-creates a Hazard AND a CAPA. Integrates with Hazards, CAPAs, and Dashboard metrics. Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `pub get`, `build_runner`, migration `0015`, `supabase functions deploy inspection-item-fail`).

## Files
- server: `supabase/migrations/0015_inspection_audit.sql`; `supabase/functions/inspection-item-fail/index.ts`
- domain: `entities/{inspection_enums, inspection}.dart`, `checklist_templates.dart`, `inspection_scoring.dart`, `repositories/inspection_repository.dart`
- data: `inspection_dtos.dart`, `inspection_repository_impl.dart`
- application: `inspection_use_cases.dart`
- presentation: `providers/inspection_providers.dart`, `screens/{inspection_list, inspection_new, inspection_run}_screen.dart`
- wiring: `/inspections`, `/inspections/new`, `/inspections/:id/run`
- tests: `inspection_scoring_test.dart`

## 1. Checklist engine
`ChecklistTemplates` seeds a default prompt list per type (Housekeeping · Fire Safety · PPE · Vehicle · Equipment). Creating an inspection materialises those as `inspection_items`. The run screen marks each **Pass / Fail / N/A**, with an optional note on fail; a progress bar tracks completion.

## 2. Scoring
`InspectionScoring.scorePercent` = % pass among **scorable** items (pass+fail; N/A excluded), 1-dp; null when nothing scorable. Computed and stored on submit. `allAnswered` gates submission.

## 3. Hazard + CAPA generation (the key rule)
On **Submit**, for every `fail` item the client invokes the **`inspection-item-fail` Edge Function**, which under the service role **atomically creates a Hazard and a CAPA** linked to the item (`inspection_items.generated_hazard_id` / `generated_capa_id`) — **idempotent** (skips if already generated). The CAPA carries `inspection_item_id` (the 4th source in `CapaSourceRef`). Then the inspection is set `submitted` with its score. Audit rows for the new hazard/CAPA come from their table triggers.

## 4. Offline & integration
- Create + item answers go through the offline outbox (entities `inspection`, `inspection_item`; inspection enqueued before items so the FK order holds on sync).
- **Submit requires connectivity** (server-side generation) — surfaced clearly.
- Generated hazards/CAPAs appear in the Hazards list and Actions board (providers invalidated on submit); scores feed Dashboard metrics (Prompt 13).

## 5. Self-Check
| Rule | Enforced / test |
|---|---|
| Failed item → Hazard + CAPA | `inspection-item-fail` (atomic, idempotent) |
| CAPA linked via inspection_item_id | Edge Function insert; `CapaSourceRef` (4th source) |
| Scoring excludes N/A | `inspection_scoring_test` |
| Submit needs all items answered | `allAnswered` + controller guard |
| Conduct = Supervisor+ | RLS + Edge Function rank check |
| Every type has a checklist | `inspection_scoring_test` |
| Offline capture | outbox (inspection + items) |

## 6. Ledger note (pending approval)
- Inspections module at `lib/features/inspections`; `inspection-item-fail` Edge Function (auto hazard+CAPA on fail, idempotent); checklist templates per type; scoring excludes N/A; submit online-only. Audit triggers on inspections/inspection_items (0015).

**End of Prompt 12 deliverable.**
