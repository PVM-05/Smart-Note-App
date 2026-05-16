import '../models/note_model.dart';
import '../services/local_note_service.dart';
import '../services/sync_service.dart';

abstract class NoteRepository {
  Future<List<Note>> getNotes(String userId);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);
  Future<List<Note>> getUnsyncedNotes(String userId);
}

class NoteRepositoryImpl implements NoteRepository {
  final _localService = LocalNoteService();
  final _syncService  = SyncService();

  @override
  Future<List<Note>> getNotes(String userId) async {
    final localNotes = await _localService.getAllNotes(userId: userId);

    if (localNotes.isEmpty) {
      // Lần đầu đăng nhập / thiết bị mới → pull cloud về trước
      await _syncService.pullFromCloud();
      return await _localService.getAllNotes(userId: userId);
    }

    // Có data local → trả ngay, sync ngầm
    _syncService.syncWithConflictResolution();
    return localNotes;
  }

  @override
  Future<void> saveNote(Note note) async {
    // Luôn đánh dấu chưa sync khi lưu
    final noteToSave = note.copyWith(isSynced: false);
    await _localService.insertNote(noteToSave);
    _syncService.syncNow(); // push lên cloud ngay nếu có mạng
  }

  @override
  Future<void> deleteNote(String id) async {
    // SyncService xử lý cả local lẫn cloud (kể cả offline)
    await _syncService.deleteNote(id);
  }

  @override
  Future<List<Note>> getUnsyncedNotes(String userId) async {
    return await _localService.getUnsyncedNotes(userId: userId);
  }
}