import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizverse/models/user_model.dart';
import 'package:quizverse/services/cloudinary_service.dart';

class AuthFirestoreService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  Future<User?> registerUser({
    required String email,
    required String password,
    required String fullName,
    required String username,
    File? profileImageFile,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user == null) return null;
      final uid = user.uid;
      String? profilePhotoUrl;

      if (profileImageFile != null) {
        profilePhotoUrl = await _cloudinaryService.uploadProfilePicture(
          profileImageFile,
          uid,
        );
      }

      final newUser = UserModel(
        uid: uid,
        fullName: fullName,
        username: username,
        email: email,
        profilePhotoUrl: profilePhotoUrl,
      );

      await _db.collection('users').doc(uid).set(newUser.toMap());

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'Email sudah terdaftar. Silakan gunakan email lain.';
      } else if (e.code == 'weak-password') {
        throw 'Password terlalu lemah.';
      }

      throw 'Registrasi Gagal: ${e.message}';
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> signInAndFetchProfile(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;

      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      } else {
        throw 'Data profil tidak ditemukan. Silakan login ulang.';
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        throw 'Email atau Password salah. Periksa kembali kredensial Anda.';
      }

      throw 'Login Gagal: ${e.message}';
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> checkLoginStatus() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;

    try {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, user.uid);
      }
      return null;
    } catch (e) {
      print('Error checking login status/fetching profile: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
