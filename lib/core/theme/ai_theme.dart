// lib/core/theme/ai_theme.dart
import 'package:flutter/material.dart';

class AITheme extends ThemeExtension<AITheme> {
  final Color? accent;
  final Color? background;
  final Color? border;

  const AITheme({this.accent, this.background, this.border});

  @override
  AITheme copyWith({Color? accent, Color? background, Color? border}) {
    return AITheme(
      accent: accent ?? this.accent,
      background: background ?? this.background,
      border: border ?? this.border,
    );
  }

  @override
  AITheme lerp(ThemeExtension<AITheme>? other, double t) {
    if (other is! AITheme) return this;
    return AITheme(
      accent: Color.lerp(accent, other.accent, t),
      background: Color.lerp(background, other.background, t),
      border: Color.lerp(border, other.border, t),
    );
  }
}
