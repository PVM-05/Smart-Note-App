import 'package:flutter/material.dart';
import '../../../core/design/app_colors.dart';

class EditorMoreOptionsSheet extends StatelessWidget {
  final bool hasBeenSavedInDb;
  final String status;
  final VoidCallback onDelete;
  final VoidCallback onLabelSelection;
  final VoidCallback onToggleArchive;

  const EditorMoreOptionsSheet({
    super.key,
    required this.hasBeenSavedInDb,
    required this.status,
    required this.onDelete,
    required this.onLabelSelection,
    required this.onToggleArchive,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider(context),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          if (hasBeenSavedInDb)
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: AppColors.textSecondary(context)),
              title: const Text('Xóa ghi chú'),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ListTile(
            leading: Icon(Icons.label_outline,
                color: AppColors.textSecondary(context)),
            title: const Text('Nhãn'),
            onTap: () {
              Navigator.pop(context);
              onLabelSelection();
            },
          ),
          if (hasBeenSavedInDb)
            ListTile(
              leading: Icon(
                  status == 'archived'
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  color: AppColors.textSecondary(context)),
              title: Text(status == 'archived' ? 'Hủy lưu trữ' : 'Lưu trữ'),
              onTap: () {
                Navigator.pop(context);
                onToggleArchive();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
