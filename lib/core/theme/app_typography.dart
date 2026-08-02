// path: lib/core/theme/app_typography.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';

/// Locked typography (Master Prompt). Inter (fallback Roboto).
/// H1 32/Bold · H2 24/SemiBold · H3 18/SemiBold · Body 14–16 · Caption 12.
abstract final class AppTypography {
  static const String fontFamily = 'Inter';
  static const List<String> fontFallback = ['Roboto'];

  /// Tabular figures for all KPIs/scores/counts (Item 6).
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
        displaySmall: _t(32, FontWeight.w700, primary), // H1
        headlineMedium: _t(24, FontWeight.w600, primary), // H2
        titleLarge: _t(18, FontWeight.w600, primary), // H3
        bodyLarge: _t(16, FontWeight.w400, primary),
        bodyMedium: _t(14, FontWeight.w400, primary),
        labelSmall: _t(12, FontWeight.w400, secondary), // caption
      );

  /// Oversized tabular numeral used by KPI tiles / Risk Compass centre (Item 6).
  static TextStyle metric(Color color, {double size = 28}) =>
      _t(size, FontWeight.w800, color).copyWith(fontFeatures: tabular);

  static TextStyle _t(double size, FontWeight weight, Color color) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.3,
      );

  // Convenience static styles (light defaults; theme injects colour at runtime).
  static final h1 = _t(32, FontWeight.w700, AppColors.primaryText);
  static final caption = _t(12, FontWeight.w400, AppColors.secondaryText);
}
