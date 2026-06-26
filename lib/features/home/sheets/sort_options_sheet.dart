import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';

enum SortType {
  updatedNewest,
  createdNewest,
  custom,
}

class SortOptionsSheet extends StatelessWidget {
  final SortType currentSortType;
  final ValueChanged<SortType> onSortTypeChanged;

  const SortOptionsSheet({
    super.key,
    required this.currentSortType,
    required this.onSortTypeChanged,
  });

  Widget _buildSortOption(
    BuildContext context, {
    required SortType type,
    required IconData icon,
    required String title,
  }) {
    final isSelected = currentSortType == type;
    const primaryColor = AppColors.primary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon,
          color: isSelected ? primaryColor : AppColors.textMetadata(context)),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? primaryColor : AppColors.textPrimary(context),
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: primaryColor, size: 20)
          : null,
      onTap: () => onSortTypeChanged(type),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Sắp xếp theo',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                letterSpacing: -0.2,
              ),
            ),
          ),
          const Divider(),
          _buildSortOption(
            context,
            type: SortType.custom,
            icon: Icons.drag_handle,
            title: 'Tuỳ chỉnh',
          ),
          _buildSortOption(
            context,
            type: SortType.updatedNewest,
            icon: Icons.history,
            title: 'Ngày tạo',
          ),
          _buildSortOption(
            context,
            type: SortType.createdNewest,
            icon: Icons.access_time,
            title: 'Ngày sửa đổi',
          ),
        ],
      ),
    );
  }
}
