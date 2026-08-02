// path: lib/core/theme/ohs_theme_extension.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';

/// Signature design-system tokens that don't fit Material's ThemeData
/// (Master Prompt Items 1–9). Exposed via ThemeExtension so widgets read them
/// with `Theme.of(context).extension<OhsThemeExtension>()` and they adapt to
/// light/dark automatically.
@immutable
class OhsThemeExtension extends ThemeExtension<OhsThemeExtension> {
  const OhsThemeExtension({
    required this.riskLow,
    required this.riskMedium,
    required this.riskHigh,
    required this.riskCritical,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.brandAccent,
    required this.duotoneBgOpacity,
  });

  // Risk band colours (locked tokens; map 1:1 to risk_band enum).
  final Color riskLow; // Primary Green
  final Color riskMedium; // Warning Amber
  final Color riskHigh; // Critical Red
  final Color riskCritical; // Critical Red (full intensity)

  final Color heroGradientStart; // curved hero header (Item 4a)
  final Color heroGradientEnd;
  final Color brandAccent; // decorative only (Item 1b)

  /// Duotone icon badge background opacity (Item 5): 15%.
  final double duotoneBgOpacity;

  static const light = OhsThemeExtension(
    riskLow: AppColors.primaryGreen,
    riskMedium: AppColors.warningAmber,
    riskHigh: AppColors.criticalRed,
    riskCritical: AppColors.criticalRed,
    heroGradientStart: AppColors.primaryGreen,
    heroGradientEnd: AppColors.primaryGreenDeep,
    brandAccent: AppColors.brandAccent,
    duotoneBgOpacity: 0.15,
  );

  static const dark = OhsThemeExtension(
    riskLow: AppColors.greenOnDark,
    riskMedium: AppColors.warningAmber,
    riskHigh: AppColors.redOnDark,
    riskCritical: AppColors.redOnDark,
    heroGradientStart: AppColors.primaryGreen,
    heroGradientEnd: AppColors.primaryGreenDeep,
    brandAccent: AppColors.brandAccent,
    duotoneBgOpacity: 0.22,
  );

  @override
  OhsThemeExtension copyWith({
    Color? riskLow,
    Color? riskMedium,
    Color? riskHigh,
    Color? riskCritical,
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? brandAccent,
    double? duotoneBgOpacity,
  }) {
    return OhsThemeExtension(
      riskLow: riskLow ?? this.riskLow,
      riskMedium: riskMedium ?? this.riskMedium,
      riskHigh: riskHigh ?? this.riskHigh,
      riskCritical: riskCritical ?? this.riskCritical,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      brandAccent: brandAccent ?? this.brandAccent,
      duotoneBgOpacity: duotoneBgOpacity ?? this.duotoneBgOpacity,
    );
  }

  @override
  OhsThemeExtension lerp(ThemeExtension<OhsThemeExtension>? other, double t) {
    if (other is! OhsThemeExtension) return this;
    return OhsThemeExtension(
      riskLow: Color.lerp(riskLow, other.riskLow, t)!,
      riskMedium: Color.lerp(riskMedium, other.riskMedium, t)!,
      riskHigh: Color.lerp(riskHigh, other.riskHigh, t)!,
      riskCritical: Color.lerp(riskCritical, other.riskCritical, t)!,
      heroGradientStart: Color.lerp(heroGradientStart, other.heroGradientStart, t)!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      duotoneBgOpacity: t < 0.5 ? duotoneBgOpacity : other.duotoneBgOpacity,
    );
  }
}
