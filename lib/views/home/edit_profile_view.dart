import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quizverse/services/profile_service.dart';

class EditProfileView extends StatefulWidget {
  final String fullName;
  final String username;
  final String email;
  final String? profilePhotoUrl;

  const EditProfileView({
    super.key,
    required this.fullName,
    required this.username,
    required this.email,
    this.profilePhotoUrl,
  });

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;

  File? _newProfileImage;
  bool _deleteCurrentPhoto = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.fullName);
    _usernameController = TextEditingController(text: widget.username);
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _newProfileImage = File(pickedFile.path);
          _deleteCurrentPhoto = false;
        });

        debugPrint('Image selected from gallery: ${pickedFile.path}');
      } else {
        debugPrint('No image selected from gallery');
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih foto: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile != null) {
        setState(() {
          _newProfileImage = File(pickedFile.path);
          _deleteCurrentPhoto = false;
        });

        debugPrint('Photo taken from camera: ${pickedFile.path}');
      } else {
        debugPrint('Camera cancelled');
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.blue),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.green),
                  title: const Text('Ambil Foto'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                if (widget.profilePhotoUrl != null || _newProfileImage != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Hapus Foto Profil'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _newProfileImage = null;
                        _deleteCurrentPhoto = true;
                      });
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Batal'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateProfile() async {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();

    if (fullName.isEmpty) {
      setState(() {
        _errorMessage = 'Nama lengkap tidak boleh kosong!';
      });
      return;
    }

    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Username tidak boleh kosong!';
      });
      return;
    }

    if (username.length < 3) {
      setState(() {
        _errorMessage = 'Username minimal 3 karakter!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User tidak ditemukan');
      }

      if (username != widget.username) {
        final isAvailable = await _profileService.isUsernameAvailable(
          username,
          userId,
        );

        if (!isAvailable) {
          setState(() {
            _errorMessage = 'Username "$username" sudah digunakan!';
            _isLoading = false;
          });
          return;
        }
      }

      await _profileService.updateProfile(
        userId: userId,
        fullName: fullName,
        username: username,
        newProfileImage: _newProfileImage,
        deleteProfilePhoto: _deleteCurrentPhoto,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().contains('Exception:')
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Gagal memperbarui profil: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildProfileImageSection(ThemeData theme) {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _showPhotoOptions,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withAlpha(26),
                border: Border.all(color: theme.primaryColor, width: 3),
              ),
              child: ClipOval(child: _buildProfileImage(theme)),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(ThemeData theme) {
    if (_newProfileImage != null) {
      return Image.file(
        _newProfileImage!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
      );
    }

    if (_deleteCurrentPhoto) {
      return Icon(Icons.person, size: 60, color: theme.primaryColor);
    }

    if (widget.profilePhotoUrl != null && widget.profilePhotoUrl!.isNotEmpty) {
      return Image.network(
        widget.profilePhotoUrl!,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.person, size: 60, color: theme.primaryColor);
        },
      );
    }

    return Icon(Icons.person, size: 60, color: theme.primaryColor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            _buildProfileImageSection(theme),
            const SizedBox(height: 12),

            Text(
              'Ketuk foto untuk mengubah',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 32),

            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                prefixIcon: Icon(Icons.badge),
                hintText: 'Masukkan nama lengkap',
              ),
              enabled: !_isLoading,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.alternate_email),
                hintText: 'Masukkan username',
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                suffixIcon: Tooltip(
                  message: 'Email tidak dapat diubah',
                  child: Icon(Icons.info_outline, color: Colors.grey[600]),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              enabled: false,
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.error.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.error),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _updateProfile,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Menyimpan...' : 'Simpan Perubahan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.cancel),
              label: const Text('Batal'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
