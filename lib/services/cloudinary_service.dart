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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = '${uid}_$timestamp';

      debugPrint('Uploading image with public_id: $publicId');

      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'profile_$publicId.jpg',
        ),
        'upload_preset': uploadPreset,
        'folder': 'user_profiles',
        'public_id': publicId,
      });

      Response response = await _dio.post(
        _uploadUrl,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
      );

      debugPrint('Cloudinary response status: ${response.statusCode}');
      debugPrint('Cloudinary response data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final secureUrl = response.data['secure_url'] as String;
        debugPrint('Upload successful! URL: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('Upload failed with status ${response.statusCode}');
        if (response.data != null && response.data['error'] != null) {
          debugPrint('Cloudinary error: ${response.data['error']}');
        }
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');

      if (e is DioException && e.response != null) {
        debugPrint('Error response data: ${e.response?.data}');
      }
      return null;
    }
  }

  Future<bool> deleteProfilePicture(String publicId) async {
    try {
      debugPrint('Delete request for public_id: $publicId');
      return true;
    } catch (e) {
      debugPrint('Error deleting from Cloudinary: $e');
      return false;
    }
  }
}
