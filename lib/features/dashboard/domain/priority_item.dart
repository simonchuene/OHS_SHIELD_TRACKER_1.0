// path: lib/features/dashboard/domain/priority_item.dart
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

enum PriorityKind { hazard, capa, incident }

/// A "Today's Priorities" row normalised across hazards, CAPAs and incidents so
/// the three can be ranked in one list. Display (icon/colour/route) is derived
/// from [kind]/[severityRank] in the widget layer — this stays Flutter-free.
class PriorityItem {
  const PriorityItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.severityRank,
    required this.statusLabel,
    required this.isOverdue,
    required this.dueDate,
    required this.updatedAt,
  });

  final PriorityKind kind;
  final String id;
  final String title;
  final String subtitle;

  /// 3 Critical · 2 High/Serious · 1 Medium/Moderate · 0 Low/Minor.
  final int severityRank;
  final String statusLabel;
  final bool isOverdue;
  final DateTime? dueDate;
  final DateTime updatedAt;

  /// Ranking (highest priority first):
  /// 1) severity descending (Critical → Low),
  /// 2) overdue before on-track within the same severity,
  /// 3) soonest due date first (items with a due date ahead of those without),
  /// 4) most recently updated as the final tie-breaker.
  static int compare(PriorityItem a, PriorityItem b) {
    final bySeverity = b.severityRank.compareTo(a.severityRank);
    if (bySeverity != 0) return bySeverity;
    if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
    final ad = a.dueDate;
    final bd = b.dueDate;
    if (ad != null || bd != null) {
      if (ad == null) return 1; // a due date ranks ahead of no due date
      if (bd == null) return -1;
      final byDue = ad.compareTo(bd); // ascending — soonest first
      if (byDue != 0) return byDue;
    }
    return b.updatedAt.compareTo(a.updatedAt); // most recently updated first
  }

  factory PriorityItem.fromHazard(Map<String, dynamic> h) {
    final loc = (h['location_text'] as String?)?.trim();
    return PriorityItem(
      kind: PriorityKind.hazard,
      id: h['id'] as String,
      title: _text(h['title'], 'Hazard'),
      subtitle: _join('Hazard', loc),
      severityRank: _bandRank(RiskBand.fromDb(h['risk_level'] as String?)),
      statusLabel: HazardStatus.fromDb(h['status'] as String).label,
      isOverdue: false,
      dueDate: null,
      updatedAt: _ts(h['updated_at']),
    );
  }

  factory PriorityItem.fromCapa(Map<String, dynamic> c) {
    final due = c['due_date'] != null ? DateTime.tryParse(c['due_date'] as String) : null;
    return PriorityItem(
      kind: PriorityKind.capa,
      id: c['id'] as String,
      title: _text(c['description'], 'Corrective action'),
      subtitle: 'CAPA',
      severityRank: _priorityRank(CapaPriority.fromDb(c['priority'] as String)),
      statusLabel: CapaStatus.fromDb(c['status'] as String).label,
      isOverdue: CorrectiveAction.isPastDue(due),
      dueDate: due,
      updatedAt: _ts(c['updated_at']),
    );
  }

  factory PriorityItem.fromIncident(Map<String, dynamic> i) {
    final loc = (i['location_text'] as String?)?.trim();
    final typeLabel = IncidentType.fromDb(i['incident_type'] as String).label;
    return PriorityItem(
      kind: PriorityKind.incident,
      id: i['id'] as String,
      title: _text(i['description'], typeLabel),
      subtitle: _join('Incident', loc ?? typeLabel),
      severityRank: _severityRank(IncidentSeverity.fromDb(i['severity'] as String)),
      statusLabel: IncidentStatus.fromDb(i['status'] as String).label,
      isOverdue: false,
      dueDate: null,
      updatedAt: _ts(i['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'severityRank': severityRank,
        'statusLabel': statusLabel,
        'isOverdue': isOverdue,
        'dueDate': dueDate?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PriorityItem.fromJson(Map<String, dynamic> j) => PriorityItem(
        kind: PriorityKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => PriorityKind.hazard,
        ),
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        severityRank: (j['severityRank'] as num?)?.toInt() ?? 0,
        statusLabel: j['statusLabel'] as String? ?? '',
        isOverdue: j['isOverdue'] as bool? ?? false,
        dueDate: j['dueDate'] == null ? null : DateTime.tryParse(j['dueDate'] as String),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  static String _text(dynamic v, String fallback) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? fallback : s;
  }

  static String _join(String kind, String? tail) =>
      (tail == null || tail.isEmpty) ? kind : '$kind · $tail';

  static DateTime _ts(dynamic v) =>
      DateTime.tryParse(v as String? ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);

  static int _bandRank(RiskBand? b) => switch (b) {
        RiskBand.critical => 3,
        RiskBand.high => 2,
        RiskBand.medium => 1,
        RiskBand.low => 0,
        null => 0,
      };
  static int _priorityRank(CapaPriority p) => switch (p) {
        CapaPriority.critical => 3,
        CapaPriority.high => 2,
        CapaPriority.medium => 1,
        CapaPriority.low => 0,
      };
  static int _severityRank(IncidentSeverity s) => switch (s) {
        IncidentSeverity.critical => 3,
        IncidentSeverity.serious => 2,
        IncidentSeverity.moderate => 1,
        IncidentSeverity.minor => 0,
      };
}
