import 'package:flutter/material.dart';
import '../models/note_model.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;

  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: note.status == 'pinned' ? const Icon(Icons.push_pin, size: 16) : null,
      ),
    );
  }
}
