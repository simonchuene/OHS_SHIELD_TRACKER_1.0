// path: lib/features/dashboard/presentation/widgets/risk_compass.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';

/// The signature Risk Compass (Master Prompt Item 3) — a segmented radial gauge
/// (Low/Medium/High/Critical arcs in the locked tokens) with the score as a
/// large tabular numeral and a small compliance checkmark at the ring's gap.
class RiskCompass extends StatelessWidget {
  const RiskCompass({required this.score, this.size = 120, super.key});
  final int score; // 0..100
  final double size;

  @override
  Widget build(BuildContext context) {
    // Resolved per brightness: the score and the indicator tick are drawn with
    // an explicit colour, so they must follow the OS light/dark mode rather than
    // the light-mode constant (which was invisible on a dark surface).
    final foreground = context.primaryTextColor;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size(size, size), painter: _CompassPainter(score, foreground)),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$score',
              style: TextStyle(
                fontSize: size * 0.28, fontWeight: FontWeight.w800,
                color: foreground, fontFeatures: const [FontFeature.tabularFigures()],
              ),),
          Text('of 100', style: TextStyle(fontSize: size * 0.09, color: AppColors.secondaryText)),
        ],),
        Positioned(
          bottom: size * 0.06,
          child: Container(
            width: size * 0.16, height: size * 0.16,
            decoration: const BoxDecoration(color: Color(0xFFE4E3DA), shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: size * 0.11, color: AppColors.primaryGreen),
          ),
        ),
      ],),
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter(this.score, this.foreground);
  final int score;

  /// Brightness-resolved colour for the score indicator tick (painters have no
  /// access to a theme, so it is passed in).
  final Color foreground;

  static const _colors = [
    AppColors.primaryGreen, // Low
    AppColors.warningAmber, // Medium
    AppColors.criticalRed, // High
    Color(0xFF8E1616), // Critical (full intensity)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 8);
    final stroke = size.width * 0.09;
    const startDeg = 135.0, totalDeg = 270.0, segDeg = totalDeg / 4;

    for (var i = 0; i < 4; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = _colors[i];
      canvas.drawArc(rect, _rad(startDeg + i * segDeg + 2), _rad(segDeg - 4), false, paint);
    }

    // Score indicator tick.
    final angle = _rad(startDeg + (score.clamp(0, 100) / 100) * totalDeg);
    final r = size.width / 2 - 8;
    final c = size.center(Offset.zero);
    final p = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    canvas.drawCircle(p, stroke * 0.55, Paint()..color = foreground);
  }

  double _rad(double deg) => deg * math.pi / 180;

  @override
  bool shouldRepaint(covariant _CompassPainter old) => old.score != score || old.foreground != foreground;
}
