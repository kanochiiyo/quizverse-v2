import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quizverse/services/cloudinary_service.dart';
import 'package:quizverse/services/profile_photo_history_service.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ProfilePhotoHistoryService _historyService =
      ProfilePhotoHistoryService();

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? username,
    File? newProfileImage,
    bool deleteProfilePhoto = false,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (fullName != null && fullName.isNotEmpty) {
        updateData['fullName'] = fullName;
      }

      if (username != null && username.isNotEmpty) {
        updateData['username'] = username;
      }

      if (deleteProfilePhoto) {
        updateData['profilePhotoUrl'] = null;
        debugPrint('Deleting profile photo for user: $userId');
      } else if (newProfileImage != null) {
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

          await _historyService.savePhotoToHistory(photoUrl);
        } else {
          throw Exception('Gagal upload foto profil ke Cloudinary.');
        }
      }

      updateData['updatedAt'] = FieldValue.serverTimestamp();

      debugPrint('Updating Firestore with data: $updateData');
      await _firestore.collection('users').doc(userId).update(updateData);

      debugPrint('Profile updated successfully for user: $userId');
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

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
        return true;
      }

      final existingUser = querySnapshot.docs.first;
      return existingUser.id == currentUserId;
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return false;
    }
  }

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
