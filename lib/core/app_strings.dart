// lib/core/app_strings.dart
// Kho chuỗi văn bản tập trung của toàn bộ ứng dụng Smart Note.
// Mục đích: tránh lặp lại chuỗi cứng (hardcode) rải rác trong code,
// dễ dàng bảo trì và hỗ trợ đa ngôn ngữ trong tương lai.

class AppStrings {
  // ── Tên ứng dụng ──
  static const String appName = 'Smart Note';

  // ── Sinh trắc học ──
  static const String biometricReason              = 'Xác thực để bảo vệ ghi chú của bạn';
  static const String biometricNotAvailable        = 'Thiết bị không hỗ trợ sinh trắc học';
  static const String biometricNotEnrolled         = 'Vui lòng đăng ký vân tay trong Cài đặt thiết bị';
  static const String biometricAuthFailed          = 'Xác thực thất bại. Thử lại?';
  static const String biometricAuthSuccess         = 'Xác thực thành công';
  static const String biometricPromptReason        = 'Xác thực để mở ghi chú';
  static const String biometricLockedOut           = 'Sinh trắc học bị tạm khóa do thử sai nhiều lần';
  static const String biometricPermanentlyLockedOut = 'Sinh trắc học bị khóa vĩnh viễn. Vui lòng mở khóa thiết bị bằng mã PIN';
  static const String biometricUnknownError        = 'Có lỗi xảy ra khi xác thực sinh trắc học';

  // ── Màn hình Cài đặt ──
  static const String settingsTitle        = 'Cài đặt';
  static const String darkModeTitle        = 'Giao diện tối';
  static const String darkModeSubtitle     = 'Thay đổi giao diện sáng hoặc tối cho ứng dụng';
  static const String languageTitle        = 'Ngôn ngữ';
  static const String languageSubtitle     = 'Lựa chọn ngôn ngữ hiển thị hệ thống';
  static const String biometricLockTitle   = 'Khóa ghi chú bằng vân tay';
  static const String biometricLockSubtitle = 'Sử dụng Vân tay hoặc Khuôn mặt để mở ghi chú';
  static const String featureInDevelopment = 'Tính năng đang phát triển';
  static const String alertOk             = 'Đồng ý';
  static const String alertCancel         = 'Hủy';

  // ── Thông báo Toast / SnackBar ──
  static const String themeDarkSnackbar  = 'Đã chuyển sang giao diện tối';
  static const String themeLightSnackbar = 'Đã chuyển sang giao diện sáng';

  // ── Trạng thái rỗng (Empty State) ──
  static const String emptyHomeTitle    = 'Chưa có ghi chú nào';
  static const String emptyHomeSubtitle = 'Nhấn + để tạo ghi chú đầu tiên';

  static const String emptyArchiveTitle    = 'Kho lưu trữ trống';
  static const String emptyArchiveSubtitle = 'Các ghi chú được lưu trữ sẽ hiển thị ở đây';

  static const String emptyTrashTitle    = 'Thùng rác trống';
  static const String emptyTrashSubtitle = 'Ghi chú trong thùng rác sẽ tự xóa sau 7 ngày';

  static const String emptySearchTitle    = 'Không tìm thấy kết quả';
  static const String emptySearchSubtitle = 'Thử từ khóa khác';
  static const String emptySearchAction   = 'Xóa bộ lọc';
}
