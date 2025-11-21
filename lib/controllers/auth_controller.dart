import 'dart:io';
import 'package:quizverse/services/auth_firestore_service.dart';
import 'package:quizverse/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthController {
  final AuthFirestoreService _authService = AuthFirestoreService();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  User? get firebaseUser => FirebaseAuth.instance.currentUser;

  Future<void> login({required String email, required String password}) async {
    try {
      _currentUser = await _authService.signInAndFetchProfile(email, password);
      if (_currentUser == null) {
        throw Exception("Login gagal: Data pengguna tidak dapat dimuat.");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String username,
    File? profileImageFile,
  }) async {
    try {
      final firebaseUser = await _authService.registerUser(
        email: email,
        password: password,
        fullName: fullName,
        username: username,
        profileImageFile: profileImageFile,
      );

      if (firebaseUser != null) {
        _currentUser = await _authService.signInAndFetchProfile(
          email,
          password,
        );
      } else {
        throw Exception("Registrasi gagal: User tidak terbuat di Firebase.");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> checkInitialLoginStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _currentUser = null;
        return false;
      }

      _currentUser = await _authService.signInAndFetchProfile(
        user.email!,
        "dummy_password_unused_for_profile_fetch",
      );

      return _currentUser != null;
    } catch (e) {
      print("Error fetching profile on status check: $e");
      _currentUser = null;
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
    _currentUser = null;
  }

  UserModel? getLoggedInUser() {
    return _currentUser;
  }

  String? getLoggedInUserId() {
    return _currentUser?.uid;
  }

  String? getLoggedInUsername() {
    return _currentUser?.username;
  }
}
