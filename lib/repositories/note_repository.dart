import '../models/note_model.dart';
import '../services/local_note_service.dart';

abstract class NoteRepository {
  Future<List<Note>> getNotes(String userId);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);
  Future<List<Note>> getUnsyncedNotes();
}

class NoteRepositoryImpl implements NoteRepository {
  final LocalNoteService _localService = LocalNoteService();

  @override
  Future<List<Note>> getNotes(String userId) async {
    return await _localService.getAllNotes(userId);
  }

  @override
  Future<void> saveNote(Note note) async {
    // Lưu local trước (offline-first)
    await _localService.insertNote(note);
  }

  @override
  Future<void> deleteNote(String id) async {
    await _localService.deleteNote(id);
  }

  @override
  Future<List<Note>> getUnsyncedNotes() async {
    return await _localService.getUnsyncedNotes();
  }
}
