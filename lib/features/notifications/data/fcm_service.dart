// path: lib/features/notifications/data/fcm_service.dart
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';

/// Thin FCM wrapper: initialises Firebase (best-effort), requests permission,
/// registers the device token, and routes notification taps to a deep link.
/// All calls are guarded so a missing Firebase config never crashes the app
/// (push simply stays inactive until real config/keys are wired — Prompt 18).
class FcmService {
  FcmService(this._logger);
  final LoggerService _logger;

  Future<void> init({
    required Future<void> Function(String token, String platform) onToken,
    required void Function(String route) onDeepLink,
    void Function(String title, String body, String? route)? onForegroundMessage,
  }) async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) await onToken(token, _platform());
      messaging.onTokenRefresh.listen((t) => onToken(t, _platform()));

      // App opened from a background push.
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _route(m, onDeepLink));
      final initial = await messaging.getInitialMessage();
      if (initial != null) _route(initial, onDeepLink);

      // Foreground delivery. Android does not display a notification while the
      // app is in focus — it hands the message here instead — so without this
      // listener a push arriving during use was silently dropped. The caller
      // decides how to surface it (in-app banner).
      if (onForegroundMessage != null) {
        FirebaseMessaging.onMessage.listen((m) {
          final n = m.notification;
          if (n == null) return; // data-only message: nothing to show
          onForegroundMessage(n.title ?? 'Notification', n.body ?? '', _routeFor(m));
        });
      }
    } catch (e, s) {
      _logger.warn('FCM init skipped (no config / unsupported platform)', e, s);
    }
  }

  /// Deep-link route for a message's payload, or null when it carries no
  /// recognised target. Shared by the tap handlers and the foreground banner.
  String? _routeFor(RemoteMessage m) {
    final type = m.data['entityType'] as String?;
    final id = m.data['entityId'] as String?;
    if (type == null || id == null) return null;
    return switch (type) {
      'hazard' => '/hazards/$id',
      'incident' => '/incidents/$id',
      'investigation' => '/investigations/$id',
      'corrective_action' => '/capa/$id',
      'inspection' => '/inspections/$id/run',
      _ => null,
    };
  }

  void _route(RemoteMessage m, void Function(String) onDeepLink) {
    final route = _routeFor(m);
    if (route != null) onDeepLink(route);
  }

  String _platform() => Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'web');
}
