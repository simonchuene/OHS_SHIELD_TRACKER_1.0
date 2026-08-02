# OHS Shield Tracker — Audit Log Viewer (Prompt 16)

> Read-only compliance visibility over `audit_logs`. Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `pub get`, `build_runner`).

## Files
- domain: `audit_log_entry.dart` (+ `AuditDiff`), `audit_filter.dart`
- data: `audit_log_dto.dart`, `audit_repository.dart`
- presentation: `providers/audit_providers.dart`, `screens/{audit_list, audit_detail}_screen.dart`
- wiring: `/audit`, `/audit/:id` (Administrator/Manager/Safety-Officer only)
- tests: `audit_diff_test.dart`

## 1. Read-only by construction
`AuditRepository` exposes **only** `list` and `get` (SELECT). There is **no** create/update/delete method, and none can be added meaningfully because RLS blocks all mutation on `audit_logs` (2B: policy grants SELECT to rank ≥3; INSERT/UPDATE/DELETE revoked). The module is purely compliance visibility.

## 2. RBAC
Access is limited to **Safety Officer / Manager / Administrator**:
- **RLS** `audit_select` (rank ≥3) is authoritative.
- The **router guard** redirects rank < 3 away from `/audit` (UX; already added in Prompt 5A wiring).

## 3. Screens
- **List**: filter/search by **action** (ilike), **entity type** (chips), **user**, and **date range**; newest first, capped at 200.
- **Detail**: header (action · entity · actor · timestamp) + **Before → After field diff**.

## 4. Diff
`AuditDiff.compute(before, after)` (pure): compares the two JSON states, emits per-field `FieldChange` (before/after, added/removed), and ignores housekeeping noise (`updated_at`, `version`). Tested for changed/added/removed/insert/no-change cases.

## 5. Self-Check
| Requirement | Handling / test |
|---|---|
| Read-only (no mutation path) | repo has only `list`/`get`; RLS blocks writes (2B) |
| SO/Manager/Admin only | RLS `audit_select` (≥3) + router guard |
| Filter by user/action/date/entity | `AuditFilter` + repo query |
| Before/After diff | `AuditDiff` + `audit_diff_test` |
| Actor names resolved | via `companyUsersProvider` map |

## 6. Ledger note (pending approval)
- Audit Viewer at `lib/features/audit`; read-only (`list`/`get`); `AuditDiff` before/after (ignores updated_at/version); SO/Manager/Admin via RLS + router guard. Completes MVP Module 12.

**End of Prompt 16 deliverable.**
