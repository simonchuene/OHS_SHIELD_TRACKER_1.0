// path: lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/router/app_router.dart';
import 'package:ohs_shield_tracker/core/theme/app_theme.dart';
import 'package:ohs_shield_tracker/features/attachments/presentation/providers/attachment_providers.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';

/// Root application widget. Wires the router and the light/dark themes built
/// from the locked design tokens. Localization is out of scope for MVP1 but the
/// MaterialApp is structured so `localizationsDelegates`/`supportedLocales` can
/// be added later without restructuring (Master Prompt Localization note).
class OhsShieldApp extends ConsumerWidget {
  const OhsShieldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    // Start the offline sync engine + attachment upload queue for the app's
    // lifetime (they push the local outbox to Supabase when connectivity allows).
    ref.watch(syncEngineProvider);
    ref.watch(attachmentUploadQueueProvider);
    return MaterialApp.router(
      title: 'OHS Shield Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
