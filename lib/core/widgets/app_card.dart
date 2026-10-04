import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Minimalist card. Defaults to a soft, shadow-on-white surface.
///
/// Pass [bordered] = true for inline list rows. Use [elevation] > 0 for
/// prominent floating cards (e.g. stats, hero info).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    this.borderRadius,
    this.onTap,
    this.elevation = 0,
    this.bordered = false,
    this.borderColor,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final double elevation;
  final bool bordered;
  final Color? borderColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final showShadow = elevation > 0 || (!bordered && onTap == null);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: radius,
        border: bordered
            ? Border.all(color: borderColor ?? AppColors.border, width: 1)
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.shadowSoft,
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                borderRadius: radius,
                splashColor: AppColors.primaryContainer.withValues(alpha: 0.6),
                highlightColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
  }
}
