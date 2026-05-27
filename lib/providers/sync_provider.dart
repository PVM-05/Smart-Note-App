import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../repositories/sync_repository.dart';
import '../models/sync_status.dart';

// providers/sync_provider.dart
class SyncProvider with ChangeNotifier {
  final SyncRepository _syncRepo;
  SyncStatus _status = SyncStatus.idle;
  String? _userId;

  // Stream thông báo khi sync kéo về dữ liệu mới → HomeScreen lắng nghe để refresh
  final _newDataController = StreamController<void>.broadcast();
  Stream<void> get onSyncWithNewData => _newDataController.stream;

  SyncStatus get status => _status;

  SyncProvider(this._syncRepo) {
    _syncRepo.syncStatusStream.listen((status) {
      _status = status;
      notifyListeners();
    });

    // Tự động lắng nghe mạng để kích hoạt lại luồng đồng bộ
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none) && _userId != null) {
        syncNow();
      }
    });
  }

  void updateUser(String? newUserId) {
    if (_userId == newUserId) return;
    _userId = newUserId;
    if (_userId != null) syncNow();
  }

  Future<void> syncNow() async {
    if (_userId == null) return;
    try {
      await _syncRepo.syncNow(_userId!);

      // Sau khi syncNow hoàn tất, kiểm tra xem có dữ liệu mới không
      final hasNew = await _syncRepo.pullFromCloud(_userId!);
      if (hasNew) {
        _newDataController.add(null); // Phát tín hiệu cho HomeScreen refresh
      }
    } catch (e) {
      developer.log("SyncProvider Error: $e");
    }
  }

  @override
  void dispose() {
    _newDataController.close();
    super.dispose();
  }
}