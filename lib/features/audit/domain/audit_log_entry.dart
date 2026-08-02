// path: lib/features/audit/domain/audit_log_entry.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'audit_log_entry.freezed.dart';

/// An immutable audit record (read-only). This module NEVER exposes create/
/// update/delete — `audit_logs` has no client mutation path (2B).
@freezed
class AuditLogEntry with _$AuditLogEntry {
  const AuditLogEntry._();

  const factory AuditLogEntry({
    required String id,
    String? actorId,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? beforeState,
    Map<String, dynamic>? afterState,
    required DateTime createdAt,
  }) = _AuditLogEntry;

  List<FieldChange> get diff => AuditDiff.compute(beforeState, afterState);
}

/// A single before→after field change.
class FieldChange {
  const FieldChange(this.field, this.before, this.after);
  final String field;
  final String? before;
  final String? after;

  bool get isAdded => before == null && after != null;
  bool get isRemoved => before != null && after == null;
}

/// Pure before/after diff over two JSON maps.
abstract final class AuditDiff {
  static List<FieldChange> compute(Map<String, dynamic>? before, Map<String, dynamic>? after) {
    final keys = <String>{...?before?.keys, ...?after?.keys}..removeWhere(_isNoise);
    final changes = <FieldChange>[];
    for (final k in keys.toList()..sort()) {
      final b = before?[k];
      final a = after?[k];
      if (_str(b) != _str(a)) {
        changes.add(FieldChange(k, before != null && before.containsKey(k) ? _str(b) : null,
            after != null && after.containsKey(k) ? _str(a) : null,),);
      }
    }
    return changes;
  }

  // Housekeeping columns rarely useful in a human diff.
  static bool _isNoise(String k) => k == 'updated_at' || k == 'version';

  static String? _str(dynamic v) => v?.toString();
}
