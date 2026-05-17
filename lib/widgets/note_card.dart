import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final String? searchQuery;
  final VoidCallback? onMenuPressed;
  final bool isGrid;

  const NoteCard({
    super.key,
    required this.note,
    this.searchQuery,
    this.onMenuPressed,
    this.isGrid = true,
  });

  String _formatDate(DateTime date) {
    final months = [
      'th 1', 'th 2', 'th 3', 'th 4', 'th 5', 'th 6',
      'th 7', 'th 8', 'th 9', 'th 10', 'th 11', 'th 12'
    ];
    return 'Ngày ${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  static Color getNoteColor(String id) {
    // Bảng màu sắp xếp tương phản (đối diện trên bánh xe màu)
    final colors = [
      const Color(0xFFEF9A9A), // Đỏ nhạt
      const Color(0xFF90CAF9), // Xanh dương nhạt (đối lập đỏ)
      const Color(0xFFFFE082), // Vàng nhạt
      const Color(0xFFA5D6A7), // Xanh lá nhạt (đối lập vàng/cam)
      const Color(0xFFFFAB91), // Cam nhạt (đối lập xanh dương)
    ];
    return colors[id.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(note.updatedAt),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
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
                color: const Color(0xFF475569).withValues(alpha: 0.85),
                height: 1.55,
              ),
              maxLines: 6,
            ),

          // ── FOOTER: TRẠNG THÁI ──
          if (note.status == 'pinned' || !note.isSynced)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  if (note.status == 'pinned')
                    const Icon(Icons.push_pin_rounded, size: 13, color: Color(0xFF2E75B6)),
                  if (!note.isSynced)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.cloud_upload_outlined, size: 13, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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
          backgroundColor: Colors.yellow.shade200,
          color: Colors.black87,
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
