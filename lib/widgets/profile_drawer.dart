import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/note_provider.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Drawer(
      // Độ rộng chiếm 85% màn hình tạo cảm giác như một trang riêng trượt ra
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // ── KHU VỰC HEADER CUSTOM THEO YÊU CẦU ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // 1. Dấu X ở góc phải để thoát
                  Positioned(
                    top: 0,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Khối thông tin xếp dọc chính giữa
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12), // Tạo khoảng cách với lề trên

                      // 2. Trên cùng là tên email
                      Text(
                        auth.email ?? 'example@gmail.com',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Dưới email là avatar
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: const Color(0xFF2E75B6),
                        child: Text(
                          auth.email?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. Dưới cùng là tên tài khoản
                      Text(
                        auth.userData?['displayName'] ?? 'Người dùng',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // ── DANH SÁCH MENU CHỨC NĂNG BÊN DƯỚI ──
            _buildMenuItem(
              icon: Icons.account_circle_outlined,
              label: 'Quản lý tài khoản của bạn',
              onTap: () {
                Navigator.pop(context); // Đóng drawer trước khi chuyển trang
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.logout,
              label: 'Đăng xuất',
              textColor: Colors.redAccent,
              iconColor: Colors.redAccent,
              onTap: () async {
                Navigator.pop(context);
                final userId = auth.userId;
                await auth.signOut();
                if (context.mounted && userId != null) {
                  final noteProvider = Provider.of<NoteProvider>(context, listen: false);
                  await noteProvider.clearLocalData(userId);
                  noteProvider.clearNotes();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (Route<dynamic> route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Khối hỗ trợ vẽ thẻ vuốt ngang tinh gọn
  Widget _buildSwipeableCard({
    required String title,
    required String desc,
    required Color cardColor,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF2E75B6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // Khối hỗ trợ tạo danh sách nút bấm đồng bộ thiết kế
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
    Color iconColor = Colors.black54,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        leading: Icon(icon, color: iconColor),
        title: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 15),
        ),
        onTap: onTap,
      ),
    );
  }
}