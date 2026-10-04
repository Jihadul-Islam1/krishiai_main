import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/screen_header.dart';

/// Bangla privacy policy. Static content rendered through the shared
/// header + SectionHeader + AppCard pattern.
const _kPrivacyHeader = ScreenHeader(
  eyebrow: AppStrings.privacyEyebrow,
  title: AppStrings.privacyTitle,
  leadingIcon: Icons.privacy_tip_outlined,
  gradient: [AppColors.scaffoldDark, AppColors.notificationCard],
);

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _kPrivacyHeader,
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
                const _UpdatedRow(),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: AppStrings.privacySection1Title,
                  body: AppStrings.privacySection1Body,
                ),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: AppStrings.privacySection2Title,
                  body: AppStrings.privacySection2Body,
                ),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: AppStrings.privacySection3Title,
                  body: AppStrings.privacySection3Body,
                ),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: AppStrings.privacySection4Title,
                  body: AppStrings.privacySection4Body,
                ),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: AppStrings.privacySection5Title,
                  body: AppStrings.privacySection5Body,
                ),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: AppStrings.privacySection6Title,
                  body: AppStrings.privacySection6Body,
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    AppStrings.privacyDisclaimer,
                    textAlign: TextAlign.center,
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
// _Section — title in h3 + body text inside an AppCard.
// ============================================================
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevation: AppElevation.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }
}

// ============================================================
// _UpdatedRow — small tinted card that surfaces the "last
// updated" metadata above the policy sections.
// ============================================================
class _UpdatedRow extends StatelessWidget {
  const _UpdatedRow();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevation: AppElevation.card,
      color: AppColors.primaryContainer,
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      child: Row(
        children: [
          IconBadge(
            icon: Icons.event_note_outlined,
            tint: AppColors.tintBlue,
            color: AppColors.primary,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.privacyHeaderTitle,
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.privacyUpdatedOn,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
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
