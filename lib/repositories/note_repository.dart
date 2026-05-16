import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/note_model.dart';
import '../services/local_note_service.dart';
import '../services/firestore_note_service.dart';
import '../services/pending_delete_service.dart';

abstract class NoteRepository {
  Future<List<Note>> getNotes(String userId);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);
  Future<List<Note>> getUnsyncedNotes(String userId);
  Future<List<Note>> searchNotes({
    required String userId,
    required String query,
  });
  Future<List<Note>> getTrashNotes(String userId);
  Future<void> clearLocalData(String userId);
}

class NoteRepositoryImpl implements NoteRepository {
  final _localService     = LocalNoteService();
  final _firestoreService = FirestoreNoteService();
  final _pendingDeleteSvc = PendingDeleteService();

  // ── Kiểm tra có thể sync không ──
  Future<bool> _canSync() async {
    if (FirebaseAuth.instance.currentUser == null) return false;
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // ── Lấy danh sách notes ──
  @override
  Future<List<Note>> getNotes(String userId) async {
    final localNotes = await _localService.getAllNotes(userId: userId);

    if (localNotes.isEmpty && await _canSync()) {
      // Lần đầu đăng nhập → pull cloud về
      await _pullFromCloud();
      return await _localService.getAllNotes(userId: userId);
    }

    // Có data local → sync ngầm
    _syncInBackground(userId);
    return localNotes;
  }

  // ── Lưu note — đánh dấu dirty rồi push ngay ──
  @override
  Future<void> saveNote(Note note) async {
    // 1. Luôn mark isSynced=false trước khi lưu
    final dirty = note.copyWith(isSynced: false);
    await _localService.insertNote(dirty);
    log('💾 Saved local: ${note.id}');

    // 2. Push lên cloud ngay nếu có mạng
    if (await _canSync()) {
      try {
        await _firestoreService.saveNote(dirty);
        await _localService.markSynced(note.id);
        log('☁️ Synced to cloud: ${note.id}');
      } catch (e) {
        log('⚠️ Cloud save failed, will retry: $e');
        // Giữ isSynced=false → SyncProvider sẽ retry sau
      }
    } else {
      log('📵 Offline — queued for sync: ${note.id}');
    }
  }

  // ── Xóa note — xóa local ngay, cloud khi có mạng ──
  @override
  Future<void> deleteNote(String id) async {
    await _localService.deleteNote(id);
    log('🗑️ Deleted local: $id');

    if (await _canSync()) {
      try {
        await _firestoreService.deleteNote(id);
        await _pendingDeleteSvc.remove(id);
        log('🗑️ Deleted cloud: $id');
      } catch (e) {
        log('⚠️ Cloud delete failed, queued: $e');
        await _pendingDeleteSvc.add(id);
      }
    } else {
      await _pendingDeleteSvc.add(id);
      log('📋 Delete queued for later: $id');
    }
  }

  // ── Search ──
  @override
  Future<List<Note>> searchNotes({
    required String userId,
    required String query,
  }) async {
    return await _localService.searchNotes(userId: userId, query: query);
  }

  // ── Unsynced ──
  @override
  Future<List<Note>> getUnsyncedNotes(String userId) async {
    return await _localService.getUnsyncedNotes(userId: userId);
  }

  // ── Pull cloud về local ──
  Future<void> _pullFromCloud() async {
    try {
      log('⬇️ Pulling from cloud...');
      final cloudNotes = await _firestoreService.getNotes();
      for (final note in cloudNotes) {
        await _localService.insertNote(note);
      }
      log('✅ Pulled ${cloudNotes.length} notes from cloud');
    } catch (e) {
      log('❌ Pull failed: $e');
    }
  }

  // ── Sync ngầm: push unsynced + xử lý pending deletes ──
  Future<void> _syncInBackground(String userId) async {
    if (!await _canSync()) return;

    try {
      // 1. Pending deletes
      final pendingIds = await _pendingDeleteSvc.getAll();
      for (final id in pendingIds) {
        try {
          await _firestoreService.deleteNote(id);
          await _pendingDeleteSvc.remove(id);
          log('🗑️ Background deleted: $id');
        } catch (_) {}
      }

      // 2. Unsynced notes
      final unsynced = await _localService.getUnsyncedNotes(userId: userId);
      if (unsynced.isEmpty) return;

      log('🔄 Background syncing ${unsynced.length} notes...');
      await _firestoreService.batchSaveNotes(unsynced);
      for (final note in unsynced) {
        await _localService.markSynced(note.id);
      }
      log('✅ Background sync done: ${unsynced.length} notes');
    } catch (e) {
      log('⚠️ Background sync error: $e');
    }
  }

  @override
  Future<List<Note>> getTrashNotes(String userId) async {
    return await _localService.getTrashNotes(userId: userId);
  }

  @override
  Future<void> clearLocalData(String userId) async {
    await _localService.clearUserNotes(userId); // Hàm này bạn đã viết sẵn trong LocalNoteService rồi
  }
}