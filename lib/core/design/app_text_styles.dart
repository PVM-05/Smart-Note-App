// lib/core/design/app_text_styles.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  static TextStyle displayLarge(BuildContext c) => GoogleFonts.inter(fontSize: 57, fontWeight: FontWeight.w700);
  static TextStyle displayMedium(BuildContext c) => GoogleFonts.inter(fontSize: 45, fontWeight: FontWeight.w700);
  static TextStyle displaySmall(BuildContext c) => GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w700);

  static TextStyle titleLarge(BuildContext c) => GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600);
  static TextStyle bodyMedium(BuildContext c) => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle labelSmall(BuildContext c) => GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600);
}
