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
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/states.dart';
import '../../../data/models/subscription.dart';
import '../../providers/app_providers.dart';

/// Plan picker (free / premium monthly / premium yearly). Uses the
/// shared gradient header + SectionHeader + AppCard pattern. The
/// current plan card is status-aware (tinted by subscription state).
const _kSubscriptionHeader = ScreenHeader(
  eyebrow: AppStrings.subscriptionEyebrow,
  title: AppStrings.subscriptionTitle,
  subtitle: AppStrings.subscriptionHeaderSubtitle,
  gradient: [AppColors.scaffoldDark, AppColors.notificationCard],
  height: 160,
  leadingIcon: Icons.workspace_premium_rounded,
);

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  Future<void> _activate(WidgetRef ref, String planId) async {
    final repo = await ref.read(subscriptionRepoProvider.future);
    await repo.setPremium(active: planId != 'free', days: 30);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(currentSubscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _kSubscriptionHeader,
          Expanded(
            child: subAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorStateView(
                message: '${AppStrings.subscriptionFailed}: ${e.toString()}',
              ),
              data: (sub) => ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.huge,
                ),
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  _CurrentPlanBanner(sub: sub),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                    eyebrow: 'WHY PREMIUM',
                    title: AppStrings.subscriptionHeaderTitle,
                    subtitle: AppStrings.subscriptionHeaderSubtitle,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PlanList(
                    currentId: sub.planId ?? 'free',
                    onChoose: (planId) async {
                      try {
                        await _activate(ref, planId);
                        ref.invalidate(currentSubscriptionProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              planId == 'free'
                                  ? AppStrings.subscriptionDowngraded
                                  : AppStrings.subscriptionActivated,
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${AppStrings.subscriptionFailed}: $e',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                    eyebrow: 'FAQ',
                    title: AppStrings.subscriptionFaqHeader,
                    subtitle: AppStrings.subscriptionFaqBody,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _FaqTeaser(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _Header — gradient shell, eyebrow + title + premium avatar.
// ============================================================
// (Migrated to ScreenHeader via _kSubscriptionHeader; class deleted.)

// ============================================================
// _CurrentPlanBanner — status-aware flat card showing the
// farmer'"'"'s current tier and expiry (if any).
// ============================================================
class _CurrentPlanBanner extends StatelessWidget {
  const _CurrentPlanBanner({required this.sub});
  final UserSubscription sub;

  static const _months = [
    'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রি', 'মে', 'জুন',
    'জুলা', 'আগ', 'সেপ্ট', 'অক্টো', 'নভে', 'ডিসে',
  ];

  String _fmtDate(DateTime d) {
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = sub.isPremium;
    final tint = isPremium ? AppColors.tintAmber : AppColors.tintGreen;
    final color = isPremium ? AppColors.warning : AppColors.primary;
    final label = isPremium
        ? AppStrings.subscriptionCurrentPremium
        : AppStrings.subscriptionCurrentFree;
    final detail = sub.expiresAt != null
        ? '${AppStrings.subscriptionExpirePrefix} ${_fmtDate(sub.expiresAt!)}'
        : AppStrings.subscriptionCurrentFreeDetail;

    return AppCard(
      elevation: AppElevation.card,
      color: tint.withValues(alpha: 0.12),
      borderColor: color.withValues(alpha: 0.25),
      child: Row(
        children: [
          IconBadge(
            icon: isPremium
                ? Icons.workspace_premium_rounded
                : Icons.eco_outlined,
            tint: tint,
            color: color,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.subscriptionCurrentLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.title.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppTextStyles.caption,
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
// _PlanList — data-driven list of _PlanCard tiles loaded from
// the SubscriptionRepository.
// ============================================================
class _PlanList extends ConsumerWidget {
  const _PlanList({required this.currentId, required this.onChoose});
  final String currentId;
  final Future<void> Function(String planId) onChoose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repoAsync = ref.watch(subscriptionRepoProvider);
    return repoAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: LoadingState(),
      ),
      error: (e, _) => ErrorStateView(
        message: '${AppStrings.subscriptionFailed}: ${e.toString()}',
      ),
      data: (repo) {
        final plans = repo.availablePlans();
        return Column(
          children: [
            for (var i = 0; i < plans.length; i++) ...[
              _PlanCard(
                plan: plans[i],
                isCurrent: plans[i].id == currentId,
                onChoose: () => onChoose(plans[i].id),
              ),
              if (i < plans.length - 1)
                const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

// ============================================================
// _PlanCard — single plan tile with icon, price, features,
// current badge, and CTA button.
// ============================================================
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.onChoose,
  });

  final SubscriptionPlan plan;
  final bool isCurrent;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final isPremium = plan.tier == SubscriptionTier.premium;
    final tint = isPremium ? AppColors.tintBlue : AppColors.tintSlate;
    final color = isPremium ? AppColors.info : AppColors.textSecondary;

    return AppCard(
      padding: EdgeInsets.zero,
      elevation: AppElevation.card,
      borderColor: isCurrent
          ? AppColors.primary.withValues(alpha: 0.4)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md,
            ),
            child: Row(
              children: [
                IconBadge(
                  icon: isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.eco_outlined,
                  tint: tint,
                  color: color,
                  size: 44,
                  iconSize: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(plan.title, style: AppTextStyles.title),
                      const SizedBox(height: 2),
                      Text(
                        plan.priceLabel,
                        style: AppTextStyles.caption.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      AppStrings.subscriptionCurrentPlanBadge,
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const AppDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final feature in plan.features) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: color,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            feature,
                            style: AppTextStyles.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                isCurrent
                    ? PrimaryButton(
                        label: AppStrings.subscriptionActivePlan,
                        onPressed: null,
                      )
                    : PrimaryButton(
                        label: isPremium
                            ? AppStrings.subscriptionChoosePremium
                            : AppStrings.subscriptionChooseFree,
                        onPressed: onChoose,
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
// _FaqTeaser — small tinted card linking to the help screen for
// full FAQ info.
// ============================================================
class _FaqTeaser extends StatelessWidget {
  const _FaqTeaser();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/help'),
      elevation: AppElevation.card,
      color: AppColors.primaryContainer,
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      child: Row(
        children: [
          IconBadge(
            icon: Icons.help_outline_rounded,
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
                  AppStrings.subscriptionFaqHeader,
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.subscriptionFaqBody,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
