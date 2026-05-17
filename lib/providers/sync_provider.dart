import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../repositories/sync_repository.dart';

class SyncProvider extends ChangeNotifier {
  final SyncRepository _syncRepo;

  SyncStatus _status      = SyncStatus.idle;
  DateTime?  _lastSyncedAt;
  int        _pendingCount = 0;
  String?    _userId;
  bool       _isSyncing   = false;

  // Lắng nghe mạng
  final _connectivity = Connectivity();

  SyncStatus get status        => _status;
  DateTime?  get lastSyncedAt  => _lastSyncedAt;
  int        get pendingCount  => _pendingCount;

  String get statusLabel {
    switch (_status) {
      case SyncStatus.idle:    return 'Chưa sync';
      case SyncStatus.syncing: return 'Đang đồng bộ';
      case SyncStatus.success: return 'Đã đồng bộ';
      case SyncStatus.error:   return 'Lỗi sync';
    }
  }

  SyncProvider(this._syncRepo) {
    // Lắng nghe status từ SyncRepository
    _syncRepo.syncStatusStream.listen((status) {
      _status = status;
      notifyListeners();
    });

    // Lắng nghe mạng → sync khi có mạng trở lại
    _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline) {
        log('📶 SyncProvider: có mạng → trigger sync');
        syncNow();
      }
    });
  }

  // ── Gọi khi AuthProvider cập nhật user ──
  void updateUser(String? newUserId) {
    if (_userId == newUserId) return;
    _userId = newUserId;
    log('👤 SyncProvider: userId = $_userId');
    if (_userId != null) {
      syncNow(); // sync ngay khi có user
    }
  }

  // ── Sync thủ công hoặc tự động ──
  Future<void> syncNow() async {
    if (_userId == null) {
      log('⚠️ SyncProvider.syncNow: userId null, bỏ qua');
      return;
    }
    if (_isSyncing) {
      log('⏳ SyncProvider: đang sync, bỏ qua lần này');
      return;
    }

    _isSyncing = true;

    try {
      final unsynced = await _syncRepo.getUnsyncedNotes(_userId!);
      _pendingCount = unsynced.length;
      notifyListeners();

      log('🔄 SyncProvider: ${unsynced.length} notes cần sync');

      if (unsynced.isNotEmpty) {
        await _syncRepo.syncNotesBatch(unsynced);
        _lastSyncedAt = DateTime.now();
        _pendingCount = 0;
        log('✅ SyncProvider: sync thành công');
      } else {
        _status = SyncStatus.success;
        _lastSyncedAt = DateTime.now();
      }
    } catch (e) {
      log('❌ SyncProvider.syncNow lỗi: $e');
      _status = SyncStatus.error;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}