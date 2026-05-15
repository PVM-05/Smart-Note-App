import 'package:flutter/material.dart';
import '../repositories/sync_repository.dart';
import '../utils/connectivity_helper.dart';

class SyncProvider extends ChangeNotifier {
  final SyncRepository _syncRepo;
  final _connectivityHelper = ConnectivityHelper();

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;

  SyncStatus get status => _status;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pendingCount => _pendingCount;

  SyncProvider(this._syncRepo) {
    _init();
  }

  // Label hiển thị trên UI
  String get statusLabel {
    switch (_status) {
      case SyncStatus.idle:
        return 'Chưa sync';
      case SyncStatus.syncing:
        return 'Đang sync...';
      case SyncStatus.success:
        return 'Đã đồng bộ';
      case SyncStatus.error:
        return 'Lỗi sync';
    }
  }

  void _init() {
    // Lắng nghe status từ SyncRepository
    _syncRepo.syncStatusStream.listen((status) {
      _status = status;
      // Note: SyncRepository should manage lastSyncedAt and pendingCount internally or expose them
      notifyListeners();
    });

    // Bắt đầu lắng nghe mạng
    _connectivityHelper.startListening(onOnline: () => syncNow());

    // Sync ngay khi khởi động
    syncNow();
  }

  Future<void> syncNow() async {
    final notes = await _syncRepo.getUnsyncedNotes();
    _pendingCount = notes.length;
    notifyListeners();

    if (notes.isNotEmpty) {
      try {
        await _syncRepo.syncNotesBatch(notes);
        _lastSyncedAt = DateTime.now();
        _pendingCount = 0;
      } catch (e) {
        // Error status handled via stream
      }
      notifyListeners();
    }
  }

  void startBackgroundSync() {
    // Logic for background sync can be added here using workmanager or similar
  }

  @override
  void dispose() {
    _connectivityHelper.stopListening();
    super.dispose();
  }
}
