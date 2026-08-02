# OHS Shield Tracker — Offline Sync Engine (Prompt 4B)

> Dedicated subsystem built on the Prompt 4A foundation. No business features. Source of truth: `MVP1_1.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `build_runner` for `app_database.g.dart`).

## Files

| File | Role |
|---|---|
| [core/database/app_database.dart](../lib/core/database/app_database.dart) | Drift DB: `SyncQueueEntries` (outbox, mirrors server `sync_queue`) + `CachedRecords` (offline cache + per-record status) |
| [services/sync/sync_models.dart](../lib/services/sync/sync_models.dart) | `SyncStatus`, `SyncOperation`, `ConflictStrategy`, entity→strategy/table registry (D4) |
| [services/sync/retry_policy.dart](../lib/services/sync/retry_policy.dart) | Exponential backoff + jitter (D5) |
| [services/sync/conflict_resolver.dart](../lib/services/sync/conflict_resolver.dart) | Two-tier resolution (D4), pure/testable |
| [services/sync/offline_mutation_service.dart](../lib/services/sync/offline_mutation_service.dart) | Queueing hooks for Hazard/Incident/Inspection/CAPA |
| [services/sync/sync_engine.dart](../lib/services/sync/sync_engine.dart) | Orchestration: connectivity → drain → reconcile |
| [services/sync/sync_providers.dart](../lib/services/sync/sync_providers.dart) | Riverpod DI + lifecycle + per-record status stream |
| [test/services/sync/*](../test/services/sync/) | Unit tests for resolver + retry |

## 1. Drift tables mirroring `sync_queue`

`SyncQueueEntries` mirrors the server `sync_queue` (id, company_id, user_id, entity_type, entity_id, operation, payload, base_version, status, attempts, next_attempt_at, last_error, timestamps). `CachedRecords` stores an offline-readable JSON snapshot per `(entityType, entityId)` plus `version` and `syncStatus` — this is what the UI badge watches. (Design note: a single generic cache table powers the engine + status now; feature-specific typed Drift tables can be added per feature prompt if complex local queries demand it.)

## 2. Orchestration

`SyncEngine.start(connectivityStream)` subscribes to `connectivityStatusProvider`; each transition to **online** triggers `drain()`. `drain()` pulls **due** pending entries (`next_attempt_at <= now`) oldest-first and processes them **sequentially** (FIFO preserves create-before-update ordering). A `_running` guard prevents overlapping drains. `syncNow()` re-arms `failed` entries and drains (pull-to-refresh / failed-badge tap).

Per entry: mark `syncing` → run op → on success reconcile cache from the authoritative server row + delete queue entry → on failure schedule retry or mark `failed`.

## 3. Conflict resolution (D4 — two-tier)

| Entity | Strategy |
|---|---|
| hazard, incident, risk_assessment, investigation, inspection | **Last-Write-Wins + audit trail** |
| corrective_action, inspection_item | **Field-level merge** |

- **Detection:** each update carries `base_version`. Conflict = `serverRow.version != base_version`.
- **LWW:** whole-row; newer `updated_at` wins. Local newer → `ApplyLocal`; server newer → `AcceptServer` (local change dropped, cache refreshed). The applied write is audit-logged server-side; accept-server is logged locally.
- **Field-merge:** the offline editor's changed fields (the diff) are PATCHed — untouched fields keep the server value automatically; same-field conflict resolves to the client value (defined tie-break).
- `inspection` (header) defaults to LWW; `inspection_item` (independent lines) uses field-merge — matches D4's intent (independent checklist edits).

## 4. Retry (D5)

Exponential backoff: base 2 s · factor 2 · **max 5 attempts** · cap 60 s · ±20% jitter. Retryable = network/timeout/5xx/429. Non-retryable = RLS denial (`42501`) and 4xx validation → straight to `failed`. Exhausted retries → `failed` (user-retryable via `syncNow`).

## 5. Sync status model (per record)

`pending → syncing → synced` on success; `→ failed` on exhaustion/non-retryable. Surfaced reactively via `recordSyncStatusProvider((type:…, id:…))` → the Prompt 3 §9.4 badge. `pendingSyncCountProvider` drives the global offline banner.

## 6. Queueing hooks (consumed by Prompts 7/8A/11/12)

`OfflineMutationService`:
- `enqueueCreate(entityType, entityId, data, companyId, userId)` — client mints the UUID, writes cache (pending) + insert queue entry.
- `enqueueUpdate(entityType, entityId, changedFields, baseVersion, …)` — stores the **diff** + base version (drives merge/LWW).
- `enqueueDelete(entityType, entityId, baseVersion, …)`.

Feature repositories call these for offline-capable writes, then return immediately; the engine syncs later.

---

## 7. Self-Check — end-to-end walkthroughs

### 7.1 Create (offline → online)
1. Employee reports a hazard offline. Repo calls `enqueueCreate('hazard', H1, {...}, …)`.
2. `CachedRecords[H1]` = data, version 0, **pending**. `SyncQueueEntries` += `{op:insert, entity:H1, base_version:null, status:pending}`. UI badge: **pending**.
3. Connectivity returns → `drain()` → entry → `syncing`.
4. `INSERT hazards {…}` → server returns row `{version:0,…}`. `_reconcile` sets cache **synced**, queue entry deleted.
5. **Final:** queue empty; `CachedRecords[H1]` synced @ version 0. Badge: **synced**.

### 7.2 Update (no conflict)
1. Supervisor edits H1 title offline from `base_version 0`. `enqueueUpdate('hazard', H1, {title:'New'}, 0)`.
2. Cache merged (title=New), **pending**; queue += `{op:update, diff:{title}, base_version:0}`.
3. Online → drain → fetch server H1 `{version:0}`. `version(0)==base(0)` → **no conflict** → `ApplyLocal({title})`.
4. `PATCH hazards SET title WHERE id=H1` → trigger bumps to version 1 → returns row. Cache **synced** @ version 1; entry deleted.
5. **Final:** server + cache both `title='New'`, version 1.

### 7.3 Conflicting update (LWW)
1. Offline, Supervisor A edits H1 description from `base_version 1` at 10:00. Queue += `{diff:{description:'A'}, base_version:1}`; cache pending.
2. Meanwhile Manager B (online) edits H1 → server row now `version 2`, `updated_at 10:05`, `description:'B'`.
3. A reconnects → drain → fetch server `{version:2, updated_at:10:05}`. `version(2)!=base(1)` → **conflict**; hazard = LWW.
4. Compare timestamps: server `updated_at 10:05` **newer** than A's local edit (10:00) → `AcceptServer`.
5. Cache refreshed to server row (`description:'B'`, version 2), status **synced**; A's change dropped; event logged. Had A's edit been newer, `ApplyLocal` would PATCH `description:'A'` → version 3.
6. **Final (this timeline):** single converged record `description:'B'`, version 2; no lost-update corruption, resolution recorded.

> Field-merge variant (CAPA): if A changes `status` and B changed `owner_id`, A's `status` diff PATCHes onto B's row — both survive (field-level merge), version bumps once more.

## 8. Decisions captured for the Ledger (pending approval)

| Slot | Value |
|---|---|
| Conflict resolution rule | D4 confirmed as implemented; `inspection` header → LWW, `inspection_item` → field-merge |
| Retry/backoff policy | D5 implemented (base 2s ×2, max 5, cap 60s, ±20% jitter) |
| Local Drift tables | `SyncQueueEntries` (outbox mirror) + `CachedRecords` (generic cache + per-record status) |
| Sync status states | pending · syncing · synced · failed (no deviations) |

**End of Prompt 4B deliverable.**
