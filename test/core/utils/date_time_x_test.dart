// path: test/core/utils/date_time_x_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/core/utils/date_time_x.dart';

void main() {
  group('DateTime.local', () {
    test('a timestamptz parsed as UTC is converted to the device zone', () {
      // What `DateTime.parse` yields for a Postgres timestamptz.
      final utc = DateTime.parse('2026-08-15T06:00:00Z');
      expect(utc.isUtc, isTrue);

      final local = utc.local;
      expect(local.isUtc, isFalse);
      // Same instant, re-expressed — never shifted.
      expect(local.toUtc(), equals(utc));
      expect(local.difference(utc), Duration.zero);
    });

    test('a date-only value is left alone', () {
      // `date` columns (due_date, scheduled_date) parse as local midnight.
      // Converting these would shift the day for users west of UTC.
      final dateOnly = DateTime.parse('2026-08-15');
      expect(dateOnly.isUtc, isFalse);

      expect(dateOnly.local, equals(dateOnly));
      expect(dateOnly.local.day, 15);
      expect(dateOnly.local.hour, 0);
    });

    test('is idempotent', () {
      final utc = DateTime.parse('2026-08-15T06:00:00Z');
      expect(utc.local.local, equals(utc.local));
    });
  });
}
