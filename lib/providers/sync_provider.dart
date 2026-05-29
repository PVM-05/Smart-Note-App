import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../repositories/sync_repository.dart';
import '../models/sync_status.dart';

// providers/sync_provider.dart
class SyncProvider with ChangeNotifier {
  final SyncRepository _syncRepo;
  SyncStatus _status = SyncStatus.idle;
  String? _userId;
  bool _isOffline = false;
  Timer? _debounceTimer; // Debounce rapid connectivity changes

  // Stream thông báo khi sync kéo về dữ liệu mới → HomeScreen lắng nghe để refresh
  final _newDataController = StreamController<void>.broadcast();
  Stream<void> get onSyncWithNewData => _newDataController.stream;

  SyncStatus get status => _status;
  bool get isOffline => _isOffline;

  SyncProvider(this._syncRepo) {
    _syncRepo.syncStatusStream.listen((status) {
      _status = status;
      notifyListeners();
    });

    // Khởi tạo trạng thái mạng ban đầu
    Connectivity().checkConnectivity().then((results) {
      _isOffline = results.contains(ConnectivityResult.none);
      notifyListeners();
    });

    // Tự động lắng nghe mạng — debounce 500ms để tránh banner flickering khi toggle wifi nhanh
    Connectivity().onConnectivityChanged.listen((results) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        final oldOffline = _isOffline;
        _isOffline = results.contains(ConnectivityResult.none);

        if (oldOffline != _isOffline || !_isOffline) {
          notifyListeners();
        }

        if (!_isOffline && _userId != null) {
          syncNow();
        }
      });
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
      final hasNew = await _syncRepo.syncNow(_userId!);

      if (hasNew) {
        _newDataController.add(null); // Phát tín hiệu cho HomeScreen refresh
      }
    } catch (e) {
      debugPrint("SyncProvider Error: $e");
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _newDataController.close();
    super.dispose();
  }
}