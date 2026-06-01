import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/design/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final photoUrl = auth.userData?['photoUrl'] ?? '';
    final displayName = auth.userData?['displayName'] ?? 'Người dùng';
    final email = auth.email ?? '';

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(0)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── CLOSE BUTTON ──
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: AppColors.textMetadata(context)),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            const SizedBox(height: 8),

            // ── AVATAR ──
            CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.primary,
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: GoogleFonts.roboto(
                    fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold),
              )
                  : null,
            ),

            const SizedBox(height: 12),

            // ── TÊN ──
            Text(
              displayName,
              style: GoogleFonts.roboto(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
            ),

            const SizedBox(height: 4),

            // ── EMAIL ──
            Text(
              email,
              style: GoogleFonts.roboto(fontSize: 13, color: AppColors.textMetadata(context)),
            ),

            const SizedBox(height: 20),

            // ── QUẢN LÝ TÀI KHOẢN ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary(context),
                  side: BorderSide(color: AppColors.divider(context)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.manage_accounts_outlined,
                      size: 18, color: AppColors.textMetadata(context)),
                    const SizedBox(width: 8),
                    Text('Quản lý tài khoản',
                        style: GoogleFonts.roboto(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),

            const Spacer(),

            Divider(height: 1, color: AppColors.divider(context)),

            // ── ĐĂNG XUẤT ──
            ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
              title: Text(
                'Đăng xuất',
                style: GoogleFonts.roboto(
                  color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              onTap: () => _signOut(context, auth),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, AuthProvider auth) async {
    // 1. Lưu lại NavigatorState và Provider TRƯỚC KHI đóng Drawer
    final navigator = Navigator.of(context);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final userId = auth.userId;

    // 2. Đóng Drawer
    navigator.pop();

    // 3. Hiển thị Dialog (dùng navigator.context để đảm bảo context còn sống)
    final confirm = await showDialog<bool>(
      context: navigator.context,
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
                    color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    // Nếu người dùng hủy thì dừng lại
    if (confirm != true) return;

    // 4. Thực hiện đăng xuất ở Firebase/Google
    await auth.signOut();

    // 5. Xóa dữ liệu local và điều hướng về LoginScreen
    if (userId != null) {
      noteProvider.clearLocalData(userId);
      noteProvider.clearNotes();
    }

    // pushAndRemoveUntil sẽ xóa toàn bộ lịch sử trang (kể cả HomeScreen)
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }
}