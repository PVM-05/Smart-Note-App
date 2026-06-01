// lib/core/theme/theme_x.dart
import 'package:flutter/material.dart';
import '../theme/note_theme.dart';
import '../theme/ai_theme.dart';

extension ThemeX on BuildContext {
  NoteTheme get noteTheme => Theme.of(this).extension<NoteTheme>()!;
  AITheme get aiTheme => Theme.of(this).extension<AITheme>()!;
}
