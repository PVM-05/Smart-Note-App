// lib/widgets/note_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart'; // 🌟 1. Cài đặt trực tiếp gói thư viện Shimmer
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final String? searchQuery;
  final VoidCallback? onMenuPressed;
  final bool isGrid;

  // Khuyến khích sử dụng const constructor để Flutter đưa vào bộ nhớ cache hệ thống
  const NoteCard({
    super.key,
    required this.note,
    this.searchQuery,
    this.onMenuPressed,
    this.isGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    // Tối ưu hóa màu sắc tĩnh để tránh tính toán run-time alpha `.withValues`
    const Color contentColor = Color(0xDA475569);

    // Kiểm tra trạng thái dữ liệu đa phương tiện từ Note Model
    final hasImages = note.imageUrls.isNotEmpty;
    final hasAudio = note.audioUrls.isNotEmpty;

    // Tự động kiểm tra độ sáng hệ thống để thích ứng tone màu mờ cho cả Dark/Light Mode
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    // 🌟 2. BỌC REPAINTBOUNDARY NGOÀI CÙNG: Cô lập đồ họa của từng NoteCard,
    // giúp tối ưu hóa hiệu năng render 60 FPS khi cuộn danh sách lưới MasonryGrid
    return RepaintBoundary(
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias, // Giúp ảnh bo tròn mượt mà khớp theo góc của Card
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: isDark ? const Color(0xFF1E293B) : Colors.white, // Thích ứng màu nền theo Theme
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min, // Tự co giãn chiều cao linh hoạt theo nội dung
          children: [

            // ── 1. HÌNH ẢNH TOÀN BỘ (KÈM HIỆU ỨNG SHIMMER LIBRARY) ──
            if (hasImages)
              Image.network(
                note.imageUrls.first, // Lấy hình ảnh đầu tiên trong danh sách
                fit: BoxFit.cover,    // 🌟 Thay đổi thành BoxFit.cover để ảnh phủ đều khít khung
                width: double.infinity,

                // 🌟 SIÊU TỐI ƯU RAM/CPU: Ép Flutter scale ảnh trực tiếp ở tầng native engine về đúng kích thước hiển thị.
                // Tránh việc nạp ảnh gốc độ phân giải cao làm nghẽn bộ nhớ đệm (Giải quyết triệt để vấn đề lag máy ảo)
                cacheWidth: 400,

                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Shimmer.fromColors(
                    baseColor: shimmerBase,
                    highlightColor: shimmerHighlight,
                    period: const Duration(milliseconds: 1200),
                    child: Container(
                      height: 160, // Đồng bộ chiều cao khung Shimmer khớp hoàn toàn với ảnh
                      width: double.infinity,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 60,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  child: Icon(
                      Icons.broken_image_outlined,
                      color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                      size: 20
                  ),
                ),
              ),

            // Phần thân chứa Tiêu đề, Nội dung văn bản, Thông tin file ghi âm và Chân thẻ
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── 2. HEADER: TIÊU ĐỀ & MENU ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (note.title.isNotEmpty)
                              _buildHighlightedText(
                                note.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF1A202C),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 2,
                              ),
                          ],
                        ),
                      ),
                      if (onMenuPressed != null)
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                          onPressed: onMenuPressed,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),

                  if (note.title.isNotEmpty && note.content.isNotEmpty)
                    const SizedBox(height: 8),

                  // ── 3. NỘI DUNG VĂN BẢN ──
                  if (note.content.isNotEmpty)
                    _buildHighlightedText(
                      note.content,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : contentColor,
                        height: 1.55,
                      ),
                      maxLines: 6, // Hiển thị tối đa 6 dòng preview giống Google Keep
                    ),

                  // ── 4. HIỂN THỊ BIỂU TƯỢNG VÀ TÊN FILE ÂM THANH ──
                  if (hasAudio) ...[
                    const SizedBox(height: 10),
                    _buildAudioFileAttachment(note.audioUrls.first, isDark),
                  ],

                  // ── 5. FOOTER: DANH SÁCH THẺ (TAGS) ──
                  if (note.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Wrap(
                        spacing: 6.0,
                        runSpacing: 6.0,
                        children: note.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), // Màu nền dịu mắt thích ứng theme
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget hiển thị Biểu tượng Micro + Tên file âm thanh gọn gàng
  Widget _buildAudioFileAttachment(String audioUrl, bool isDark) {
    String fileName = 'Ghi âm thanh 1';
    try {
      final uri = Uri.parse(audioUrl);
      final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (lastSegment.isNotEmpty) {
        fileName = lastSegment;
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC), // Nền bao bọc file đính kèm thích ứng theme
        borderRadius: BorderRadius.circular(8),
        border: isDark ? Border.all(color: const Color(0xFF334155), width: 0.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Chỉ chiếm không gian vừa đủ theo tên file
        children: [
          Icon(
            Icons.mic_none_rounded, // Biểu tượng ghi âm
            size: 16,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              fileName,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // Nếu tên file quá dài sẽ tự động hiển thị dấu ...
            ),
          ),
        ],
      ),
    );
  }

  // ⚡ SIÊU TỐI ƯU CPU: Giải thuật so khớp chuỗi tĩnh không dùng vòng lặp vô hạn
  Widget _buildHighlightedText(
      String text, {
        required TextStyle style,
        int maxLines = 1,
      }) {
    final query = searchQuery?.trim() ?? '';

    if (query.isEmpty) {
      return Text(
          text,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    if (!lowerText.contains(lowerQuery)) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          backgroundColor: const Color(0xFFFEF08A),
          color: const Color(0xFF1E293B),
        ),
      ));
      start = index + query.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}