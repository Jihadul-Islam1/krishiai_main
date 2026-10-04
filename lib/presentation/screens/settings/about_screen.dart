import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_divider.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/section_header.dart';

/// About / credits page. Renders through the shared header +
/// SectionHeader + AppCard pattern shared with help / privacy settings.
const _kAboutHeader = ScreenHeader(
  eyebrow: AppStrings.aboutEyebrow,
  title: AppStrings.aboutTitle,
  leadingIcon: Icons.info_outline_rounded,
  gradient: [AppColors.scaffoldDark, AppColors.notificationCard],
);

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _kAboutHeader,
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.huge,
              ),
              children: [
                const SizedBox(height: AppSpacing.lg),
                // --------------- App info ---------------
                const SectionHeader(
                  eyebrow: 'PRODUCT',
                  title: AppStrings.aboutHeaderTitle,
                  subtitle: AppStrings.aboutHeaderSubtitle,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: EdgeInsets.zero,
                  elevation: AppElevation.card,
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.eco_outlined,
                        tint: AppColors.tintGreen,
                        color: AppColors.primary,
                        label: AppStrings.aboutAppNameLabel,
                        value: AppStrings.aboutAppNameValue,
                      ),
                      const AppDivider(),
                      _InfoRow(
                        icon: Icons.tag_rounded,
                        tint: AppColors.tintBlue,
                        color: AppColors.info,
                        label: AppStrings.aboutVersionLabel,
                        value: AppStrings.aboutVersionValue,
                      ),
                      const AppDivider(),
                      _InfoRow(
                        icon: Icons.devices_rounded,
                        tint: AppColors.tintViolet,
                        color: AppColors.primary,
                        label: AppStrings.aboutPlatformLabel,
                        value: AppStrings.aboutPlatformValue,
                      ),
                      const AppDivider(),
                      _InfoRow(
                        icon: Icons.translate_rounded,
                        tint: AppColors.tintAmber,
                        color: AppColors.accentDark,
                        label: AppStrings.aboutLanguageLabel,
                        value: AppStrings.aboutLanguageValue,
                      ),
                      const AppDivider(),
                      _InfoRow(
                        icon: Icons.verified_outlined,
                        tint: AppColors.tintSlate,
                        color: AppColors.textSecondary,
                        label: AppStrings.aboutLicenseLabel,
                        value: AppStrings.aboutLicenseValue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // --------------- Features ---------------
                const SectionHeader(
                  eyebrow: 'WHAT''S INSIDE',
                  title: AppStrings.aboutFeaturesHeader,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  elevation: AppElevation.card,
                  child: Column(
                    children: const [
                      _FeatureBullet(
                        icon: Icons.eco_outlined,
                        tint: AppColors.tintGreen,
                        color: AppColors.primary,
                        text: AppStrings.aboutFeatureFarm,
                      ),
                      _FeatureBullet(
                        icon: Icons.local_florist_outlined,
                        tint: AppColors.tintBlue,
                        color: AppColors.info,
                        text: AppStrings.aboutFeatureDisease,
                      ),
                      _FeatureBullet(
                        icon: Icons.wb_sunny_outlined,
                        tint: AppColors.tintAmber,
                        color: AppColors.accentDark,
                        text: AppStrings.aboutFeatureWeather,
                      ),
                      _FeatureBullet(
                        icon: Icons.trending_up_outlined,
                        tint: AppColors.tintViolet,
                        color: AppColors.primary,
                        text: AppStrings.aboutFeatureMarket,
                      ),
                      _FeatureBullet(
                        icon: Icons.support_agent_outlined,
                        tint: AppColors.tintSlate,
                        color: AppColors.textSecondary,
                        text: AppStrings.aboutFeatureAssistant,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // --------------- Credits / disclaimer ---------------
                const SectionHeader(
                  eyebrow: 'CREDITS',
                  title: AppStrings.aboutCreditsHeader,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  color: AppColors.primaryContainer.withValues(alpha: 0.5),
                  elevation: AppElevation.card,
                  child: Text(
                    AppStrings.aboutCreditsBody,
                    style: AppTextStyles.body,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: Text(
                    AppStrings.aboutCopyright,
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _InfoRow — IconBadge leading + label / value pair inside an
// AppCard group, separated by AppDivider.
// ============================================================
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.tint,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color tint;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          IconBadge(
            icon: icon,
            tint: tint,
            color: color,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _FeatureBullet — IconBadge leading + feature text, carried
// over from the legacy layout but with token-driven colors.
// ============================================================
class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({
    required this.icon,
    required this.tint,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color tint;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconBadge(
            icon: icon,
            tint: tint,
            color: color,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
