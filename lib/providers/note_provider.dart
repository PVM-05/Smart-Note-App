import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../repositories/note_repository.dart';

class NoteProvider extends ChangeNotifier {
  final NoteRepository _repository;
  List<Note> _notes = [];
  List<Note> _filtered  = [];

  // 1. Biến riêng biệt để quản lý Thùng rác
  List<Note> _trashNotes = [];

  bool _isLoading = false;
  bool _isSearching     = false;
  Timer? _debounce;
  final Set<String> _selectedNoteIds = {};

  List<Note> get _activeList => _isSearching ? _filtered : _notes;

  List<Note> get notes       => _activeList.where((n) => n.status != 'trash').toList();
  List<Note> get pinnedNotes => _activeList.where((n) => n.status == 'pinned').toList();
  List<Note> get normalNotes => _activeList.where((n) => n.status == 'normal').toList();

  // Expose mảng rác riêng cho TrashScreen đọc
  List<Note> get trashNotes  => _trashNotes;

  bool get isLoading => _isLoading;
  bool get isSearching  => _isSearching;
  Set<String> get selectedNoteIds => _selectedNoteIds;
  bool get isSelectionMode => _selectedNoteIds.isNotEmpty;
  // Chọn nhiều note trong trash
  final Set<String> _selectedTrashNoteIds = {};

  Set<String> get selectedTrashNoteIds => _selectedTrashNoteIds;
  bool get isTrashSelectionMode => _selectedTrashNoteIds.isNotEmpty;

  NoteProvider(this._repository);

  // ── Thao tác chọn ──
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

  // ── Thao tác hàng loạt (Batch Actions) ──
  Future<void> deleteSelectedNotes() async {
    final idsToDelete = _selectedNoteIds.toList();
    clearSelection(); // Xóa UI trước để tạo cảm giác mượt mà

    for (final id in idsToDelete) {
      await deleteNote(id); // Gọi hàm xóa từng note đang có sẵn
    }
  }

  Future<void> togglePinSelectedNotes() async {
    final idsToToggle = _selectedNoteIds.toList();
    clearSelection();

    for (final id in idsToToggle) {
      // Tìm note trong danh sách hiện tại để lấy data
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

  // ── XÓA MỀM (Chuyển vào thùng rác) ──
  // 2. SỬA LẠI HÀM XÓA: Biến thành XÓA MỀM (Soft Delete)
  Future<void> deleteNote(String id) async {
    final index = _notes.indexWhere((note) => note.id == id);
    if (index != -1) {
      final trashedNote = _notes[index].copyWith(
        status: 'trash',
        isSynced: false,
        updatedAt: DateTime.now(), // Đánh dấu mốc thời gian bắt đầu tính 7 ngày
      );

      _notes.removeAt(index);
      _trashNotes.insert(0, trashedNote);
      notifyListeners();

      // Ghi đè trạng thái 'trash' xuống SQLite và đẩy lên mây
      await _repository.saveNote(trashedNote);
    }
  }

  // 3. THÊM HÀM NÀY: Nạp dữ liệu thùng rác + Tự động tiêu hủy sau 7 ngày
  Future<void> fetchTrashNotes(String userId) async {
    final allTrash = await _repository.getTrashNotes(userId);
    final now = DateTime.now();

    _trashNotes = [];

    for (final note in allTrash) {
      // Tính toán số ngày đã nằm trong thùng rác kể từ lần update cuối (bấm nút xóa)
      final daysInTrash = now.difference(note.updatedAt).inDays;

      if (daysInTrash >= 7) {
        // Quá hạn 7 ngày -> Gọi lệnh HARD DELETE (Xóa sạch hoàn toàn)
        await _repository.deleteNote(note.id);
      } else {
        // Chưa quá hạn -> Giữ lại hiển thị trong thùng rác
        _trashNotes.add(note);
      }
    }
    notifyListeners();
  }

  // 4. THÊM HÀM: Xóa vĩnh viễn thủ công
  Future<void> deleteNoteForever(String id) async {
    _trashNotes.removeWhere((n) => n.id == id);
    notifyListeners();
    await _repository.deleteNote(id); // Hard delete vĩnh viễn dưới DB
  }

  // 5. THÊM HÀM: Khôi phục ghi chú
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
    clearTrashSelection(); // Xóa UI trước cho mượt
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

  // Xóa sạch bách toàn bộ trạng thái khi đăng xuất
  void clearNotes() {
    _notes = [];
    _filtered = [];
    _trashNotes = [];
    _selectedNoteIds.clear();
    _selectedTrashNoteIds.clear();
    _isSearching = false;
    notifyListeners();
  }

  // 2. Thêm hàm public này để HomeScreen gọi xóa dữ liệu dưới SQLite
  Future<void> clearLocalData(String userId) async {
    // Gọi xuống repository thay vì để UI gọi trực tiếp
    await _repository.clearLocalData(userId);
  }
}
