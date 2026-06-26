// lib/core/design/app_colors.dart
// Central design color tokens for Smart Note (moved from core/app_colors.dart)
import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryVariant = Color(0xFF2563EB);
  static const Color accent = Color(0xFF60A5FA);

  // Light
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInputBackground = Color(0xFFF1F5F9);
  static const Color lightToolbarBackground = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF1E293B);
  static const Color lightTextMetadata = Color(0xFF64748B);
  static const Color lightPlaceholder = Color(0xFF94A3B8);
  static const Color lightDivider = Color(0xFFE2E8F0);
  static const Color lightDisabled = Color(0xFFE2E8F0);
  static const Color lightRipple = Color(0x1A000000);
  static const Color lightSelected = Color(0x333B82F6);

  // Dark (Google Keep–inspired: deeper navy base for OLED richness)
  static const Color darkBackground = Color(0xFF141519); // deeper than before
  static const Color darkSurface = Color(0xFF1E2028);    // richer surface
  static const Color darkSearchBar = Color(0xFF272A33);  // subtle contrast
  static const Color darkIconCircle = Color(0xFF3C404B);
  static const Color darkInputBackground = Color(0xFF272A33);
  static const Color darkToolbarBackground = Color(0xFF1E2028);
  static const Color darkDrawerSelected = Color(0xFF2E3A50);
  static const Color darkFabBackground = Color(0xFF3C404B);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFE8EAED);
  static const Color darkTextMetadata = Color(0xFF9AA0A6);
  static const Color darkPlaceholder = Color(0xFF9AA0A6);
  static const Color darkDivider = Color(0xFF3C404B);
  static const Color darkDisabled = Color(0xFF48484A);
  static const Color darkRipple = Color(0x1AFFFFFF);
  static const Color darkSelected = Color(0x333B82F6); // blue-tinted selection
  static const Color darkAccent = Color(0xFF60A5FA);   // accent-400 blue

  // On colors
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Color(0xFF1E293B);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Helpers
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBackground : lightBackground;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color inputBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkInputBackground : lightInputBackground;

  static Color toolbarBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkToolbarBackground : lightToolbarBackground;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color textMetadata(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextMetadata : lightTextMetadata;

  static Color placeholder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPlaceholder : lightPlaceholder;

  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkDivider : lightDivider;

  static Color disabled(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkDisabled : lightDisabled;

  static Color ripple(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkRipple : lightRipple;

  static Color selected(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSelected : lightSelected;

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Thanh tìm kiếm trên Home / Search.
  static Color searchBarBackground(BuildContext context) =>
      _isDark(context) ? darkSearchBar : Colors.white;

  /// Nền vòng tròn icon bộ lọc (màn tìm kiếm).
  static Color filterIconCircleBackground(BuildContext context) =>
      _isDark(context) ? darkIconCircle : Colors.white;

  /// Icon trong vòng bộ lọc.
  static Color filterIconColor(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : lightTextMetadata;

  /// Mục drawer đang chọn — nền.
  static Color drawerSelectedBackground(BuildContext context) =>
      _isDark(context) ? darkDrawerSelected : primary.withValues(alpha: 0.12);

  /// Mục drawer đang chọn — chữ & icon.
  static Color drawerSelectedForeground(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : primary;

  /// Chip bộ lọc trên thanh search.
  static Color filterChipBackground(BuildContext context) =>
      _isDark(context) ? darkIconCircle : primary.withValues(alpha: 0.12);

  static Color filterChipForeground(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : primaryVariant;

  /// FAB tạo ghi chú.
  static Color fabBackground(BuildContext context) =>
      _isDark(context) ? darkFabBackground : lightSurface;

  static Color fabForeground(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : primary;

  /// Viền/tick khi chọn màu trong picker (Keep: tím ở dark, xanh ở light).
  static Color notePickerAccent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFBB86FC)
          : primary;

  /// Nền ô “Mặc định” trong picker.
  static Color notePickerClearSwatch(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF3C3F43)
          : Colors.white;

  static const List<NotePaletteEntry> _notePalette = [
    NotePaletteEntry(
      light: Color(0xFFF28B82),
      dark: Color(0xFF5C2B29),
      label: 'Cam ánh hồng',
    ),
    NotePaletteEntry(
      light: Color(0xFFFBBC04),
      dark: Color(0xFF692B17),
      label: 'Cam',
    ),
    NotePaletteEntry(
      light: Color(0xFFFFF475),
      dark: Color(0xFF7C4A03),
      label: 'Vàng',
    ),
    NotePaletteEntry(
      light: Color(0xFFCCFF90),
      dark: Color(0xFF264D3A),
      label: 'Xanh lá',
    ),
    NotePaletteEntry(
      light: Color(0xFFA7FFEB),
      dark: Color(0xFF0C625D),
      label: 'Xanh mint',
    ),
    NotePaletteEntry(
      light: Color(0xFFCBF0F8),
      dark: Color(0xFF256377),
      label: 'Xanh nhạt',
    ),
    NotePaletteEntry(
      light: Color(0xFFAECBFA),
      dark: Color(0xFF284255),
      label: 'Xanh lam',
    ),
    NotePaletteEntry(
      light: Color(0xFFD7AEFB),
      dark: Color(0xFF472E5B),
      label: 'Tím',
    ),
    NotePaletteEntry(
      light: Color(0xFFFDCFE8),
      dark: Color(0xFF6C394F),
      label: 'Hồng',
    ),
    NotePaletteEntry(
      light: Color(0xFFE6C9A8),
      dark: Color(0xFF482C16),
      label: 'Cát',
    ),
    NotePaletteEntry(
      light: Color(0xFFE8EAED),
      dark: Color(0xFF3C3F43),
      label: 'Xám',
    ),
  ];

  static List<NotePaletteEntry> noteBackgroundPalette(BuildContext context) =>
      _notePalette;

  /// Màu hiển thị theo theme; [storedHex] luôn lưu bản **light** (canonical).
  static Color? resolveNoteBackground(BuildContext context, String? storedHex) {
    if (storedHex == null || storedHex.isEmpty) return null;
    final parsed = parseColor(storedHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    for (final entry in _notePalette) {
      if (entry.light.toARGB32() == parsed.toARGB32() ||
          entry.dark.toARGB32() == parsed.toARGB32()) {
        return isDark ? entry.dark : entry.light;
      }
    }
    return parsed;
  }

  static bool isNotePaletteColorSelected(String? storedHex, NotePaletteEntry entry) {
    if (storedHex == null || storedHex.isEmpty) return false;
    final parsed = parseColor(storedHex);
    return entry.light.toARGB32() == parsed.toARGB32() ||
        entry.dark.toARGB32() == parsed.toARGB32();
  }

  static Color parseColor(String hex) {
    try {
      var value = hex.replaceAll('#', '').trim();
      if (value.length == 6) value = 'FF$value';
      return Color(int.parse(value, radix: 16));
    } catch (e) {
      // Bắt lỗi nếu màu từ phiên bản cũ không phải là HEX (vd: "Red")
      return Colors.transparent;
    }
  }
}

/// Một ô màu trong bảng chọn nền ghi chú (light + dark).
class NotePaletteEntry {
  const NotePaletteEntry({
    required this.light,
    required this.dark,
    required this.label,
  });

  final Color light;
  final Color dark;
  final String label;

  Color displayColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Hex lưu DB — luôn dùng màu light để đồng bộ giữa theme.
  String get storageHex {
    final value = light.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${value.substring(2)}';
  }
}
