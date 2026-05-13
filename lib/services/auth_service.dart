// lib/services/auth_service.dart
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      log('✅ Đăng ký thành công: ${result.user?.email}');
      log('✅ UID: ${result.user?.uid}');
      return result.user;
    } catch (e) {
      log('❌ Lỗi đăng ký: $e');
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
      log('✅ Đăng nhập thành công: ${result.user?.email}');
      log('✅ UID: ${result.user?.uid}');
      return result.user;
    } catch (e) {
      log('❌ Lỗi đăng nhập: $e');
      return null;
    }
  }

  // Đăng nhập Google (Thực tế để test)
  Future<User?> signInWithGoogle() async {
    try {
      log('🚀 Bắt đầu đăng nhập Google...');
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      log('✅ Google Login thành công: ${userCredential.user?.email}');
      return userCredential.user;
    } catch (e) {
      log('❌ Lỗi Google Login: $e');
      return null;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }
}