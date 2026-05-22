import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../repositories/sync_repository.dart';
import '../models/sync_status.dart';

class SyncProvider extends ChangeNotifier {
  final SyncRepository _syncRepo;

  // =========================
  // State
  // =========================
  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;

  String? _userId;
  bool _isSyncing = false;

  // =========================
  // Stream subscriptions
  // =========================
  StreamSubscription? _syncStatusSubscription;
  StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;

  // =========================
  // Getters
  // =========================
  SyncStatus get status => _status;

  DateTime? get lastSyncedAt => _lastSyncedAt;

  int get pendingCount => _pendingCount;

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

  // =========================
  // Constructor
  // =========================
  SyncProvider(this._syncRepo) {
    _listenSyncStatus();
    _listenConnectivity();
  }

  // =========================
  // Listen sync status
  // =========================
  void _listenSyncStatus() {
    _syncStatusSubscription =
        _syncRepo.syncStatusStream.listen((status) {
          _status = status;
          notifyListeners();
        });
  }

  // =========================
  // Listen internet connection
  // =========================
  void _listenConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
          final isOnline =
          !results.contains(ConnectivityResult.none);

          if (isOnline) {
            log('📶 Có mạng trở lại → auto sync');
            syncNow();
          }
        });
  }

  // =========================
  // Update current user
  // =========================
  void updateUser(String? newUserId) {
    if (_userId == newUserId) return;

    _userId = newUserId;

    log('👤 SyncProvider: userId = $_userId');

    if (_userId != null) {
      syncNow();
    }
  }

  // =========================
  // Sync now
  // =========================
  Future<void> syncNow() async {
    if (_userId == null) {
      log('⚠️ userId null → bỏ qua sync');
      return;
    }

    if (_isSyncing) {
      log('⏳ Đang sync → bỏ qua lần gọi mới');
      return;
    }

    _isSyncing = true;

    try {
      _status = SyncStatus.syncing;
      notifyListeners();

      final unsyncedNotes =
      await _syncRepo.getUnsyncedNotes(_userId!);

      _pendingCount = unsyncedNotes.length;

      notifyListeners();

      log('🔄 Có $_pendingCount notes cần sync');

      if (unsyncedNotes.isNotEmpty) {
        await _syncRepo.syncNotesBatch(unsyncedNotes);

        _pendingCount = 0;

        log('✅ Sync thành công');
      }

      _status = SyncStatus.success;
      _lastSyncedAt = DateTime.now();
    } catch (e) {
      log('❌ Sync lỗi: $e');

      _status = SyncStatus.error;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // =========================
  // Dispose
  // =========================
  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
    _connectivitySubscription?.cancel();

    super.dispose();
  }
}