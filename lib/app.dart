// path: lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/router/app_router.dart';
import 'package:ohs_shield_tracker/core/theme/app_theme.dart';
import 'package:ohs_shield_tracker/features/attachments/presentation/providers/attachment_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';

/// Root application widget. Wires the router and the light/dark themes built
/// from the locked design tokens. Localization is out of scope for MVP1 but the
/// MaterialApp is structured so `localizationsDelegates`/`supportedLocales` can
/// be added later without restructuring (Master Prompt Localization note).
class OhsShieldApp extends ConsumerStatefulWidget {
  const OhsShieldApp({super.key});

  @override
  ConsumerState<OhsShieldApp> createState() => _OhsShieldAppState();
}

class _OhsShieldAppState extends ConsumerState<OhsShieldApp> {
  /// User id this device's push token was last registered for. Guards against
  /// re-registering on every rebuild, and forces a fresh registration when a
  /// different user signs in on the same device.
  String? _pushRegisteredFor;

  /// Lets a foreground push raise a banner from outside any widget's context.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Android suppresses its own notification while the app is in focus, so a
  /// push arriving during use is shown in-app instead.
  void _showForegroundNotification(String title, String body, String? route, GoRouter router) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        action: route == null
            ? null
            : SnackBarAction(label: 'View', onPressed: () => router.go(route)),
      ),);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    // Start the offline sync engine + attachment upload queue for the app's
    // lifetime (they push the local outbox to Supabase when connectivity allows).
    ref.watch(syncEngineProvider);
    ref.watch(attachmentUploadQueueProvider);

    // Register this device for push once the user is known. This must wait for
    // sign-in: `registerForPush` no-ops without a user, and the `device_tokens`
    // RLS policy requires `user_id = auth.uid()` + a matching company, so an
    // anonymous write would be rejected. Runs post-frame so `build` stays free
    // of side effects; the id guard makes repeat builds a no-op.
    final userId = ref.watch(currentUserProvider).valueOrNull?.id;
    if (userId != _pushRegisteredFor) {
      _pushRegisteredFor = userId;
      if (userId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(notificationControllerProvider.notifier).registerForPush(
                router.go,
                onForegroundMessage: (title, body, route) =>
                    _showForegroundNotification(title, body, route, router),
              );
        });
      }
    }

    return MaterialApp.router(
      title: 'OHS Shield Tracker',
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
