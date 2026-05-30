// lib/widgets/note_card_shimmer.dart
// Widget hiệu ứng "shimmer" (ánh sáng lướt qua) dùng để hiển thị skeleton loading
// khi danh sách ghi chú đang tải dữ liệu — tránh màn hình trắng gây khó chịu.
// Tự động thích nghi màu sắc theo giao diện Sáng / Tối của ứng dụng.
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/app_colors.dart';

class NoteCardShimmer extends StatelessWidget {
  final bool isGrid;

  const NoteCardShimmer({
    super.key,
    this.isGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Chọn màu shimmer phù hợp với giao diện để đạt thẩm mỹ cao
    final baseColor      = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0); // Màu nền skeleton
    final highlightColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5); // Màu ánh sáng lướt qua
    final cardColor      = isDark ? AppColors.darkSurface   : Colors.white;             // Màu nền card

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Skeleton dòng tiêu đề
            Container(
              width: double.infinity,
              height: 18,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),

            // Skeleton dòng nội dung thứ nhất
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),

            // Skeleton dòng nội dung thứ hai (ngắn hơn để trông tự nhiên)
            Container(
              width: MediaQuery.of(context).size.width * 0.4,
              height: 12,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),

            // Hàng cuối — mô phỏng ngày tháng và biểu tượng đính kèm
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Skeleton ngày tháng
                Container(
                  width: 60,
                  height: 10,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Skeleton biểu tượng tròn nhỏ (ví dụ: ghim, khóa...)
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: baseColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
