import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _items = <_NavItem>[
    _NavItem(
      route: '/home',
      label: AppStrings.tabHome,
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    _NavItem(
      route: '/farm',
      label: AppStrings.tabFarm,
      icon: Icons.grass_outlined,
      activeIcon: Icons.grass,
    ),
    _NavItem(
      route: '/ai',
      label: AppStrings.tabAi,
      icon: Icons.smart_toy_outlined,
      activeIcon: Icons.smart_toy,
    ),
    _NavItem(
      route: '/market',
      label: AppStrings.tabMarket,
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront,
    ),
    _NavItem(
      route: '/profile',
      label: AppStrings.tabProfile,
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _items.indexWhere((e) => location.startsWith(e.route));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        height: 68,
        elevation: 8,
        onDestinationSelected: (i) {
          context.go(_items[i].route);
        },
        destinations: [
          for (final item in _items)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: item.label,
            ),
        ],
      ),
      floatingActionButton: index == 1
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/ai/scan'),
              icon: const Icon(Icons.camera_alt),
              label: const Text(AppStrings.scanCrop),
            )
          : null,
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
