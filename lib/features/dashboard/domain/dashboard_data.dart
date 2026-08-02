// path: lib/features/dashboard/domain/dashboard_data.dart
/// Immutable dashboard snapshot with manual JSON (for offline last-known cache).
library;


class KpiSet {
  const KpiSet({
    this.openHazards = 0,
    this.highRiskHazards = 0,
    this.openCapas = 0,
    this.overdueCapas = 0,
    this.incidents30d = 0,
    this.nearMisses30d = 0,
    this.seriousIncidents30d = 0,
    this.capaClosureRate = 0,
    this.inspectionCompletionRate = 0,
  });

  final int openHazards;
  final int highRiskHazards;
  final int openCapas;
  final int overdueCapas;
  final int incidents30d;
  final int nearMisses30d;
  final int seriousIncidents30d;
  final double capaClosureRate; // 0..1
  final double inspectionCompletionRate; // 0..1

  Map<String, dynamic> toJson() => {
        'openHazards': openHazards, 'highRiskHazards': highRiskHazards, 'openCapas': openCapas,
        'overdueCapas': overdueCapas, 'incidents30d': incidents30d, 'nearMisses30d': nearMisses30d,
        'seriousIncidents30d': seriousIncidents30d, 'capaClosureRate': capaClosureRate,
        'inspectionCompletionRate': inspectionCompletionRate,
      };
  factory KpiSet.fromJson(Map<String, dynamic> j) => KpiSet(
        openHazards: (j['openHazards'] as num?)?.toInt() ?? 0,
        highRiskHazards: (j['highRiskHazards'] as num?)?.toInt() ?? 0,
        openCapas: (j['openCapas'] as num?)?.toInt() ?? 0,
        overdueCapas: (j['overdueCapas'] as num?)?.toInt() ?? 0,
        incidents30d: (j['incidents30d'] as num?)?.toInt() ?? 0,
        nearMisses30d: (j['nearMisses30d'] as num?)?.toInt() ?? 0,
        seriousIncidents30d: (j['seriousIncidents30d'] as num?)?.toInt() ?? 0,
        capaClosureRate: (j['capaClosureRate'] as num?)?.toDouble() ?? 0,
        inspectionCompletionRate: (j['inspectionCompletionRate'] as num?)?.toDouble() ?? 0,
      );
}

class TrendPoint {
  const TrendPoint(this.label, this.value);
  final String label;
  final int value;
  Map<String, dynamic> toJson() => {'label': label, 'value': value};
  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(j['label'] as String, j['value'] as int);
}

class DeptRisk {
  const DeptRisk(this.label, this.count);
  final String label;
  final int count;
  Map<String, dynamic> toJson() => {'label': label, 'count': count};
  factory DeptRisk.fromJson(Map<String, dynamic> j) => DeptRisk(j['label'] as String, j['count'] as int);
}

class DashboardData {
  const DashboardData({
    required this.scopeLabel,
    required this.safetyScore,
    required this.kpi,
    this.incidentTrend = const [],
    this.deptRanking = const [],
    required this.generatedAt,
    this.fromCache = false,
  });

  final String scopeLabel;
  final int safetyScore;
  final KpiSet kpi;
  final List<TrendPoint> incidentTrend;
  final List<DeptRisk> deptRanking;
  final DateTime generatedAt;
  final bool fromCache;

  DashboardData copyWith({bool? fromCache}) => DashboardData(
        scopeLabel: scopeLabel, safetyScore: safetyScore, kpi: kpi,
        incidentTrend: incidentTrend, deptRanking: deptRanking,
        generatedAt: generatedAt, fromCache: fromCache ?? this.fromCache,
      );

  Map<String, dynamic> toJson() => {
        'scopeLabel': scopeLabel, 'safetyScore': safetyScore, 'kpi': kpi.toJson(),
        'incidentTrend': [for (final t in incidentTrend) t.toJson()],
        'deptRanking': [for (final d in deptRanking) d.toJson()],
        'generatedAt': generatedAt.toIso8601String(),
      };
  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        scopeLabel: j['scopeLabel'] as String,
        safetyScore: j['safetyScore'] as int,
        kpi: KpiSet.fromJson(Map<String, dynamic>.from(j['kpi'] as Map)),
        incidentTrend: [for (final t in (j['incidentTrend'] as List? ?? [])) TrendPoint.fromJson(Map<String, dynamic>.from(t as Map))],
        deptRanking: [for (final d in (j['deptRanking'] as List? ?? [])) DeptRisk.fromJson(Map<String, dynamic>.from(d as Map))],
        generatedAt: DateTime.parse(j['generatedAt'] as String),
        fromCache: true,
      );
}
