// path: lib/core/theme/app_spacing.dart
/// Locked spacing scale (Master Prompt): 4·8·12·16·24·32·40·64.
/// Grid: 16px margins, 16px gutters.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 64;

  static const double screenMargin = 16;
  static const double gutter = 16;

  /// WCAG 2.1 AA minimum touch target.
  static const double minTouchTarget = 44;
}
