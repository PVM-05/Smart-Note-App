import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../repositories/note_repository.dart';

class NoteProvider extends ChangeNotifier {
  final NoteRepository _repository;
  List<Note> _notes = [];
  bool _isLoading = false;

  List<Note> get notes => _notes;
  List<Note> get pinnedNotes => _notes.where((n) => n.status == 'pinned').toList();
  List<Note> get normalNotes => _notes.where((n) => n.status == 'normal').toList();
  bool get isLoading => _isLoading;

  NoteProvider(this._repository);

  Future<void> fetchNotes(String userId) async {
    _isLoading = true;
    notifyListeners();
    _notes = await _repository.getNotes(userId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addNote(Note note) async {
    await _repository.saveNote(note); // Tự động sync
    _notes.insert(0, note);
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    _notes.removeWhere((note) => note.id == id);
    notifyListeners();
  }

  Future<void> togglePin(Note note) async {
    final updatedNote = note.copyWith(
      status: note.status == 'pinned' ? 'normal' : 'pinned',
    );
    await _repository.saveNote(updatedNote);
    
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = updatedNote;
      notifyListeners();
    }
  }
}
