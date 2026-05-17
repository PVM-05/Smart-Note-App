import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import '../providers/auth_provider.dart';

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

  bool _expandName = false;
  bool _expandBio = false;
  bool _expandPassword = false;

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
    setState(() => _isSavingProfile = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .update({'displayName': name});
      await auth.user!.updateDisplayName(name);
      await auth.reloadUserData();
      setState(() => _expandName = false);
      _showSnack('Đã cập nhật tên ✓');
    } catch (e) {
      _showSnack('Lỗi: $e', isError: true);
    } finally {
      setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _saveBio() async {
    setState(() => _isSavingProfile = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.user!.uid)
          .update({'bio': _bioController.text.trim()});
      await auth.reloadUserData();
      setState(() => _expandBio = false);
      _showSnack('Đã cập nhật tiểu sử ✓');
    } catch (e) {
      _showSnack('Lỗi: $e', isError: true);
    } finally {
      setState(() => _isSavingProfile = false);
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
    setState(() => _isChangingPassword = true);
    final user = FirebaseAuth.instance.currentUser!;
    try {
      final credential =
      EmailAuthProvider.credential(email: user.email!, password: oldPw);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPw);
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _expandPassword = false);
      _showSnack('Đổi mật khẩu thành công ✓');
    } on FirebaseAuthException catch (e) {
      _showSnack(
          e.code == 'wrong-password'
              ? 'Mật khẩu cũ không đúng'
              : 'Lỗi: ${e.message}',
          isError: true);
    } finally {
      setState(() => _isChangingPassword = false);
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit()),
      backgroundColor: isError ? Colors.red[700] : const Color(0xFF388E3C),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final photoUrl = auth.userData?['photoUrl'] ?? '';
        final displayName = auth.userData?['displayName'] ?? 'Người dùng';
        final bio = auth.userData?['bio'] ?? '';
        final email = auth.email ?? '';
        final isEmailProvider =
            auth.user?.providerData.any((p) => p.providerId == 'password') ??
                false;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Quản lý tài khoản',
                style: GoogleFonts.outfit(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 18)),
          ),
          body: ListView(
            children: [
              // ── AVATAR HEADER ──
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 24, 0, 20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: _primary,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: _isUploadingAvatar
                                ? const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)
                                : (photoUrl.isEmpty
                                ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'U',
                              style: GoogleFonts.outfit(
                                  fontSize: 34,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            )
                                : null),
                          ),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                              border:
                              Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color:
                                    Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4)
                              ],
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(displayName,
                        style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(email,
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: Colors.grey[500])),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(bio,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 13, color: Colors.grey[600])),
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 8, color: Color(0xFFF5F5F5)),

              // ── TÊN HIỂN THỊ ──
              _ExpandTile(
                icon: Icons.person_outline,
                title: 'Tên hiển thị',
                value: displayName,
                isExpanded: _expandName,
                onTap: () => setState(() {
                  _expandName = !_expandName;
                  _expandBio = false;
                  _expandPassword = false;
                }),
                expandedChild: _EditPanel(
                  child: Column(
                    children: [
                      _buildField(
                          controller: _nameController,
                          hint: 'Tên hiển thị'),
                      const SizedBox(height: 12),
                      _buildActions(
                        onCancel: () =>
                            setState(() => _expandName = false),
                        onSave: _saveName,
                        isLoading: _isSavingProfile,
                      ),
                    ],
                  ),
                ),
              ),

              _thinDivider(),

              // ── TIỂU SỬ ──
              _ExpandTile(
                icon: Icons.notes_outlined,
                title: 'Tiểu sử',
                value: bio.isNotEmpty ? bio : 'Chưa có tiểu sử',
                valueColor: bio.isEmpty ? Colors.grey[400] : null,
                isExpanded: _expandBio,
                onTap: () => setState(() {
                  _expandBio = !_expandBio;
                  _expandName = false;
                  _expandPassword = false;
                }),
                expandedChild: _EditPanel(
                  child: Column(
                    children: [
                      _buildField(
                          controller: _bioController,
                          hint: 'Viết gì đó về bản thân...',
                          maxLines: 3),
                      const SizedBox(height: 12),
                      _buildActions(
                        onCancel: () =>
                            setState(() => _expandBio = false),
                        onSave: _saveBio,
                        isLoading: _isSavingProfile,
                      ),
                    ],
                  ),
                ),
              ),

              _thinDivider(),

              // ── EMAIL (chỉ đọc) ──
              ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: const Icon(Icons.email_outlined,
                    color: Colors.black45, size: 22),
                title: Text('Email',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Colors.grey[500])),
                subtitle: Text(email,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500)),
              ),

              // ── ĐỔI MẬT KHẨU ──
              if (isEmailProvider) ...[
                _thinDivider(),
                _ExpandTile(
                  icon: Icons.lock_outline,
                  title: 'Đổi mật khẩu',
                  value: '••••••••',
                  isExpanded: _expandPassword,
                  onTap: () => setState(() {
                    _expandPassword = !_expandPassword;
                    _expandName = false;
                    _expandBio = false;
                  }),
                  expandedChild: _EditPanel(
                    child: Column(
                      children: [
                        _buildField(
                          controller: _oldPasswordController,
                          hint: 'Mật khẩu hiện tại',
                          isPassword: true,
                          obscure: _obscureOld,
                          onToggle: () =>
                              setState(() => _obscureOld = !_obscureOld),
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          controller: _newPasswordController,
                          hint: 'Mật khẩu mới',
                          isPassword: true,
                          obscure: _obscureNew,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                        const SizedBox(height: 10),
                        _buildField(
                          controller: _confirmPasswordController,
                          hint: 'Xác nhận mật khẩu mới',
                          isPassword: true,
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                        ),
                        const SizedBox(height: 12),
                        _buildActions(
                          onCancel: () =>
                              setState(() => _expandPassword = false),
                          onSave: _changePassword,
                          isLoading: _isChangingPassword,
                          saveLabel: 'Đổi mật khẩu',
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _thinDivider() => const Divider(
      height: 1, thickness: 1, indent: 56, color: Color(0xFFF0F0F0));

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
      style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        GoogleFonts.outfit(color: Colors.grey[400], fontSize: 14),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: Colors.grey[400]),
          onPressed: onToggle,
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primary, width: 1.5)),
      ),
    );
  }

  Widget _buildActions({
    required VoidCallback onCancel,
    required VoidCallback onSave,
    required bool isLoading,
    String saveLabel = 'Lưu',
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel,
          child: Text('Hủy',
              style:
              GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14)),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: isLoading ? null : onSave,
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: isLoading
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Text(saveLabel,
              style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── EXPANDABLE TILE ──
class _ExpandTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget expandedChild;

  const _ExpandTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.isExpanded,
    required this.onTap,
    required this.expandedChild,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: Icon(icon, color: Colors.black45, size: 22),
          title: Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 12, color: Colors.grey[500])),
          subtitle: Text(value,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          trailing: Icon(
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: Colors.grey[400],
            size: 20,
          ),
          onTap: onTap,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: expandedChild,
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// ── EDIT PANEL WRAPPER ──
class _EditPanel extends StatelessWidget {
  final Widget child;
  const _EditPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: child,
    );
  }
}