// path: test/shared/friendly_time_ago_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/shared/widgets/offline_banner.dart';

void main() {
  final now = DateTime(2026, 8, 6, 12);
  String ago(Duration d) => friendlyTimeAgo(now.subtract(d), now: now);

  test('sub-minute reads as just now', () {
    expect(ago(const Duration(seconds: 5)), 'just now');
    expect(ago(const Duration(seconds: 59)), 'just now');
  });

  test('minutes are singular then plural', () {
    expect(ago(const Duration(minutes: 1)), 'a minute ago');
    expect(ago(const Duration(minutes: 12)), '12 minutes ago');
  });

  test('hours are singular then plural', () {
    expect(ago(const Duration(hours: 1)), 'an hour ago');
    expect(ago(const Duration(hours: 5)), '5 hours ago');
  });

  test('days roll into yesterday then a day count', () {
    expect(ago(const Duration(days: 1)), 'yesterday');
    expect(ago(const Duration(days: 3)), '3 days ago');
  });

  test('beyond a week falls back to an absolute date', () {
    expect(ago(const Duration(days: 30)), startsWith('on '));
  });

  test('a clock skewed into the future degrades to just now, not a negative', () {
    expect(friendlyTimeAgo(now.add(const Duration(minutes: 5)), now: now), 'just now');
  });
}
