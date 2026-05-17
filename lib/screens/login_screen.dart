import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/connectivity_helper.dart';
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

  static const _primary = Color(0xFF2E75B6);
  static const _secondary = Color(0xFF1A237E);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // LOGIC: XỬ LÝ ĐĂNG NHẬP BẰNG EMAIL
  Future<void> _handleLogin(BuildContext context, AuthProvider auth) async {
    FocusScope.of(context).unfocus(); // Ẩn bàn phím

    final isOnline = await ConnectivityHelper().isOnline();
    if (!isOnline) {
      auth.setError('Không có kết nối mạng. Vui lòng kiểm tra lại.');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      auth.setError('Vui lòng nhập đầy đủ Email và Mật khẩu.');
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

  // LOGIC: XỬ LÝ ĐĂNG NHẬP BẰNG GOOGLE
  Future<void> _handleGoogleLogin(BuildContext context, AuthProvider auth) async {
    final isOnline = await ConnectivityHelper().isOnline();
    if (!isOnline) {
      auth.setError('Không có kết nối mạng. Vui lòng kiểm tra lại.');
      return;
    }

    final success = await auth.signInWithGoogle();
    if (success && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SyncingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            // Background với các hình khối mờ (Glassmorphism hiện đại)
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.5,
              colors: [
                _primary.withValues(alpha: 0.08),
                Colors.white,
                _secondary.withValues(alpha: 0.03),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Consumer<AuthProvider>(
                builder: (context, auth, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 50),

                      // ── LOGO APP ──
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _primary.withValues(alpha: 0.1),
                            border: Border.all(
                                color: _primary.withValues(alpha: 0.2), width: 2),
                          ),
                          child: const Icon(
                            Icons.note_alt_rounded,
                            size: 56,
                            color: _primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── TIÊU ĐỀ CÓ ANIMATION ──
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isLogin ? 'Chào mừng trở lại!' : 'Tạo tài khoản mới',
                          key: ValueKey<bool>(_isLogin), // Bắt buộc phải có key để chạy animation
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isLogin
                              ? 'Đăng nhập để tiếp tục đồng bộ ghi chú'
                              : 'Bắt đầu hành trình ghi chú thông minh của bạn',
                          key: ValueKey<bool>(_isLogin),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── FORM NHẬP LIỆU ──
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Mật khẩu',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onToggleVisibility: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                        ),
                      ),

                      // ── QUÊN MẬT KHẨU (Chỉ hiện khi ở tab Đăng nhập) ──
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _isLogin ? 40 : 16,
                        alignment: Alignment.centerRight,
                        child: _isLogin
                            ? TextButton(
                          onPressed: () {
                            // TODO: Làm màn hình Quên mật khẩu
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Quên mật khẩu?',
                            style: GoogleFonts.outfit(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),

                      // ── THÔNG BÁO LỖI ──
                      if (auth.error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  auth.error!,
                                  style: GoogleFonts.outfit(
                                    color: Colors.red.shade800,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── NÚT ACTION CHÍNH (ĐĂNG NHẬP / ĐĂNG KÝ) ──
                      FilledButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => _handleLogin(context, auth),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                            : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isLogin ? 'Đăng nhập' : 'Đăng ký',
                            key: ValueKey<bool>(_isLogin),
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── ĐƯỜNG KẺ "HOẶC TIẾP TỤC VỚI" ──
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[300])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Hoặc tiếp tục với',
                              style: GoogleFonts.outfit(
                                  color: Colors.grey[500], fontSize: 13),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── NÚT ĐĂNG NHẬP GOOGLE ──
                      OutlinedButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => _handleGoogleLogin(context, auth),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google_logo.png', // Sử dụng ảnh có sẵn trong project của bạn
                              height: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Đăng nhập bằng Google',
                              style: GoogleFonts.outfit(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── CHUYỂN ĐỔI TAB ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLogin
                                ? 'Chưa có tài khoản? '
                                : 'Đã có tài khoản? ',
                            style: GoogleFonts.outfit(
                              color: Colors.grey[600],
                              fontSize: 15,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              _isLogin = !_isLogin;
                              auth.setError(null); // Xóa lỗi khi chuyển tab
                            }),
                            child: Text(
                              _isLogin ? 'Đăng ký ngay' : 'Đăng nhập',
                              style: GoogleFonts.outfit(
                                color: _primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // UI: CẤU TRÚC Ô NHẬP LIỆU (Cải tiến sang giao diện phẳng)
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 15),
        floatingLabelStyle: GoogleFonts.outfit(color: _primary, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 22),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey[400],
            size: 22,
          ),
          onPressed: onToggleVisibility,
          splashRadius: 24,
        )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FA), // Màu xám siêu nhạt cho nền
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),

        // Viền khi bình thường
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        // Viền khi bấm vào (Focus)
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
      ),
    );
  }
}