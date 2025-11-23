import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quizverse/services/cloudinary_service.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  /// Update profile user (nama, username, foto)
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? username,
    File? newProfileImage,
    bool deleteProfilePhoto = false,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      // Update nama lengkap
      if (fullName != null && fullName.isNotEmpty) {
        updateData['fullName'] = fullName;
      }

      // Update username
      if (username != null && username.isNotEmpty) {
        updateData['username'] = username;
      }

      // Handle foto profil
      if (deleteProfilePhoto) {
        // Hapus foto profil
        updateData['profilePhotoUrl'] = null;
        debugPrint('Deleting profile photo for user: $userId');
      } else if (newProfileImage != null) {
        // Upload foto baru ke Cloudinary
        debugPrint('Uploading new profile photo for user: $userId');
        debugPrint('File path: ${newProfileImage.path}');
        debugPrint('File size: ${await newProfileImage.length()} bytes');

        final String? photoUrl = await _cloudinaryService.uploadProfilePicture(
          newProfileImage,
          userId,
        );

        if (photoUrl != null) {
          updateData['profilePhotoUrl'] = photoUrl;
          debugPrint('Photo uploaded successfully: $photoUrl');
        } else {
          throw Exception('Gagal upload foto profil ke Cloudinary.');
        }
      }

      // Update timestamp
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      // Update ke Firestore
      debugPrint('Updating Firestore with data: $updateData');
      await _firestore.collection('users').doc(userId).update(updateData);

      debugPrint('Profile updated successfully for user: $userId');
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  /// Cek apakah username sudah dipakai user lain
  Future<bool> isUsernameAvailable(
    String username,
    String currentUserId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return true; // Username available
      }

      // Cek apakah username ini milik user sendiri
      final existingUser = querySnapshot.docs.first;
      return existingUser.id == currentUserId;
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return false;
    }
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }
}
