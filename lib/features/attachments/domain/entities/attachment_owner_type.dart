// path: lib/features/attachments/domain/entities/attachment_owner_type.dart
/// The entities an attachment can belong to (polymorphic `attachments.owner_type`).
/// `dbValue` matches the `attachment_owner_type` Postgres enum.
enum AttachmentOwnerType {
  hazard('hazard'),
  incident('incident'),
  investigation('investigation'),
  correctiveAction('corrective_action'),
  inspection('inspection');

  const AttachmentOwnerType(this.dbValue);
  final String dbValue;

  static AttachmentOwnerType fromDb(String v) =>
      AttachmentOwnerType.values.firstWhere((e) => e.dbValue == v,
          orElse: () => AttachmentOwnerType.hazard,);
}
