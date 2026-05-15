import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/local_note_service.dart';

class AuthProvider extends ChangeNotifier {
  final LocalNoteService _localNoteService = LocalNoteService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get userId => _user?.uid;
  String? get email => _user?.email;

  // Cho phép set lỗi validation từ UI
  void setError(String? message) {
    _error = message;
    notifyListeners();
  }

  AuthProvider() {
    _user = FirebaseAuth.instance.currentUser;
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      _error = null;
      notifyListeners();
    });
  }

  // ✅ GOOGLE
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await FirebaseAuth.instance
          .signInWithCredential(credential);
      _user = result.user;
      log('✅ Google login: ${_user?.uid}');
      return true;
    } catch (e) {
      _error = 'Đăng nhập Google thất bại: $e';
      log('❌ Google error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ EMAIL LOGIN (FIX - Dùng Firebase trực tiếp)
  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      _user = userCredential.user;
      log('✅ Email login: ${_user?.uid}');
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _error = 'Không tìm thấy tài khoản';
          break;
        case 'wrong-password':
          _error = 'Sai mật khẩu';
          break;
        case 'invalid-email':
          _error = 'Email không hợp lệ';
          break;
        case 'user-disabled':
          _error = 'Tài khoản đã bị vô hiệu hóa';
          break;
        default:
          _error = 'Lỗi đăng nhập: ${e.message}';
      }
      return false;
    } catch (e) {
      _error = 'Lỗi không xác định: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ REGISTER (FIX - Firebase trực tiếp)
  Future<bool> registerWithEmail(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      _user = userCredential.user;
      log('✅ Register: ${_user?.uid}');
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          _error = 'Email đã được sử dụng';
          break;
        case 'weak-password':
          _error = 'Mật khẩu quá yếu (ít nhất 6 ký tự)';
          break;
        case 'invalid-email':
          _error = 'Email không hợp lệ';
          break;
        default:
          _error = 'Lỗi đăng ký: ${e.message}';
      }
      return false;
    } catch (e) {
      _error = 'Lỗi không xác định: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ LOGOUT
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      await _localNoteService.clearAllData();
    } catch (e) {
      log('Logout error: $e');
    }
    _user = null;
    _error = null;
    notifyListeners();
  }
}
