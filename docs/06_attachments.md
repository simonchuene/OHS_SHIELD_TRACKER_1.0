# OHS Shield Tracker — Attachment & Media Management (Prompt 6, shared service)

> Cross-cutting service consumed by Hazard, Incident, Investigation, CAPA, and Inspection. Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `flutter pub get`, `build_runner`, platform camera/location/storage permissions, and the `attachments` Storage bucket from 0008).

## Files (`lib/features/attachments/`)
- domain: `attachment_constants.dart` (limits, path builder, validator), `entities/{attachment_owner_type, gps_location, attachment}.dart`, `repositories/attachment_repository.dart`
- data: `attachment_dtos.dart`, `attachment_repository_impl.dart`, `media_capture_service.dart`, `attachment_upload_queue.dart`
- application: `attachment_use_cases.dart`
- presentation: `providers/attachment_providers.dart`, `widgets/attachment_field.dart`
- core: `PendingUploads` Drift table added to `app_database.dart` (schema v2)
- tests: `test/features/attachments/attachment_rules_test.dart`

## 1. Single API surface (Ledger §3)
`AttachmentUseCases` / `AttachmentRepository`:
`upload(...)` · `listForOwner(type,id)` · `listVersions(attachmentId)` · `preview(attachmentId,{versionId})` · `download(attachmentId,{versionId})` · `delete(attachmentId)`.
Downstream modules embed **one widget** — `AttachmentField(ownerType:, ownerId:)` — for capture/upload/preview/delete/history.

## 2. Storage integration
- Private bucket `attachments`; path `<company_id>/<owner_type>/<owner_id>/<version_uuid>.<ext>` — **matches the Storage RLS (0008)** so tenant isolation holds.
- Limits enforced client-side (`AttachmentValidator`) and by DB CHECK (0004): **≤ 20 MB**, `image/jpeg` · `image/png` · `application/pdf`.
- Preview via time-limited signed URL (1 h); download via `storage.download`.

## 3. Version history (never delete)
- First upload → `attachments` row + `attachment_versions` v1 (active).
- Re-upload to the same attachment → prior versions set `is_active=false`, new version `vN+1` (active). **No history is ever deleted.**
- `delete()` is a **logical** delete (`attachments.is_active=false`); versions remain.

## 4. Camera + GPS capture
`MediaCaptureService` — `capturePhoto()` (camera), `pickImage()` (gallery), `pickPdf()` (file picker), each returning `CapturedMedia` with optional `GpsLocation`. `currentGps()` is best-effort (permission-guarded, never blocks capture). Reused across Hazard/Incident/Inspection forms per the Master Prompt.

## 5. Offline queuing
- When offline, `AttachmentController.add` copies the file to persistent storage and enqueues a `PendingUploads` row instead of failing.
- `AttachmentUploadQueue` drains on reconnect (D5 backoff reused), uploading via the repository and deleting the local temp on success. `pendingUploadCountProvider` surfaces the backlog.

## 6. Self-Check

### 6.1 Version-history invariant
| Step | attachments | attachment_versions |
|---|---|---|
| upload A (new) | 1 row active | v1 active |
| upload A (revision) | same row (file_name/type updated) | v1 **inactive**, v2 active |
| delete A | row `is_active=false` | v1, v2 **retained** (unchanged) |

⇒ history is append-only; supersede = flag, never delete. ✔

### 6.2 Constraints honoured
| Rule | Enforced |
|---|---|
| ≤ 20 MB | `AttachmentValidator` + DB CHECK `file_size <= 20971520` |
| JPG/PNG/PDF only | `AttachmentLimits` + DB CHECK on content_type |
| Tenant isolation | path `foldername[1]=company_id` = Storage RLS (0008) |
| Owner linkage (5 entities) | `AttachmentOwnerType` ↔ `attachment_owner_type` enum |

### 6.3 Tests
`attachment_rules_test` — validator (type/size), path builder (matches RLS), owner-type round-trip.

## 7. Ledger note (pending approval)
- **§3 Attachment API surface:** `upload · listForOwner · listVersions · preview · download · delete` (interface `AttachmentRepository`, facade `AttachmentUseCases`).
- **§3 Reusable camera + GPS widget:** `AttachmentField` (`lib/features/attachments/presentation/widgets/attachment_field.dart`) backed by `MediaCaptureService`.
- **Offline:** `PendingUploads` Drift table (app_database schema v2) + `AttachmentUploadQueue` (D5 backoff).

**End of Prompt 6 deliverable.**
