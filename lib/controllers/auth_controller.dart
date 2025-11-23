import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quizverse/services/auth_firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthController {
  final AuthFirestoreService _authService = AuthFirestoreService();

  User? get firebaseUser => FirebaseAuth.instance.currentUser;

  Future<void> login({required String email, required String password}) async {
    try {
      await _authService.signInAndFetchProfile(email, password);
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

      if (firebaseUser == null) {
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
        return false;
      }

      final userProfile = await _authService.checkLoginStatus();

      return userProfile != null;
    } catch (e) {
      debugPrint("Error checking login status: $e");
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
  }

  String? getLoggedInUserId() {
    return firebaseUser?.uid;
  }

  String? getLoggedInEmail() {
    return firebaseUser?.email;
  }
}
