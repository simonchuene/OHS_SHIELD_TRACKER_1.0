// path: test/core/utils/validators_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/core/utils/validators.dart';

void main() {
  group('email', () {
    test('rejects empty and malformed', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('  '), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });
    test('accepts valid', () {
      expect(Validators.email('name@company.com'), isNull);
      expect(Validators.email('l.mkhize+ohs@acme.co.za'), isNull);
    });
  });

  group('password', () {
    test('requires >= 8 chars', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('short'), isNotNull);
      expect(Validators.password('longenough'), isNull);
    });
  });
}
