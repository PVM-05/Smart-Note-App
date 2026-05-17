import 'package:flutter/material.dart';
import '../screens/main_shell.dart';

class MainDrawer extends StatelessWidget {
  final String currentRoute;

  const MainDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header của Drawer
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 60, 24, 20),
            child: Text(
              'Smart Note',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E75B6),
              ),
            ),
          ),

          // Mục Ghi chú
          _buildDrawerItem(
            context,
            icon: Icons.lightbulb_outline,
            label: 'Ghi chú',
            isSelected: currentRoute == '/home',
            onTap: () {
              Navigator.pop(context); // Đóng drawer trước
              if (currentRoute != '/home') {
                // Điều hướng về Home an toàn
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainShell(initialIndex: 0)),
                );
              }
            },
          ),

          // Mục Thùng rác
          _buildDrawerItem(
            context,
            icon: Icons.delete_outline,
            label: 'Thùng rác',
            isSelected: currentRoute == '/trash',
            onTap: () {
              Navigator.pop(context); // Đóng drawer trước
              if (currentRoute != '/trash') {
                // Điều hướng sang Thùng rác an toàn
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainShell(initialIndex: 1)),
                );
              }
            },
          ),
        ],
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
      padding: const EdgeInsets.only(right: 8),
      child: ListTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
        ),
        leading: Icon(icon, color: isSelected ? const Color(0xFF2E75B6) : Colors.black87),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF2E75B6) : Colors.black87,
          ),
        ),
        selected: isSelected,
        selectedTileColor: const Color(0xFF2E75B6).withValues(alpha: 0.1),
        onTap: onTap,
      ),
    );
  }
}