// lib/services/biometric_service.dart
// Dịch vụ xác thực sinh trắc học (vân tay / khuôn mặt) dùng package local_auth.
// Cung cấp 3 chức năng chính:
//   1. isAvailable()   — Kiểm tra thiết bị có phần cứng sinh trắc học không
//   2. isEnrolled()    — Kiểm tra người dùng đã đăng ký vân tay/khuôn mặt chưa
//   3. authenticate()  — Hiện hộp thoại xác thực và trả về kết quả true/false
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../core/app_strings.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Kiểm tra thiết bị có hỗ trợ sinh trắc học không.
  /// Trả về true nếu phần cứng vân tay hoặc khuôn mặt tồn tại.
  Future<bool> isAvailable() async {
    try {
      final bool canCheck    = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('❌ Lỗi khi kiểm tra khả năng sinh trắc học: $e');
      return false;
    }
  }

  /// Kiểm tra người dùng đã đăng ký ít nhất một vân tay hoặc khuôn mặt chưa.
  /// Trả về true nếu có ít nhất một phương thức sinh trắc học đã được cài đặt.
  Future<bool> isEnrolled() async {
    try {
      final List<BiometricType> danhSachSinhTracHoc =
          await _auth.getAvailableBiometrics();
      return danhSachSinhTracHoc.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Lỗi khi kiểm tra đăng ký sinh trắc học: $e');
      return false;
    }
  }

  /// Hiện hộp thoại xác thực sinh trắc học của hệ thống, trả về true nếu thành công.
  /// Xử lý các lỗi có cấu trúc theo LocalAuthExceptionCode và ném Exception
  /// với thông báo tiếng Việt để tầng UI hiển thị cho người dùng.
  Future<bool> authenticate(
      {String reason = AppStrings.biometricPromptReason}) async {
    try {
      final bool daXacThuc = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
      return daXacThuc;
    } on LocalAuthException catch (e) {
      debugPrint('❌ Ngoại lệ LocalAuth: ${e.code}');
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
          // Thiết bị không có phần cứng sinh trắc học
          throw Exception(AppStrings.biometricNotAvailable);
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          // Thiết bị hỗ trợ nhưng chưa đăng ký vân tay/khuôn mặt
          throw Exception(AppStrings.biometricNotEnrolled);
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          // Bị tạm khóa do nhập sai quá nhiều lần
          throw Exception(AppStrings.biometricLockedOut);
        default:
          // Lỗi không xác định
          throw Exception(AppStrings.biometricUnknownError);
      }
    } catch (e) {
      debugPrint('❌ Lỗi không xác định khi xác thực sinh trắc học: $e');
      throw Exception(AppStrings.biometricUnknownError);
    }
  }
}
