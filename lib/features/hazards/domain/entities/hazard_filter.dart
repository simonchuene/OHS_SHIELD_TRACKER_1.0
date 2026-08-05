// path: lib/features/hazards/domain/entities/hazard_filter.dart
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_category.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

/// Filter/search for the hazard list. `mineOnly` supports the "Mine" quick chip
/// (Employees see their own; higher roles see wider scopes via RLS).
class HazardFilter {
  const HazardFilter({this.status, this.riskLevel, this.siteId, this.query, this.mineOnly = false});

  final HazardStatus? status;
  final RiskBand? riskLevel;
  final String? siteId;
  final String? query;
  final bool mineOnly;

  /// True when any narrowing is applied — used to tell an empty result caused by
  /// a filter apart from there genuinely being no hazards.
  bool get isActive =>
      status != null || riskLevel != null || mineOnly || (query?.trim().isNotEmpty ?? false);

  HazardFilter copyWith({
    HazardStatus? status,
    RiskBand? riskLevel,
    String? siteId,
    String? query,
    bool? mineOnly,
    bool clearStatus = false,
    bool clearRisk = false,
  }) =>
      HazardFilter(
        status: clearStatus ? null : (status ?? this.status),
        riskLevel: clearRisk ? null : (riskLevel ?? this.riskLevel),
        siteId: siteId ?? this.siteId,
        query: query ?? this.query,
        mineOnly: mineOnly ?? this.mineOnly,
      );
}

/// Input for reporting a hazard.
class ReportHazardParams {
  const ReportHazardParams({
    required this.title,
    required this.category,
    this.description,
    this.siteId,
    this.departmentId,
    this.latitude,
    this.longitude,
    this.locationText,
    this.submitNow = true,
  });

  final String title;
  final HazardCategory category;
  final String? description;
  final String? siteId;
  final String? departmentId;
  final double? latitude;
  final double? longitude;
  final String? locationText;

  /// When true the hazard is created as `submitted`; otherwise `draft`.
  final bool submitNow;
}
