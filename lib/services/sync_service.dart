import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_note_service.dart';
import 'firestore_note_service.dart';

// Trạng thái sync — dùng cho UI
enum SyncStatus { idle, syncing, success, error }

class SyncService {
  final _localService     = LocalNoteService();
  final _firestoreService = FirestoreNoteService();
  final _auth             = FirebaseAuth.instance;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  DateTime? lastSyncedAt;
  int pendingCount = 0;

  // Callback để báo UI cập nhật
  Function(SyncStatus)? onStatusChanged;

  void _setStatus(SyncStatus s) {
    _status = s;
    onStatusChanged?.call(s);
  }

  // ── Kiểm tra điều kiện để sync ──
  Future<bool> _canSync() async {
    // 1. Phải có user đang login
    if (_auth.currentUser == null) {
      log('⚠️ SyncService: chưa login, bỏ qua sync');
      return false;
    }

    // 2. Phải có mạng
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      log('⚠️ SyncService: không có mạng, bỏ qua sync');
      return false;
    }

    return true;
  }

  // ── Sync chính: đẩy notes chưa sync lên Firestore ──
  Future<void> syncNow() async {
    if (_status == SyncStatus.syncing) return; // tránh chạy 2 lần cùng lúc
    if (!await _canSync()) return;

    try {
      _setStatus(SyncStatus.syncing);

      // 1. Lấy tất cả notes chưa sync từ SQLite
      final unsyncedNotes = await _localService.getUnsyncedNotes();
      pendingCount = unsyncedNotes.length;

      if (unsyncedNotes.isEmpty) {
        log('✅ SyncService: không có gì cần sync');
        _setStatus(SyncStatus.success);
        lastSyncedAt = DateTime.now();
        return;
      }

      log('🔄 SyncService: đang sync ${unsyncedNotes.length} notes...');

      // 2. Batch push lên Firestore (ghi 1 lần thay vì từng cái)
      await _firestoreService.batchSaveNotes(unsyncedNotes);

      // 3. Đánh dấu tất cả đã sync trong SQLite
      for (final note in unsyncedNotes) {
        await _localService.markSynced(note.id);
      }

      pendingCount = 0;
      lastSyncedAt = DateTime.now();
      _setStatus(SyncStatus.success);
      log('✅ SyncService: sync ${unsyncedNotes.length} notes thành công');

    } catch (e) {
      _setStatus(SyncStatus.error);
      log('❌ SyncService lỗi: $e');
    }
  }

  // ── Pull: tải notes từ Firestore về SQLite ──
  // Dùng khi user login lần đầu trên thiết bị mới
  Future<void> pullFromCloud() async {
    if (!await _canSync()) return;

    try {
      log('⬇️ SyncService: đang tải data từ cloud...');
      final cloudNotes = await _firestoreService.getNotes();

      for (final note in cloudNotes) {
        // Lưu vào SQLite, đánh dấu isSynced=true luôn
        await _localService.insertNote(note);
      }

      log('✅ SyncService: đã tải ${cloudNotes.length} notes từ cloud');
    } catch (e) {
      log('❌ SyncService pullFromCloud lỗi: $e');
    }
  }

  // ── Conflict resolution: so sánh updatedAt ──
  // Nếu cùng 1 note bị sửa trên 2 thiết bị → giữ bản mới nhất
  Future<void> syncWithConflictResolution() async {
    if (!await _canSync()) return;

    try {
      _setStatus(SyncStatus.syncing);

      // Lấy từ cả 2 nguồn
      final localNotes = await _localService.getAllNotes();
      final cloudNotes = await _firestoreService.getNotes();

      // Tạo map để so sánh nhanh theo id
      final cloudMap = {for (final n in cloudNotes) n.id: n};

      for (final local in localNotes) {
        final cloud = cloudMap[local.id];

        if (cloud == null) {
          // Note chỉ có local → push lên cloud
          await _firestoreService.saveNote(local);
          await _localService.markSynced(local.id);

        } else if (local.updatedAt.isAfter(cloud.updatedAt)) {
          // Local mới hơn → push lên cloud
          await _firestoreService.saveNote(local);
          await _localService.markSynced(local.id);
          log('🔀 Conflict: giữ bản local (${local.id})');

        } else if (cloud.updatedAt.isAfter(local.updatedAt)) {
          // Cloud mới hơn → cập nhật local
          await _localService.updateNote(cloud);
          log('🔀 Conflict: giữ bản cloud (${cloud.id})');
        }
        // Bằng nhau → không làm gì
      }

      lastSyncedAt = DateTime.now();
      _setStatus(SyncStatus.success);
      log('✅ SyncService: conflict resolution hoàn tất');

    } catch (e) {
      _setStatus(SyncStatus.error);
      log('❌ SyncService conflict lỗi: $e');
    }
  }
}