// path: lib/shared/widgets/rank_gated_action.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';

/// Client-side RBAC affordances.
///
/// **UX only.** RLS at the database is the authoritative gate (architecture §10)
/// — the client is untrusted, and a disabled button must never be the only thing
/// preventing an action. These exist so a user is told *before* tapping that
/// their role cannot perform a step, instead of getting a server rejection after.
///
/// Every gate here should mirror a policy that would also refuse server-side. A
/// mismatch the permissive way is invisible until someone hits an error; the
/// restrictive way silently blocks legitimate work.

/// True when the signed-in user's role rank meets [minRank]. Use directly for
/// inline/secondary buttons that do not want the full-width treatment below.
bool hasMinRank(WidgetRef ref, int minRank) =>
    (ref.watch(authRoleRankProvider) ?? 0) >= minRank;

/// The one-line explanation shown under a denied action. Centralised so the
/// wording stays identical everywhere — hazard and incident had already drifted
/// apart on styling before this existed.
class RoleDeniedNote extends StatelessWidget {
  const RoleDeniedNote({this.message, super.key});

  static const defaultMessage = 'Your role cannot perform this step.';
  final String? message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          message ?? defaultMessage,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),
        ),
      );
}

/// A full-width primary workflow action, disabled when the signed-in role may
/// not perform it, with the reason shown beneath.
///
/// [onPressed] may already be null for the caller's own reasons (a request in
/// flight, an incomplete form); the rank check only ever disables further, never
/// re-enables. Pass [permitted] to override the rank comparison for guards that
/// are not purely rank-based — e.g. a CAPA's owner may start work without
/// Supervisor rank (Ledger §10).
class RankGatedAction extends ConsumerWidget {
  const RankGatedAction({
    required this.minRank,
    required this.onPressed,
    required this.child,
    this.permitted,
    this.deniedMessage,
    super.key,
  });

  final int minRank;
  final VoidCallback? onPressed;
  final Widget child;
  final bool? permitted;
  final String? deniedMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = permitted ?? hasMinRank(ref, minRank);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: allowed ? onPressed : null, child: child),
        ),
        if (!allowed) RoleDeniedNote(message: deniedMessage),
      ],
    );
  }
}
