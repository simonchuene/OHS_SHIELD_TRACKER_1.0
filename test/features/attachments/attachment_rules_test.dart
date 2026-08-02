// path: test/features/attachments/attachment_rules_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/attachment_constants.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';

void main() {
  group('AttachmentValidator', () {
    test('accepts JPG/PNG/PDF within 20 MB', () {
      expect(AttachmentValidator.validate(contentType: 'image/jpeg', sizeBytes: 1024), isNull);
      expect(AttachmentValidator.validate(contentType: 'image/png', sizeBytes: 1024), isNull);
      expect(AttachmentValidator.validate(contentType: 'application/pdf', sizeBytes: 1024), isNull);
    });
    test('rejects disallowed types', () {
      expect(AttachmentValidator.validate(contentType: 'image/gif', sizeBytes: 1024), isNotNull);
      expect(AttachmentValidator.validate(contentType: 'video/mp4', sizeBytes: 1024), isNotNull);
    });
    test('rejects empty and > 20 MB', () {
      expect(AttachmentValidator.validate(contentType: 'image/png', sizeBytes: 0), isNotNull);
      expect(AttachmentValidator.validate(contentType: 'image/png', sizeBytes: 20 * 1024 * 1024 + 1), isNotNull);
      expect(AttachmentValidator.validate(contentType: 'image/png', sizeBytes: 20 * 1024 * 1024), isNull);
    });
  });

  group('AttachmentPaths', () {
    test('builds <company>/<owner_type>/<owner_id>/<version>.<ext> (matches RLS 0008)', () {
      final path = AttachmentPaths.build(
        companyId: 'c1', ownerType: AttachmentOwnerType.correctiveAction,
        ownerId: 'ca9', versionId: 'v7', contentType: 'application/pdf',
      );
      expect(path, 'c1/corrective_action/ca9/v7.pdf');
    });
  });

  group('AttachmentOwnerType', () {
    test('db value round-trips', () {
      for (final t in AttachmentOwnerType.values) {
        expect(AttachmentOwnerType.fromDb(t.dbValue), t);
      }
    });
    test('corrective_action maps correctly', () {
      expect(AttachmentOwnerType.fromDb('corrective_action'), AttachmentOwnerType.correctiveAction);
    });
  });
}
