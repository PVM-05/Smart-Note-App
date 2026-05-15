import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_model.dart';
import '../screens/editor_screen.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;

  const NoteCard({super.key, required this.note, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Nhảy sang EditorScreen ở chế độ CHỈNH SỬA (truyền note hiện tại vào)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(note: note),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.status == 'pinned')
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Icon(
                  Icons.push_pin_rounded,
                  size: 16,
                  color: Color(0xFF2E75B6),
                ),
              ),
            Hero(
              tag: 'note_title_${note.id}',
              child: Material(
                color: Colors.transparent,
                child: Text(
                  note.title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Hero(
              tag: 'note_content_${note.id}',
              child: Material(
                color: Colors.transparent,
                child: Text(
                  note.content,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
