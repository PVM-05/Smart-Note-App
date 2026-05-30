// lib/core/app_colors.dart
// Bảng màu trung tâm của toàn bộ ứng dụng Smart Note.
// Định nghĩa tất cả màu sắc dùng chung, phân chia theo:
//   - Màu thương hiệu (Brand)
//   - Bảng màu Sáng (Light Mode)
//   - Bảng màu Tối (Dark Mode)
//   - Màu trạng thái (Success / Error / Warning)
//   - Hàm trợ giúp tự động chọn màu theo giao diện hiện tại
import 'package:flutter/material.dart';

class AppColors {
  // ── Màu thương hiệu ──
  static const Color primary = Color(0xFF2E75B6); // Xanh dương chủ đạo
  static const Color accent  = Color(0xFF1E88E5); // Xanh dương nhấn

  // ── Bảng màu Giao diện Sáng ──
  static const Color lightBackground    = Color(0xFFF8F9FA); // Nền trang sáng
  static const Color lightSurface       = Colors.white;      // Nền card/surface sáng
  static const Color lightTextPrimary   = Color(0xFF1C1C1E); // Chữ chính sáng
  static const Color lightTextSecondary = Color(0xFF6C757D); // Chữ phụ sáng (ghi chú, mô tả)
  static const Color lightDivider       = Color(0xFFE5E5EA); // Đường kẻ chia sáng

  // ── Bảng màu Giao diện Tối (tông màu tối cao cấp, tránh đen tuyền #000) ──
  static const Color darkBackground    = Color(0xFF0F0F0F); // Nền trang tối — không dùng #000 thuần
  static const Color darkSurface       = Color(0xFF1A1A1A); // Nền card tối — trông sang trọng hơn
  static const Color darkTextPrimary   = Color(0xFFF5F5F5); // Chữ chính tối
  static const Color darkTextSecondary = Color(0xFF9E9E9E); // Chữ phụ tối
  static const Color darkDivider       = Color(0xFF2A2A2A); // Đường kẻ chia tối

  // ── Màu hiển thị trên nền chính ──
  static const Color onPrimary = Colors.white;       // Chữ/icon trên nền primary
  static const Color onSurface = Color(0xFF1C1C1E); // Chữ/icon trên nền surface

  // ── Màu trạng thái / ngữ nghĩa ──
  static const Color success = Color(0xFF34C759); // Thành công — xanh lá
  static const Color error   = Color(0xFFFF3B30); // Lỗi — đỏ
  static const Color warning = Color(0xFFFFCC00); // Cảnh báo — vàng

  // ── Hàm trợ giúp: tự động trả về màu phù hợp theo giao diện Sáng/Tối ──

  /// Màu nền trang chính
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBackground : lightBackground;

  /// Màu nền card / surface
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : lightSurface;

  /// Màu chữ chính (tiêu đề, nội dung quan trọng)
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  /// Màu chữ phụ (mô tả, ghi chú, placeholder)
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  /// Màu đường kẻ chia
  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkDivider : lightDivider;
}
