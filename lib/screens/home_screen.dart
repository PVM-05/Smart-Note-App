import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../services/local_note_service.dart';
import '../widgets/note_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = LocalNoteService();
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _service.getAllNotes();
    setState(() => _notes = notes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Note')),
      body: _notes.isEmpty 
          ? const Center(child: Text('Chưa có ghi chú nào. Hãy bấm + để thêm.'))
          : ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, i) => NoteCard(
                title: _notes[i].title,
                content: _notes[i].content,
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addNote() async {
    try {
      final note = Note(
        id: const Uuid().v4(),
        title: 'Note ${_notes.length + 1}',
        content: 'Nội dung ghi chú...',
      );
      await _service.insertNote(note);
      await _loadNotes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bị lỗi: $e')),
        );
      }
    }
  }
}
