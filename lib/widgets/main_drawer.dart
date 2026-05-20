import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../screens/home_screen.dart';
import '../screens/manage_labels_screen.dart';
import '../screens/trash_screen.dart';
import '../screens/archive_screen.dart';

class MainDrawer extends StatelessWidget {
  final String currentRoute;

  const MainDrawer({
    super.key,
    required this.currentRoute,
  });

  static const Color primaryColor = Color(0xFF2E75B6);

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context);

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

            // ================= NOTES =================

            _buildKeepDrawerItem(
              context,
              icon: Icons.lightbulb_outline,
              label: 'Ghi chú',
              isSelected:
              currentRoute == '/home' && activeLabel == null,
              onTap: () {
                noteProvider.selectLabel(null);

                Navigator.pop(context);

                if (currentRoute != '/home') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeScreen(),
                    ),
                  );
                }
              },
            ),

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
                    MaterialPageRoute(
                      builder: (_) =>
                      const ManageLabelsScreen(),
                    ),
                  );
                },
              ),
            ] else ...[
              Padding(
                padding:
                const EdgeInsets.fromLTRB(24, 8, 16, 8),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'NHÃN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        letterSpacing: 1,
                      ),
                    ),

                    TextButton(
                      style: TextButton.styleFrom(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize:
                        MaterialTapTargetSize
                            .shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.pop(context);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const ManageLabelsScreen(),
                          ),
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
                final isLabelSelected =
                    currentRoute == '/home' &&
                        activeLabel == label;

                return _buildKeepDrawerItem(
                  context,
                  icon: Icons.label_outline,
                  label: label,
                  isSelected: isLabelSelected,
                  onTap: () {
                    noteProvider.selectLabel(label);

                    Navigator.pop(context);

                    if (currentRoute != '/home') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const HomeScreen(),
                        ),
                      );
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
                    MaterialPageRoute(
                      builder: (_) =>
                      const ManageLabelsScreen(),
                    ),
                  );
                },
              ),
            ],

            // ================= TRASH =================



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
                    MaterialPageRoute(
                      builder: (_) => const ArchiveScreen(),
                    ),
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
                    MaterialPageRoute(
                      builder: (_) =>
                      const TrashScreen(),
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ================= DIVIDER =================

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

  // ================= DRAWER ITEM =================

  Widget _buildKeepDrawerItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required bool isSelected,
        required VoidCallback onTap,
      }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        child: ListTile(
          dense: true,
          visualDensity:
          const VisualDensity(vertical: -1),

          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),

          selected: isSelected,

          selectedTileColor:
          primaryColor.withValues(alpha: 0.12),

          leading: Icon(
            icon,
            size: 22,
            color: isSelected
                ? primaryColor
                : Colors.black87,
          ),

          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: isSelected
                  ? primaryColor
                  : Colors.black87,
            ),
          ),

          onTap: onTap,
        ),
      ),
    );
  }
}