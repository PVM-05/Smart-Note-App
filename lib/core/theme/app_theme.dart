// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import 'note_theme.dart';
import 'ai_theme.dart';

class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.lightSurface,
      error: AppColors.error,
      onPrimary: AppColors.onPrimary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      extensions: <ThemeExtension<dynamic>>[
        const NoteTheme(pinnedNote: Color(0xFFFFF8E1), selectedNote: Color(0xFFE0F2FE)),
        const AITheme(accent: Color(0xFF8B5CF6), background: Color(0xFFF7F3FF), border: Color(0xFFEDE7F6)),
      ],
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.darkAccent,
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.error,
      onPrimary: AppColors.onPrimary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      dividerColor: AppColors.darkDivider,
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkBackground,
      ),
      extensions: <ThemeExtension<dynamic>>[
        const NoteTheme(pinnedNote: Color(0xFF3E2723), selectedNote: Color(0xFF0B3244)),
        const AITheme(accent: Color(0xFF8B5CF6), background: Color(0xFF1B1038), border: Color(0xFF2B0E44)),
      ],
    );
  }
}
