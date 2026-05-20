import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  bool _isUploadingAvatar = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;



  static const _primary = Color(0xFF2E75B6);

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.userData?['displayName'] ?? '';
    _bioController.text = auth.userData?['bio'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Tên không được để trống', isError: true);
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .update({'displayName': name});
      await auth.user!.updateDisplayName(name);
      await auth.reloadUserData();
      _showSnack('Đã cập nhật tên ✓');
    } catch (e) {
      _showSnack('Lỗi: $e', isError: true);
    }
  }

  Future<void> _saveBio() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .update({'bio': _bioController.text.trim()});
      await auth.reloadUserData();
      _showSnack('Đã cập nhật tiểu sử ✓');
    } catch (e) {
      _showSnack('Lỗi: $e', isError: true);
    }
  }

  Future<void> _changePassword() async {
    final oldPw = _oldPasswordController.text;
    final newPw = _newPasswordController.text;
    final confirmPw = _confirmPasswordController.text;
    if (oldPw.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
      _showSnack('Điền đầy đủ thông tin', isError: true);
      return;
    }
    if (newPw.length < 6) {
      _showSnack('Mật khẩu mới phải có ít nhất 6 ký tự', isError: true);
      return;
    }
    if (newPw != confirmPw) {
      _showSnack('Mật khẩu xác nhận không khớp', isError: true);
      return;
    }
    final user = FirebaseAuth.instance.currentUser!;
    try {
      final credential =
          EmailAuthProvider.credential(email: user.email!, password: oldPw);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPw);
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnack('Đổi mật khẩu thành công ✓');
    } on FirebaseAuthException catch (e) {
      _showSnack(
          e.code == 'wrong-password'
              ? 'Mật khẩu cũ không đúng'
              : 'Lỗi: ${e.message}',
          isError: true);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80);
    if (picked == null) return;
    setState(() => _isUploadingAvatar = true);
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars/${auth.user!.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .update({'photoUrl': url});
      await auth.user!.updatePhotoURL(url);
      await auth.reloadUserData();
      _showSnack('Đã cập nhật ảnh ✓');
    } catch (e) {
      _showSnack('Lỗi upload: $e', isError: true);
    } finally {
      setState(() => _isUploadingAvatar = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.roboto()),
      backgroundColor: isError ? Colors.red[700] : const Color(0xFF388E3C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── PERSONAL INFO BOTTOM SHEET ──
  void _showPersonalInfoBottomSheet(BuildContext context, AuthProvider auth) {
    _nameController.text = auth.userData?['displayName'] ?? '';
    _bioController.text = auth.userData?['bio'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Thông tin cá nhân',
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tên hiển thị',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildField(
                    controller: _nameController,
                    hint: 'Tên hiển thị',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tiểu sử',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildField(
                    controller: _bioController,
                    hint: 'Viết gì đó về bản thân...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Hủy',
                          style: GoogleFonts.roboto(color: const Color(0xFF6B7280)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSavingProfile
                            ? null
                            : () async {
                                final navigator = Navigator.of(context);
                                setModalState(() => _isSavingProfile = true);
                                await _saveName();
                                await _saveBio();
                                setModalState(() => _isSavingProfile = false);
                                navigator.pop();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E75B6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: _isSavingProfile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text('Lưu thay đổi',
                                style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── SECURITY BOTTOM SHEET ──
  void _showSecurityBottomSheet(BuildContext context) {
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Đổi mật khẩu',
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _oldPasswordController,
                    hint: 'Mật khẩu hiện tại',
                    isPassword: true,
                    obscure: _obscureOld,
                    onToggle: () => setModalState(() => _obscureOld = !_obscureOld),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _newPasswordController,
                    hint: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                    isPassword: true,
                    obscure: _obscureNew,
                    onToggle: () => setModalState(() => _obscureNew = !_obscureNew),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _confirmPasswordController,
                    hint: 'Xác nhận mật khẩu mới',
                    isPassword: true,
                    obscure: _obscureConfirm,
                    onToggle: () => setModalState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Hủy',
                          style: GoogleFonts.roboto(color: const Color(0xFF6B7280)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isChangingPassword
                            ? null
                            : () async {
                                final navigator = Navigator.of(context);
                                setModalState(() => _isChangingPassword = true);
                                await _changePassword();
                                setModalState(() => _isChangingPassword = false);
                                if (_oldPasswordController.text.isEmpty) {
                                  // Đổi mật khẩu thành công sẽ tự động xóa text field
                                  navigator.pop();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E75B6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: _isChangingPassword
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text('Cập nhật',
                                style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showComingSoonToast(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tính năng $feature đang được phát triển!',
          style: GoogleFonts.roboto(),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showAppInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Về ứng dụng',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Smart Note Pro',
                style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Phiên bản: 1.0.0', style: GoogleFonts.roboto()),
            const SizedBox(height: 12),
            Text(
                'Ứng dụng ghi chú thông minh cao cấp được phát triển bởi đội ngũ Smart Note. Toàn bộ dữ liệu được bảo mật và đồng bộ hóa đám mây an toàn.',
                style: GoogleFonts.roboto(color: const Color(0xFF4B5563), fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, AuthProvider auth) async {
    final navigator = Navigator.of(context);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final userId = auth.userId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Đăng xuất?',
            style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn đăng xuất không?',
            style: GoogleFonts.roboto()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Hủy', style: GoogleFonts.roboto())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Đăng xuất',
                style: GoogleFonts.roboto(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await auth.signOut();

    if (userId != null) {
      noteProvider.clearLocalData(userId);
      noteProvider.clearNotes();
    }

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final photoUrl = auth.userData?['photoUrl'] ?? '';
        final displayName = auth.userData?['displayName'] ?? 'Người dùng';
        final email = auth.email ?? '';
        final isEmailProvider =
            auth.user?.providerData.any((p) => p.providerId == 'password') ??
                false;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB), // bg-gray-50
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Cài đặt',
              style: GoogleFonts.roboto(
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: const Color(0xFFE5E7EB), height: 1),
            ),
          ),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // ── 1. USER PROFILE CARD (GRADIENT) ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  backgroundImage: photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: _isUploadingAvatar
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : (photoUrl.isEmpty
                                          ? Text(
                                              displayName.isNotEmpty
                                                  ? displayName[0].toUpperCase()
                                                  : 'U',
                                              style: GoogleFonts.roboto(
                                                fontSize: 24,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null),
                                ),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                      )
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 11, color: Color(0xFF374151)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email,
                                    style: GoogleFonts.roboto(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Smart Note Pro',
                                    style: GoogleFonts.roboto(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '✨ Premium Member',
                                      style: GoogleFonts.roboto(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── 2. SECTIONS ──
              _buildSectionTitle('TÀI KHOẢN'),
              _buildSectionCard([
                _buildSectionItem(
                  icon: Icons.person_outline_rounded,
                  iconColor: const Color(0xFF2563EB), // text-blue-600
                  iconBg: const Color(0xFFEFF6FF), // bg-blue-50
                  label: 'Thông tin cá nhân',
                  description: 'Quản lý thông tin tài khoản',
                  onTap: () => _showPersonalInfoBottomSheet(context, auth),
                ),
                if (isEmailProvider)
                  _buildSectionItem(
                    icon: Icons.lock_outline_rounded,
                    iconColor: const Color(0xFF16A34A), // text-green-600
                    iconBg: const Color(0xFFF0FDF4), // bg-green-50
                    label: 'Bảo mật',
                    description: 'Mật khẩu và xác thực',
                    onTap: () => _showSecurityBottomSheet(context),
                  ),
              ]),

              const SizedBox(height: 16),
              _buildSectionTitle('TÙY CHỈNH'),
              _buildSectionCard([
                _buildSectionItem(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF9333EA), // text-purple-600
                  iconBg: const Color(0xFFFAF5FF), // bg-purple-50
                  label: 'Giao diện',
                  description: 'Màu sắc và chủ đề',
                  onTap: () => _showComingSoonToast(context, 'Giao diện'),
                ),
                _buildSectionItem(
                  icon: Icons.notifications_none_rounded,
                  iconColor: const Color(0xFFEA580C), // text-orange-600
                  iconBg: const Color(0xFFFFF7ED), // bg-orange-50
                  label: 'Thông báo',
                  description: 'Quản lý nhắc nhở',
                  onTap: () => _showComingSoonToast(context, 'Thông báo'),
                ),
              ]),

              const SizedBox(height: 16),
              _buildSectionTitle('HỖ TRỢ'),
              _buildSectionCard([
                _buildSectionItem(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF0D9488), // text-teal-600
                  iconBg: const Color(0xFFF0FDFA), // bg-teal-50
                  label: 'Trợ giúp',
                  description: 'Hướng dẫn sử dụng',
                  onTap: () => _showComingSoonToast(context, 'Trợ giúp'),
                ),
                _buildSectionItem(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF4B5563), // text-gray-600
                  iconBg: const Color(0xFFF3F4F6), // bg-gray-50
                  label: 'Về ứng dụng',
                  description: 'Phiên bản 1.0.0',
                  onTap: () => _showAppInfoDialog(context),
                ),
              ]),

              const SizedBox(height: 32),

              // ── 3. LOGOUT BUTTON ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA), width: 2), // border-red-200
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _signOut(context, auth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Đăng xuất tài khoản',
                              style: GoogleFonts.roboto(
                                color: const Color(0xFFDC2626),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF6B7280), // text-gray-500
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    List<Widget> dividedChildren = [];
    for (int i = 0; i < children.length; i++) {
      dividedChildren.add(children[i]);
      if (i != children.length - 1) {
        dividedChildren.add(
          const Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            color: Color(0xFFF3F4F6),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: dividedChildren,
        ),
      ),
    );
  }

  Widget _buildSectionItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF9CA3AF),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: isPassword ? 1 : maxLines,
      style: GoogleFonts.roboto(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 18,
                    color: Colors.grey[400]),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primary, width: 1.5)),
      ),
    );
  }
}