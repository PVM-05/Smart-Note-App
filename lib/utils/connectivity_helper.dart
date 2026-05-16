import 'dart:async';
import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityHelper {
  final _connectivity = Connectivity();
  StreamSubscription? _subscription;

  // Bắt đầu lắng nghe — onOnline callback khi có mạng trở lại
  void startListening({required VoidCallback onOnline}) {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      if (isOnline) {
        log('📶 ConnectivityHelper: có mạng');
        onOnline();
      } else {
        log('📵 ConnectivityHelper: mất mạng');
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}

// Typedef để dùng trong startListening
typedef VoidCallback = void Function();