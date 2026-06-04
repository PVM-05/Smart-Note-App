import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';

class EditorColorPickerSheet extends StatelessWidget {
  final String? noteColor;
  final ValueChanged<String?> onColorSelected;

  const EditorColorPickerSheet({
    super.key,
    required this.noteColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.noteBackgroundPalette(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chọn màu ghi chú',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: palette.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, index) {
                  if (index == 0) {
                    return _noteColorSwatch(
                      context: ctx,
                      tooltip: 'Mặc định',
                      fillColor: AppColors.notePickerClearSwatch(ctx),
                      isClear: true,
                      isSelected: noteColor == null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onColorSelected(null);
                      },
                    );
                  }
                  final entry = palette[index - 1];
                  final isSelected =
                      AppColors.isNotePaletteColorSelected(noteColor, entry);
                  return _noteColorSwatch(
                    context: ctx,
                    tooltip: entry.label,
                    fillColor: entry.displayColor(ctx),
                    isClear: false,
                    isSelected: isSelected,
                    onTap: () {
                      Navigator.pop(ctx);
                      onColorSelected(entry.storageHex);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteColorSwatch({
    required BuildContext context,
    required String tooltip,
    required Color fillColor,
    required bool isClear,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final accent = AppColors.notePickerAccent(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      preferBelow: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: fillColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? accent : AppColors.divider(context),
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: isClear
                    ? (isDark
                        ? const Icon(Icons.water_drop_outlined,
                            size: 18, color: Colors.white70)
                        : CustomPaint(
                            painter: _NoColorSlashPainter(
                              color: AppColors.textMetadata(context),
                            ),
                          ))
                    : null,
              ),
              if (isSelected)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoColorSlashPainter extends CustomPainter {
  _NoColorSlashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.78),
      Offset(size.width * 0.78, size.height * 0.22),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _NoColorSlashPainter oldDelegate) =>
      oldDelegate.color != color;
}
