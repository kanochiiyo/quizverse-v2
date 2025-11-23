import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quizverse/services/auth_firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthController {
  final AuthFirestoreService _authService = AuthFirestoreService();

  // Getter untuk akses Firebase User
  User? get firebaseUser => FirebaseAuth.instance.currentUser;

  /// Login user dengan email dan password
  Future<void> login({required String email, required String password}) async {
    try {
      await _authService.signInAndFetchProfile(email, password);
    } catch (e) {
      rethrow;
    }
  }

  /// Register user baru
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

      if (firebaseUser == null) {
        throw Exception("Registrasi gagal: User tidak terbuat di Firebase.");
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Cek apakah user sudah login
  Future<bool> checkInitialLoginStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return false;
      }

      // Cek apakah user masih valid di Firestore
      final userProfile = await _authService.checkLoginStatus();

      return userProfile != null;
    } catch (e) {
      debugPrint("Error checking login status: $e");
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _authService.signOut();
  }

  /// Helper: Get current user ID
  String? getLoggedInUserId() {
    return firebaseUser?.uid;
  }

  /// Helper: Get current user email
  String? getLoggedInEmail() {
    return firebaseUser?.email;
  }
}
