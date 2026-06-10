// lib/widgets/main_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/design/app_colors.dart';
import '../core/app_localizations.dart';
import '../providers/note_provider.dart';
import '../providers/language_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    Provider.of<LanguageProvider>(context); // Listen to LanguageProvider for real-time rebuilds
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
                    children: [
                      const SizedBox(width: 12),
                      Text(
                        'Smart Note',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
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
              label: AppLocalizations.translate(context, 'drawerNotes'),
              isSelected: currentRoute == '/home' && activeLabel == null && !noteProvider.showOnlyReminders,
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

            _buildKeepDrawerItem(
              context,
              icon: Icons.notifications_none_outlined,
              label: AppLocalizations.translate(context, 'drawerReminders'),
              isSelected: currentRoute == '/home' && noteProvider.showOnlyReminders,
              onTap: () async {
                noteProvider.setShowOnlyReminders(true);
                Navigator.pop(context);

                if (currentRoute != '/home') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                } else {
                  onLabelSelected?.call();
                }
              },
            ),

            const SizedBox(height: 8),

            _sectionDivider(context),

            // ================= LABEL SECTION =================
            if (systemLabels.isEmpty) ...[
              _buildKeepDrawerItem(
                context,
                icon: Icons.add,
                label: AppLocalizations.translate(context, 'drawerCreateNewLabel'),
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
                    Text(
                      AppLocalizations.translate(context, 'drawerLabels'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMetadata(context),
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
                      child: Text(
                        AppLocalizations.translate(context, 'drawerEditLabels'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMetadata(context),
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
                label: AppLocalizations.translate(context, 'drawerCreateNewLabel'),
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
              label: AppLocalizations.translate(context, 'drawerArchive'),
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
              label: AppLocalizations.translate(context, 'drawerTrash'),
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
              label: AppLocalizations.translate(context, 'drawerSettings'),
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
        color: AppColors.divider(context),
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
          selectedTileColor: AppColors.drawerSelectedBackground(context),
          leading: Icon(
            icon,
            size: 22,
            color: isSelected
                ? AppColors.drawerSelectedForeground(context)
                : AppColors.textPrimary(context),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppColors.drawerSelectedForeground(context)
                  : AppColors.textPrimary(context),
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}