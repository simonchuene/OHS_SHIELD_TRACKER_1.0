// path: lib/shared/widgets/duotone_icon_badge.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/ohs_theme_extension.dart';

/// Duotone icon treatment (Master Prompt Item 5): glyph in [color] at full
/// opacity over a filled circle of the same colour at 15% opacity. Mandatory in
/// cards and list rows — never a flat single-tone icon on white.
class DuotoneIconBadge extends StatelessWidget {
  const DuotoneIconBadge({
    required this.icon,
    required this.color,
    this.size = 38,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final opacity =
        Theme.of(context).extension<OhsThemeExtension>()?.duotoneBgOpacity ?? 0.15;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}
