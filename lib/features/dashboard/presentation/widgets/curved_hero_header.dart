// path: lib/features/dashboard/presentation/widgets/curved_hero_header.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';

/// Curved green hero header (Master Prompt Item 4/4a): full-bleed green panel
/// with a shallow convex bottom, logo chip + two-line wordmark, avatar with the
/// progress-ring frame, left-aligned greeting, and the low-opacity brand
/// watermark (the real icon asset) upper-right.
class CurvedHeroHeader extends StatelessWidget {
  const CurvedHeroHeader({required this.firstName, required this.initials, required this.scopeLabel, super.key});
  final String firstName;
  final String initials;
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(clipBehavior: Clip.none, children: [
        // Green panel with shallow convex bottom curve.
        Container(
          height: 200,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primaryGreen, AppColors.primaryGreenDeep]),
            borderRadius: BorderRadius.only(bottomLeft: Radius.elliptical(400, 46), bottomRight: Radius.elliptical(400, 46)),
          ),
        ),
        // Brand watermark (real icon asset, low opacity) upper-right.
        Positioned(
          top: -20, right: -30,
          child: Opacity(opacity: 0.10, child: Image.asset('assets/branding/app_icon.png', width: 180, height: 180)),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.asset('assets/branding/app_icon.png', width: 38, height: 38),
                ),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('OHS SHIELD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: .3)),
                  Text('TRACKER', style: TextStyle(color: Color(0xFFA5D6A7), fontWeight: FontWeight.w500, fontSize: 11, letterSpacing: 4)),
                ],),
                const Spacer(),
                _AvatarRing(initials: initials),
              ],),
              const SizedBox(height: 16),
              Text('Good day, $firstName', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Stay safe. Make it count. · $scopeLabel', style: const TextStyle(color: Color(0xFFA5D6A7), fontSize: 13)),
            ],),
          ),
        ),
      ],),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.initials});
  final String initials;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFA5D6A7), width: 2.5),
      ),
      child: CircleAvatar(
        radius: 18, backgroundColor: const Color(0xFFFFFEF9),
        child: Text(initials, style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}
