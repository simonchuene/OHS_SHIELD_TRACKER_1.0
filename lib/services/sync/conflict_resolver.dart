// path: lib/services/sync/conflict_resolver.dart
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';

/// Outcome of resolving a queued update against the current server row.
sealed class Resolution {
  const Resolution();
}

/// Apply [fields] to the server row (PATCH). Used when there is no conflict, or
/// when the local change wins (LWW newer / field-merge).
class ApplyLocal extends Resolution {
  const ApplyLocal(this.fields);
  final Map<String, dynamic> fields;
}

/// Server wins — discard the local change and refresh the cache from [serverRow].
class AcceptServer extends Resolution {
  const AcceptServer(this.serverRow);
  final Map<String, dynamic> serverRow;
}

/// Target row no longer exists / cannot be resolved — mark failed, surface to user.
class Unresolvable extends Resolution {
  const Unresolvable(this.reason);
  final String reason;
}

/// Implements the two-tier strategy (D4). Pure/testable: no I/O.
class ConflictResolver {
  const ConflictResolver();

  Resolution resolveUpdate({
    required String entityType,
    required Map<String, dynamic> changedFields,
    required int? baseVersion,
    required Map<String, dynamic>? serverRow,
    required DateTime localUpdatedAt,
  }) {
    if (serverRow == null) {
      return const Unresolvable('Record no longer exists on the server.');
    }

    final serverVersion = (serverRow['version'] as num?)?.toInt();
    final hasConflict = baseVersion != null && serverVersion != baseVersion;

    if (!hasConflict) {
      return ApplyLocal(changedFields); // fast path
    }

    switch (SyncEntity.strategyFor(entityType)) {
      case ConflictStrategy.fieldMerge:
        // Client's touched fields win; untouched server fields are preserved
        // automatically because a PATCH only sets the provided keys.
        return ApplyLocal(changedFields);

      case ConflictStrategy.lastWriteWins:
        final serverUpdatedAt =
            DateTime.tryParse(serverRow['updated_at']?.toString() ?? '');
        final localWins =
            serverUpdatedAt == null || localUpdatedAt.isAfter(serverUpdatedAt);
        // Either way the audit trail records what happened (server-side trigger
        // on the applied write; local log on accept-server).
        return localWins ? ApplyLocal(changedFields) : AcceptServer(serverRow);
    }
  }
}
