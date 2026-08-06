// path: lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Locked colour system (Master Prompt Color System). These hex values are
/// owned by MVP1_1.md and must never change across MVP1/2/3.
abstract final class AppColors {
  // Semantic (identical in light & dark — meaning never changes)
  static const primaryGreen = Color(0xFF2E7D32);
  static const warningAmber = Color(0xFFF9A825);
  static const criticalRed = Color(0xFFC62828);
  static const infoBlue = Color(0xFF1565C0);

  // Light surfaces / text
  static const background = Color(0xFFF5F5F5);
  static const cardBackground = Color(0xFFFFFFFF);
  static const primaryText = Color(0xFF212121);
  static const secondaryText = Color(0xFF9E9E9E);

  // Dark surfaces / text (same hierarchy; only surfaces invert — Dark Mode rule)
  static const backgroundDark = Color(0xFF121212);
  static const cardBackgroundDark = Color(0xFF1E1E1E);
  static const primaryTextDark = Color(0xFFECECEC);

  // AA-safe lightened semantic tints for text/icons on dark surfaces ONLY
  // (status meaning is unchanged; these improve contrast, never recolour meaning).
  static const greenOnDark = Color(0xFF4CAF50);
  static const redOnDark = Color(0xFFEF5350);
  static const blueOnDark = Color(0xFF42A5F5);

  // Brand accent — DECORATIVE ONLY (Item 1b). Never used for status/semantic UI.
  static const brandAccent = Color(0xFF923357);

  // Deeper green for hero gradient (sampled from source icon, Item 4/4a)
  static const primaryGreenDeep = Color(0xFF1B5E20);
}

/// Brightness-aware text tokens.
///
/// The theme already injects the right colour into `textTheme`, so styles taken
/// from `Theme.of(context).textTheme` adapt automatically. Use these only where
/// a colour is set explicitly (custom painters, per-state text colours) —
/// reaching for the raw `AppColors.primaryText` constant there hardcodes the
/// light-mode value and renders near-black-on-black in dark mode.
extension AppTextColors on BuildContext {
  /// Primary text/foreground for the current brightness.
  Color get primaryTextColor => Theme.of(this).brightness == Brightness.dark
      ? AppColors.primaryTextDark
      : AppColors.primaryText;
}
