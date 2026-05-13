import '../models/note_model.dart';
import '../services/local_note_service.dart';
import '../services/sync_service.dart';

abstract class NoteRepository {
  Future<List<Note>> getNotes(String userId);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);
  Future<List<Note>> getUnsyncedNotes();
}

class NoteRepositoryImpl implements NoteRepository {
  final LocalNoteService _localService = LocalNoteService();
  final SyncService _syncService = SyncService();

  @override
  Future<List<Note>> getNotes(String userId) async {
    final localNotes = await _localService.getAllNotes();

    // Nếu local rỗng (đăng nhập lần đầu / thiết bị mới)
    // → Pull từ Firestore về trước, sau đó mới trả data
    if (localNotes.isEmpty) {
      await _syncService.pullFromCloud();
      return await _localService.getAllNotes();
    }

    // Nếu đã có data local → trả ngay, sync conflict ngầm
    _syncService.syncWithConflictResolution();
    return localNotes;
  }

  @override
  Future<void> saveNote(Note note) async {
    // 1. Lưu local trước (offline-first)
    await _localService.insertNote(note);
    
    // 2. Trigger sync ngay (background)
    // Lưu ý: SyncService hiện tại đồng bộ tất cả các bản ghi chưa sync
    _syncService.syncNow();
  }

  @override
  Future<void> deleteNote(String id) async {
    await _localService.deleteNote(id);
    _syncService.syncNow(); // Sync delete state
  }

  @override
  Future<List<Note>> getUnsyncedNotes() async {
    return await _localService.getUnsyncedNotes();
  }
}
