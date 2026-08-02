// path: lib/features/investigations/domain/entities/investigation_analysis.dart
/// Structured root-cause analysis stored in `investigations.analysis` (JSONB).
/// Holds both a 5-Whys chain and a Fishbone (Ishikawa) category map; the chosen
/// method decides which the UI edits, but both persist.
class InvestigationAnalysis {
  const InvestigationAnalysis({this.fiveWhys = const [], this.fishbone = const {}});

  final List<String> fiveWhys;
  final Map<String, List<String>> fishbone;

  /// Standard Fishbone categories (6M).
  static const fishboneCategories = ['People', 'Process', 'Equipment', 'Environment', 'Materials', 'Management'];

  static InvestigationAnalysis empty() => InvestigationAnalysis(
        fishbone: {for (final c in fishboneCategories) c: const <String>[]},
      );

  Map<String, dynamic> toJson() => {
        'five_whys': fiveWhys,
        'fishbone': fishbone.map((k, v) => MapEntry(k, v)),
      };

  factory InvestigationAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return InvestigationAnalysis.empty();
    final whys = (json['five_whys'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final fish = <String, List<String>>{};
    final raw = json['fishbone'];
    if (raw is Map) {
      raw.forEach((k, v) {
        fish[k.toString()] = (v as List?)?.map((e) => e.toString()).toList() ?? [];
      });
    }
    return InvestigationAnalysis(fiveWhys: whys, fishbone: fish.isEmpty ? InvestigationAnalysis.empty().fishbone : fish);
  }

  InvestigationAnalysis copyWith({List<String>? fiveWhys, Map<String, List<String>>? fishbone}) =>
      InvestigationAnalysis(fiveWhys: fiveWhys ?? this.fiveWhys, fishbone: fishbone ?? this.fishbone);
}
