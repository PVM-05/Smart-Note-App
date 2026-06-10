import 'package:flutter/material.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/app_localizations.dart';

class EditorMoreOptionsSheet extends StatelessWidget {
  final bool hasBeenSavedInDb;
  final String status;
  final VoidCallback onDelete;
  final VoidCallback onLabelSelection;
  final VoidCallback onToggleArchive;
  final VoidCallback onExportPdf;

  const EditorMoreOptionsSheet({
    super.key,
    required this.hasBeenSavedInDb,
    required this.status,
    required this.onDelete,
    required this.onLabelSelection,
    required this.onToggleArchive,
    required this.onExportPdf,
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
              title: Text(AppLocalizations.translate(context, 'deleteNote')),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ListTile(
            leading: Icon(Icons.label_outline,
                color: AppColors.textSecondary(context)),
            title: Text(AppLocalizations.translate(context, 'labels')),
            onTap: () {
              Navigator.pop(context);
              onLabelSelection();
            },
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined,
                color: AppColors.textSecondary(context)),
            title: Text(AppLocalizations.translate(context, 'exportPdf')),
            onTap: () {
              Navigator.pop(context);
              onExportPdf();
            },
          ),
          if (hasBeenSavedInDb)
            ListTile(
              leading: Icon(
                  status == 'archived'
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  color: AppColors.textSecondary(context)),
              title: Text(status == 'archived'
                  ? AppLocalizations.translate(context, 'unarchive')
                  : AppLocalizations.translate(context, 'archive')),
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
