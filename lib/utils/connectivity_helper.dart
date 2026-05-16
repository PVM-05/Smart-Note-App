import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityHelper {
  final _connectivity = Connectivity();
  StreamSubscription? _subscription;

  // Bắt đầu lắng nghe mạng
  void startListening({Function? onOnline}) {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);

      if (isOnline) {
        debugPrint('📶 ConnectivityHelper: có mạng');
        onOnline?.call();
      } else {
        debugPrint('📵 ConnectivityHelper: mất mạng');
      }
    });
    debugPrint('👂 ConnectivityHelper: đang lắng nghe mạng...');
  }

  // Dừng lắng nghe — gọi khi app bị đóng
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('🛑 ConnectivityHelper: dừng lắng nghe');
  }

  // Kiểm tra mạng tại thời điểm hiện tại
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}