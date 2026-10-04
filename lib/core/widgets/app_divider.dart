import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A thin hairline divider.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = 0, this.endIndent = 0});
  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.divider,
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: endIndent,
    );
  }
}
