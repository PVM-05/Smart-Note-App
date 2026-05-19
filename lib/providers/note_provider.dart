// lib/providers/note_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../repositories/note_repository.dart';

class NoteProvider extends ChangeNotifier {
  final NoteRepository _repository;
  List<Note> _notes = [];
  List<Note> _filtered  = [];
  List<Note> _trashNotes = [];

  bool _isLoading = false;
  bool _isSearching     = false;
  Timer? _debounce;
  final Set<String> _selectedNoteIds = {};
  final Set<String> _selectedTrashNoteIds = {};

  List<String> _customLabels = [];
  String? _selectedLabel;

  List<Note> get _activeList => _isSearching ? _filtered : _notes;

  List<Note> get _filteredByLabel {
    final list = _activeList.where((n) => n.status != 'trash').toList();
    if (_selectedLabel != null) {
      return list.where((n) => n.tags.contains(_selectedLabel)).toList();
    }
    return list;
  }

  List<Note> get notes       => _filteredByLabel;
  List<Note> get pinnedNotes => _filteredByLabel.where((n) => n.status == 'pinned').toList();
  List<Note> get normalNotes => _filteredByLabel.where((n) => n.status == 'normal').toList();
  List<Note> get trashNotes  => _trashNotes;

  bool get isLoading => _isLoading;
  bool get isSearching  => _isSearching;
  Set<String> get selectedNoteIds => _selectedNoteIds;
  bool get isSelectionMode => _selectedNoteIds.isNotEmpty;
  Set<String> get selectedTrashNoteIds => _selectedTrashNoteIds;
  bool get isTrashSelectionMode => _selectedTrashNoteIds.isNotEmpty;

  String? get selectedLabel => _selectedLabel;

  NoteProvider(this._repository);

  List<String> get allLabels {
    final Set<String> labelSet = {};
    for (var note in _notes) {
      labelSet.addAll(note.tags);
    }
    for (var note in _trashNotes) {
      labelSet.addAll(note.tags);
    }
    labelSet.addAll(_customLabels);
    final list = labelSet.toList();
    list.sort();
    return list;
  }

  void selectLabel(String? label) {
    _selectedLabel = label;
    notifyListeners();
  }

  void addLabel(String labelName) {
    final trimmed = labelName.trim();
    if (trimmed.isNotEmpty && !allLabels.contains(trimmed)) {
      _customLabels.add(trimmed);
      notifyListeners();
    }
  }

  // ── THÊM MỘT NHÃN CHO TẤT CẢ CÁC GHI CHÚ ĐANG ĐƯỢC CHỌN VÀ ĐỒNG BỘ FIREBASE ──
  Future<void> addLabelToSelectedNotes(String labelName) async {
    final idsToLabel = _selectedNoteIds.toList();
    clearSelection(); // Xóa trạng thái chọn trên UI trước cho mượt mà

    for (final id in idsToLabel) {
      final index = _notes.indexWhere((n) => n.id == id);
      if (index != -1) {
        final note = _notes[index];
        // Nếu ghi chú chưa có nhãn này thì tiến hành thêm vào
        if (!note.tags.contains(labelName)) {
          final updatedTags = List<String>.from(note.tags)..add(labelName);
          _notes[index] = note.copyWith(tags: updatedTags, isSynced: false);

          // Lưu xuống local SQLite và tự động đồng bộ sync lên Cloud Firebase
          await _repository.saveNote(_notes[index]);
        }
      }
    }
    notifyListeners();
  }

  Future<void> renameLabel(String oldName, String newName) async {
    final trimmedNew = newName.trim();
    if (trimmedNew.isEmpty || oldName == trimmedNew) return;

    if (_customLabels.contains(oldName)) {
      _customLabels.remove(oldName);
      if (!_customLabels.contains(trimmedNew)) _customLabels.add(trimmedNew);
    }

    for (int i = 0; i < _notes.length; i++) {
      if (_notes[i].tags.contains(oldName)) {
        final updatedTags = _notes[i].tags.map((t) => t == oldName ? trimmedNew : t).toList();
        _notes[i] = _notes[i].copyWith(tags: updatedTags, isSynced: false);
        await _repository.saveNote(_notes[i]);
      }
    }

    for (int i = 0; i < _trashNotes.length; i++) {
      if (_trashNotes[i].tags.contains(oldName)) {
        final updatedTags = _trashNotes[i].tags.map((t) => t == oldName ? trimmedNew : t).toList();
        _trashNotes[i] = _trashNotes[i].copyWith(tags: updatedTags, isSynced: false);
        await _repository.saveNote(_trashNotes[i]);
      }
    }

    if (_selectedLabel == oldName) _selectedLabel = trimmedNew;
    notifyListeners();
  }

  Future<void> deleteLabel(String labelName) async {
    _customLabels.remove(labelName);

    for (int i = 0; i < _notes.length; i++) {
      if (_notes[i].tags.contains(labelName)) {
        final updatedTags = _notes[i].tags.where((t) => t != labelName).toList();
        _notes[i] = _notes[i].copyWith(tags: updatedTags, isSynced: false);
        await _repository.saveNote(_notes[i]);
      }
    }

    for (int i = 0; i < _trashNotes.length; i++) {
      if (_trashNotes[i].tags.contains(labelName)) {
        final updatedTags = _trashNotes[i].tags.where((t) => t != labelName).toList();
        _trashNotes[i] = _trashNotes[i].copyWith(tags: updatedTags, isSynced: false);
        await _repository.saveNote(_trashNotes[i]);
      }
    }

    if (_selectedLabel == labelName) _selectedLabel = null;
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedNoteIds.contains(id)) {
      _selectedNoteIds.remove(id);
    } else {
      _selectedNoteIds.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedNoteIds.clear();
    notifyListeners();
  }

  Future<void> deleteSelectedNotes() async {
    final idsToDelete = _selectedNoteIds.toList();
    clearSelection();
    for (final id in idsToDelete) {
      await deleteNote(id);
    }
  }

  Future<void> togglePinSelectedNotes() async {
    final idsToToggle = _selectedNoteIds.toList();
    clearSelection();
    for (final id in idsToToggle) {
      final note = _activeList.firstWhere((n) => n.id == id);
      await togglePin(note);
    }
  }

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
    _notes.insert(0, note);
    notifyListeners();
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
    final index = _notes.indexWhere((note) => note.id == id);
    if (index != -1) {
      final trashedNote = _notes[index].copyWith(
        status: 'trash',
        isSynced: false,
        updatedAt: DateTime.now(),
      );
      _notes.removeAt(index);
      _trashNotes.insert(0, trashedNote);
      notifyListeners();
      await _repository.saveNote(trashedNote);
    }
  }

  Future<void> fetchTrashNotes(String userId) async {
    final allTrash = await _repository.getTrashNotes(userId);
    final now = DateTime.now();
    _trashNotes = [];
    for (final note in allTrash) {
      final daysInTrash = now.difference(note.updatedAt).inDays;
      if (daysInTrash >= 7) {
        await _repository.deleteNote(note.id);
      } else {
        _trashNotes.add(note);
      }
    }
    notifyListeners();
  }

  Future<void> deleteNoteForever(String id) async {
    _trashNotes.removeWhere((n) => n.id == id);
    notifyListeners();
    await _repository.deleteNote(id);
  }

  Future<void> restoreNote(String id) async {
    final index = _trashNotes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final restoredNote = _trashNotes[index].copyWith(
        status: 'normal',
        isSynced: false,
        updatedAt: DateTime.now(),
      );
      _trashNotes.removeAt(index);
      _notes.insert(0, restoredNote);
      notifyListeners();
      await _repository.saveNote(restoredNote);
    }
  }

  void toggleTrashSelection(String id) {
    if (_selectedTrashNoteIds.contains(id)) {
      _selectedTrashNoteIds.remove(id);
    } else {
      _selectedTrashNoteIds.add(id);
    }
    notifyListeners();
  }

  void clearTrashSelection() {
    _selectedTrashNoteIds.clear();
    notifyListeners();
  }

  Future<void> restoreSelectedTrashNotes() async {
    final idsToRestore = _selectedTrashNoteIds.toList();
    clearTrashSelection();
    for (final id in idsToRestore) {
      await restoreNote(id);
    }
  }

  Future<void> deleteForeverSelectedTrashNotes() async {
    final idsToDelete = _selectedTrashNoteIds.toList();
    clearTrashSelection();
    for (final id in idsToDelete) {
      await deleteNoteForever(id);
    }
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
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _isSearching = false;
      _filtered    = [];
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      _filtered = await _repository.searchNotes(userId: userId, query: query);
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
    _filtered = [];
    _trashNotes = [];
    _customLabels = [];
    _selectedLabel = null;
    _selectedNoteIds.clear();
    _selectedTrashNoteIds.clear();
    _isSearching = false;
    notifyListeners();
  }

  Future<void> clearLocalData(String userId) async {
    await _repository.clearLocalData(userId);
  }
}