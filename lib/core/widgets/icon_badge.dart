import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Soft tinted circular icon badge. Default sizes feel minimalist on cards.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.tint = AppColors.tintGreen,
    this.color = AppColors.primary,
    this.size = 44,
    this.iconSize,
    this.shape = BoxShape.circle,
  });
  final IconData icon;
  final Color tint;
  final Color color;
  final double size;
  final double? iconSize;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final effectiveIconSize = iconSize ?? (size <= 36 ? 18 : (size <= 48 ? 22 : 28));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint, shape: shape),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: effectiveIconSize),
    );
  }
}

/// A square rounded version for inline list rows.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    this.tint = AppColors.tintGreen,
    this.color = AppColors.primary,
    this.size = 36,
  });
  final IconData icon;
  final Color tint;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size <= 36 ? 16 : 20),
    );
  }
}
