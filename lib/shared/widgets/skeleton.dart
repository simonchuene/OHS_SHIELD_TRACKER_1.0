// path: lib/shared/widgets/skeleton.dart
import 'package:flutter/material.dart';

/// Wraps a subtree of [SkeletonBox]es and sweeps a single shimmer highlight
/// across all of them, so a loading screen reads as "content is coming" instead
/// of showing a bare spinner. One controller drives the whole subtree.
class Shimmer extends StatefulWidget {
  const Shimmer({required this.child, super.key});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1350))..repeat();

  static const _base = Color(0xFFE6E8EB);
  static const _highlight = Color(0xFFF5F7F9);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: const [_base, _highlight, _base],
          stops: const [0.35, 0.5, 0.65],
          transform: _SlideGradient(_controller.value),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

/// Translates the shimmer gradient left→right across the bounds as t goes 0→1.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);
  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues((t * 2 - 1) * bounds.width, 0, 0);
}

/// A single grey placeholder shape. Colour comes from the enclosing [Shimmer]'s
/// shader, so a stand-alone box (without a Shimmer ancestor) simply shows grey.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.width, this.height = 16, this.radius = 8, super.key});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E8EB),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Loading placeholder for list screens: card rows with a leading dot, two text
/// lines, and a trailing chip. The card stays solid; only the inner shapes
/// shimmer (each row carries its own in-sync [Shimmer]).
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.rows = 6, this.padding = const EdgeInsets.all(16), super.key});
  final int rows;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const _SkeletonCard(),
      );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Shimmer(
          child: Row(children: [
            SkeletonBox(width: 44, height: 44, radius: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                SkeletonBox(width: double.infinity, height: 13),
                SizedBox(height: 8),
                SkeletonBox(width: 110, height: 11),
              ],),
            ),
            SizedBox(width: 12),
            SkeletonBox(width: 62, height: 22, radius: 999),
          ],),
        ),
      );
}

/// Loading placeholder for detail screens: title, subtitle, and a few blocks.
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({super.key});
  @override
  Widget build(BuildContext context) => const Shimmer(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 200, height: 22),
            SizedBox(height: 10),
            SkeletonBox(width: 140, height: 12),
            SizedBox(height: 24),
            SkeletonBox(width: double.infinity, height: 64, radius: 12),
            SizedBox(height: 16),
            SkeletonBox(width: double.infinity, height: 96, radius: 12),
            SizedBox(height: 16),
            SkeletonBox(width: double.infinity, height: 52, radius: 12),
          ],),
        ),
      );
}
