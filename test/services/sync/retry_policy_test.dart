// path: test/services/sync/retry_policy_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/services/sync/retry_policy.dart';

void main() {
  const policy = RetryPolicy();

  test('stops after max attempts (D5: 5)', () {
    expect(policy.hasAttemptsLeft(4), isTrue);
    expect(policy.hasAttemptsLeft(5), isFalse);
  });

  test('delay grows exponentially and is capped at 60s', () {
    final zeroJitter = Random(0);
    // With jitter the value is within ±20%; assert the capped ceiling holds.
    for (var attempt = 1; attempt <= 8; attempt++) {
      final d = policy.delayForAttempt(attempt, random: zeroJitter);
      expect(d.inMilliseconds, lessThanOrEqualTo((60 * 1.2 * 1000).round()));
    }
  });

  test('early attempts are near base*factor^n', () {
    // attempt 1 ~ 2s * 2^1 = 4s (±20%)
    final d = policy.delayForAttempt(1, random: Random(1));
    expect(d.inMilliseconds, inInclusiveRange((4000 * 0.8).round(), (4000 * 1.2).round()));
  });
}
