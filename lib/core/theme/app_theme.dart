// path: lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/core/theme/app_radii.dart';
import 'package:ohs_shield_tracker/core/theme/app_typography.dart';
import 'package:ohs_shield_tracker/core/theme/ohs_theme_extension.dart';

/// Builds Material 3 light & dark themes from the locked token set.
/// Both themes share spacing, typography, hierarchy, navigation and component
/// design (Master Prompt Dark Mode rule).
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.cardBackgroundDark : AppColors.cardBackground;
    final bg = isDark ? AppColors.backgroundDark : AppColors.background;
    final primaryTextColor = isDark ? AppColors.primaryTextDark : AppColors.primaryText;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primaryGreen,
      error: AppColors.criticalRed,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme(primaryTextColor, AppColors.secondaryText),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.standardCard),
      ),
      // NOTE: use a bounded minimum width (min height 52), NOT Size.fromHeight
      // (which is Size(infinity, 52)). An infinite minimum width makes a themed
      // button demand unbounded width inside a Row, which aborts RenderFlex
      // layout and leaves the whole subtree unpainted. Full-width buttons still
      // fill their width via the surrounding Column's stretch / a SizedBox.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.infoBlue,
          side: const BorderSide(color: AppColors.infoBlue),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.infoBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.criticalRed),
        ),
      ),
      extensions: [isDark ? OhsThemeExtension.dark : OhsThemeExtension.light],
    );
  }
}
