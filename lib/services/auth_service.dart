// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Đăng ký tài khoản mới
  Future<User?> register(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Đăng ký thành công: ${result.user?.email}');
      print('✅ UID: ${result.user?.uid}');
      return result.user;
    } catch (e) {
      print('❌ Lỗi đăng ký: $e');
      return null;
    }
  }

  // Đăng nhập
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Đăng nhập thành công: ${result.user?.email}');
      print('✅ UID: ${result.user?.uid}');
      return result.user;
    } catch (e) {
      print('❌ Lỗi đăng nhập: $e');
      return null;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }
}