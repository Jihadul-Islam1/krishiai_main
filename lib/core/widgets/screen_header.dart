import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Shared gradient page header used across the app.
///
/// Variants supported:
/// - eyebrow + title (most screens)
/// - eyebrow + title + subtitle (ai_assistant, subscription)
/// - optional `leadingIcon` rendered as a white-on-tinted glass badge
/// - optional `actionIcon` rendered as a 44x44 round button (tappable by
///   default; pass `actionDecorative: true` for a non-tappable container)
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.gradient,
    this.height = 140,
    this.actionIcon,
    this.onAction,
    this.actionTooltip,
    this.actionDecorative = false,
    this.actionBadgeCount = 0,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;

  /// Two-stop linear gradient. Defaults to `weatherCard -> fieldCard`
  /// (the most common combination across feature screens).
  final List<Color>? gradient;
  final double height;

  final IconData? actionIcon;
  final VoidCallback? onAction;
  final String? actionTooltip;
  final bool actionDecorative;
  final int actionBadgeCount;

  @override
  Widget build(BuildContext context) {
    final colors = gradient ??
        const [AppColors.weatherCard, AppColors.fieldCard];
    return Stack(
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppRadius.xxl),
              bottomRight: Radius.circular(AppRadius.xxl),
            ),
          ),
        ),
        Positioned(
          right: -40,
          top: -30,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leadingIcon != null) ...[
                  _LeadingBadge(icon: leadingIcon!),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: _TitleBlock(
                    eyebrow: eyebrow,
                    title: title,
                    subtitle: subtitle,
                  ),
                ),
                if (actionIcon != null)
                  _TrailingAction(
                    icon: actionIcon!,
                    onTap: onAction,
                    tooltip: actionTooltip,
                    decorative: actionDecorative,
                    badgeCount: actionBadgeCount,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LeadingBadge extends StatelessWidget {
  const _LeadingBadge({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });
  final String eyebrow;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          style: AppTextStyles.overline.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          title,
          style: AppTextStyles.h1.copyWith(color: Colors.white),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ],
    );
  }
}

class _TrailingAction extends StatelessWidget {
  const _TrailingAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.decorative,
    required this.badgeCount,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool decorative;
  final int badgeCount;
  @override
  Widget build(BuildContext context) {
    if (decorative) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 22)),
      );
    }
    final body = SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const SizedBox.expand(),
          Center(child: Icon(icon, color: Colors.white, size: 22)),
          if (badgeCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final ink = Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: body,
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: ink);
    }
    return ink;
  }
}
