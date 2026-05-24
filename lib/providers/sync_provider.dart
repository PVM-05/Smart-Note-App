import 'dart:async';
import 'dart:developer';
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
      // Gọi một hàm duy nhất thực hiện toàn bộ quy trình đóng gói
      await _syncRepo.syncNow(_userId!);
    } catch (e) {
      developer.log("SyncProvider Error: $e");
    }
  }
}