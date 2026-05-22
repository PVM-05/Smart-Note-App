// lib/widgets/main_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart'; // Đảm bảo import đầy đủ nếu có
import '../providers/note_provider.dart';
import '../screens/home_screen.dart';
import '../screens/manage_labels_screen.dart';
import '../screens/setting_screen.dart';
import '../screens/trash_screen.dart';
import '../screens/archive_screen.dart';

class MainDrawer extends StatelessWidget {
  final String currentRoute;
  final VoidCallback? onLabelSelected; // <── THÊM DÒNG NÀY: Callback báo hiệu reset cuộn cho HomeScreen

  const MainDrawer({
    super.key,
    required this.currentRoute,
    this.onLabelSelected, // <── THÊM DÒNG NÀY
  });

  static const Color primaryColor = Color(0xFF2E75B6);

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final systemLabels = noteProvider.allLabels;
    final activeLabel = noteProvider.selectedLabel;

    return SizedBox(
      width: 320,
      child: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ================= HEADER =================
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      SizedBox(width: 12),
                      Text(
                        'Smart Note',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ================= NOTES (TẤT CẢ GHI CHÚ) =================
            _buildKeepDrawerItem(
              context,
              icon: Icons.lightbulb_outline,
              label: 'Ghi chú',
              isSelected: currentRoute == '/home' && activeLabel == null,
              onTap: () async {
                noteProvider.selectLabel(null);
                Navigator.pop(context);

                if (currentRoute != '/home') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                } else {
                  // Nếu đang ở sẵn HomeScreen -> kích hoạt callback làm mới và reset cuộn về đầu
                  onLabelSelected?.call();
                }
              },
            ),

            const SizedBox(height: 16),

            _sectionDivider(context),

            // ================= LABEL SECTION =================
            if (systemLabels.isEmpty) ...[
              _buildKeepDrawerItem(
                context,
                icon: Icons.add,
                label: 'Tạo nhãn mới',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageLabelsScreen()),
                  );
                },
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nhãn',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        letterSpacing: 1,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ManageLabelsScreen()),
                        );
                      },
                      child: const Text(
                        'Chỉnh sửa',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Dynamic labels
              ...systemLabels.map((label) {
                final isLabelSelected = currentRoute == '/home' && activeLabel == label;

                return _buildKeepDrawerItem(
                  context,
                  icon: Icons.label_outline,
                  label: label,
                  isSelected: isLabelSelected,
                  onTap: () async {
                    noteProvider.selectLabel(label);
                    Navigator.pop(context);

                    if (currentRoute != '/home') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    } else {
                      // Nếu đang ở sẵn HomeScreen -> kích hoạt callback làm mới dữ liệu nhãn dán
                      onLabelSelected?.call();
                    }
                  },
                );
              }),

              // Create label button
              _buildKeepDrawerItem(
                context,
                icon: Icons.add,
                label: 'Tạo nhãn mới',
                isSelected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageLabelsScreen()),
                  );
                },
              ),
            ],

            // ================= TRASH & ARCHIVE =================
            _sectionDivider(context),

            _buildKeepDrawerItem(
              context,
              icon: Icons.archive_outlined,
              label: 'Lưu trữ',
              isSelected: currentRoute == '/archive',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != '/archive') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ArchiveScreen()),
                  );
                }
              },
            ),

            _buildKeepDrawerItem(
              context,
              icon: Icons.delete_outline,
              label: 'Thùng rác',
              isSelected: currentRoute == '/trash',
              onTap: () {
                Navigator.pop(context);
                if (currentRoute != '/trash') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const TrashScreen()),
                  );
                }
              },
            ),

            _buildKeepDrawerItem(
              context,
              icon: Icons.settings_outlined,
              label: 'Cài đặt',
              isSelected: currentRoute == '/settings',
              onTap: () {
                Navigator.pop(context); // Đóng drawer
                // Điều hướng sang trang SettingScreen độc lập
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: Colors.grey.shade300,
      ),
    );
  }

  Widget _buildKeepDrawerItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required bool isSelected,
        required VoidCallback onTap,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          selected: isSelected,
          selectedTileColor: primaryColor.withValues(alpha: 0.12),
          leading: Icon(
            icon,
            size: 22,
            color: isSelected ? primaryColor : Colors.black87,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? primaryColor : Colors.black87,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}