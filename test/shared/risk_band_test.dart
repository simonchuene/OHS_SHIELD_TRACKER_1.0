// path: test/shared/risk_band_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

void main() {
  test('fromScore covers 1-25 with no gaps (matches locked bands)', () {
    for (var s = 1; s <= 25; s++) {
      final band = RiskBand.fromScore(s);
      final expected = s <= 5
          ? RiskBand.low
          : s <= 12
              ? RiskBand.medium
              : s <= 17
                  ? RiskBand.high
                  : RiskBand.critical;
      expect(band, expected, reason: 'score $s');
    }
  });

  test('band boundaries', () {
    expect(RiskBand.fromScore(5), RiskBand.low);
    expect(RiskBand.fromScore(6), RiskBand.medium);
    expect(RiskBand.fromScore(12), RiskBand.medium);
    expect(RiskBand.fromScore(13), RiskBand.high);
    expect(RiskBand.fromScore(17), RiskBand.high);
    expect(RiskBand.fromScore(18), RiskBand.critical);
    expect(RiskBand.fromScore(25), RiskBand.critical);
  });

  test('db round-trip', () {
    for (final b in RiskBand.values) {
      expect(RiskBand.fromDb(b.dbValue), b);
    }
    expect(RiskBand.fromDb(null), isNull);
  });
}
