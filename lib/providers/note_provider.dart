// lib/providers/note_provider.dart
import 'dart:developer' as developer;

import '../services/cloudinary_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../repositories/note_repository.dart';


class NoteProvider extends ChangeNotifier {
  final NoteRepository _repository;
  List<Note> _notes = [];
  List<Note> _filtered  = [];
  List<Note> _trashNotes = [];
  List<Note> _pinnedNotesList = []; // Thêm mảng quản lý Note ghim riêng biệt

  bool _isLoading = false;
  bool _isSearching = false;
  Timer? _debounce;
  final Set<String> _selectedNoteIds = {};
  final Set<String> _selectedTrashNoteIds = {};

  // Các biến phục vụ Lazy Loading (Đã đưa vào trong class)
  int _currentOffset = 0;
  final int _pageLimit = 20;
  bool _hasMoreNotes = true;
  bool _isLoadingMore = false;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreNotes => _hasMoreNotes;

  // Quản lý nhãn toàn cục và bộ lọc
  List<String> _customLabels = [];
  String? _selectedLabel;

  List<Note> get _activeList => _isSearching ? _filtered : _notes;

  // Lọc chính xác cho danh sách Note thường dựa theo Label (nếu có)
  List<Note> get normalNotes {
    final list = _activeList.where((n) => n.status == 'normal').toList();
    if (_selectedLabel != null) {
      return list.where((n) => n.tags.contains(_selectedLabel)).toList();
    }
    return list;
  }

  // Lọc Note ghim riêng để không bị ảnh hưởng bởi phân trang của Note thường
  List<Note> get pinnedNotes {
    final list = _isSearching
        ? _filtered.where((n) => n.status == 'pinned').toList()
        : _pinnedNotesList;
    if (_selectedLabel != null) {
      return list.where((n) => n.tags.contains(_selectedLabel)).toList();
    }
    return list;
  }

  // Getter tổng hợp để giữ tương thích với các view cũ nếu cần
  List<Note> get notes {
    if (_isSearching) return _filtered;
    return [..._pinnedNotesList, ..._notes];
  }

  List<Note> get trashNotes  => _trashNotes;
  bool get isLoading => _isLoading;
  bool get isSearching  => _isSearching;
  Set<String> get selectedNoteIds => _selectedNoteIds;
  bool get isSelectionMode => _selectedNoteIds.isNotEmpty;
  Set<String> get selectedTrashNoteIds => _selectedTrashNoteIds;
  bool get isTrashSelectionMode => _selectedTrashNoteIds.isNotEmpty;

  // Archived
  List<Note> _archivedNotes = [];
  final Set<String> _selectedArchiveNoteIds = {};
  List<Note> get archivedNotes => _archivedNotes;
  Set<String> get selectedArchiveNoteIds => _selectedArchiveNoteIds;
  bool get isArchiveSelectionMode => _selectedArchiveNoteIds.isNotEmpty;

  String? get selectedLabel => _selectedLabel;

  NoteProvider(this._repository);

  List<String> get allLabels {
    final Set<String> labelSet = {};
    for (var note in [..._notes, ..._pinnedNotesList]) {
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

  final CloudinaryService _cloudinaryService = CloudinaryService();



  void selectLabel(String? label) {
    _selectedLabel = label;
    notifyListeners();
  }

  // ── LAZY LOADING & REFRESH LOGIC ──

  // Khởi chạy hoặc làm mới lại từ đầu (Trang 1)
  Future<void> refreshNotes(String userId) async {
    _currentOffset = 0;
    _hasMoreNotes = true;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Tải toàn bộ note ghim (Vì số lượng ghim thường ít, ưu tiên lên đầu)
      if (kIsWeb) {
        final all = await _repository.getNotes(userId);
        _pinnedNotesList = all.where((n) => n.status == 'pinned').toList();
      } else {
        // Nếu repo của bạn chưa tách hàm getPinnedNotes, có thể dùng getNotes lọc status ngầm
        final all = await _repository.getNotes(userId);
        _pinnedNotesList = all.where((n) => n.status == 'pinned').toList();
      }

      // 2. Tải trang đầu tiên của các Note thường
      final fetchedNotes = await _repository.getNotes(userId, limit: _pageLimit, offset: _currentOffset);

      // Lọc bỏ note pinned nếu repo trả về chung, tránh trùng lặp hiển thị
      _notes = fetchedNotes.where((n) => n.status != 'pinned').toList();

      if (fetchedNotes.length < _pageLimit) {
        _hasMoreNotes = false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cuộn xuống đáy -> Tải thêm trang tiếp theo
  Future<void> fetchMoreNotes(String userId) async {
    if (_isLoadingMore || !_hasMoreNotes || _isSearching) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentOffset += _pageLimit;
      final moreNotes = await _repository.getNotes(userId, limit: _pageLimit, offset: _currentOffset);

      if (moreNotes.isEmpty) {
        _hasMoreNotes = false;
      } else {
        final onlyNormalMore = moreNotes.where((n) => n.status != 'pinned').toList();
        _notes.addAll(onlyNormalMore);

        if (moreNotes.length < _pageLimit) {
          _hasMoreNotes = false;
        }
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Hàm fetchNotes cũ được chuyển hướng gọi qua refreshNotes để đảm bảo không lỗi giao diện
  Future<void> fetchNotes(String userId) async {
    await refreshNotes(userId);
  }

  // ── CÁC LOGIC THAO TÁC NOTE ──

  void addLabel(String labelName) {
    final trimmed = labelName.trim();
    if (trimmed.isNotEmpty && !allLabels.contains(trimmed)) {
      _customLabels.add(trimmed);
      notifyListeners();
    }
  }

  Future<void> addLabelToSelectedNotes(String labelName) async {
    final idsToLabel = _selectedNoteIds.toList();
    clearSelection();

    for (final id in idsToLabel) {
      int index = _notes.indexWhere((n) => n.id == id);
      bool isPinned = false;
      if (index == -1) {
        index = _pinnedNotesList.indexWhere((n) => n.id == id);
        isPinned = true;
      }

      if (index != -1) {
        final targetList = isPinned ? _pinnedNotesList : _notes;
        final note = targetList[index];
        if (!note.tags.contains(labelName)) {
          final updatedTags = List<String>.from(note.tags)..add(labelName);
          targetList[index] = note.copyWith(tags: updatedTags, isSynced: false);
          await _repository.saveNote(targetList[index]);
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

    for (int i = 0; i < _pinnedNotesList.length; i++) {
      if (_pinnedNotesList[i].tags.contains(oldName)) {
        final updatedTags = _pinnedNotesList[i].tags.map((t) => t == oldName ? trimmedNew : t).toList();
        _pinnedNotesList[i] = _pinnedNotesList[i].copyWith(tags: updatedTags, isSynced: false);
        await _repository.saveNote(_pinnedNotesList[i]);
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

    for (int i = 0; i < _pinnedNotesList.length; i++) {
      if (_pinnedNotesList[i].tags.contains(labelName)) {
        final updatedTags = _pinnedNotesList[i].tags.where((t) => t != labelName).toList();
        _pinnedNotesList[i] = _pinnedNotesList[i].copyWith(tags: updatedTags, isSynced: false);
        await _repository.saveNote(_pinnedNotesList[i]);
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
      Note? note;
      try {
        note = _activeList.firstWhere((n) => n.id == id);
      } catch (_) {
        note = _pinnedNotesList.firstWhere((n) => n.id == id);
      }
      await togglePin(note);
    }
  }

  Future<void> addNote(Note note) async {
    if (note.status == 'pinned') {
      _pinnedNotesList.insert(0, note);
    } else {
      _notes.insert(0, note);
    }
    notifyListeners();
    await _repository.saveNote(note);
  }

  Future<void> updateNote(Note note) async {
    // Biến cờ hiệu kiểm tra xem phần tử đã được xử lý dịch chuyển hay chưa
    bool isHandled = false;

    // KỊCH BẢN 1: Tìm kiếm ghi chú trong danh sách thường (_notes)
    int indexInNormal = _notes.indexWhere((n) => n.id == note.id);
    if (indexInNormal != -1) {
      if (note.status == 'pinned') {
        // Nếu ghi chú được nâng cấp lên Ghim -> Xóa khỏi danh sách thường, đẩy lên đầu danh sách ghim
        _notes.removeAt(indexInNormal);
        _pinnedNotesList.insert(0, note);
      } else if (note.status == 'trash' || note.status == 'archived') {
        // Nếu ghi chú bị chuyển vào thùng rác/kho lưu trữ -> Xóa hẳn khỏi màn hình chính
        _notes.removeAt(indexInNormal);
      } else {
        // Cập nhật nội dung văn bản thông thường tại chỗ
        _notes[indexInNormal] = note;
      }
      isHandled = true;
    }

    // KỊCH BẢN 2: Nếu chưa xử lý, tìm kiếm tiếp trong danh sách ghim (_pinnedNotesList)
    if (!isHandled) {
      int indexInPinned = _pinnedNotesList.indexWhere((n) => n.id == note.id);
      if (indexInPinned != -1) {
        if (note.status != 'pinned' && note.status == 'normal') {
          // 🌟 VÁ LỖI CHÍ MẠNG: Hạ cấp bỏ ghim -> Xóa khỏi danh sách ghim, trả về đầu danh sách thường
          _pinnedNotesList.removeAt(indexInPinned);
          _notes.insert(0, note);
        } else if (note.status == 'trash' || note.status == 'archived') {
          // Bỏ ghim và đẩy thẳng vào thùng rác/kho lưu trữ -> Xóa khỏi danh sách ghim
          _pinnedNotesList.removeAt(indexInPinned);
        } else {
          // Cập nhật nội dung văn bản ghi chú ghim tại chỗ
          _pinnedNotesList[indexInPinned] = note;
        }
        isHandled = true;
      }
    }

    // KỊCH BẢN 3: Trường hợp Note từ màn hình Archive/Trash được khôi phục trực tiếp về Home
    if (!isHandled && (note.status == 'normal' || note.status == 'pinned')) {
      if (note.status == 'pinned') {
        _pinnedNotesList.insert(0, note);
      } else {
        _notes.insert(0, note);
      }
    }

    // 🌟 TỐI ƯU HIỆU NĂNG CHÍ MẠNG: Phát tín hiệu cập nhật UI lập tức từ RAM tạm
    notifyListeners();

    // Đẩy tác vụ ghi dữ liệu xuống SQLite/Cloud chạy ngầm bất đồng bộ (Background worker style)
    // Loại bỏ từ khóa 'await' tại đây để giải phóng hoàn toàn CPU, giúp hiệu ứng đóng mở Note mượt mà 60 FPS
    _repository.saveNote(note).catchError((error) {
      developer.log("Lỗi ghi dữ liệu ngầm tại NoteProvider: $error", name: 'app.provider.note');
    });
  }

  Future<void> deleteNote(String id) async {
    int index = _notes.indexWhere((note) => note.id == id);
    if (index != -1) {
      final trashedNote = _notes[index].copyWith(status: 'trash', isSynced: false, updatedAt: DateTime.now());
      _notes.removeAt(index);
      _trashNotes.insert(0, trashedNote);
      notifyListeners();
      await _repository.saveNote(trashedNote);
      return;
    }

    index = _pinnedNotesList.indexWhere((note) => note.id == id);
    if (index != -1) {
      final trashedNote = _pinnedNotesList[index].copyWith(status: 'trash', isSynced: false, updatedAt: DateTime.now());
      _pinnedNotesList.removeAt(index);
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
        // Thay vì gọi repo trực tiếp, gọi qua hàm vừa sửa để xóa luôn file cloud của note quá hạn
        await deleteNoteForever(note.id);
      } else {
        _trashNotes.add(note);
      }
    }
    notifyListeners();
  }

  Future<void> deleteNoteForever(String id) async {
    try {
      // 1. Tìm thông tin ghi chú trong danh sách Thùng rác để lấy danh sách URL đính kèm
      final noteToDelete = _trashNotes.firstWhere(
            (n) => n.id == id,
        orElse: () => _notes.firstWhere((n) => n.id == id), // Phòng hờ xóa trực tiếp
      );

      // 2. Trích xuất danh sách link ảnh và âm thanh đính kèm
      final imageUrls = List<String>.from(noteToDelete.imageUrls);
      final audioUrls = List<String>.from(noteToDelete.audioUrls);

      // 3. Tiến hành xóa bất đồng bộ tất cả hình ảnh đính kèm trên Cloudinary
      for (String url in imageUrls) {
        if (url.trim().isNotEmpty) {
          await _cloudinaryService.deleteFile(url, resourceType: 'image');
        }
      }

      // 4. Tiến hành xóa bất đồng bộ tất cả tệp âm thanh trên Cloudinary (quản lý qua tag 'video')
      for (String url in audioUrls) {
        if (url.trim().isNotEmpty) {
          await _cloudinaryService.deleteFile(url, resourceType: 'video');
        }
      }
    } catch (e) {
      debugPrint("Không tìm thấy note hoặc lỗi khi dọn dẹp dữ liệu Cloud: $e");
    }

    // 5. Sau khi dọn sạch Cloud, tiến hành xóa bản ghi dưới database cục bộ và máy chủ
    _trashNotes.removeWhere((n) => n.id == id);
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
    await _repository.deleteNoteForever(id);
  }

  Future<void> restoreNote(String id) async {
    final index = _trashNotes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final restoredNote = _trashNotes[index].copyWith(status: 'normal', isSynced: false, updatedAt: DateTime.now());
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

    // Gọi tuần tự giải thuật dọn dẹp đồng bộ an toàn dữ liệu
    for (final id in idsToDelete) {
      await deleteNoteForever(id);
    }
  }

  Future<void> togglePin(Note note) async {
    final isPinnedNow = note.status == 'pinned';
    final updatedNote = note.copyWith(
      status: isPinnedNow ? 'normal' : 'pinned',
    );

    if (isPinnedNow) {
      _pinnedNotesList.removeWhere((n) => n.id == note.id);
      _notes.insert(0, updatedNote);
    } else {
      _notes.removeWhere((n) => n.id == note.id);
      _pinnedNotesList.insert(0, updatedNote);
    }
    notifyListeners();
    await _repository.saveNote(updatedNote);
  }

  Future<void> fetchArchivedNotes(String userId) async {
    _archivedNotes = await _repository.getArchivedNotes(userId);
    notifyListeners();
  }

  Future<void> archiveNote(String id) async {
    int index = _notes.indexWhere((n) => n.id == id);
    List<Note>? targetSource = index != -1 ? _notes : null;

    if (index == -1) {
      index = _pinnedNotesList.indexWhere((n) => n.id == id);
      if (index != -1) targetSource = _pinnedNotesList;
    }

    if (index != -1 && targetSource != null) {
      final archivedNote = targetSource[index].copyWith(status: 'archived', isSynced: false, updatedAt: DateTime.now());
      targetSource.removeAt(index);
      _archivedNotes.insert(0, archivedNote);
      notifyListeners();
      await _repository.saveNote(archivedNote);
    }
  }

  Future<void> unarchiveNote(String id) async {
    final index = _archivedNotes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final restoredNote = _archivedNotes[index].copyWith(status: 'normal', isSynced: false, updatedAt: DateTime.now());
      _archivedNotes.removeAt(index);
      _notes.insert(0, restoredNote);
      notifyListeners();
      await _repository.saveNote(restoredNote);
    }
  }

  Future<void> moveArchivedNoteToTrash(String id) async {
    final index = _archivedNotes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final trashedNote = _archivedNotes[index].copyWith(status: 'trash', isSynced: false, updatedAt: DateTime.now());
      _archivedNotes.removeAt(index);
      _trashNotes.insert(0, trashedNote);
      notifyListeners();
      await _repository.saveNote(trashedNote);
    }
  }

  void toggleArchiveSelection(String id) {
    if (_selectedArchiveNoteIds.contains(id)) {
      _selectedArchiveNoteIds.remove(id);
    } else {
      _selectedArchiveNoteIds.add(id);
    }
    notifyListeners();
  }

  Future<void> archiveSelectedNotes() async {
    final idsToArchive = _selectedNoteIds.toList();
    clearSelection();

    for (final id in idsToArchive) {
      int index = _notes.indexWhere((n) => n.id == id);
      List<Note>? targetSource = index != -1 ? _notes : null;

      if (index == -1) {
        index = _pinnedNotesList.indexWhere((n) => n.id == id);
        if (index != -1) targetSource = _pinnedNotesList;
      }

      if (index != -1 && targetSource != null) {
        final archivedNote = targetSource[index].copyWith(status: 'archived', isSynced: false, updatedAt: DateTime.now());
        targetSource.removeAt(index);
        _archivedNotes.insert(0, archivedNote);
        await _repository.saveNote(archivedNote);
      }
    }
    notifyListeners();
  }

  void clearArchiveSelection() {
    _selectedArchiveNoteIds.clear();
    notifyListeners();
  }

  Future<void> unarchiveSelectedNotes() async {
    final ids = _selectedArchiveNoteIds.toList();
    clearArchiveSelection();
    for (final id in ids) {
      await unarchiveNote(id);
    }
  }

  Future<void> deleteSelectedArchiveNotes() async {
    final ids = _selectedArchiveNoteIds.toList();
    clearArchiveSelection();
    for (final id in ids) {
      await moveArchivedNoteToTrash(id);
    }
  }

  void search(String query, String userId) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _isSearching = false;
      _filtered = [];
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
    _filtered = [];
    notifyListeners();
  }

  void clearNotes() {
    _notes = [];
    _filtered = [];
    _trashNotes = [];
    _pinnedNotesList = [];
    _customLabels = [];
    _selectedLabel = null;
    _selectedNoteIds.clear();
    _selectedTrashNoteIds.clear();
    _isSearching = false;
    _archivedNotes = [];
    _selectedArchiveNoteIds.clear();

    // Reset chính xác biến lazy load khi clear state
    _currentOffset = 0;
    _hasMoreNotes = true;
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> clearLocalData(String userId) async {
    await _repository.clearLocalData(userId);
  }
}