import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/app_localizations.dart';
import '../../../screens/editor_screen.dart';

class HomeQuickMenu extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onTextNoteTap;

  const HomeQuickMenu({
    super.key,
    required this.animation,
    required this.onTextNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menuItems = [
      {
        'icon': Icons.mic_none_outlined,
        'title': AppLocalizations.translate(context, 'quickAudio'),
        'action': () {
          // Mở EditorScreen với auto-start recording
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const EditorScreen(note: null, autoRecord: true),
              ));
        }
      },
      {
        'icon': Icons.image_outlined,
        'title': AppLocalizations.translate(context, 'quickImage'),
        'action': () {
          // Mở EditorScreen với auto-pick image
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const EditorScreen(note: null, autoPickImage: true),
              ));
        }
      },
      {
        'icon': Icons.brush_outlined,
        'title': AppLocalizations.translate(context, 'quickDrawing'),
        'action': () {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const EditorScreen(note: null, autoOpenDrawing: true),
              ));
        }
      },
      {
        'icon': Icons.check_box_outlined,
        'title': AppLocalizations.translate(context, 'quickList'),
        'action': () {
          Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const EditorScreen(note: null, isChecklistMode: true),
              ));
        }
      },
      {
        'icon': Icons.text_fields_outlined,
        'title': AppLocalizations.translate(context, 'quickText'),
        'action': onTextNoteTap,
      },
    ];

    return Stack(
      children: [
        // 1. Lớp nền mờ kính chuyển động
        // Nền phủ tối nhẹ kiểu Google Keep
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Container(
              color: AppColors.textPrimary(context).withValues(
                alpha: (animation.value * 0.5).clamp(0.0, 1.0),
              ),
            );
          },
        ),

        GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),

        // 2. GIẢI PHÁP: Bọc SafeArea bảo vệ bên ngoài khu vực nút bấm
        SafeArea(
          child: Stack(
            children: [
              Positioned(
                bottom: 16, // Khoảng cách 16px an toàn từ đáy màn hình ứng dụng
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Các khối Option tách rời bo tròn
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(menuItems.length, (index) {
                        final item = menuItems[index];

                        final double startDelay =
                            (menuItems.length - 1 - index) * 0.08;
                        final double endDelay =
                            (startDelay + 0.5).clamp(0.0, 1.0);

                        final scaleAnimation =
                            Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Interval(startDelay, endDelay,
                                curve: Curves.easeOutBack),
                          ),
                        );

                        return ScaleTransition(
                          scale: scaleAnimation,
                          alignment: Alignment.bottomRight,
                          child: FadeTransition(
                            opacity: animation,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.textPrimary(context)
                                        .withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    Navigator.pop(context);
                                    (item['action'] as VoidCallback)();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item['title'] as String,
                                          style: GoogleFonts.roboto(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary(
                                                context),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Icon(item['icon'] as IconData,
                                            color:
                                                AppColors.textMetadata(context),
                                            size: 22),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),

                    // Nút FAB giả lập - chỉ xoay icon dấu cộng bên trong
                    FloatingActionButton(
                      heroTag: null,
                      elevation: 4,
                      backgroundColor: AppColors.surface(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle:
                                animation.value * 2.35619, // Xoay 135 độ chuẩn
                            child: child,
                          );
                        },
                        child: const Icon(
                          Icons.add,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
