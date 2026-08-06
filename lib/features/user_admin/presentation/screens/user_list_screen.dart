// path: lib/features/user_admin/presentation/screens/user_list_screen.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/shared/widgets/nav_safe_insets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/managed_user.dart';
import 'package:ohs_shield_tracker/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:ohs_shield_tracker/shared/widgets/duotone_icon_badge.dart';

/// Admin-only User List with status filter + free-text search (site/department/
/// role filters also supported by the provider). List may show cached data when
/// offline; privileged actions live on the detail screen.
class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersListProvider);
    final filter = ref.watch(userFilterControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.adminUserNew),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invite'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (q) => ref
                  .read(userFilterControllerProvider.notifier)
                  .update(filter.copyWith(query: q)),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _StatusChip(
                  label: 'All',
                  selected: filter.status == null,
                  onTap: () => ref.read(userFilterControllerProvider.notifier).update(filter.copyWith(clearStatus: true)),
                ),
                for (final s in UserStatus.values)
                  _StatusChip(
                    label: _statusLabel(s),
                    selected: filter.status == s,
                    onTap: () => ref.read(userFilterControllerProvider.notifier).update(filter.copyWith(status: s)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(usersListProvider),
              ),
              data: (list) => list.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(usersListProvider),
                      child: ListView.separated(
                        padding: navSafeInsets(context),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _UserRow(user: list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});
  final ManagedUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: DuotoneIconBadge(icon: Icons.person_rounded, color: AppColors.infoBlue),
        title: Text(user.displayName, style: Theme.of(context).textTheme.bodyLarge),
        subtitle: Text(
          '${user.email}\n${user.roles.map((r) => r.role.name).join(', ')}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        isThreeLine: true,
        trailing: StatusBadge(status: user.status),
        onTap: () => context.push(Routes.adminUserDetail(user.id)),
      ),
    );
  }
}

/// Reusable status pill (Item 2 — dot + label on a tint).
class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});
  final UserStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(_statusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No users match your filters.\nInvite someone to get started.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.secondaryText, size: 40),
          const SizedBox(height: 12),
          Text("Couldn't load users", style: Theme.of(context).textTheme.titleLarge),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],),
      );
}

String _statusLabel(UserStatus s) => switch (s) {
      UserStatus.invited => 'Invited',
      UserStatus.active => 'Active',
      UserStatus.suspended => 'Suspended',
      UserStatus.deactivated => 'Deactivated',
    };

Color _statusColor(UserStatus s) => switch (s) {
      UserStatus.invited => AppColors.infoBlue,
      UserStatus.active => AppColors.primaryGreen,
      UserStatus.suspended => AppColors.warningAmber,
      UserStatus.deactivated => AppColors.criticalRed,
    };
