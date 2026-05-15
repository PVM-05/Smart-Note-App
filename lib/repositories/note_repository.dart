import 'package:flutter/cupertino.dart';

import '../models/note_model.dart';
import '../services/firestore_note_service.dart';
import '../services/local_note_service.dart';
import '../services/sync_service.dart';

abstract class NoteRepository {
  Future<List<Note>> getNotes(String userId);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);
  Future<List<Note>> getUnsyncedNotes(String userId);
}

class NoteRepositoryImpl implements NoteRepository {
  final LocalNoteService _localService = LocalNoteService();
  final SyncService _syncService = SyncService();
  final FirestoreNoteService _firestoreService = FirestoreNoteService();

  @override
  Future<List<Note>> getNotes(String userId) async {
    final localNotes = await _localService.getAllNotes(userId);

    // Nếu local rỗng (đăng nhập lần đầu / thiết bị mới)
    // → Pull từ Firestore về trước, sau đó mới trả data
    if (localNotes.isEmpty) {
      await _syncService.pullFromCloud();
      return await _localService.getAllNotes(userId);
    }

    // Nếu đã có data local → trả ngay, sync conflict ngầm
    _syncService.syncWithConflictResolution();
    return localNotes;
  }

  @override
  Future<void> saveNote(Note note) async {
    // 1. QUAN TRỌNG: Luôn ép trạng thái isSynced = false trước khi lưu
    // Bất kể là tạo mới hay cập nhật, cứ có thay đổi là phải đánh dấu chưa đồng bộ.
    final noteToSave = note.copyWith(isSynced: false);

    // 2. Lưu local trước (offline-first) - dùng insertNote với ConflictAlgorithm.replace (Upsert)
    await _localService.insertNote(noteToSave);

    // 3. Trigger sync ngay (background)
    _syncService.syncNow();
  }

  @override
  Future<void> deleteNote(String id) async {
    await _localService.deleteNote(id);
    try {
      await _firestoreService.deleteNote(id);
    } catch (e) {
      // Offline → bỏ qua, note đã xóa local rồi
      debugPrint('⚠️ deleteNote cloud failed (offline?): $e');
    }
  }

  @override
  Future<List<Note>> getUnsyncedNotes(String userId) async {
    return await _localService.getUnsyncedNotes(userId: userId);
  }
}
