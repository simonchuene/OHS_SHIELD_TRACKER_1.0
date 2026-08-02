# OHS Shield Tracker — Notifications (Prompt 15)

> Consolidates the triggers stubbed in Prompts 7–13 into real in-app + FCM delivery. Source of truth: `MVP1_2.md` + `DECISIONS_LEDGER.md`.
>
> **Status:** Draft for human approval. Review-ready (needs `pub get`, `build_runner`, `supabase functions deploy notify-fanout`, Firebase config + `FCM_SERVER_KEY` for push — Prompt 18).

## Files
- server: `supabase/functions/notify-fanout/index.ts`
- dispatcher: `lib/services/notifications/notification_triggers.dart` (stub → real `notify-fanout` invoke; same `fire()` signature)
- domain: `app_notification.dart` (+ `NotificationDeepLink`)
- data: `notification_dto.dart`, `notification_repository.dart`, `fcm_service.dart`
- presentation: `providers/notification_providers.dart`, `screens/notification_center_screen.dart`
- wiring: `/notifications`; tests: `deep_link_test.dart`

## 1. Dispatch pipeline
Modules already call `NotificationTriggers.fire(<D7 trigger>, entityType, entityId)` (Prompts 7/8/8A/9/11/12…). This prompt upgrades that dispatcher from a log-only stub to a **real fire-and-forget invoke** of the **`notify-fanout` Edge Function** — so those existing calls now deliver, with **no caller changes**. `notify-fanout` (service role): resolves recipients, inserts `notifications` rows (client INSERT is denied by RLS), and best-effort pushes via FCM to `device_tokens`.

## 2. Triggers supported
Hazards (`hazard.created`), Incidents (`incident.created`), Risk (`risk.assessed`), Investigations (`investigation.due`), CAPAs (`capa.assigned`, `capa.overdue`), Inspections (`inspection.due`). Dotted client names map to the `notification_trigger` enum (underscore) in the function.

## 3. Recipient resolution & escalation
- `capa.assigned` → the CAPA owner. Default audience → Safety Officer+ (rank ≥3) in the company. Explicit `recipientIds` override.
- **Escalation**: overdue/critical events (from the per-module `*Escalation` rules) fire high-priority triggers (`capa.overdue`, etc.); high/critical notifications sort/style to the top. A scheduled sweep for due/overdue items is a deferred cron Edge Function (DEV) — the fan-out capability is in place.

## 4. In-app + push
- **In-app**: `notifications` table (RLS: recipient-only), Notification Center with unread styling, mark-read/mark-all, and an unread **badge count**.
- **Push (FCM)**: `FcmService` initialises Firebase (best-effort), requests permission, registers the device token in `device_tokens`, and routes taps. Guarded so a missing Firebase config never crashes the app (push stays inactive until Prompt 18 wiring).

## 5. Deep linking
`NotificationDeepLink.routeFor(entityType, entityId)` maps hazard/incident/investigation/corrective_action/inspection → the record route; tapping a notification (in-app or push) marks it read and navigates. Tested.

## 6. Offline
Notifications are persisted server-side, so they load on reconnect; FCM queues pushes for offline devices. Mark-read is online best-effort (read-state reconciles on reconnect).

## 7. Preferences
Trigger-level preferences are a light MVP concern: the UI can mute trigger types locally; **server-side preference enforcement inside `notify-fanout` is a documented future enhancement** (the function currently resolves recipients by role/ownership).

## 8. Self-Check
| Requirement | Handling / test |
|---|---|
| In-app notifications | `notifications` table + Center screen |
| FCM push, `device_tokens` | `FcmService` register + `notify-fanout` push |
| Notification Center | screen + unread badge |
| Deep linking | `NotificationDeepLink` + `deep_link_test` |
| Triggers (7 sources) | dotted→enum map in `notify-fanout` |
| Escalation | high-priority triggers + styling (cron sweep DEV) |
| Offline | server-persisted + load on reconnect |
| Consolidates stubs | `NotificationTriggers` now delivers; callers unchanged |

## 9. Ledger note (pending approval)
- Notifications at `lib/features/notifications`; `notify-fanout` Edge Function (in-app insert + FCM); `NotificationTriggers` upgraded to real dispatch (D7 dotted → enum). Deep-link route map. Preferences = client-side mute (server enforcement DEV); scheduled overdue sweep = cron DEV.

**End of Prompt 15 deliverable.**
