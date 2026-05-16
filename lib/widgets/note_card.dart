import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final String? searchQuery;
  final VoidCallback? onMenuPressed;

  const NoteCard({
    super.key,
    required this.note,
    this.searchQuery,
    this.onMenuPressed,
  });

  String _formatDate(DateTime date) {
    final months = [
      'th 1', 'th 2', 'th 3', 'th 4', 'th 5', 'th 6',
      'th 7', 'th 8', 'th 9', 'th 10', 'th 11', 'th 12'
    ];
    return 'Ngày ${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  Color _getNoteColor(String id) {
    final colors = [
      const Color(0xFFFFD8A8), // Cam nhạt
      const Color(0xFFA2D2FF), // Xanh dương nhạt
      const Color(0xFFC1E1C1), // Xanh lá nhạt
      const Color(0xFFFDE2E4), // Hồng nhạt
      const Color(0xFFFEFAE0), // Vàng nhạt
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(note.updatedAt),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (onMenuPressed != null)
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF94A3B8)),
                  onPressed: onMenuPressed,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),

          if (note.title.isNotEmpty && note.content.isNotEmpty)
            const SizedBox(height: 12),

          // ── NỘI DUNG ──
          if (note.content.isNotEmpty)
            _buildHighlightedText(
              note.content,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF475569),
                height: 1.5,
              ),
              maxLines: 6,
            ),

          const SizedBox(height: 12),

          // ── FOOTER: TRẠNG THÁI & CHẤM MÀU ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (note.status == 'pinned')
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFF2E75B6)),
                ),
              if (!note.isSynced)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              // Chấm màu đại diện theo thiết kế mới
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getNoteColor(note.id),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          )
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
