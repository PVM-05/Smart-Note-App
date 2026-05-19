// lib/widgets/main_drawer.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../screens/home_screen.dart';
import '../screens/trash_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';

class MainDrawer extends StatelessWidget {
  final String currentRoute;

  const MainDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final noteProvider = Provider.of<NoteProvider>(context);

    // Lấy thông tin user
    final email = auth.email ?? 'user@example.com';
    final photoUrl = auth.userData?['photoUrl'] ?? '';

    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. SIDEBAR USER HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: photoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  email.isNotEmpty
                                      ? email[0].toUpperCase()
                                      : 'U',
                                  style: GoogleFonts.roboto(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              email.isNotEmpty ? email[0].toUpperCase() : 'U',
                              style: GoogleFonts.roboto(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Smart Note Pro',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            // ── 2. NAVIGATION MENU ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 16),
                children: [
                  _buildDrawerItem(
                    context,
                    icon: Icons.home_outlined,
                    label: 'Tất cả ghi chú',
                    isSelected: currentRoute == '/home',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != '/home') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        );
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.archive_outlined,
                    label: 'Lưu trữ',
                    isSelected: currentRoute == '/archive',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tính năng Lưu trữ đang được phát triển!',
                            style: GoogleFonts.roboto(),
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.delete_outline,
                    label: 'Thùng rác',
                    isSelected: currentRoute == '/trash',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != '/trash') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TrashScreen()),
                        );
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.label_outline,
                    label: 'Nhãn',
                    isSelected: currentRoute == '/tags',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tính năng Gắn nhãn đang được phát triển!',
                            style: GoogleFonts.roboto(),
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  ),

                  // ── 3. STATS CARD ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEFF6FF), Color(0xFFFAF5FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng ghi chú',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: const Color(0xFF4B5563),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${noteProvider.notes.length}',
                            style: GoogleFonts.roboto(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 4. SETTINGS & LOGOUT FOOTER ──
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    hoverColor: const Color(0xFFF1F5F9),
                    leading: const Icon(Icons.settings_outlined,
                        color: Color(0xFF374151), size: 22),
                    title: Text(
                      'Cài đặt',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF374151),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen()),
                      );
                    },
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    hoverColor: const Color(0xFFFEF2F2),
                    leading: const Icon(Icons.logout_rounded,
                        color: Color(0xFFDC2626), size: 22),
                    title: Text(
                      'Đăng xuất',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    onTap: () => _signOut(context, auth),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        tileColor: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
        hoverColor: const Color(0xFFF1F5F9),
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF374151),
          size: 22,
        ),
        title: Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color:
                isSelected ? const Color(0xFF2563EB) : const Color(0xFF374151),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _signOut(BuildContext context, AuthProvider auth) async {
    final navigator = Navigator.of(context);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final userId = auth.userId;

    navigator.pop(); // Đóng Drawer

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
}
