// path: test/features/risk/risk_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/risk/domain/risk_calculator.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

void main() {
  RiskBand expected(int score) => score <= 5
      ? RiskBand.low
      : score <= 12
          ? RiskBand.medium
          : score <= 17
              ? RiskBand.high
              : RiskBand.critical;

  test('every reachable L×S product resolves to exactly one band', () {
    for (var l = 1; l <= 5; l++) {
      for (var s = 1; s <= 5; s++) {
        final score = RiskCalculator.score(l, s);
        expect(RiskCalculator.band(score), expected(score), reason: 'L=$l S=$s score=$score');
      }
    }
  });

  test('reachable distinct products are exactly the 14 known values', () {
    final products = <int>{};
    for (var l = 1; l <= 5; l++) {
      for (var s = 1; s <= 5; s++) {
        products.add(l * s);
      }
    }
    final sorted = products.toList()..sort();
    expect(sorted, RiskCalculator.reachableScores);
    // Values that can never occur from 1–5 × 1–5:
    for (final impossible in [7, 11, 13, 14, 17, 18, 19, 21, 22, 23, 24]) {
      expect(products.contains(impossible), isFalse, reason: '$impossible must be unreachable');
    }
  });

  test('band per reachable score (spec self-check table)', () {
    const bands = {
      1: RiskBand.low, 2: RiskBand.low, 3: RiskBand.low, 4: RiskBand.low, 5: RiskBand.low,
      6: RiskBand.medium, 8: RiskBand.medium, 9: RiskBand.medium, 10: RiskBand.medium, 12: RiskBand.medium,
      15: RiskBand.high, 16: RiskBand.high,
      20: RiskBand.critical, 25: RiskBand.critical,
    };
    for (final e in bands.entries) {
      expect(RiskCalculator.band(e.key), e.value, reason: 'score ${e.key}');
    }
  });

  test('CAPA priority default follows the band', () {
    expect(RiskCalculator.defaultCapaPriority(RiskBand.critical), 'critical');
    expect(RiskCalculator.defaultCapaPriority(RiskBand.high), 'high');
    expect(RiskCalculator.defaultCapaPriority(RiskBand.medium), 'medium');
    expect(RiskCalculator.defaultCapaPriority(RiskBand.low), 'low');
  });
}
