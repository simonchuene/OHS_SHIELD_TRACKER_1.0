// path: lib/features/dashboard/presentation/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/core/theme/app_radii.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/dashboard_data.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/priority_item.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/widgets/curved_hero_header.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/widgets/kpi_tile.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/widgets/mini_bar_chart.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/widgets/risk_compass.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_filter.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/providers/hazard_providers.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';
import 'package:ohs_shield_tracker/shared/widgets/app_shell.dart';
import 'package:ohs_shield_tracker/shared/widgets/duotone_icon_badge.dart';
import 'package:ohs_shield_tracker/shared/widgets/offline_banner.dart';
import 'package:ohs_shield_tracker/shared/widgets/skeleton.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final async = ref.watch(dashboardDataProvider);

    // Re-aggregate when the Dashboard tab (branch 0) regains focus, so counts
    // reflect hazards/CAPAs changed on other tabs without a manual pull-to-refresh.
    ref.listen(activeShellBranchProvider, (prev, next) {
      if (next == 0 && prev != next) {
        ref.invalidate(dashboardDataProvider);
        ref.invalidate(todaysPrioritiesProvider);
      }
    });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardDataProvider);
          ref.invalidate(todaysPrioritiesProvider);
        },
        // Bottom padding clears the floating nav pill so the last section
        // (Department risk ranking) can scroll fully into view.
        child: ListView(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16), children: [
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
                loading: () => const _DashboardSkeleton(),
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

/// Loading placeholder shaped like [_Content] (score card, KPI row, rate cards,
/// chart) so the dashboard looks structurally complete while data resolves.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();
  @override
  Widget build(BuildContext context) => const Shimmer(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SkeletonBox(width: double.infinity, height: 132, radius: 16), // safety score
          SizedBox(height: 16),
          Row(children: [
            Expanded(child: SkeletonBox(height: 116, radius: 14)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 116, radius: 14)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 116, radius: 14)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 116, radius: 14)),
          ],),
          SizedBox(height: 16),
          // Today's Priorities: header + three rows
          SkeletonBox(width: 160, height: 18),
          SizedBox(height: 10),
          SkeletonBox(width: double.infinity, height: 64, radius: 12),
          SizedBox(height: 8),
          SkeletonBox(width: double.infinity, height: 64, radius: 12),
          SizedBox(height: 8),
          SkeletonBox(width: double.infinity, height: 64, radius: 12),
          SizedBox(height: 16),
          Row(children: [
            Expanded(child: SkeletonBox(height: 84, radius: 14)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 84, radius: 14)),
          ],),
          SizedBox(height: 16),
          SkeletonBox(width: double.infinity, height: 180, radius: 16), // chart
        ],),
      );
}

class _Content extends ConsumerWidget {
  const _Content({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = data.kpi;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (data.fromCache) ...[
        // This column is pulled up 40px so the score card tucks under the hero
        // curve; give the banner that height back so it clears the curve instead
        // of being clipped by it.
        const SizedBox(height: 44),
        OfflineBanner(
          lastUpdated: data.generatedAt,
          onRetry: () {
            ref.invalidate(dashboardDataProvider);
            ref.invalidate(todaysPrioritiesProvider);
          },
        ),
      ],
      _SafetyScoreCard(score: data.safetyScore, delta: data.scoreDelta),
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
      const _TodaysPriorities(),
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

/// "Today's Priorities" — the top open hazards/CAPAs/incidents needing action,
/// ranked by severity → overdue → soonest due → most recently updated.
class _TodaysPriorities extends ConsumerWidget {
  const _TodaysPriorities();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todaysPrioritiesProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text("Today's Priorities", style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        TextButton(
          onPressed: () => context.go(Routes.hazards),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('View all'),
        ),
      ],),
      const SizedBox(height: 4),
      async.when(
        // A non-scrolling placeholder — SkeletonList is a ListView and would get
        // unbounded height inside this Column (which sits in the page ListView).
        loading: () => const Shimmer(
          child: Column(children: [
            SkeletonBox(width: double.infinity, height: 64, radius: 12),
            SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 64, radius: 12),
            SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 64, radius: 12),
          ],),
        ),
        error: (_, __) => Text('Could not load priorities', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText)),
        data: (snapshot) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Say so when this is the saved copy — a worklist that looks live but
          // isn't is worse than one that admits it.
          if (snapshot.fromCache)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Saved list · updated ${friendlyTimeAgo(snapshot.generatedAt)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),),
            ),
          if (snapshot.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                const Icon(Icons.verified_outlined, size: 18, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text('Nothing needs attention — nice work.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),),
              ],),
            )
          else
            for (final it in snapshot.items) _PriorityRow(item: it),
        ],),
      ),
    ],);
  }
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({required this.item});
  final PriorityItem item;

  static Color _severityColor(int rank) => switch (rank) {
        3 => const Color(0xFF8E1616), // Critical — deep red
        2 => AppColors.criticalRed, // High / Serious
        1 => AppColors.warningAmber, // Medium / Moderate
        _ => AppColors.primaryGreen, // Low / Minor
      };

  static IconData _kindIcon(PriorityKind k) => switch (k) {
        PriorityKind.hazard => Icons.warning_amber_rounded,
        PriorityKind.capa => Icons.checklist_rtl_rounded,
        PriorityKind.incident => Icons.crisis_alert_rounded,
      };

  String _route() => switch (item.kind) {
        PriorityKind.hazard => Routes.hazardDetail(item.id),
        PriorityKind.capa => Routes.capaDetail(item.id),
        PriorityKind.incident => Routes.incidentDetail(item.id),
      };

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(item.severityRank);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(_route()),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            DuotoneIconBadge(icon: _kindIcon(item.kind), color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),),
                const SizedBox(height: 2),
                Row(children: [
                  Flexible(child: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),),),
                  if (item.isOverdue) ...[
                    const SizedBox(width: 6),
                    const Text('· Overdue', style: TextStyle(fontSize: 11, color: AppColors.criticalRed, fontWeight: FontWeight.w700)),
                  ],
                ],),
              ],),
            ),
            const SizedBox(width: 8),
            _PriorityPill(label: item.statusLabel, color: color),
            const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
          ],),
        ),
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],),
      );
}

class _SafetyScoreCard extends StatelessWidget {
  const _SafetyScoreCard({required this.score, this.delta});
  final int score;
  final int? delta;
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
            if (delta != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(
                  delta! > 0 ? Icons.arrow_upward_rounded : (delta! < 0 ? Icons.arrow_downward_rounded : Icons.remove_rounded),
                  size: 13,
                  color: delta! > 0 ? AppColors.primaryGreen : (delta! < 0 ? AppColors.criticalRed : AppColors.secondaryText),
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    delta == 0 ? 'No change vs last 7 days' : '${delta! > 0 ? '+' : ''}$delta vs last 7 days',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: delta! > 0 ? AppColors.primaryGreen : (delta! < 0 ? AppColors.criticalRed : AppColors.secondaryText),
                    ),
                  ),
                ),
              ],),
            ],
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
