import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/local_note_service.dart';
import '../services/firestore_note_service.dart';
import '../models/sync_status.dart';
import '../models/note_model.dart';
import '../services/pending_delete_service.dart';

// lib/repositories/sync_repository.dart
abstract class SyncRepository {
  Stream<SyncStatus> get syncStatusStream;
  Future<bool> syncNow(String userId);
  Future<bool> pullFromCloud(String userId); // Đổi kiểu trả về thành Future<bool>
  Future<void> deleteNoteWithQueue(String id);
}

class SyncRepositoryImpl implements SyncRepository {
  final LocalNoteService _localService = LocalNoteService();
  final FirestoreNoteService _firestoreService = FirestoreNoteService();
  final PendingDeleteService _pendingDeleteSvc = PendingDeleteService();

  final _statusController = StreamController<SyncStatus>.broadcast();
  Completer<void>? _syncLock;

  @override
  Stream<SyncStatus> get syncStatusStream => _statusController.stream;

  Future<bool> _canSync() async {
    if (FirebaseAuth.instance.currentUser == null) return false;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return false;
    return true;
  }

  @override
  Future<bool> syncNow(String userId) async {
    if (_syncLock != null && !_syncLock!.isCompleted) {
      await _syncLock!.future;
      return false;
    }

    _syncLock = Completer<void>();
    _statusController.add(SyncStatus.syncing);
    bool hasNewChanges = false;

    try {
      // 1. Xử lý hàng đợi xóa offline
      final pendingIds = await _pendingDeleteSvc.getAll();
      for (final id in pendingIds) {
        await _firestoreService.deleteNote(id);
        await _pendingDeleteSvc.remove(id);
      }

      // 2. Phân xử xung đột (Last-Writer-Wins)
      final unsyncedNotes = await _localService.getUnsyncedNotes(userId: userId);
      final cloudNotes = await _firestoreService.getNotes();
      final cloudMap = {for (final n in cloudNotes) n.id: n};

      List<Note> notesToPush = [];
      for (final local in unsyncedNotes) {
        final cloud = cloudMap[local.id];
        // Nếu cloud chưa có note này, hoặc local có cập nhật mới hơn cloud
        if (cloud == null || local.updatedAt.isAfter(cloud.updatedAt)) {
          notesToPush.add(local);
        }
      }

      if (notesToPush.isNotEmpty) {
        await _firestoreService.batchSaveNotes(notesToPush);
        for (final note in notesToPush) {
          await _localService.markSynced(note.id);
        }
      }

      // 3. Kéo dữ liệu về (sử dụng luôn cloudNotes vừa lấy để tối ưu chi phí Firestore)
      final localAllNotes = await _localService.getAbsoluteAllNotes(userId: userId);
      final localAllMap = {for (final n in localAllNotes) n.id: n};

      for (final cloud in cloudNotes) {
        final local = localAllMap[cloud.id];
        if (local == null) {
          await _localService.insertNote(cloud);
          hasNewChanges = true;
        } else if (cloud.updatedAt.isAfter(local.updatedAt)) {
          await _localService.updateNote(cloud);
          hasNewChanges = true;
        }
      }

      _statusController.add(SyncStatus.success);
      return hasNewChanges;
    } catch (e) {
      _statusController.add(SyncStatus.error);
      rethrow;
    } finally {
      _syncLock?.complete();
      _syncLock = null;
    }
  }

  @override
  Future<bool> pullFromCloud(String userId) async {
    bool hasNewChanges = false;
    final cloudNotes = await _firestoreService.getNotes();

    // Sử dụng hàm lấy thô getAbsoluteAllNotes để không bị lọt các note lưu trữ/thùng rác
    final localNotes = await _localService.getAbsoluteAllNotes(userId: userId);
    final localMap = {for (final n in localNotes) n.id: n};

    for (final cloud in cloudNotes) {
      final local = localMap[cloud.id];

      if (local == null) {
        await _localService.insertNote(cloud);
        hasNewChanges = true;
      } else if (cloud.updatedAt.isAfter(local.updatedAt)) {
        await _localService.updateNote(cloud);
        hasNewChanges = true;
      }
    }
    return hasNewChanges; // Trả về true nếu thực sự có ghi chú mới được ghi xuống máy
  }

  @override
  Future<void> deleteNoteWithQueue(String id) async {
    await _localService.deleteNote(id);
    if (await _canSync()) {
      try {
        await _firestoreService.deleteNote(id);
        return;
      } catch (_) {}
    }
    await _pendingDeleteSvc.add(id);
  }
}