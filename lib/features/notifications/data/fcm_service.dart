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
    } catch (e, s) {
      _logger.warn('FCM init skipped (no config / unsupported platform)', e, s);
    }
  }

  void _route(RemoteMessage m, void Function(String) onDeepLink) {
    final type = m.data['entityType'] as String?;
    final id = m.data['entityId'] as String?;
    if (type == null || id == null) return;
    final route = switch (type) {
      'hazard' => '/hazards/$id',
      'incident' => '/incidents/$id',
      'investigation' => '/investigations/$id',
      'corrective_action' => '/capa/$id',
      'inspection' => '/inspections/$id/run',
      _ => null,
    };
    if (route != null) onDeepLink(route);
  }

  String _platform() => Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'web');
}
