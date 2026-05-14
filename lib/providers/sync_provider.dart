import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../utils/connectivity_helper.dart';

class SyncProvider extends ChangeNotifier {
  final _syncService        = SyncService();
  final _connectivityHelper = ConnectivityHelper();

  SyncStatus _status    = SyncStatus.idle;
  DateTime?  _lastSyncedAt;
  int        _pendingCount = 0;

  SyncStatus get status       => _status;
  DateTime?  get lastSyncedAt => _lastSyncedAt;
  int        get pendingCount => _pendingCount;

  // Label hiển thị trên UI
  String get statusLabel {
    switch (_status) {
      case SyncStatus.idle:    return 'Chưa sync';
      case SyncStatus.syncing: return 'Đang sync...';
      case SyncStatus.success: return 'Đã đồng bộ';
      case SyncStatus.error:   return 'Lỗi sync';
    }
  }

  void init() {
    // Lắng nghe status từ SyncService
    _syncService.onStatusChanged = (status) {
      _status       = status;
      _lastSyncedAt = _syncService.lastSyncedAt;
      _pendingCount = _syncService.pendingCount;
      notifyListeners();
    };

    // Bắt đầu lắng nghe mạng
    _connectivityHelper.startListening();

    // Sync ngay khi khởi động
    syncNow();
  }

  Future<void> syncNow() async {
    await _syncService.syncNow();
  }

  void dispose() {
    _connectivityHelper.stopListening();
    super.dispose();
  }
}