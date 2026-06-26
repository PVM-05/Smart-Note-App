// lib/core/design/app_text_styles.dart
// 🔒 Font family lock: Outfit across all roles. Do not deviate.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  static TextStyle displayLarge(BuildContext c) => GoogleFonts.outfit(fontSize: 57, fontWeight: FontWeight.w700, letterSpacing: -1.0);
  static TextStyle displayMedium(BuildContext c) => GoogleFonts.outfit(fontSize: 45, fontWeight: FontWeight.w700, letterSpacing: -0.8);
  static TextStyle displaySmall(BuildContext c) => GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w600, letterSpacing: -0.5);

  static TextStyle titleLarge(BuildContext c) => GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.2);
  static TextStyle bodyMedium(BuildContext c) => GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, height: 1.55);
  static TextStyle labelSmall(BuildContext c) => GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3);
}
