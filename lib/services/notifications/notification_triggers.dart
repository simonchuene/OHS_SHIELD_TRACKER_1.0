// path: lib/services/notifications/notification_triggers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Canonical notification trigger names (Ledger D7).
abstract final class NotificationTrigger {
  static const hazardCreated = 'hazard.created';
  static const incidentCreated = 'incident.created';
  static const riskAssessed = 'risk.assessed';
  static const capaAssigned = 'capa.assigned';
  static const capaOverdue = 'capa.overdue';
  static const investigationDue = 'investigation.due';
  static const inspectionDue = 'inspection.due';
}

/// Dispatches domain events to the `notify-fanout` Edge Function (which resolves
/// recipients, inserts in-app `notifications`, and pushes via FCM). Fire-and-forget
/// and best-effort — a delivery failure must never block the originating write.
/// (Prompts 7–13 already call `fire(...)`; upgrading this from the earlier stub
/// makes those calls deliver for real, no caller changes needed.)
class NotificationTriggers {
  const NotificationTriggers(this._client, this._logger);
  final SupabaseClient _client;
  final LoggerService _logger;

  void fire(String trigger, {required String entityType, required String entityId, Map<String, dynamic>? data}) {
    // Do not await — never block the caller's mutation on notification delivery.
    unawaited(_dispatch(trigger, entityType, entityId, data));
  }

  Future<void> _dispatch(String trigger, String entityType, String entityId, Map<String, dynamic>? data) async {
    try {
      await _client.functions.invoke('notify-fanout', body: {
        'trigger': trigger, 'entityType': entityType, 'entityId': entityId, ...?data,
      },);
    } catch (e, s) {
      _logger.warn('notify-fanout dispatch failed ($trigger $entityType/$entityId)', e, s);
    }
  }
}

final notificationTriggersProvider = Provider<NotificationTriggers>(
  (ref) => NotificationTriggers(ref.watch(supabaseClientProvider), ref.watch(loggerProvider)),
);
