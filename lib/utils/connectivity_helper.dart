import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_service.dart';

class ConnectivityHelper {
  final _connectivity = Connectivity();
  final _syncService  = SyncService();
  StreamSubscription? _subscription;

  // Bắt đầu lắng nghe mạng
  void startListening() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);

      if (isOnline) {
        print('📶 ConnectivityHelper: có mạng → trigger sync');
        _syncService.syncNow();
      } else {
        print('📵 ConnectivityHelper: mất mạng');
      }
    });
    print('👂 ConnectivityHelper: đang lắng nghe mạng...');
  }

  // Dừng lắng nghe — gọi khi app bị đóng
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    print('🛑 ConnectivityHelper: dừng lắng nghe');
  }

  // Kiểm tra mạng tại thời điểm hiện tại
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}