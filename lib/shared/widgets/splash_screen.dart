// path: lib/shared/widgets/splash_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/router/splash_gate.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';

/// Branded launch screen shown while the router resolves the initial auth state.
/// Uses the same brand green as the native launch background (see
/// android/.../launch_background.xml) so the OS splash flows seamlessly into
/// Flutter with no colour flash.
///
/// The icon is clipped to a squircle (ContinuousRectangleBorder — a superellipse,
/// the same family of shape as an adaptive launcher icon) and animated: a
/// scale+fade entrance, a slow breathing pulse, and a soft halo that expands
/// behind it while loading. Renders the raster, not the SVG: flutter_svg drops
/// the gauge's stroke-dasharray and would draw the safety arc as a full circle.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  static const double _iconSize = 140;

  /// Squircle corner. A superellipse reads visually rounder than a plain rounded
  /// rect at the same radius, so this is larger than the icon's own 21% corner.
  static const _squircle = ContinuousRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(48)),
  );

  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..repeat(reverse: true);

  late final Animation<double> _iconFade =
      CurvedAnimation(parent: _entrance, curve: const Interval(0, 0.5, curve: Curves.easeOut));
  late final Animation<double> _iconScale = Tween<double>(begin: 0.82, end: 1)
      .animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack));
  late final Animation<double> _textFade =
      CurvedAnimation(parent: _entrance, curve: const Interval(0.45, 1, curve: Curves.easeOut));
  late final Animation<double> _textLift = Tween<double>(begin: 14, end: 0)
      .animate(CurvedAnimation(parent: _entrance, curve: const Interval(0.45, 1, curve: Curves.easeOutCubic)));
  late final Animation<double> _breathe =
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);

  Timer? _hold;

  @override
  void initState() {
    super.initState();
    // Start the hold here — i.e. once Flutter is actually drawing this screen —
    // so the animation gets its full run. The native launch screen covers the
    // preceding startup, which would otherwise eat most of the window.
    _hold = Timer(splashHold, () {
      if (mounted) ref.read(splashGateProvider).value = true;
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: _iconSize * 1.6,
            height: _iconSize * 1.6,
            child: AnimatedBuilder(
              animation: Listenable.merge([_entrance, _pulse]),
              builder: (context, child) {
                final halo = 1 + (_breathe.value * 0.22);
                return Stack(alignment: Alignment.center, children: [
                  // Soft halo breathing outward behind the tile.
                  Opacity(
                    opacity: (1 - _breathe.value) * 0.16 * _iconFade.value,
                    child: Transform.scale(
                      scale: halo,
                      child: Container(
                        width: _iconSize,
                        height: _iconSize,
                        decoration: const ShapeDecoration(color: Colors.white, shape: _squircle),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: _iconFade.value,
                    // Entrance scale plus a subtle breathing motion.
                    child: Transform.scale(
                      scale: _iconScale.value * (1 + _breathe.value * 0.025),
                      child: child,
                    ),
                  ),
                ],);
              },
              child: Container(
                decoration: ShapeDecoration(
                  shape: _squircle,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const ClipPath(
                  clipper: ShapeBorderClipper(shape: _squircle),
                  child: Image(
                    image: AssetImage('assets/branding/app_icon.png'),
                    width: _iconSize,
                    height: _iconSize,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _entrance,
            builder: (context, child) => Opacity(
              opacity: _textFade.value,
              child: Transform.translate(offset: Offset(0, _textLift.value), child: child),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'OHS SHIELD TRACKER',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2.5),
              ),
              const SizedBox(height: 6),
              Text(
                'Stay safe. Make it count.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            ],),
          ),
        ],),
      ),
    );
  }
}
