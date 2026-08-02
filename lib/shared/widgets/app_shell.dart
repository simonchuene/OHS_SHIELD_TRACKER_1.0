// path: lib/shared/widgets/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/core/theme/app_radii.dart';

/// Floating pill bottom navigation (Master Prompt Item 8), inset 12px with soft
/// elevation. Active tab = filled green pill with inline label; inactive tabs
/// show icon + label in Secondary Text. Hosts the StatefulShellRoute branches.
/// This is the PERMANENT navigation framework — future modules mount under More.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (_Tab(icon: Icons.grid_view_rounded, label: 'Dashboard')),
    (_Tab(icon: Icons.warning_amber_rounded, label: 'Hazards')),
    (_Tab(icon: Icons.check_circle_outline_rounded, label: 'Actions')),
    (_Tab(icon: Icons.more_horiz_rounded, label: 'More')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  _NavItem(
                    tab: _tabs[i],
                    active: navigationShell.currentIndex == i,
                    onTap: () => navigationShell.goBranch(
                      i,
                      initialLocation: i == navigationShell.currentIndex,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.active, required this.onTap});
  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (active) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            children: [
              Icon(tab.icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(tab.label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13,),),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Semantics(
        label: tab.label,
        button: true,
        child: SizedBox(
          width: 56,
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, color: AppColors.secondaryText, size: 22),
              const SizedBox(height: 2),
              Text(tab.label,
                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 10),),
            ],
          ),
        ),
      ),
    );
  }
}
