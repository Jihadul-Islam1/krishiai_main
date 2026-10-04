import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_divider.dart';
import '../../../core/widgets/icon_badge.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../../data/models/subscription.dart';
import '../../providers/app_providers.dart';

/// Top-level settings hub. Surfaces language, account, notification,
/// subscription, help, privacy, about, and logout destinations on a single
/// scrollable surface that mirrors the home_dashboard minimalist pattern
/// (gradient _Header + SectionHeader sections + AppCard nav rows).
const _kSettingsHeader = ScreenHeader(
  eyebrow: 'PREFERENCES',
  title: AppStrings.settingsTitle,
  leadingIcon: Icons.settings_rounded,
  gradient: [AppColors.weatherCard, AppColors.fieldCard],
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmerAsync = ref.watch(currentFarmerProvider);
    final subAsync = ref.watch(currentSubscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _kSettingsHeader,
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.huge,
              ),
              children: [
                // ---------------- Account & language ----------------
                const SectionHeader(
                  eyebrow: 'ACCOUNT',
                  title: AppStrings.tabProfile,
                  subtitle: AppStrings.settingsAccountSubtitle,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: EdgeInsets.zero,
                  elevation: AppElevation.card,
                  child: Column(
                    children: [
                      _NavRow(
                        icon: Icons.person_outline,
                        tint: AppColors.tintGreen,
                        color: AppColors.primary,
                        title: AppStrings.settingsEditProfile,
                        subtitle: farmerAsync.valueOrNull?.name ??
                            AppStrings.settingsProfileNotSet,
                        onTap: () => context.push('/profile/edit'),
                      ),
                      const AppDivider(),
                      _NavRow(
                        icon: Icons.translate_rounded,
                        tint: AppColors.tintViolet,
                        color: AppColors.primary,
                        title: AppStrings.languageLabel,
                        subtitle: AppStrings.bangla,
                        onTap: () => _showLanguageSheet(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // ---------------- Inbox & subscription ----------------
                const SectionHeader(
                  eyebrow: 'INBOX',
                  title: AppStrings.settingsInboxTitle,
                  subtitle: AppStrings.settingsInboxSubtitle,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: EdgeInsets.zero,
                  elevation: AppElevation.card,
                  child: Column(
                    children: [
                      _NavRow(
                        icon: Icons.notifications_outlined,
                        tint: AppColors.tintAmber,
                        color: AppColors.accentDark,
                        title: AppStrings.notifications,
                        subtitle: AppStrings.settingsInboxSubtitle,
                        onTap: () => context.push('/notifications'),
                      ),
                      const AppDivider(),
                      _NavRow(
                        icon: Icons.workspace_premium_outlined,
                        tint: AppColors.tintBlue,
                        color: AppColors.info,
                        title: AppStrings.settingsSubscription,
                        subtitle: subAsync.when(
                          data: (s) => s.tier == SubscriptionTier.premium
                              ? AppStrings.settingsPremiumActive
                              : AppStrings.settingsFreePlan,
                          loading: () => AppStrings.saving,
                          error: (_, _) => AppStrings.settingsUnknown,
                        ),
                        trailing: subAsync.valueOrNull?.tier ==
                                SubscriptionTier.premium
                            ? const Icon(
                                Icons.verified_rounded,
                                color: AppColors.success,
                                size: 20,
                              )
                            : null,
                        onTap: () => context.push('/subscription'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // ---------------- Help & info ----------------
                const SectionHeader(
                  eyebrow: 'INFO',
                  title: AppStrings.settingsHelpTitle,
                  subtitle: AppStrings.settingsHelpSubtitle,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: EdgeInsets.zero,
                  elevation: AppElevation.card,
                  child: Column(
                    children: [
                      _NavRow(
                        icon: Icons.help_outline_rounded,
                        tint: AppColors.tintGreen,
                        color: AppColors.primary,
                        title: AppStrings.settingsHelp,
                        onTap: () => context.push('/help'),
                      ),
                      const AppDivider(),
                      _NavRow(
                        icon: Icons.privacy_tip_outlined,
                        tint: AppColors.tintSlate,
                        color: AppColors.textSecondary,
                        title: AppStrings.settingsPrivacy,
                        onTap: () => context.push('/privacy'),
                      ),
                      const AppDivider(),
                      _NavRow(
                        icon: Icons.info_outline_rounded,
                        tint: AppColors.tintBlue,
                        color: AppColors.info,
                        title: AppStrings.settingsAbout,
                        onTap: () => context.push('/about'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _LogoutCard(onTap: () => _confirmLogout(context, ref)),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    '${AppStrings.appName} v1.0.0',
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

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.settingsLogout),
        content: const Text(AppStrings.settingsLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.settingsLogout),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = await ref.read(farmerRepoProvider.future);
      await repo.clear();
      final prefs = await ref.read(sharedPreferencesProvider.future);
      await prefs.remove('onboarding_complete');
      ref.invalidate(currentFarmerProvider);
      ref.invalidate(farmsProvider);
      ref.invalidate(cropsProvider);
      ref.invalidate(onboardingCompleteProvider);
      ref.invalidate(currentSubscriptionProvider);
      if (context.mounted) context.go('/onboarding');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.settingsLogoutFailed}: $e')),
        );
      }
    }
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Text(
                AppStrings.settingsPickLanguage,
                style: AppTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              _LanguageOption(
                flag: '🇧🇩',
                label: AppStrings.bangla,
                onTap: () => Navigator.of(ctx).pop(),
              ),
              const SizedBox(height: AppSpacing.sm),
              _LanguageOption(
                flag: '🇬🇧',
                label: AppStrings.english,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Header — matches home_dashboard / notifications_screen
// gradient shell with eyebrow + title.
// ============================================================
// ============================================================
// _NavRow — generic list row with IconBadge leading, title +
// optional subtitle, and chevron / custom trailing.
// ============================================================
// ============================================================
// _NavRow — generic list row with IconBadge leading, title +
// optional subtitle, and chevron / custom trailing.
// ============================================================
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.tint,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
                  Text(
                    title,
                    style: AppTextStyles.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// _LogoutCard — danger-tinted standalone card with logout
// row. Separated from the group cards above to emphasize the
// destructive action.
// ============================================================
class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: AppColors.danger.withValues(alpha: 0.25),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            IconBadge(
              icon: Icons.logout_rounded,
              tint: AppColors.tintRed,
              color: AppColors.danger,
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
                    AppStrings.settingsLogout,
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    AppStrings.settingsLogoutSubtitle,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.danger,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// _LanguageOption — flag + label row inside the language
// bottom sheet.
// ============================================================
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.onTap,
  });
  final String flag;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      bordered: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label, style: AppTextStyles.title),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
