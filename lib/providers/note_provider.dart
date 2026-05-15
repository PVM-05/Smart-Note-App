import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../repositories/note_repository.dart';

class NoteProvider extends ChangeNotifier {
  final NoteRepository _repository;
  List<Note> _notes = [];
  bool _isLoading = false;

  List<Note> get notes => _notes.where((n) => n.status != 'trash').toList();
  List<Note> get pinnedNotes => _notes.where((n) => n.status == 'pinned').toList();
  List<Note> get normalNotes => _notes.where((n) => n.status == 'normal').toList();
  List<Note> get trashNotes => _notes.where((n) => n.status == 'trash').toList();
  bool get isLoading => _isLoading;

  NoteProvider(this._repository);

  Future<void> fetchNotes(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _notes = await _repository.getNotes(userId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNote(Note note) async {
    // Cập nhật UI ngay lập tức
    _notes.insert(0, note);
    notifyListeners();

    // Chạy ngầm việc lưu trữ và đồng bộ
    await _repository.saveNote(note);
  }

  Future<void> updateNote(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
      notifyListeners();
      await _repository.saveNote(note);
    }
  }

  Future<void> deleteNote(String id) async {
    // Thay vì xóa hẳn, ta có thể chuyển vào trash nếu muốn
    // Ở đây tôi giữ logic xóa khỏi danh sách hiện tại của bạn
    _notes.removeWhere((note) => note.id == id);
    notifyListeners();
    await _repository.deleteNote(id);
  }

  Future<void> togglePin(Note note) async {
    final updatedNote = note.copyWith(
      status: note.status == 'pinned' ? 'normal' : 'pinned',
    );

    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = updatedNote;
      notifyListeners();
      await _repository.saveNote(updatedNote);
    }
  }
  void clearNotes() {
    _notes = [];
    notifyListeners();
  }
}
