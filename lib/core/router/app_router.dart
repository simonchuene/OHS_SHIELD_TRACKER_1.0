// path: lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/auth/session_providers.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:ohs_shield_tracker/features/audit/presentation/screens/audit_detail_screen.dart';
import 'package:ohs_shield_tracker/features/audit/presentation/screens/audit_list_screen.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/screens/login_screen.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/screens/capa_board_screen.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/screens/capa_detail_screen.dart';
import 'package:ohs_shield_tracker/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/screens/hazard_detail_screen.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/screens/hazard_list_screen.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/screens/hazard_report_screen.dart';
import 'package:ohs_shield_tracker/features/incidents/presentation/screens/incident_detail_screen.dart';
import 'package:ohs_shield_tracker/features/incidents/presentation/screens/incident_list_screen.dart';
import 'package:ohs_shield_tracker/features/incidents/presentation/screens/incident_report_screen.dart';
import 'package:ohs_shield_tracker/features/investigations/presentation/screens/investigation_detail_screen.dart';
import 'package:ohs_shield_tracker/features/investigations/presentation/screens/investigation_list_screen.dart';
import 'package:ohs_shield_tracker/features/inspections/presentation/screens/inspection_list_screen.dart';
import 'package:ohs_shield_tracker/features/inspections/presentation/screens/inspection_new_screen.dart';
import 'package:ohs_shield_tracker/features/inspections/presentation/screens/inspection_run_screen.dart';
import 'package:ohs_shield_tracker/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:ohs_shield_tracker/features/reports/presentation/screens/report_screen.dart';
import 'package:ohs_shield_tracker/features/risk/presentation/screens/risk_assessment_screen.dart';
import 'package:ohs_shield_tracker/features/user_admin/presentation/screens/invite_user_screen.dart';
import 'package:ohs_shield_tracker/features/user_admin/presentation/screens/user_detail_screen.dart';
import 'package:ohs_shield_tracker/features/user_admin/presentation/screens/user_list_screen.dart';
import 'package:ohs_shield_tracker/shared/widgets/app_shell.dart';
import 'package:ohs_shield_tracker/shared/widgets/placeholder_screen.dart';

/// Declarative navigation (GoRouter) with an auth-redirect guard and a role
/// guard on restricted routes. Feature prompts replace the [PlaceholderScreen]
/// builders with real screens; the shell/route structure here is stable.
final goRouterProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);

  final rootKey = GlobalKey<NavigatorState>();
  final shellKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.splash,
    refreshListenable: GoRouterRefreshStream(client.auth.onAuthStateChange),
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final loc = state.matchedLocation;

      // Splash is transient: never linger on it — route straight to the right place.
      if (loc == Routes.splash) return loggedIn ? Routes.dashboard : Routes.login;

      final authRoutes = {Routes.login, Routes.forgotPassword};
      final onAuthRoute = authRoutes.contains(loc);

      if (!loggedIn && !onAuthRoute) return Routes.login;
      if (loggedIn && onAuthRoute) return Routes.dashboard;

      // Role guard: Audit Viewer is SO/Manager/Admin (rank >= 3). RLS is the
      // authoritative gate; this only avoids a dead-end for unauthorised roles.
      final rank = ref.read(authRoleRankProvider);
      if (loc.startsWith(Routes.audit) && rank != null && rank < 3) {
        return Routes.roleUnavailable;
      }
      // User & Access Administration is Administrator-only (rank 5). RLS + the
      // Edge Function are authoritative; this only avoids a dead-end.
      if (loc.startsWith('/admin') && rank != null && rank < 5) {
        return Routes.roleUnavailable;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const PlaceholderScreen(title: 'OHS Shield Tracker')),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.roleUnavailable, builder: (_, __) => const PlaceholderScreen(title: 'Not available for your role')),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(navigatorKey: shellKeys[0], routes: [
            GoRoute(path: Routes.dashboard, builder: (_, __) => const DashboardScreen()),
          ],),
          StatefulShellBranch(navigatorKey: shellKeys[1], routes: [
            GoRoute(
              path: Routes.hazards,
              builder: (_, __) => const HazardListScreen(),
              routes: [
                GoRoute(path: 'new', parentNavigatorKey: rootKey, builder: (_, __) => const HazardReportScreen()),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootKey,
                  builder: (_, s) => HazardDetailScreen(hazardId: s.pathParameters['id']!),
                  routes: [
                    GoRoute(path: 'assess', parentNavigatorKey: rootKey, builder: (_, s) => RiskAssessmentScreen(hazardId: s.pathParameters['id']!)),
                  ],
                ),
              ],
            ),
          ],),
          StatefulShellBranch(navigatorKey: shellKeys[2], routes: [
            GoRoute(
              path: Routes.capa,
              builder: (_, __) => const CapaBoardScreen(),
              routes: [
                GoRoute(path: ':id', parentNavigatorKey: rootKey, builder: (_, s) => CapaDetailScreen(capaId: s.pathParameters['id']!)),
              ],
            ),
          ],),
          StatefulShellBranch(navigatorKey: shellKeys[3], routes: [
            GoRoute(
              path: Routes.more,
              builder: (_, __) => const PlaceholderScreen(title: 'More'),
              routes: [
                GoRoute(path: 'profile', builder: (_, __) => const PlaceholderScreen(title: 'Profile')),
              ],
            ),
            GoRoute(
              path: Routes.adminUsers,
              builder: (_, __) => const UserListScreen(),
              routes: [
                GoRoute(path: 'new', parentNavigatorKey: rootKey, builder: (_, __) => const InviteUserScreen()),
                GoRoute(path: ':id', parentNavigatorKey: rootKey, builder: (_, s) => UserDetailScreen(userId: s.pathParameters['id']!)),
              ],
            ),
            GoRoute(
              path: Routes.incidents,
              builder: (_, __) => const IncidentListScreen(),
              routes: [
                GoRoute(path: 'new', parentNavigatorKey: rootKey, builder: (_, __) => const IncidentReportScreen()),
                GoRoute(path: ':id', parentNavigatorKey: rootKey, builder: (_, s) => IncidentDetailScreen(incidentId: s.pathParameters['id']!)),
              ],
            ),
            GoRoute(
              path: Routes.investigations,
              builder: (_, __) => const InvestigationListScreen(),
              routes: [
                GoRoute(path: ':id', parentNavigatorKey: rootKey, builder: (_, s) => InvestigationDetailScreen(investigationId: s.pathParameters['id']!)),
              ],
            ),
            GoRoute(
              path: Routes.inspections,
              builder: (_, __) => const InspectionListScreen(),
              routes: [
                GoRoute(path: 'new', parentNavigatorKey: rootKey, builder: (_, __) => const InspectionNewScreen()),
                GoRoute(path: ':id/run', parentNavigatorKey: rootKey, builder: (_, s) => InspectionRunScreen(inspectionId: s.pathParameters['id']!)),
              ],
            ),
            GoRoute(path: Routes.reports, builder: (_, __) => const ReportScreen()),
            GoRoute(path: Routes.notifications, builder: (_, __) => const NotificationCenterScreen()),
            GoRoute(
              path: Routes.audit,
              builder: (_, __) => const AuditListScreen(),
              routes: [
                GoRoute(path: ':id', parentNavigatorKey: rootKey, builder: (_, s) => AuditDetailScreen(auditId: s.pathParameters['id']!)),
              ],
            ),
            GoRoute(path: Routes.settings, builder: (_, __) => const PlaceholderScreen(title: 'Settings')),
          ],),
        ],
      ),
    ],
    errorBuilder: (_, state) => PlaceholderScreen(title: 'Not found: ${state.uri}'),
  );
});
