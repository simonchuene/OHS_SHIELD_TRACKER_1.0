// path: test/features/notifications/deep_link_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/notifications/domain/app_notification.dart';

void main() {
  test('maps each entity type to its record route', () {
    expect(NotificationDeepLink.routeFor('hazard', 'h1'), '/hazards/h1');
    expect(NotificationDeepLink.routeFor('incident', 'i1'), '/incidents/i1');
    expect(NotificationDeepLink.routeFor('investigation', 'v1'), '/investigations/v1');
    expect(NotificationDeepLink.routeFor('corrective_action', 'c1'), '/capa/c1');
    expect(NotificationDeepLink.routeFor('inspection', 's1'), '/inspections/s1/run');
  });

  test('unknown or missing target → null (no navigation)', () {
    expect(NotificationDeepLink.routeFor('report', 'r1'), isNull);
    expect(NotificationDeepLink.routeFor(null, 'x'), isNull);
    expect(NotificationDeepLink.routeFor('hazard', null), isNull);
  });

  test('priority helpers', () {
    final n = AppNotification(id: '1', triggerType: 'incident_created', priority: 'high', title: 't', createdAt: DateTime(2026, 8, 1));
    expect(n.isHighPriority, isTrue);
    final normal = n.copyWith(priority: 'normal');
    expect(normal.isHighPriority, isFalse);
  });
}
