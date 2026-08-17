// path: lib/core/router/routes.dart
/// Centralised route paths & names. Keeps deep-link targets (notifications,
/// Prompt 15) and guards consistent. Feature routes are registered against
/// these constants in `app_router.dart`.
abstract final class Routes {
  // Auth
  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/login/forgot';
  /// Where invite and password-reset deep links land.
  static const setPassword = '/set-password';
  static const roleUnavailable = '/unavailable';

  // Shell tabs
  static const dashboard = '/dashboard';
  static const hazards = '/hazards';
  static const capa = '/capa';
  static const more = '/more';

  // Hazards
  static const hazardNew = '/hazards/new';
  static String hazardDetail(String id) => '/hazards/$id';
  static String hazardAssess(String id) => '/hazards/$id/assess';

  // Incidents
  static const incidents = '/incidents';
  static String incidentDetail(String id) => '/incidents/$id';

  // Investigations
  static const investigations = '/investigations';
  static String investigationDetail(String id) => '/investigations/$id';

  // CAPA
  static String capaDetail(String id) => '/capa/$id';

  // Inspections
  static const inspections = '/inspections';
  static String inspectionRun(String id) => '/inspections/$id/run';

  // User & Access Administration (Administrator only)
  static const adminUsers = '/admin/users';
  static const adminUserNew = '/admin/users/new';
  static String adminUserDetail(String id) => '/admin/users/$id';

  // Cross-cutting
  static const reports = '/reports';
  static const notifications = '/notifications';
  static const audit = '/audit';
  static const profile = '/more/profile';
  static const settings = '/settings';
}
