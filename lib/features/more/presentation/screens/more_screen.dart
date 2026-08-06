// path: lib/features/more/presentation/screens/more_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/shared/widgets/duotone_icon_badge.dart';

/// The "More" tab — the hub for every module that isn't one of the three
/// primary tabs (Dashboard / Hazards / Actions), plus the signed-in identity
/// and sign-out. Role-gated entries mirror the router guards and RLS: the audit
/// log is Safety Officer+ (rank 3) and user administration is Administrator
/// only (rank 5); RLS remains authoritative, this just avoids dead ends.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final rank = ref.watch(authRoleRankProvider) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
        children: [
          if (user != null) _Identity(name: user.displayName, email: user.email, initials: user.initials, role: user.primaryRole),
          const _SectionHeader('Safety'),
          _MoreTile(
            icon: Icons.report_gmailerrorred_rounded,
            color: AppColors.criticalRed,
            title: 'Incidents',
            subtitle: 'Report and track incidents',
            onTap: () => context.push(Routes.incidents),
          ),
          _MoreTile(
            icon: Icons.search_rounded,
            color: AppColors.infoBlue,
            title: 'Investigations',
            subtitle: 'Root cause analysis',
            onTap: () => context.push(Routes.investigations),
          ),
          _MoreTile(
            icon: Icons.checklist_rounded,
            color: AppColors.primaryGreen,
            title: 'Inspections',
            subtitle: 'Checklists and audits of the workplace',
            onTap: () => context.push(Routes.inspections),
          ),
          const _SectionHeader('Insights'),
          _MoreTile(
            icon: Icons.description_outlined,
            color: AppColors.infoBlue,
            title: 'Reports',
            subtitle: 'Export registers and summaries',
            onTap: () => context.push(Routes.reports),
          ),
          _MoreTile(
            icon: Icons.notifications_none_rounded,
            color: AppColors.warningAmber,
            title: 'Notifications',
            subtitle: 'Alerts and assignments',
            onTap: () => context.push(Routes.notifications),
          ),
          if (rank >= AppRole.safetyOfficer.rank)
            _MoreTile(
              icon: Icons.history_rounded,
              color: AppColors.secondaryText,
              title: 'Audit log',
              subtitle: 'Who changed what, and when',
              onTap: () => context.push(Routes.audit),
            ),
          if (rank >= AppRole.administrator.rank) ...[
            const _SectionHeader('Administration'),
            _MoreTile(
              icon: Icons.manage_accounts_outlined,
              color: AppColors.primaryGreen,
              title: 'User & Access Administration',
              subtitle: 'Invite users, assign roles and scope',
              onTap: () => context.push(Routes.adminUsers),
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.criticalRed),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Anything not yet synced stays queued on this device until you sign back in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    // The router's auth guard redirects to login once the session clears.
    await ref.read(currentUserProvider.notifier).signOut();
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.name, required this.email, required this.initials, this.role});
  final String name;
  final String email;
  final String initials;
  final AppRole? role;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.14),
            child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(name.isEmpty ? email : name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,),
              const SizedBox(height: 2),
              Text(role == null ? email : '${_roleLabel(role!)} · $email',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),),
            ],),
          ),
        ],),
      );

  static String _roleLabel(AppRole r) => switch (r) {
        AppRole.employee => 'Employee',
        AppRole.supervisor => 'Supervisor',
        AppRole.safetyOfficer => 'Safety Officer',
        AppRole.manager => 'Manager',
        AppRole.administrator => 'Administrator',
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),),
      );
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ListTile(
          onTap: onTap,
          leading: DuotoneIconBadge(icon: icon, color: color),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
        ),
      );
}
