// path: lib/services/sync/retry_policy.dart
import 'dart:math';

/// Exponential backoff with jitter (Decision D5).
/// base 2s · factor 2 · max 5 attempts · cap 60s · ±20% jitter.
class RetryPolicy {
  const RetryPolicy({
    this.baseDelay = const Duration(seconds: 2),
    this.factor = 2,
    this.maxAttempts = 5,
    this.cap = const Duration(seconds: 60),
    this.jitter = 0.2,
  });

  final Duration baseDelay;
  final double factor;
  final int maxAttempts;
  final Duration cap;
  final double jitter;

  bool hasAttemptsLeft(int attempts) => attempts < maxAttempts;

  /// Delay before the next attempt, given how many attempts have already run.
  Duration delayForAttempt(int attempts, {Random? random}) {
    final rng = random ?? Random();
    final raw = baseDelay.inMilliseconds * pow(factor, attempts);
    final capped = min(raw.toDouble(), cap.inMilliseconds.toDouble());
    final jitterFactor = 1 + ((rng.nextDouble() * 2 - 1) * jitter); // 1 ± jitter
    return Duration(milliseconds: (capped * jitterFactor).round());
  }
}
