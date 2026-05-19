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

          // ── DANH SÁCH THẺ (TAGS) - Chuẩn Google Keep ──
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
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      borderRadius: BorderRadius.circular(16), // Bo tròn thành viên thuốc
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // ── FOOTER: TRẠNG THÁI (Ghim / Đồng bộ) ──
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
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
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