import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/disease.dart';

/// Shared visual treatment for diagnosis severity (chips, dots, banners).
extension SeverityStyle on Severity {
  Color get color => switch (this) {
        Severity.low => AppColors.severityLow,
        Severity.medium => AppColors.severityMedium,
        Severity.high => AppColors.severityHigh,
      };

  Color get tint => switch (this) {
        Severity.low => AppColors.tintGreen,
        Severity.medium => AppColors.tintAmber,
        Severity.high => AppColors.tintRed,
      };

  IconData get icon => switch (this) {
        Severity.low => Icons.check_circle_rounded,
        Severity.medium => Icons.error_outline_rounded,
        Severity.high => Icons.warning_amber_rounded,
      };

  String get riskLabel => switch (this) {
        Severity.low => 'কম ঝুঁকি',
        Severity.medium => 'মাঝারি ঝুঁকি',
        Severity.high => 'গুরুতর ঝুঁকি',
      };
}
