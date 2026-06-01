// lib/widgets/empty_state.dart
// Widget hiển thị trạng thái rỗng (danh sách trống) dùng chung cho toàn bộ ứng dụng.
// Hỗ trợ animation mờ dần + trượt lên khi xuất hiện, có thể truyền vào icon, tiêu đề,
// mô tả và nút hành động tùy chọn (ví dụ: "Xóa bộ lọc").
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/design/app_colors.dart';

class EmptyStateWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;      // Hiệu ứng mờ dần
  late final Animation<Offset> _slideAnimation;    // Hiệu ứng trượt lên

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Mờ dần theo đường cong easeOut cho cảm giác mượt mà
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // Trượt lên nhẹ từ phía dưới với hiệu ứng bật lò xo
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textSecondaryColor = AppColors.textSecondary(context);
    final textPrimaryColor = AppColors.textPrimary(context);

    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Biểu tượng chính — làm mờ 60% để trông nhẹ nhàng hơn
                Icon(
                  widget.icon,
                  size: 64,
                  color: textSecondaryColor.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),

                // Tiêu đề — font Space Grotesk đậm
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Mô tả phụ — font Inter nhỏ hơn, màu xám
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: textSecondaryColor,
                  ),
                ),

                // Nút hành động tùy chọn (chỉ hiển thị khi được truyền vào)
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: widget.onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      widget.actionLabel!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
