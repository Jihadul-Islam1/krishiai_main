import 'package:flutter/material.dart';

/// Minimalist, professional palette for Krishi AI.
///
/// The palette is intentionally low-saturation and high-contrast to feel
/// modern and timeless. Greens and amber accents are tuned so hero cards,
/// status chips, and charts read clearly on a near-white canvas.
class AppColors {
  AppColors._();

  // ----- Brand: greens ----------------------------------------------------
  static const Color primary = Color(0xFF1F7A3A);
  static const Color primaryDark = Color(0xFF145C2B);
  static const Color primaryLight = Color(0xFFE7F2EA);
  static const Color primaryContainer = Color(0xFFEDF5EF);
  static const Color primaryOnContainer = Color(0xFF1B5E20);

  // ----- Accent: amber -----------------------------------------------------
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentDark = Color(0xFFB45309);
  static const Color accentLight = Color(0xFFFEF3C7);

  // ----- Surfaces ---------------------------------------------------------
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF4F4F5);
  static const Color scaffoldDark = Color(0xFF0F172A);

  // ----- Hero cards (preserved signature surfaces) ------------------------
  static const Color weatherCard = Color(0xFF0F1F18);
  static const Color fieldCard = Color(0xFF14532D);
  static const Color aiCard = Color(0xFF0B1220);
  static const Color notificationCard = Color(0xFF1E293B);

  // ----- Text -------------------------------------------------------------
  static const Color textPrimary = Color(0xFF0F1419);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF8A938D);
  static const Color textOnDark = Colors.white;
  static const Color textOnDarkMuted = Color(0xCCFFFFFF);

  // ----- Borders / dividers -----------------------------------------------
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF1F3F4);

  // ----- Status -----------------------------------------------------------
  static const Color success = Color(0xFF1F7A3A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Severity scale (for diagnoses)
  static const Color severityLow = Color(0xFF16A34A);
  static const Color severityMedium = Color(0xFFD97706);
  static const Color severityHigh = Color(0xFFDC2626);

  // Soft tinted backgrounds used by IconBadge / status chips.
  static const Color tintGreen = Color(0xFFDCFCE7);
  static const Color tintAmber = Color(0xFFFEF3C7);
  static const Color tintRed = Color(0xFFFEE2E2);
  static const Color tintBlue = Color(0xFFDBEAFE);
  static const Color tintViolet = Color(0xFFEDE9FE);
  static const Color tintSlate = Color(0xFFF1F5F9);

  // Chart palette (calibrated for white backgrounds)
  static const List<Color> chartPalette = [
    Color(0xFF1F7A3A),
    Color(0xFFF59E0B),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
  ];

  // Soft shadow color (rgba(15, 20, 25, 0.06))
  static Color get shadowSoft => const Color(0xFF0F1419).withValues(alpha: 0.06);
  static Color get shadowMedium => const Color(0xFF0F1419).withValues(alpha: 0.10);
}