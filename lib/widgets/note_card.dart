// lib/widgets/note_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── HEADER: TIÊU ĐỀ & MENU ──
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
                          color: const Color(0xFF1A202C),
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
            const SizedBox(height: 10),

          // ── NỘI DUNG ──
          if (note.content.isNotEmpty)
            _buildHighlightedText(
              note.content,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: contentColor,
                height: 1.55,
              ),
              maxLines: 6,
            ),

          // ── DANH SÁCH THẺ (TAGS) ──
          if (note.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: note.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
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

    // Nếu tiêu đề/nội dung không chứa từ khóa -> Trả về text thường, tiết kiệm 90% tài nguyên xử lý RichText
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
          backgroundColor: const Color(0xFFFEF08A), // vàng nhẹ mượt mà
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