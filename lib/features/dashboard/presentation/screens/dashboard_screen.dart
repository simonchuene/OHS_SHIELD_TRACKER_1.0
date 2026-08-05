// path: lib/features/dashboard/presentation/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/core/theme/app_radii.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/dashboard_data.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/widgets/curved_hero_header.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/widgets/kpi_tile.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/widgets/mini_bar_chart.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/widgets/risk_compass.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_filter.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/providers/hazard_providers.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final async = ref.watch(dashboardDataProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardDataProvider),
        child: ListView(padding: EdgeInsets.zero, children: [
          CurvedHeroHeader(
            firstName: user?.firstNameOrEmail ?? '',
            initials: user?.initials ?? '?',
            scopeLabel: async.valueOrNull?.scopeLabel ?? '',
          ),
          Transform.translate(
            offset: const Offset(0, -40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: async.when(
                loading: () => const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text('Could not load dashboard.\n$e', textAlign: TextAlign.center))),
                data: (d) => _Content(data: d),
              ),
            ),
          ),
        ],),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = data.kpi;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (data.fromCache)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.warningAmber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('Showing last synced data · ${DateFormat.jm().add_yMMMd().format(data.generatedAt)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8a5a00)),),
        ),
      _SafetyScoreCard(score: data.safetyScore),
      const SizedBox(height: 16),
      Row(children: [
        KpiTile(icon: Icons.warning_amber_rounded, color: AppColors.warningAmber, value: k.openHazards, label: 'Open Hazards',
            onTap: () { ref.read(hazardFilterControllerProvider.notifier).update(const HazardFilter()); context.go(Routes.hazards); },),
        KpiTile(icon: Icons.local_fire_department_outlined, color: AppColors.criticalRed, value: k.highRiskHazards, label: 'High Risk',
            onTap: () { ref.read(hazardFilterControllerProvider.notifier).update(const HazardFilter(riskLevel: RiskBand.high)); context.go(Routes.hazards); },),
        KpiTile(icon: Icons.checklist_rtl_rounded, color: AppColors.infoBlue, value: k.openCapas, label: 'Open CAPAs',
            onTap: () => context.go(Routes.capa),),
        KpiTile(icon: Icons.schedule_rounded, color: AppColors.criticalRed, value: k.overdueCapas, label: 'Overdue',
            onTap: () => context.go(Routes.capa),),
      ],),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _RateCard(label: 'CAPA closure', rate: k.capaClosureRate)),
        const SizedBox(width: 8),
        Expanded(child: _RateCard(label: 'Inspection completion', rate: k.inspectionCompletionRate)),
      ],),
      const SizedBox(height: 16),
      _Section(title: 'Incident trend (6 weeks)', child: MiniBarChart(
        values: [for (final t in data.incidentTrend) t.value],
        labels: [for (final t in data.incidentTrend) t.label],
      ),),
      const SizedBox(height: 16),
      _Section(title: 'Near misses (30d): ${k.nearMisses30d} · Incidents (30d): ${k.incidents30d}', child: const SizedBox.shrink()),
      if (data.deptRanking.isNotEmpty) ...[
        const SizedBox(height: 8),
        _Section(title: 'Department risk ranking', child: RankingBars(entries: [for (final d in data.deptRanking) (d.label, d.count)])),
      ],
      const SizedBox(height: 24),
    ],);
  }
}

class _SafetyScoreCard extends StatelessWidget {
  const _SafetyScoreCard({required this.score});
  final int score;
  @override
  Widget build(BuildContext context) {
    final band = RiskBand.fromScore(((100 - score) / 4).clamp(1, 25).round()); // inverse-ish, for label colour only
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadii.heroCard,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        SizedBox(
          width: 120,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Safety Score', style: Theme.of(context).textTheme.titleLarge),
            const Text('Overall risk rating', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            const Divider(height: 16),
            Row(children: [
              Icon(score >= 70 ? Icons.trending_up_rounded : Icons.trending_flat_rounded, size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 4),
              Text(score >= 70 ? 'Great work!' : 'Needs attention', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
            ],),
            const SizedBox(height: 2),
            Text(band == RiskBand.low ? 'Low overall risk' : '${band.label} overall risk', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
          ],),
        ),
        Expanded(child: Center(child: RiskCompass(score: score))),
      ],),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.label, required this.rate});
  final String label;
  final double rate;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${(rate * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (child is! SizedBox) const SizedBox(height: 8),
          child,
        ],),
      );
}
