import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../services/local_note_service.dart';
import '../services/firestore_note_service.dart';
import '../models/sync_status.dart';
import '../services/pending_delete_service.dart';

// lib/repositories/sync_repository.dart
abstract class SyncRepository {
  Stream<SyncStatus> get syncStatusStream;
  Future<void> syncNow(String userId);
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
  Future<void> syncNow(String userId) async {
    if (_syncLock != null && !_syncLock!.isCompleted) {
      await _syncLock!.future;
      return;
    }

    _syncLock = Completer<void>();
    _statusController.add(SyncStatus.syncing);

    try {
      // 1. Xử lý hàng đợi xóa offline
      final pendingIds = await _pendingDeleteSvc.getAll();
      for (final id in pendingIds) {
        await _firestoreService.deleteNote(id);
        await _pendingDeleteSvc.remove(id);
      }

      // 2. Đẩy ghi chú chưa sync lên cloud (Batch Write)
      final unsyncedNotes = await _localService.getUnsyncedNotes(userId: userId);
      if (unsyncedNotes.isNotEmpty) {
        await _firestoreService.batchSaveNotes(unsyncedNotes);
        
        // Tối ưu hóa: Gộp việc cập nhật trạng thái synced trên SQLite vào 1 transaction duy nhất
        final db = await _localService.db;
        await db.transaction((txn) async {
          for (final note in unsyncedNotes) {
            await txn.update(
              'notes',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [note.id],
            );
          }
        });
      }

      // 3. Kéo dữ liệu về phân xử
      await pullFromCloud(userId);

      _statusController.add(SyncStatus.success);
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

    final db = await _localService.db;

    // Tối ưu hóa: Thực hiện tất cả các tác vụ insert/update trong 1 TRANSACTION duy nhất
    await db.transaction((txn) async {
      for (final cloud in cloudNotes) {
        final local = localMap[cloud.id];

        if (local == null) {
          await txn.insert(
            'notes',
            cloud.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          hasNewChanges = true;
        } else if (cloud.updatedAt.isAfter(local.updatedAt)) {
          await txn.update(
            'notes',
            cloud.toMap(),
            where: 'id = ?',
            whereArgs: [cloud.id],
          );
          hasNewChanges = true;
        }
      }
    });

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