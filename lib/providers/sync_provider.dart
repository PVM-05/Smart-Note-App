import 'package:flutter/material.dart';
import '../repositories/sync_repository.dart';
import '../utils/connectivity_helper.dart';

class SyncProvider extends ChangeNotifier {
  final SyncRepository _syncRepo;
  final _connectivityHelper = ConnectivityHelper();

  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;
  String? _userId;

  SyncStatus get status => _status;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pendingCount => _pendingCount;

  SyncProvider(this._syncRepo) {
    _init();
  }

  void updateUser(String? newUserId) {
    if (_userId != newUserId) {
      _userId = newUserId;
      if (_userId != null) {
        syncNow();
      }
    }
  }

  String get statusLabel {
    switch (_status) {
      case SyncStatus.idle:
        return 'Chưa sync';
      case SyncStatus.syncing:
        return 'Đang đồng bộ';
      case SyncStatus.success:
        return 'Đã đồng bộ';
      case SyncStatus.error:
        return 'Lỗi sync';
    }
  }

  void _init() {
    _syncRepo.syncStatusStream.listen((status) {
      _status = status;
      notifyListeners();
    });

    _connectivityHelper.startListening(onOnline: () => syncNow());
  }

  Future<void> syncNow() async {
    if (_userId == null) return;
    final notes = await _syncRepo.getUnsyncedNotes(_userId!);
    _pendingCount = notes.length;
    notifyListeners();

    if (notes.isNotEmpty) {
      try {
        await _syncRepo.syncNotesBatch(notes);
        _lastSyncedAt = DateTime.now();
        _pendingCount = 0;
      } catch (e) {
        // Ignored or handle error appropriately.
        debugPrint('Sync failed: $e');
      }
      notifyListeners();
    }
  }

  void startBackgroundSync() {
  }

  @override
  void dispose() {
    _connectivityHelper.stopListening();
    super.dispose();
  }
}
