# OHS Shield Tracker — Flutter Foundation (Prompt 4A)

> Project scaffolding only. **No business features. No offline sync engine** (Prompt 4B). Source of truth: `MVP1_1.md` + `DECISIONS_LEDGER.md`. Emitted as real files (`// path:` headers).
>
> **Status:** Draft for human approval. Review-ready first implementation (needs `flutter pub get` + `dart run build_runner build` + real `--dart-define` secrets + Inter font files before it runs).

## 1. Folder Structure

```
lib/
├── main.dart                      # entrypoint: init Supabase, ProviderScope overrides
├── app.dart                       # MaterialApp.router + themes
├── core/
│   ├── config/app_config.dart     # env via --dart-define (no secrets in repo)
│   ├── auth/session_providers.dart# session presence + role rank (full auth = Prompt 5)
│   ├── error/{failure,result,guard,exceptions}.dart
│   ├── logging/logger_service.dart
│   ├── providers/core_providers.dart  # DI: supabase, secure storage, connectivity, logger
│   ├── router/{routes,app_router}.dart
│   └── theme/{app_colors,app_typography,app_spacing,app_radii,ohs_theme_extension,app_theme}.dart
├── shared/
│   └── widgets/{app_shell,placeholder_screen,duotone_icon_badge,...}.dart
├── features/                      # one folder per module (Prompts 5–16)
│   └── <feature>/{presentation, application, domain, data}/
├── services/                      # cross-cutting services (attachments, notifications, sync, audit)
└── repositories/base_repository.dart  # shared repository base/contracts
```

Matches the Master Prompt root (`core, shared, features, services, repositories` + `app.dart`), with the confirmed feature-internal pattern (D8).

## 2. Feature Structure (D8 — confirmed)

Each feature is a vertical slice of Clean Architecture:

```
features/<feature>/
├── presentation/   # screens, widgets, Riverpod notifiers/providers
├── application/    # use cases (one intent each)
├── domain/         # entities, value objects, repository interfaces, policies
└── data/           # repository impls, DTOs, mappers, local/remote data sources
```

Dependency rule: `presentation → application → domain`; `data` implements `domain` interfaces. Domain has zero framework imports.

## 3. Dependency Injection Strategy

- **Riverpod is the DI container.** Infrastructure singletons are providers in `core/providers/core_providers.dart`.
- `main.dart` performs async init (Supabase) then **overrides** `appConfigProvider` + `supabaseClientProvider` in `ProviderScope` — no service locator, fully testable via provider overrides.
- Feature providers (Prompt 5+) use **`@riverpod` code-gen** and depend on core providers via `ref.watch`.

## 4. State Management Pattern

- **Code-generated Riverpod** (`riverpod_generator`) for feature state.
- **Provider naming convention (Ledger):**
  - Repository providers: `<feature>RepositoryProvider` (e.g. `hazardRepositoryProvider`).
  - Async screen/list state: `@riverpod` **Notifier** classes named `<Feature><Thing>Notifier` (e.g. `HazardListNotifier`) exposing `AsyncValue<T>`.
  - Derived/computed values: plain `@riverpod` functions.
  - Core infrastructure uses hand-written `Provider`s (no codegen) to stay build-runner-free at the foundation layer.
- Screens are `ConsumerWidget`/`ConsumerStatefulWidget`; state flows one-way via `AsyncValue` with `.when(data/loading/error)` mapped to the Prompt 3 loading/error states.

## 5. Repository Pattern

- Domain declares `abstract interface class <X>Repository`; data provides the impl extending `BaseRepository`.
- `BaseRepository.run(...)` funnels every call through `guardAsync`, so infrastructure exceptions become `Failure`s uniformly.
- Repositories return `Future<Result<T>>` (never throw to callers).
- Offline-capable repositories (Prompt 4B onward) read/write the Drift mirror first, then enqueue sync.

## 6. DTO Strategy (Ledger)

- DTOs live in `data/`, suffixed `Dto`, generated with `freezed` + `json_serializable` (`fromJson`/`toJson`), field names matching PostgREST/snake_case columns via `@JsonKey`.
- **Mapping convention:** `XDto.toEntity()` and `XEntity.toDto()` (or `toInsert()/toUpdate()` maps for PostgREST). Entities are immutable `freezed` classes in `domain/` with no JSON concerns.
- Local Drift row classes ↔ entities via the same mapper extensions (Prompt 4B).

## 7. Error Handling Strategy

- `Result<T>` = `Ok<T>` | `Err<T>` (sealed, dependency-free) — see `core/error/result.dart`.
- `Failure` hierarchy: `Network`, `Auth`, `Server`, `Cache`, `Validation`, `Permission`, `Unknown`.
- `guardAsync` maps `AuthException`/`PostgrestException` (incl. `42501` → `PermissionFailure`)/`StorageException`/`SocketException`/`TimeoutException` → `Failure`.
- Presentation renders failures via the Prompt 3 error states; `ValidationFailure.fieldErrors` drives inline field errors.

## 8. Logging Strategy

- `LoggerService` interface (facade over `logger`); `AppLogger` uses `ProductionFilter` in prod, `DevelopmentFilter` otherwise.
- **No PII in logs (POPIA):** callers log IDs, never witness/injured-party names/contacts.
- Injected via `loggerProvider`; consumed by `guardAsync` and repositories.

## 9. Theming Strategy (Light + Dark)

- Tokens split into `AppColors` / `AppTypography` / `AppSpacing` / `AppRadii` (locked values).
- Signature tokens that don't fit Material live in `OhsThemeExtension` (risk-band colours, hero gradient, brand accent, duotone opacity) — read via `Theme.of(context).extension<OhsThemeExtension>()`, auto-adapting light/dark.
- `AppTheme.light/dark` build Material 3 `ThemeData`: card radius 12, CTA radius 16, input radius 12 (Item 2), Inter font, tabular-numeral helper for metrics (Item 6).
- Dark mode keeps identical hierarchy; only surfaces invert; semantic hues get AA-safe lightened text tints (never a meaning change).

## 10. Navigation Strategy

- GoRouter via `goRouterProvider`; paths centralised in `Routes`.
- `StatefulShellRoute.indexedStack` hosts the four permanent tabs behind the **floating pill nav** (`AppShell`, Item 8); MVP2/3 modules mount under **More** without touching the shell.
- **Auth redirect guard** (no session → `/login`; session on auth route → `/dashboard`) with `refreshListenable` bound to Supabase auth changes.
- **Role guard** on `/audit` (rank ≥ 3); RLS remains authoritative.
- Deep-link builders (`Routes.hazardDetail(id)` etc.) for notification taps (Prompt 15).

## 11. Shared Component Strategy

- Reusable, theme-driven widgets in `shared/widgets/`, each mapping to a Prompt 3 component.
- Delivered now: `AppShell` (pill nav), `DuotoneIconBadge` (Item 5), `PlaceholderScreen`.
- Planned (built as first consumed, per Prompt 3 §2): `AppCard`, `HeroCard`, `PrimaryButton`, `StatusPill`, `KpiTile`, `PriorityListRow`, `RiskCompass`, `ComplianceCheckmarkBadge`, `AvatarRing`, `SyncStatusBadge`, `EmptyState`, `LoadingSkeleton`. Each reads locked tokens + `OhsThemeExtension` so styling stays consistent across MVP1/2/3.

## 12. Self-check

| 4A requirement | Delivered |
|---|---|
| Folder + feature structure | ✅ §1–2 |
| DI strategy | ✅ Riverpod + overrides |
| State mgmt pattern | ✅ codegen Riverpod + naming |
| Repository pattern | ✅ BaseRepository + Result |
| DTO strategy | ✅ freezed/json + mappers |
| Error handling | ✅ Result/Failure/guard |
| Logging | ✅ LoggerService |
| Theming light+dark | ✅ tokens + ThemeExtension |
| Navigation | ✅ GoRouter + shell + guards |
| Shared components | ✅ strategy + examples |
| No business features / no sync engine | ✅ placeholders only |
| Icon by path, never redrawn | ✅ pubspec asset only |

## 13. Decisions captured for the Ledger (pending approval)

| Slot | Value |
|---|---|
| Flutter SDK pinned to | **3.24.5** (constraint `>=3.24 <4.0`) |
| Provider naming convention | `<feature>RepositoryProvider`; `<Feature><Thing>Notifier`; codegen `@riverpod`; core = plain providers |
| DTO ↔ Entity convention | `Dto` suffix (freezed+json) in `data/`; `toEntity()`/`toDto()` mappers; freezed entities in `domain/` |
| Feature folder structure | `features/<f>/{presentation, application, domain, data}` (D8 confirmed) |
| Secure storage | `flutter_secure_storage` (encryptedSharedPreferences / Keychain first_unlock) |
| Error/Result convention | `Result<Ok/Err>` + `Failure` hierarchy + `guardAsync` |

**End of Prompt 4A deliverable.**
