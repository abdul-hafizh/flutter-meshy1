import 'package:flutter/material.dart';

/// Brand palette derived from the Snapy logo (orange -> purple/magenta swirl).
class AppColors {
  AppColors._();

  static const Color orange = Color(0xFFFF7A18);
  static const Color orangeDeep = Color(0xFFFF4E00);
  static const Color purple = Color(0xFF9B2FCE);
  static const Color purpleDeep = Color(0xFF6423A6);

  static const Color background = Color(0xFFFAF8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF4F1F8);

  static const Color textPrimary = Color(0xFF241A2E);
  static const Color textSecondary = Color(0xFF8D8798);
  static const Color textFaint = Color(0xFFB7B2C2);

  static const Color success = Color(0xFF2FB380);
  static const Color info = Color(0xFF3B82F6);
  static const Color border = Color(0xFFEFEAF4);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange, purple],
  );

  static const LinearGradient brandGradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFEDD9), Color(0xFFF3E3FA)],
  );

  static Color shadowFor(Color c) => c.withValues(alpha: 0.25);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.orange,
        secondary: AppColors.purple,
        surface: AppColors.surface,
        error: const Color(0xFFE0453A),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
