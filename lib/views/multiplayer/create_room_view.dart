import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quizverse/controllers/quiz_controller.dart';
import 'package:quizverse/models/category_model.dart';
import 'package:quizverse/services/multiplayer_service.dart';
import 'package:quizverse/views/multiplayer/waiting_room_view.dart';

class CreateRoomView extends StatefulWidget {
  const CreateRoomView({super.key});

  @override
  State<CreateRoomView> createState() => _CreateRoomViewState();
}

class _CreateRoomViewState extends State<CreateRoomView> {
  final QuizController _quizController = QuizController();
  final MultiplayerService _multiplayerService = MultiplayerService();

  String? selectedCategory;
  String? selectedCategoryName;
  bool isLoadingCategories = true;
  String? categoryError;
  List<CategoryModel> categories = [];

  String selectedDifficulty = 'easy';
  int selectedAmount = 10;
  bool isCreating = false;

  final List<Map<String, String>> difficulties = [
    {'id': 'easy', 'name': 'Mudah'},
    {'id': 'medium', 'name': 'Sedang'},
    {'id': 'hard', 'name': 'Sulit'},
  ];

  final List<int> amountOptions = [5, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      isLoadingCategories = true;
      categoryError = null;
    });

    try {
      final fetchedCategories = await _quizController.loadCategories();
      if (!mounted) return;
      setState(() {
        categories = fetchedCategories;
        isLoadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        categoryError = e.toString().replaceFirst("Exception: ", "");
        isLoadingCategories = false;
      });
    }
  }

  Future<void> _createRoom() async {
    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap pilih kategori terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isCreating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User tidak ditemukan');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final username = userData?['username'] ?? 'Unknown';
      final photoUrl = userData?['profilePhotoUrl'];

      final room = await _multiplayerService.createRoom(
        hostId: user.uid,
        hostName: username,
        category: selectedCategory!,
        categoryName: selectedCategoryName!,
        difficulty: selectedDifficulty,
        questionAmount: selectedAmount,
        hostPhotoUrl: photoUrl,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              WaitingRoomView(roomId: room.roomId, isHost: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat room: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Room')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('Pilih Kategori'),
            _buildCategoryList(),
            if (categoryError != null) _buildCategoryError(),

            const SizedBox(height: 24),
            _buildSectionTitle('Tingkat Kesulitan'),
            Row(
              children: difficulties.map((diff) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _buildSelectionCard(
                      text: diff['name']!,
                      icon: _getDifficultyIcon(diff['id']!),
                      isSelected: selectedDifficulty == diff['id'],
                      onTap: () {
                        setState(() {
                          selectedDifficulty = diff['id']!;
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('Jumlah Soal'),
            Row(
              children: amountOptions.map((amount) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: _buildSelectionCard(
                      text: '$amount Soal',
                      icon: Icons.format_list_numbered,
                      isSelected: selectedAmount == amount,
                      onTap: () {
                        setState(() {
                          selectedAmount = amount;
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: isCreating ? null : _createRoom,
              icon: isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_circle),
              label: Text(isCreating ? 'Membuat Room...' : 'Buat Room'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCategoryList() {
    if (isLoadingCategories) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (categories.isEmpty && categoryError == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const Text("Tidak ada kategori ditemukan."),
      );
    }

    return SizedBox(
      height: 105,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category.id.toString();

          return _buildCategoryCard(
            category: category,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                selectedCategory = category.id.toString();
                selectedCategoryName = category.name;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard({
    required CategoryModel category,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category.iconData,
              size: 30,
              color: isSelected ? Colors.white : colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryError() {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Text(
            categoryError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 16, color: Colors.grey[600]),
            onPressed: _loadCategories,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required String text,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : colorScheme.onSurface.withAlpha(178),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isSelected ? Colors.white : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDifficultyIcon(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return Icons.grass;
      case 'medium':
        return Icons.local_fire_department_outlined;
      case 'hard':
        return Icons.bolt;
      default:
        return Icons.help_outline;
    }
  }
}
