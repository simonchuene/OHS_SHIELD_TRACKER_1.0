# OHS Shield Tracker — Risk Assessment (Prompt 9)

> Consumes shared `RiskBand` (Prompt 7), attachments/sync as needed, and updates hazard risk. Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `pub get`, `build_runner`, migration `0014`).

## Files
- server: `supabase/migrations/0014_risk_triggers.sql` (audit + `hazards.risk_level` sync)
- domain: `risk_calculator.dart`, `entities/risk_assessment.dart`, `repositories/risk_assessment_repository.dart`
- data: `risk_assessment_dto.dart`, `risk_assessment_repository_impl.dart`
- application: `risk_use_cases.dart`
- presentation: `providers/risk_providers.dart`, `widgets/risk_matrix.dart`, `screens/risk_assessment_screen.dart`
- wiring: route `/hazards/:id/assess`; hazard detail "Assess risk" + latest-risk section
- tests: `test/features/risk/risk_calculator_test.dart`

## 1. Calculator & matrix
- **Score = Likelihood × Severity** (each 1–5); band per the locked table via the single shared `RiskBand.fromScore`. The screen computes **live** as factors change and shows a colour-coded score chip + a 5×5 **Risk Matrix** (each cell coloured by its band; current cell outlined; tap to set).
- Colours use the locked tokens (Green/Amber/Red for High/Red for Critical) via `hazardRiskColor`.

## 2. Validation & residual risk
- Likelihood/Severity must be 1–5. **Residual** is optional but all-or-nothing (both factors or neither), also 1–5. Residual score/band shown live.

## 3. Persistence, offline & hazard sync
- `risk_score`/`risk_band` are **GENERATED** columns — the client never sends them (payload excludes them; DB computes on insert). Locally the entity computes score/band via `RiskCalculator` for immediate display.
- **Offline draft support:** save enqueues via the outbox (entity `risk_assessment`); syncs LWW on reconnect.
- On insert, trigger `0014` mirrors the new band onto `hazards.risk_level`, so the hazard card colour + dashboard heatmap stay current. Audit trigger records the assessment.

## 4. CAPA priority default
`RiskCalculator.defaultCapaPriority(band)` maps Critical→critical · High→high · Medium→medium · Low→low (Master Prompt Risk DoD — the level drives CAPA priority defaults; consumed by CAPA in Prompt 11).

## 5. Self-Check — reachable score → band → colour (no gaps/overlaps)

Only 14 products are reachable from 1–5 × 1–5; the other integers in 1–25 can never occur.

| Score | Band | Colour token |
|---|---|---|
| 1, 2, 3, 4, 5 | Low | Primary Green |
| 6, 8, 9, 10, 12 | Medium | Warning Amber |
| 15, 16 | High | Critical Red |
| 20, 25 | Critical | Critical Red (full intensity) |
| **7, 11, 13, 14, 17, 18, 19, 21, 22, 23, 24** | *unreachable* | — (never produced by L×S) |

Every reachable product maps to exactly one band. `risk_calculator_test` proves: all 25 L×S combos band correctly; the reachable set equals the 14 values; the 11 impossible values never occur; boundaries (5/6/12/13/17/18/25) hold. The DB generated column uses the identical CASE (Prompt 2A §5.3), so client and server agree.

## 6. Ledger note (pending approval)
- Risk module at `lib/features/risk`; `RiskCalculator` (score/band/reachable/CAPA-priority) is the single scoring authority (mirrors the DB generated column). Trigger `0014` syncs `hazards.risk_level`. `risk.assessed` notification fired on save.

**End of Prompt 9 deliverable.**
