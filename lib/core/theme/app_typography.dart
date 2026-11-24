import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Apple HIG readable type scale — enforces a strict >= 11sp floor.
abstract final class AppTypography {
  static const double minReadableSize = 11.0;

  static const double captionSize = 11.0;
  static const double footnoteSize = 12.0;
  static const double subheadSize = 13.5;
  static const double bodySize = 15.0;
  static const double headlineSize = 17.0;
  static const double titleSize = 20.0;
  static const double largeTitleSize = 24.0;

  static TextTheme darkTextTheme() {
    return const TextTheme(
      headlineMedium: TextStyle(
        fontSize: largeTitleSize,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: titleSize,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        fontSize: headlineSize,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(
        fontSize: bodySize,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontSize: subheadSize,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontSize: footnoteSize,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        height: 1.35,
      ),
      labelLarge: TextStyle(
        fontSize: subheadSize,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: footnoteSize,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: captionSize,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.2,
      ),
    );
  }
}
