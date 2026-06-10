import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/design/app_colors.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'syncing_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  int _countdownSeconds = 60;
  Timer? _timer;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    // Tự động kiểm tra trạng thái xác thực mỗi 5 giây
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkEmailVerifiedSilently());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _isResending = true;
      _countdownSeconds = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds == 0) {
        setState(() {
          _isResending = false;
          _timer?.cancel();
        });
      } else {
        setState(() {
          _countdownSeconds--;
        });
      }
    });
  }

  Future<void> _checkEmailVerifiedSilently() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified && mounted) {
        _autoCheckTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SyncingScreen()),
        );
      }
    }
  }

  Future<void> _checkEmailVerifiedManually() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified && mounted) {
        _autoCheckTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác thực email thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SyncingScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tài khoản của bạn chưa được xác thực. Vui lòng kiểm tra lại email!'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã gửi lại email xác thực. Vui lòng kiểm tra hộp thư!'),
              backgroundColor: AppColors.success,
            ),
          );
          _startCountdown();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể gửi lại email: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelAndLogout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Icon phong thư
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                'Xác thực email của bạn',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Chúng tôi đã gửi một liên kết xác thực đến địa chỉ email:',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                email,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Vui lòng mở hộp thư của bạn (kiểm tra cả hộp thư rác/Spam nếu cần) và bấm vào liên kết xác thực để kích hoạt tài khoản.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: AppColors.textMetadata(context),
                  height: 1.4,
                ),
              ),
              const Spacer(),

              // Nút bấm "Tôi đã xác thực"
              FilledButton.icon(
                onPressed: _checkEmailVerifiedManually,
                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                label: Text(
                  'Tôi đã xác thực',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Nút bấm "Gửi lại email xác thực"
              OutlinedButton.icon(
                onPressed: _isResending ? null : _resendVerificationEmail,
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  _isResending ? 'Gửi lại sau ($_countdownSeconds s)' : 'Gửi lại email xác thực',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 2),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Nút bấm "Hủy & Quay lại đăng nhập"
              TextButton(
                onPressed: _cancelAndLogout,
                child: Text(
                  'Quay lại đăng nhập',
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
