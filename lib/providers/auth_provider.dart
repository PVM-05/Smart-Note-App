import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/local_note_service.dart';

class AuthProvider extends ChangeNotifier {
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

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? get userData => _userData;

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
      if (user == null) {
        _userData = null; // Xóa data khi đăng xuất
      }
      notifyListeners();
    });
  }

  Future<void> _syncUserProfile(User user, {String? displayName, String? photoUrl}) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      // Tạo mới nếu chưa có
      await userDoc.set({
        'email': user.email,
        'displayName': displayName ?? user.displayName ?? '',
        'photoUrl': photoUrl ?? user.photoURL ?? '',
        'bio': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _userData = (await userDoc.get()).data();
    } else {
      _userData = snapshot.data();
    }
    notifyListeners();
  }

  /// Reload lại userData từ Firestore sau khi cập nhật profile
  Future<void> reloadUserData() async {
    final currentUser = _user;
    if (currentUser == null) return;
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final snapshot = await userDoc.get();

      if (!snapshot.exists) {
        // Tạo mới profile nếu trên Firestore chưa có
        await userDoc.set({
          'email': currentUser.email,
          'displayName': currentUser.displayName ?? '',
          'photoUrl': currentUser.photoURL ?? '',
          'bio': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        _userData = (await userDoc.get()).data();
      } else {
        _userData = snapshot.data();
      }
      notifyListeners();
    } catch (e) {
      log('❌ reloadUserData error: $e');
    }
  }

  // ==================================================================
  // 🔐 AUTH LOGIC: GOOGLE SIGN IN
  // DATA FLOW: FE (Button) -> Google API -> Firebase Auth -> Update _user
  // ==================================================================
  // ==================================================================
  // 🔐 AUTH LOGIC: GOOGLE SIGN IN
  // DATA FLOW: FE (Button) -> Google API -> Firebase Auth -> Update _user
  // ==================================================================
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
      if (_user != null) await _syncUserProfile(_user!);
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

  // ✅ EMAIL LOGIN
  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      _user = userCredential.user;
      if (_user != null) await _syncUserProfile(_user!);
      log('✅ Email login: ${_user?.uid}');
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _translateAuthError(e.code); // Dùng hàm dịch lỗi
      return false;
    } catch (e) {
      _error = 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ REGISTER
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
      if (_user != null) await _syncUserProfile(_user!);
      log('✅ Register: ${_user?.uid}');
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _translateAuthError(e.code); // Dùng hàm dịch lỗi
      return false;
    } catch (e) {
      _error = 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 📝 HÀM DỊCH MÃ LỖI FIREBASE SANG TIẾNG VIỆT
  String _translateAuthError(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'Tài khoản không tồn tại. Vui lòng kiểm tra lại email.';
      case 'wrong-password':
        return 'Mật khẩu không chính xác.';
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'invalid-email':
        return 'Định dạng email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng cho một tài khoản khác.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (cần ít nhất 6 ký tự).';
      case 'network-request-failed':
        return 'Không có kết nối mạng. Vui lòng kiểm tra lại WiFi/4G.';
      case 'too-many-requests':
        return 'Bạn đã nhập sai quá nhiều lần. Vui lòng thử lại sau một lát.';
      default:
        return 'Lỗi đăng nhập: $errorCode';
    }
  }

  // ==================================================================
  // 🚪 AUTH LOGIC: LOGOUT
  // DATA FLOW: FE (Button) -> Clear Firebase Session -> Clear Local State -> UI Redirect
  // ==================================================================
  // ==================================================================
  // 🚪 AUTH LOGIC: LOGOUT
  // DATA FLOW: FE (Button) -> Clear Firebase Session -> Clear Local State
  // ==================================================================
  // ✅ LOGOUT
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      // KHÔNG gọi LocalNoteService().clearUserNotes(uid) ở đây nữa!
      // Việc giữ lại data giúp bảo vệ các ghi chú offline chưa kịp sync.

      // Đăng xuất khỏi Firebase và Google
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } catch (e) {
      log('❌ Soft Logout error: $e');
    } finally {
      _user = null;
      _userData = null; // Xóa thông tin profile trong RAM
      _error = null;
      _isLoading = false;
      notifyListeners();
    }
  }
}
