import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/primary_button.dart';
import '../../providers/app_providers.dart';

class _OnboardItem {
  const _OnboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const _items = <_OnboardItem>[
  _OnboardItem(
    title: AppStrings.onboardTitle1,
    subtitle: AppStrings.onboardSubtitle1,
    icon: Icons.smart_toy,
    color: AppColors.primary,
  ),
  _OnboardItem(
    title: AppStrings.onboardTitle2,
    subtitle: AppStrings.onboardSubtitle2,
    icon: Icons.wb_sunny,
    color: AppColors.accent,
  ),
  _OnboardItem(
    title: AppStrings.onboardTitle3,
    subtitle: AppStrings.onboardSubtitle3,
    icon: Icons.storefront,
    color: AppColors.primary,
  ),
  _OnboardItem(
    title: AppStrings.onboardTitle4,
    subtitle: AppStrings.onboardSubtitle4,
    icon: Icons.account_balance_wallet,
    color: AppColors.accent,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Future<void> _markVisited() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    ref.invalidate(onboardingCompleteProvider);
  }

  void _continue() async {
    await _markVisited();
    if (mounted) context.go('/profile-setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TextButton(
                  onPressed: _continue,
                  child: const Text(AppStrings.skip),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      for (int i = 0; i < _items.length; i++)
                        Expanded(
                          child: _OnboardBlock(item: _items[i], compact: true),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: PrimaryButton(
                onPressed: _continue,
                label: AppStrings.getStarted,
                fullWidth: true,
                icon: Icons.arrow_forward,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardBlock extends StatelessWidget {
  const _OnboardBlock({required this.item, this.compact = false});
  final _OnboardItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final circleSize = compact ? 84.0 : 120.0;
    final iconSize = compact ? 44.0 : 64.0;
    final titleStyle = compact
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleLarge;
    final bodyStyle = compact
        ? Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)
        : Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.black54);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color.withValues(alpha: 0.12),
            ),
            child: Icon(item.icon, size: iconSize, color: item.color),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              item.subtitle,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle,
            ),
          ),
        ],
      ),
    );
  }
}
