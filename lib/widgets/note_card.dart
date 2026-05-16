import 'package:flutter/material.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;
  final String? searchQuery; // THÊM — để highlight

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: _buildHighlightedText(
          note.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
        ),
        subtitle: _buildHighlightedText(
          note.content,
          style: const TextStyle(color: Colors.grey),
          maxLines: 2,
        ),
        trailing: note.status == 'pinned'
            ? const Icon(Icons.push_pin, size: 16, color: Colors.orange)
            : note.isSynced
            ? null
            : const Icon(Icons.sync, size: 14, color: Colors.grey),
      ),
    );
  }

  // Highlight từ khóa search bằng màu vàng
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
        // Phần còn lại không có keyword
        spans.add(TextSpan(
          text: text.substring(start),
          style: style,
        ));
        break;
      }
      // Phần trước keyword
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: style,
        ));
      }
      // Keyword — highlight nền vàng
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          backgroundColor: Colors.yellow.shade300,
          color: Colors.black,
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