// lib/providers/note_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note_model.dart';
import '../repositories/note_repository.dart';
import '../services/cloudinary_service.dart';
import '../services/biometric_service.dart';
import '../core/app_strings.dart';
import '../services/reminder_service.dart';
import 'package:uuid/uuid.dart';

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
  String? _userId;
  List<String> _customLabels = [];
  String? _selectedLabel;
  bool _showOnlyReminders = false;

  bool get showOnlyReminders => _showOnlyReminders;

  void setShowOnlyReminders(bool val) {
    _showOnlyReminders = val;
    if (val) {
      _selectedLabel = null; // Tắt lọc theo nhãn khi bật lọc nhắc nhở
    }
    notifyListeners();
  }

  List<Note> get _activeList => _isSearching ? _filtered : _notes;

  // Lọc chính xác cho danh sách Note thường dựa theo Label và Nhắc nhở (nếu có)
  List<Note> get normalNotes {
    var list = _activeList.where((n) => n.status == 'normal').toList();
    if (_selectedLabel != null) {
      list = list.where((n) => n.tags.contains(_selectedLabel)).toList();
    }
    if (_showOnlyReminders) {
      list = list.where((n) => n.reminder != null).toList();
    }
    return list;
  }

  // Lọc Note ghim riêng dựa theo Label và Nhắc nhở (nếu có)
  List<Note> get pinnedNotes {
    var list = _isSearching
        ? _filtered.where((n) => n.status == 'pinned').toList()
        : _pinnedNotesList;
    if (_selectedLabel != null) {
      list = list.where((n) => n.tags.contains(_selectedLabel)).toList();
    }
    if (_showOnlyReminders) {
      list = list.where((n) => n.reminder != null).toList();
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

  // Cache labels — chỉ tính lại khi dữ liệu thay đổi
  List<String>? _cachedLabels;

  List<String> get allLabels {
    if (_cachedLabels != null) return _cachedLabels!;
    final Set<String> labelSet = {};
    for (var note in _notes) {
      labelSet.addAll(note.tags);
    }
    for (var note in _pinnedNotesList) {
      labelSet.addAll(note.tags);
    }
    for (var note in _trashNotes) {
      labelSet.addAll(note.tags);
    }
    labelSet.addAll(_customLabels);
    final list = labelSet.toList();
    list.sort();
    _cachedLabels = list;
    return list;
  }

  void _invalidateLabelCache() {
    _cachedLabels = null;
  }

  final CloudinaryService _cloudinaryService = CloudinaryService();
  final BiometricService _biometricService = BiometricService();



  void selectLabel(String? label) {
    _selectedLabel = label;
    _showOnlyReminders = false;
    notifyListeners();
  }

  // ── LAZY LOADING & REFRESH LOGIC ──

  // Khởi chạy hoặc làm mới lại từ đầu (Trang 1)
  Future<void> refreshNotes(String userId) async {
    _userId = userId;
    _currentOffset = 0;
    _hasMoreNotes = true;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Tải riêng các note ghim bằng query chuyên biệt (không tải toàn bộ bảng)
      _pinnedNotesList = await _repository.getPinnedNotes(userId);

      // 2. Tải trang đầu tiên của các Note thường
      final fetchedNotes = await _repository.getNotes(userId, limit: _pageLimit, offset: _currentOffset);

      // Lọc bỏ note pinned nếu repo trả về chung, tránh trùng lặp hiển thị
      _notes = fetchedNotes.where((n) => n.status != 'pinned').toList();

      if (fetchedNotes.length < _pageLimit) {
        _hasMoreNotes = false;
      }
      
      // Tải nhãn dán tùy chọn từ cơ sở dữ liệu
      _customLabels = await _repository.getCustomLabels(userId);
      
      _invalidateLabelCache();
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

  void addLabel(String labelName) async {
    final trimmed = labelName.trim();
    if (trimmed.isNotEmpty && !allLabels.contains(trimmed)) {
      _customLabels.add(trimmed);
      _invalidateLabelCache();
      notifyListeners();
      if (_userId != null) {
        await _repository.saveCustomLabels(_userId!, _customLabels);
      }
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

  Future<void> updateTagsForSelectedNotes(List<String> tags) async {
    final idsToLabel = _selectedNoteIds.toList();

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
        targetList[index] = note.copyWith(tags: tags, isSynced: false);
        await _repository.saveNote(targetList[index]);
      }
    }
    _invalidateLabelCache();
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
    _invalidateLabelCache();
    notifyListeners();
    if (_userId != null) {
      await _repository.saveCustomLabels(_userId!, _customLabels);
    }
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
    _invalidateLabelCache();
    notifyListeners();
    if (_userId != null) {
      await _repository.saveCustomLabels(_userId!, _customLabels);
    }
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
    _selectedNoteIds.clear();
    // Gom tất cả thao tác rồi chỉ notifyListeners 1 lần
    for (final id in idsToDelete) {
      int index = _notes.indexWhere((note) => note.id == id);
      if (index != -1) {
        final trashedNote = _notes[index].copyWith(status: 'trash', isSynced: false, updatedAt: DateTime.now());
        _notes.removeAt(index);
        _trashNotes.insert(0, trashedNote);
        await _repository.saveNote(trashedNote);
        continue;
      }
      index = _pinnedNotesList.indexWhere((note) => note.id == id);
      if (index != -1) {
        final trashedNote = _pinnedNotesList[index].copyWith(status: 'trash', isSynced: false, updatedAt: DateTime.now());
        _pinnedNotesList.removeAt(index);
        _trashNotes.insert(0, trashedNote);
        await _repository.saveNote(trashedNote);
      }
    }
    _invalidateLabelCache();
    notifyListeners();
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
    // Lên lịch thông báo cục bộ trước để hoạt động offline tức thì
    await _scheduleReminderIfNeeded(note);
    await _repository.saveNote(note);
  }

  Future<void> updateNote(Note note) async {
    int index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      if (note.status == 'pinned') {
        _notes.removeAt(index);
        _pinnedNotesList.insert(0, note);
      } else {
        _notes[index] = note;
      }
      notifyListeners();
      // Lên lịch thông báo cục bộ trước để hoạt động offline tức thì
      await _scheduleReminderIfNeeded(note);
      await _repository.saveNote(note);
      return;
    }

    index = _pinnedNotesList.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      if (note.status != 'pinned') {
        _pinnedNotesList.removeAt(index);
        _notes.insert(0, note);
      } else {
        _pinnedNotesList[index] = note;
      }
      notifyListeners();
      // Lên lịch thông báo cục bộ trước để hoạt động offline tức thì
      await _scheduleReminderIfNeeded(note);
      await _repository.saveNote(note);
    }
  }

  Future<void> _scheduleReminderIfNeeded(Note note) async {
    if (note.status == 'trash') {
      await ReminderService().cancelReminder(note.id);
      return;
    }
    if (note.reminder != null) {
      if (note.reminder!.isAfter(DateTime.now())) {
        String body;
        String? bigText;
        if (note.isChecklist) {
          final pendingCount = note.pendingChecklistCount;
          body = "Bạn có $pendingCount công việc chưa hoàn thành.";
          bigText = "$body\n${note.checklistPlainText}";
        } else {
          // Giải mã văn bản thuần sạch sẽ từ Quill Delta JSON để tránh lỗi định dạng
          final plainText = note.plainTextContent;
          body = plainText.length > 100
              ? '${plainText.substring(0, 97)}...'
              : plainText;
          if (body.isEmpty) {
            body = 'Bạn có một nhắc nhở ghi chú!';
          }
        }
        await ReminderService().scheduleReminder(
          id: note.id,
          title: note.title.isNotEmpty ? note.title : 'Nhắc nhở ghi chú',
          body: body,
          bigText: bigText,
          scheduledDate: note.reminder!,
        );
      } else {
        // Đã trôi qua, không làm gì
      }
    } else {
      await ReminderService().cancelReminder(note.id);
    }
  }

  Future<void> deleteNote(String id) async {
    // Hủy nhắc nhở khi đưa ghi chú vào thùng rác
    await ReminderService().cancelReminder(id);

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
    _userId = userId;
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
    // Hủy nhắc nhở khi xóa vĩnh viễn ghi chú
    await ReminderService().cancelReminder(id);

    try {
      // 1. Tìm note trong tất cả các list — không throw nếu không tìm thấy
      Note? noteToDelete =
          _trashNotes.cast<Note?>().firstWhere((n) => n?.id == id, orElse: () => null) ??
          _notes.cast<Note?>().firstWhere((n) => n?.id == id, orElse: () => null) ??
          _pinnedNotesList.cast<Note?>().firstWhere((n) => n?.id == id, orElse: () => null) ??
          _archivedNotes.cast<Note?>().firstWhere((n) => n?.id == id, orElse: () => null);

      if (noteToDelete != null) {
        // 2. Xóa tất cả hình ảnh đính kèm trên Cloudinary
        for (final url in noteToDelete.imageUrls) {
          if (url.trim().isNotEmpty) {
            await _cloudinaryService.deleteFile(url, resourceType: 'image');
          }
        }

        // 3. Xóa tất cả tệp âm thanh trên Cloudinary
        for (final url in noteToDelete.audioUrls) {
          if (url.trim().isNotEmpty) {
            await _cloudinaryService.deleteFile(url, resourceType: 'video');
          }
        }
      } else {
        debugPrint('⚠️ deleteNoteForever: Không tìm thấy note $id trong memory — bỏ qua dọn Cloud, tiếp tục xóa DB.');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi dọn dẹp dữ liệu Cloud cho note $id: $e');
    }

    // 4. Xóa khỏi tất cả danh sách in-memory rồi xóa DB
    _trashNotes.removeWhere((n) => n.id == id);
    _notes.removeWhere((n) => n.id == id);
    _pinnedNotesList.removeWhere((n) => n.id == id);
    _archivedNotes.removeWhere((n) => n.id == id);
    notifyListeners();
    await _repository.deleteNoteForever(id);
  }


  Future<void> restoreNote(String id) async {
    final index = _trashNotes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _trashNotes[index];
      final restoredNote = note.copyWith(
        status: 'normal',
        isSynced: false,
        updatedAt: DateTime.now(),
      );
      _trashNotes.removeAt(index);
      _notes.insert(0, restoredNote);
      notifyListeners();
      await _repository.saveNote(restoredNote);
      // Lên lịch lại nhắc nhở nếu note có reminder trong tương lai
      await _scheduleReminderIfNeeded(restoredNote);
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
    final ids = _selectedTrashNoteIds.toList();
    clearTrashSelection();
    for (final id in ids) {
      await restoreNote(id);
    }
  }

  Future<void> deleteForeverSelectedTrashNotes() async {
    final ids = _selectedTrashNoteIds.toList();
    clearTrashSelection();
    for (final id in ids) {
      await deleteNoteForever(id);
    }
  }

  Future<void> emptyTrash() async {
    final ids = _trashNotes.map((n) => n.id).toList();
    clearTrashSelection();
    for (final id in ids) {
      await deleteNoteForever(id);
    }
  }

  Future<void> togglePin(Note note) async {
    final isPinnedNow = note.status == 'pinned';
    final updatedNote = note.copyWith(
      status: isPinnedNow ? 'normal' : 'pinned',
      isSynced: false,
      updatedAt: DateTime.now(),
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
    _userId = userId;
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
      // Hủy nhắc nhở khi lưu trữ ghi chú
      await ReminderService().cancelReminder(id);
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
      // Lên lịch lại nhắc nhở nếu note có reminder trong tương lai
      await _scheduleReminderIfNeeded(restoredNote);
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
      // Hủy nhắc nhở khi chuyển note vào thùng rác
      await ReminderService().cancelReminder(id);
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

  // ── KÉO THẢ SẮP XẾP GHI CHÚ ──
  Future<void> reorderNotes(int oldIndex, int newIndex, {bool isPinned = false}) async {
    final list = isPinned ? _pinnedNotesList : _notes;
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex >= list.length) return;
    if (oldIndex == newIndex) return;

    // 1. Di chuyển item trong bộ nhớ
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // 2. Gán lại sortOrder tuần tự cho toàn bộ danh sách
    final updatedNotes = <Note>[];
    for (int i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i) {
        list[i] = list[i].copyWith(sortOrder: i, isSynced: false);
        updatedNotes.add(list[i]);
      }
    }

    notifyListeners();

    // 3. Batch update vào SQLite + sync Cloud
    if (updatedNotes.isNotEmpty) {
      await _repository.updateNotesSortOrder(updatedNotes);
    }
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

  Future<bool> toggleLock(String noteId) async {
    final isBiometricAvailable = await _biometricService.isAvailable();
    if (!isBiometricAvailable) {
      throw Exception(AppStrings.biometricNotAvailable);
    }

    final isEnrolled = await _biometricService.isEnrolled();
    if (!isEnrolled) {
      throw Exception(AppStrings.biometricNotEnrolled);
    }

    try {
      final authenticated = await _biometricService.authenticate(
        reason: AppStrings.biometricPromptReason,
      );
      if (authenticated) {
        int index = _notes.indexWhere((n) => n.id == noteId);
        bool isPinned = false;
        if (index == -1) {
          index = _pinnedNotesList.indexWhere((n) => n.id == noteId);
          isPinned = true;
        }

        if (index != -1) {
          final targetList = isPinned ? _pinnedNotesList : _notes;
          final note = targetList[index];
          final updatedNote = note.copyWith(
            isLocked: !note.isLocked,
            isSynced: false,
          );
          targetList[index] = updatedNote;
          notifyListeners();
          await _repository.saveNote(updatedNote);
          return true;
        }
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearLocalData(String userId) async {
    await _repository.clearLocalData(userId);
  }

  // ── REMINDER METHODS ──

  // Thiết lập nhắc nhở cho ghi chú
  Future<void> setNoteReminder(Note note, DateTime scheduledTime) async {
    // 1. Cập nhật Note model
    final updatedNote = note.copyWith(
      reminder: scheduledTime,
      isSynced: false,
      updatedAt: DateTime.now(),
    );

    // 2. Cập nhật danh sách trong Provider
    _updateNoteInMemory(updatedNote);

    // 3. Lên lịch notification trước để hoạt động offline tức thì
    String body;
    String? bigText;
    if (updatedNote.isChecklist) {
      final pendingCount = updatedNote.pendingChecklistCount;
      body = "Bạn có $pendingCount công việc chưa hoàn thành.";
      bigText = "$body\n${updatedNote.checklistPlainText}";
    } else {
      // Giải mã văn bản thuần sạch sẽ từ Quill Delta JSON để tránh lỗi định dạng
      final plainText = updatedNote.plainTextContent;
      body = plainText.length > 100
          ? '${plainText.substring(0, 97)}...'
          : plainText;
      if (body.isEmpty) {
        body = 'Bạn có một nhắc nhở ghi chú!';
      }
    }

    await ReminderService().scheduleReminder(
      id: updatedNote.id,
      title: updatedNote.title.isNotEmpty ? updatedNote.title : 'Nhắc nhở ghi chú',
      body: body,
      bigText: bigText,
      scheduledDate: scheduledTime,
    );

    notifyListeners();

    // 4. Lưu xuống Database & Cloud sau (bất kể mạng chặn)
    await _repository.saveNote(updatedNote);
  }

  // Hủy nhắc nhở ghi chú
  Future<void> cancelNoteReminder(Note note) async {
    // 1. Cập nhật Note model
    final updatedNote = note.copyWith(
      clearReminder: true,
      isSynced: false,
      updatedAt: DateTime.now(),
    );

    // 2. Cập nhật danh sách trong Provider
    _updateNoteInMemory(updatedNote);

    // 3. Hủy lịch notification trước để hoạt động offline tức thì
    await ReminderService().cancelReminder(updatedNote.id);

    notifyListeners();

    // 4. Lưu xuống Database & Cloud sau (bất kể mạng chặn)
    await _repository.saveNote(updatedNote);
  }

  // Helper cập nhật ghi chú trong in-memory lists
  void _updateNoteInMemory(Note updatedNote) {
    int index = _notes.indexWhere((n) => n.id == updatedNote.id);
    if (index != -1) {
      _notes[index] = updatedNote;
      return;
    }

    index = _pinnedNotesList.indexWhere((n) => n.id == updatedNote.id);
    if (index != -1) {
      _pinnedNotesList[index] = updatedNote;
      return;
    }

    index = _archivedNotes.indexWhere((n) => n.id == updatedNote.id);
    if (index != -1) {
      _archivedNotes[index] = updatedNote;
      return;
    }
  }

  Future<void> duplicateNotes(List<String> ids) async {
    for (final id in ids) {
      Note? foundNote;
      for (final list in [_notes, _pinnedNotesList, _archivedNotes]) {
        final index = list.indexWhere((n) => n.id == id);
        if (index != -1) {
          foundNote = list[index];
          break;
        }
      }

      if (foundNote != null) {
        final newId = const Uuid().v4();
        final duplicate = Note(
          id: newId,
          userId: foundNote.userId,
          title: foundNote.title,
          content: foundNote.content,
          status: foundNote.status,
          isSynced: false,
          isLocked: foundNote.isLocked,
          noteColor: foundNote.noteColor,
          tags: List<String>.from(foundNote.tags),
          imageUrls: List<String>.from(foundNote.imageUrls),
          audioUrls: List<String>.from(foundNote.audioUrls),
          reminder: foundNote.reminder,
          sortOrder: foundNote.sortOrder,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (duplicate.status == 'pinned') {
          _pinnedNotesList.insert(0, duplicate);
        } else if (duplicate.status == 'archived') {
          _archivedNotes.insert(0, duplicate);
        } else {
          _notes.insert(0, duplicate);
        }
        await _repository.saveNote(duplicate);
      }
    }
    notifyListeners();
  }

  Future<void> updateColorForSelectedNotes(String? color) async {
    for (final id in selectedNoteIds) {
      Note? note;
      for (final list in [_notes, _pinnedNotesList]) {
        final index = list.indexWhere((n) => n.id == id);
        if (index != -1) {
          note = list[index];
          break;
        }
      }
      if (note != null) {
        final updatedNote = note.copyWith(noteColor: color, isSynced: false, updatedAt: DateTime.now());
        _updateNoteInMemory(updatedNote);
        await _repository.saveNote(updatedNote);
      }
    }
    notifyListeners();
  }

  Future<void> setReminderForSelectedNotes(DateTime dt) async {
    for (final id in selectedNoteIds) {
      Note? note;
      for (final list in [_notes, _pinnedNotesList]) {
        final index = list.indexWhere((n) => n.id == id);
        if (index != -1) {
          note = list[index];
          break;
        }
      }
      if (note != null) {
        final updatedNote = note.copyWith(reminder: dt, isSynced: false, updatedAt: DateTime.now());
        _updateNoteInMemory(updatedNote);
        await _repository.saveNote(updatedNote);
        await _scheduleReminderIfNeeded(updatedNote);
      }
    }
    notifyListeners();
  }
}