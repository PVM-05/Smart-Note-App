// lib/widgets/main_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/home_screen.dart';
import '../screens/trash_screen.dart';
import '../screens/manage_labels_screen.dart';
import '../providers/note_provider.dart';

class MainDrawer extends StatelessWidget {
  final String currentRoute;

  const MainDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);
    final systemLabels = noteProvider.allLabels;
    final activeLabel = noteProvider.selectedLabel;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── HEADER MINIMALIST ──
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 56, 24, 20),
            child: Row(
              children: [
                Text(
                  'Smart Note',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E75B6),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          // ── MỤC GHI CHÚ ──
          _buildKeepDrawerItem(
            context,
            icon: Icons.lightbulb_outline,
            label: 'Ghi chú',
            isSelected: currentRoute == '/home' && activeLabel == null,
            onTap: () {
              noteProvider.selectLabel(null); // Reset bộ lọc nhãn dán
              Navigator.pop(context);
              if (currentRoute != '/home') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
            },
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: Divider(height: 1, thickness: 1, indent: 12, endIndent: 12, color: Color(0xFFE2E8F0)),
          ),


          // ── XỬ LÝ LOGIC HIỂN THỊ THEO YÊU CẦU ĐỐI VỚI KHU VỰC NHÃN DÁN ──
          if (systemLabels.isEmpty) ...[
            // TRƯỜNG HỢP 1: Chưa có nhãn -> Chỉ hiển thị mục Tạo nhãn mới duy nhất
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
            // TRƯỜNG HỢP 2: Đã có nhãn -> Tiêu đề NHÃN & CHỈNH SỬA nằm ngang hàng nhau
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 2, 16, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Đẩy chữ về 2 phía đầu dòng
                children: [
                  Text(
                    'NHÃN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  // Nút Chỉnh sửa chữ gọn thanh mảnh, thẳng hàng
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                        color: Color(0xFF2E75B6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Liệt kê danh sách nhãn dán động hiện tại
            ...systemLabels.map((label) {
              final isLabelSelected = currentRoute == '/home' && activeLabel == label;
              return _buildKeepDrawerItem(
                context,
                icon: Icons.label_outline,
                label: label,
                isSelected: isLabelSelected,
                onTap: () {
                  noteProvider.selectLabel(label); // Kích hoạt lọc ghi chú
                  Navigator.pop(context);
                  if (currentRoute != '/home') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  }
                },
              );
            }),

            // Nút Tạo nhãn mới phụ đặt ở cuối danh sách nhãn để tiện thêm tiếp nhãn dán
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

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6.0),
            child: Divider(height: 1, thickness: 1, indent: 12, endIndent: 12, color: Color(0xFFE2E8F0)),
          ),

          // ── MỤC THÙNG RÁC ──
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

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Hàm thiết lập giao diện chung dạng viên thuốc (Stadium / Pill Shape) chuẩn Google Keep
  Widget _buildKeepDrawerItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required bool isSelected,
        required VoidCallback onTap,
      }) {
    const primaryColor = Color(0xFF2E75B6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        leading: Icon(
          icon,
          size: 22,
          color: isSelected ? primaryColor : Colors.black87,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? primaryColor : Colors.black87,
          ),
        ),
        selected: isSelected,
        selectedTileColor: primaryColor.withOpacity(0.12),
        onTap: onTap,
      ),
    );
  }
}