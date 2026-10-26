import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular farmer photo (image URL) with initials / person-icon
/// fallback while loading, offline, or when no photo has been uploaded.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 24,
    this.backgroundColor = AppColors.primary,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = _Fallback(name: name, radius: radius);
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: url == null || url.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.name, required this.radius});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Icon(Icons.person, color: Colors.white, size: radius);
    }
    return Text(
      trimmed.characters.first.toUpperCase(),
      style: TextStyle(
        color: Colors.white,
        fontSize: radius * 0.9,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
