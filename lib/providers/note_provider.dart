import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../repositories/note_repository.dart';

class NoteProvider extends ChangeNotifier {
  final NoteRepository _repository;
  List<Note> _notes = [];
  List<Note> _filtered  = [];
  bool _isLoading = false;
  bool _isSearching     = false; // THÊM — đang ở chế độ search?
  Timer? _debounce;

  List<Note> get _activeList => _isSearching ? _filtered : _notes;
  List<Note> get notes       => _activeList.where((n) => n.status != 'trash').toList();
  List<Note> get pinnedNotes => _activeList.where((n) => n.status == 'pinned').toList();
  List<Note> get normalNotes => _activeList.where((n) => n.status == 'normal').toList();
  List<Note> get trashNotes  => _activeList.where((n) => n.status == 'trash').toList();
  bool get isLoading => _isLoading;
  bool get isSearching  => _isSearching;

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

  void search(String query, String userId) {
    // Hủy debounce cũ nếu user vẫn đang gõ
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      _isSearching = false;
      _filtered    = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners(); // hiện loading ngay

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      _filtered = await _repository.searchNotes(
        userId: userId,
        query: query,
      );
      notifyListeners();
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    _isSearching = false;
    _filtered    = [];
    notifyListeners();
  }

  void clearNotes() {
    _notes = [];
    notifyListeners();
  }
}
