import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/note_model.dart';

class NoteDetailScreen extends StatelessWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'note_title_${note.id}',
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    note.title,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Last edited 2 mins ago',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const Spacer(),
                  if (note.status == 'pinned')
                    const Icon(Icons.push_pin_rounded, size: 18, color: Color(0xFF2E75B6)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Hero(
              tag: 'note_content_${note.id}',
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    note.content,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      color: Colors.black54,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: const Color(0xFF2E75B6),
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        label: Text('Edit Note', style: GoogleFonts.outfit(color: Colors.white)),
      ),
    );
  }
}
