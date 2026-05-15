import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'syncing_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;
  final LocalAuthentication authLocal = LocalAuthentication();

  static const _primary = Color(0xFF2E75B6);
  static const _secondary = Color(0xFF1A237E);

  // AUTH: XỬ LÝ SINH TRẮC HỌC (BIOMETRIC)
  // Data Flow: Người dùng -> Hệ điều hành -> Local Auth -> Chuyển sang SyncingScreen
  Future<void> _authenticateBiometric() async {
    try {
      final bool canAuthenticateWithBiometrics =
          await authLocal.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await authLocal.isDeviceSupported();

      if (!canAuthenticate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thiết bị không hỗ trợ sinh trắc học'),
            ),
          );
        }
        return;
      }

      final bool didAuthenticate = await authLocal.authenticate(
        localizedReason: 'Vui lòng xác thực để đăng nhập vào Smart Note',
      );

      if (didAuthenticate && mounted) {
        /* 
          🎯 LƯU Ý CHO TƯƠNG LAI:
          - Hiện tại logic này chỉ "mở khóa" giao diện.
          - Để hoàn thiện: Bạn cần kiểm tra xem có User Session (FirebaseAuth.instance.currentUser) không.
          - Nếu chưa có: Phải yêu cầu user đăng nhập bằng Password ít nhất một lần trước, 
            sau đó mới cho phép dùng Vân tay để "vào nhanh" ở những lần sau.
        */

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SyncingScreen()),
        );
      }
    } catch (e) {
      debugPrint('Biometric Error: $e');
    }
  }

  // UI: GIAO DIỆN CHÍNH (PHONG CÁCH GLASSMORPHISM)
  // Data Flow: Gradient Background -> SafeArea -> SingleChildScrollView -> Column UI
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                _primary.withValues(alpha: 0.1),
                Colors.white,
                Colors.white,
                _secondary.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 60),
                        Hero(
                          tag: 'app_logo',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primary.withValues(alpha: 0.1),
                            ),
                            child: const Icon(
                              Icons.note_alt_rounded,
                              size: 64,
                              color: _primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _isLogin ? 'Chào mừng trở lại' : 'Tạo tài khoản mới',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _secondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'Đăng nhập để tiếp tục đồng bộ ghi chú'
                              : 'Bắt đầu hành trình ghi chú thông minh của bạn',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 48),

                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outlined,
                          isPassword: true,
                          obscureText: _obscurePassword,
                          onToggleVisibility: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),

                        if (auth.error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            auth.error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        const SizedBox(height: 32),

                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: auth.isLoading
                                ? null
                                : () => _handleLogin(context, auth),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: auth.isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    _isLogin ? 'Đăng nhập' : 'Đăng ký',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        if (_isLogin)
                          Center(
                            child: InkWell(
                              onTap: _authenticateBiometric,
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 40,
                                  color: _primary,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin
                                  ? 'Chưa có tài khoản? '
                                  : 'Đã có tài khoản? ',
                              style: GoogleFonts.outfit(
                                color: Colors.grey[600],
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin ? 'Đăng ký ngay' : 'Đăng nhập',
                                style: GoogleFonts.outfit(
                                  color: _primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // UI: CẤU TRÚC Ô NHẬP LIỆU (CUSTOM TEXTFIELD)
  // Data Flow: Controller -> Input Decoration -> BoxShadow Container
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: _primary.withValues(alpha: 0.7)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey[400],
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // AUTH: LOGIC ĐĂNG NHẬP VÀ ĐĂNG KÝ
  // Data Flow: Email/Pass -> AuthProvider -> Firebase Auth -> Firestore Profile -> SyncingScreen
  Future<void> _handleLogin(BuildContext context, AuthProvider auth) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      auth.setError('Vui lòng nhập đầy đủ thông tin');
      return;
    }

    final success = _isLogin
        ? await auth.signInWithEmail(email, password)
        : await auth.registerWithEmail(email, password);

    if (success && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SyncingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
