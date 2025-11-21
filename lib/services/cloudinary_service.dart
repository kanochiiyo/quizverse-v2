// lib/services/cloudinary_service.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class CloudinaryService {
  static const String cloudName = 'dd19u2qqb';
  static const String uploadPreset = 'flutter_profile_upload';

  final String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  final Dio _dio = Dio();

  Future<String?> uploadProfilePicture(File imageFile, String uid) async {
    try {
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'profile_$uid.jpg',
        ),
        'upload_preset': uploadPreset,
        'folder': 'user_profiles', 
        'public_id': uid,
      });

      Response response = await _dio.post(_uploadUrl, data: formData);

      if (response.statusCode == 200 && response.data != null) {
        return response.data['secure_url'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }
}
