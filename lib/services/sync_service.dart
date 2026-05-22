import 'dart:async';
import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_note_service.dart';
import 'firestore_note_service.dart';
import 'pending_delete_service.dart';
import '../models/sync_status.dart';


class SyncService {
  final _localService      = LocalNoteService();
  final _firestoreService  = FirestoreNoteService();
  final _pendingDeleteSvc  = PendingDeleteService();
  final _auth              = FirebaseAuth.instance;

  // Lock thực sự — dùng Completer thay vì check status
  Completer<void>? _syncLock;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  DateTime? lastSyncedAt;
  int pendingCount = 0;

  Function(SyncStatus)? onStatusChanged;

  void _setStatus(SyncStatus s) {
    _status = s;
    onStatusChanged?.call(s);
  }

  Future<bool> _canSync() async {
    if (_auth.currentUser == null) {
      log('⚠️ SyncService: chưa login');
      return false;
    }
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      log('⚠️ SyncService: không có mạng');
      return false;
    }
    return true;
  }

  // ── Sync chính — có lock thực sự ──
  Future<void> syncNow() async {
    // Nếu đang sync → chờ lần trước xong rồi mới chạy
    if (_syncLock != null && !_syncLock!.isCompleted) {
      log('⏳ SyncService: đang chờ lần sync trước hoàn tất...');
      await _syncLock!.future;
      return;
    }

    if (!await _canSync()) return;

    _syncLock = Completer<void>();
    _setStatus(SyncStatus.syncing);

    try {
      final uid = _auth.currentUser!.uid;

      // 1. Xử lý pending deletes trước
      await _processPendingDeletes();

      // 2. Push notes chưa sync
      final unsyncedNotes = await _localService.getUnsyncedNotes(userId: uid);
      pendingCount = unsyncedNotes.length;

      if (unsyncedNotes.isNotEmpty) {
        log('🔄 SyncService: đang sync ${unsyncedNotes.length} notes...');
        await _firestoreService.batchSaveNotes(unsyncedNotes);

        for (final note in unsyncedNotes) {
          await _localService.markSynced(note.id);
        }
        log('✅ SyncService: sync ${unsyncedNotes.length} notes thành công');
      }

      pendingCount = 0;
      lastSyncedAt = DateTime.now();
      _setStatus(SyncStatus.success);

    } catch (e) {
      _setStatus(SyncStatus.error);
      log('❌ SyncService lỗi: $e');
    } finally {
      _syncLock?.complete();
      _syncLock = null;
    }
  }

  // ── Xử lý hàng đợi xóa offline ──
  Future<void> _processPendingDeletes() async {
    final pendingIds = await _pendingDeleteSvc.getAll();
    if (pendingIds.isEmpty) return;

    log('🗑️ SyncService: xử lý ${pendingIds.length} pending deletes...');
    for (final id in pendingIds) {
      try {
        await _firestoreService.deleteNote(id);
        await _pendingDeleteSvc.remove(id);
        log('🗑️ Đã xóa trên cloud: $id');
      } catch (e) {
        log('⚠️ Chưa xóa được $id: $e');
        // Giữ lại trong queue, thử lại lần sau
      }
    }
  }

  // ── Xóa note: local ngay, cloud khi có mạng ──
  Future<void> deleteNote(String id) async {
    // Xóa local trước
    await _localService.deleteNote(id);

    // Thử xóa cloud ngay
    if (await _canSync()) {
      try {
        await _firestoreService.deleteNote(id);
        log('🗑️ Đã xóa trên cloud ngay: $id');
        return;
      } catch (e) {
        log('⚠️ Xóa cloud thất bại, thêm vào queue: $e');
      }
    }

    // Offline hoặc lỗi → thêm vào pending queue
    await _pendingDeleteSvc.add(id);
    log('📋 Thêm vào pending deletes: $id');
  }

  // ── Pull từ cloud về local ──
  Future<void> pullFromCloud() async {
    if (!await _canSync()) return;
    try {
      log('⬇️ SyncService: đang tải data từ cloud...');
      final cloudNotes = await _firestoreService.getNotes();
      for (final note in cloudNotes) {
        await _localService.insertNote(note);
      }
      log('✅ SyncService: đã tải ${cloudNotes.length} notes từ cloud');
    } catch (e) {
      log('❌ SyncService pullFromCloud lỗi: $e');
    }
  }

  // ── Conflict resolution ──
  Future<void> syncWithConflictResolution() async {
    if (!await _canSync()) return;
    if (_syncLock != null && !_syncLock!.isCompleted) return;

    _syncLock = Completer<void>();
    _setStatus(SyncStatus.syncing);

    try {
      final uid = _auth.currentUser!.uid;

      // Xử lý pending deletes trước
      await _processPendingDeletes();

      final localNotes = await _localService.getAllNotes(userId: uid);
      final cloudNotes = await _firestoreService.getNotes();
      final cloudMap   = {for (final n in cloudNotes) n.id: n};

      for (final local in localNotes) {
        final cloud = cloudMap[local.id];

        if (cloud == null) {
          await _firestoreService.saveNote(local);
          await _localService.markSynced(local.id);

        } else if (local.updatedAt.isAfter(cloud.updatedAt)) {
          await _firestoreService.saveNote(local);
          await _localService.markSynced(local.id);
          log('🔀 Conflict: giữ bản local (${local.id})');

        } else if (cloud.updatedAt.isAfter(local.updatedAt)) {
          await _localService.updateNote(cloud);
          log('🔀 Conflict: giữ bản cloud (${cloud.id})');
        }
      }

      lastSyncedAt = DateTime.now();
      _setStatus(SyncStatus.success);
      log('✅ SyncService: conflict resolution hoàn tất');

    } catch (e) {
      _setStatus(SyncStatus.error);
      log('❌ SyncService conflict lỗi: $e');
    } finally {
      _syncLock?.complete();
      _syncLock = null;
    }
  }
}