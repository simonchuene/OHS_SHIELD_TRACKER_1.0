// path: lib/features/user_admin/presentation/screens/user_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/managed_user.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/user_lifecycle.dart';
import 'package:ohs_shield_tracker/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:ohs_shield_tracker/features/user_admin/presentation/screens/user_list_screen.dart' show StatusBadge;

/// User detail + lifecycle actions (Administrator-only; server re-enforces).
class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({required this.userId, super.key});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userDetailProvider(userId));
    final busy = ref.watch(userAdminActionControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('User')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (user) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              CircleAvatar(radius: 28, backgroundColor: AppColors.primaryGreen, child: Text(user.initials, style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.displayName, style: Theme.of(context).textTheme.titleLarge),
                  Text(user.email, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText)),
                ],),
              ),
              StatusBadge(status: user.status),
            ],),
            const SizedBox(height: 24),
            _Section(title: 'Roles & scope', children: [
              if (user.roles.isEmpty)
                const Text('No roles assigned')
              else
                for (final r in user.roles)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(r.role.name),
                    subtitle: Text(r.scopeLabel),
                  ),
            ],),
            if (user.jobTitle != null || user.phone != null)
              _Section(title: 'Profile', children: [
                if (user.jobTitle != null) Text('Job title: ${user.jobTitle}'),
                if (user.phone != null) Text('Phone: ${user.phone}'),
              ],),
            const SizedBox(height: 16),
            const Divider(),
            Text('Actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (UserLifecycle.canPerform(UserAction.resendInvite, user.status))
                _ActionButton(label: 'Resend invite', busy: busy, onTap: () => _do(context, ref, user, UserAction.resendInvite)),
              if (UserLifecycle.canPerform(UserAction.resetPassword, user.status))
                _ActionButton(label: 'Reset password', busy: busy, onTap: () => _do(context, ref, user, UserAction.resetPassword)),
              if (UserLifecycle.canPerform(UserAction.suspend, user.status))
                _ActionButton(label: 'Suspend', busy: busy, danger: true, onTap: () => _do(context, ref, user, UserAction.suspend)),
              if (UserLifecycle.canPerform(UserAction.reactivate, user.status))
                _ActionButton(label: 'Reactivate', busy: busy, onTap: () => _do(context, ref, user, UserAction.reactivate)),
              if (UserLifecycle.canPerform(UserAction.deactivate, user.status))
                _ActionButton(label: 'Deactivate', busy: busy, danger: true, onTap: () => _do(context, ref, user, UserAction.deactivate)),
            ],),
          ],
        ),
      ),
    );
  }

  Future<void> _do(BuildContext context, WidgetRef ref, ManagedUser user, UserAction action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${_verb(action)}?'),
        content: Text('${_verb(action)} ${user.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(_verb(action))),
        ],
      ),
    );
    if (confirmed != true) return;

    final ctrl = ref.read(userAdminActionControllerProvider.notifier);
    final ok = switch (action) {
      UserAction.resendInvite => await ctrl.resendInvite(user),
      UserAction.resetPassword => await ctrl.resetPassword(user),
      UserAction.suspend => await ctrl.suspend(user),
      UserAction.reactivate => await ctrl.reactivate(user),
      UserAction.deactivate => await ctrl.deactivate(user),
    };
    if (!context.mounted) return;
    final failure = ref.read(userAdminActionControllerProvider).error;
    final msg = ok
        ? '${_verb(action)} done'
        : (failure is Failure ? failure.message : 'Action failed');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _verb(UserAction a) => switch (a) {
        UserAction.resendInvite => 'Resend invite',
        UserAction.resetPassword => 'Reset password',
        UserAction.suspend => 'Suspend',
        UserAction.reactivate => 'Reactivate',
        UserAction.deactivate => 'Deactivate',
      };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          ...children,
        ],
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap, this.busy = false, this.danger = false});
  final String label;
  final VoidCallback onTap;
  final bool busy;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? AppColors.criticalRed : AppColors.infoBlue,
        side: BorderSide(color: danger ? AppColors.criticalRed : AppColors.infoBlue),
      ),
      child: Text(label),
    );
  }
}
