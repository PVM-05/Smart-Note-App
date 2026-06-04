import 'package:flutter/material.dart';
import '../../../core/design/app_colors.dart';

class EditorAddOptionsSheet extends StatelessWidget {
  final bool isRecording;
  final bool isChecklistMode;
  final VoidCallback onAddImage;
  final VoidCallback onAddDrawing;
  final VoidCallback onToggleRecording;
  final VoidCallback onSwitchToChecklistMode;

  static const _recordColor = Color(0xFFEF4444);

  const EditorAddOptionsSheet({
    super.key,
    required this.isRecording,
    required this.isChecklistMode,
    required this.onAddImage,
    required this.onAddDrawing,
    required this.onToggleRecording,
    required this.onSwitchToChecklistMode,
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
          ListTile(
            leading: Icon(Icons.image_outlined,
                color: AppColors.textSecondary(context)),
            title: const Text('Thêm hình ảnh'),
            onTap: () {
              Navigator.pop(context);
              onAddImage();
            },
          ),
          ListTile(
            leading: Icon(Icons.brush_outlined,
                color: AppColors.textSecondary(context)),
            title: const Text('Bản vẽ'),
            onTap: () {
              Navigator.pop(context);
              onAddDrawing();
            },
          ),
          ListTile(
            leading: Icon(
                isRecording
                    ? Icons.stop_circle_outlined
                    : Icons.mic_none_outlined,
                color: isRecording
                    ? _recordColor
                    : AppColors.textSecondary(context)),
            title: Text(isRecording ? 'Dừng ghi âm' : 'Ghi âm'),
            onTap: () {
              Navigator.pop(context);
              onToggleRecording();
            },
          ),
          if (!isChecklistMode)
            ListTile(
              leading: Icon(Icons.check_box_outlined,
                  color: AppColors.textSecondary(context)),
              title: const Text('Danh sách'),
              onTap: () {
                Navigator.pop(context);
                onSwitchToChecklistMode();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
