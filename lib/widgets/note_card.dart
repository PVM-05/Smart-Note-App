import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;
  final String? searchQuery;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero, // Margin đã được xử lý ở container bọc ngoài của HomeScreen
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // RẤT QUAN TRỌNG: Giúp thẻ tự co giãn chiều cao trong lưới Masonry
            children: [
              // ── PHẦN HEADER: TIÊU ĐỀ & ICON GHIM ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: note.title.isNotEmpty
                        ? _buildHighlightedText(
                      note.title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                      maxLines: 3,
                    )
                        : const SizedBox.shrink(),
                  ),
                  if (note.status == 'pinned') ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.push_pin_rounded, size: 18, color: Color(0xFF2E75B6)),
                  ]
                ],
              ),

              if (note.title.isNotEmpty && note.content.isNotEmpty)
                const SizedBox(height: 8),

              // ── PHẦN NỘI DUNG ──
              if (note.content.isNotEmpty)
                _buildHighlightedText(
                  note.content,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF475569),
                    height: 1.5,
                  ),
                  maxLines: 8, // Cho phép hiển thị tối đa 8 dòng để tạo hiệu ứng sole (Masonry)
                ),

              // ── PHẦN FOOTER: TRẠNG THÁI ĐỒNG BỘ ──
              if (!note.isSynced) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // Hàm Highlight từ khóa search bằng màu vàng (Giữ nguyên logic cực tốt của bạn)
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

    final lowerText  = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans      = <TextSpan>[];
    int start        = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: style,
        ));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: style,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          backgroundColor: Colors.yellow.shade300,
          color: Colors.black87, // Làm chữ màu đen đậm hơn một chút cho dễ đọc trên nền vàng
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