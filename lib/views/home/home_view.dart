import 'package:flutter/material.dart';
import 'package:quizverse/controllers/quiz_controller.dart';
import 'package:quizverse/models/quiz_model.dart';
import 'package:quizverse/models/category_model.dart';
import 'package:quizverse/views/home/quiz_view.dart';
import 'package:quizverse/views/multiplayer/multiplayer_lobby_view.dart';
import 'package:quizverse/services/conversion_service.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final QuizController _controller = QuizController();
  final ConversionService _conversionService = ConversionService();

  String? selectedCategory;
  bool isLoadingCategories = true;
  String? categoryError;
  List<CategoryModel> categories = [];

  String selectedDifficulty = 'easy';
  int selectedAmount = 10;

  bool isLoading = false;
  String? dailyFact;
  bool isLoadingFact = true;
  String factError = '';

  final List<Map<String, String>> difficulties = [
    {'id': 'easy', 'name': 'Mudah'},
    {'id': 'medium', 'name': 'Sedang'},
    {'id': 'hard', 'name': 'Sulit'},
  ];

  final List<int> amountOptions = [5, 10, 15, 20];

  @override
  void initState() {
    super.initState();
    _loadDailyFact();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      isLoadingCategories = true;
      categoryError = null;
    });

    try {
      final fetchedCategories = await _controller.loadCategories();
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

  Future<void> _loadDailyFact() async {
    if (!mounted) return;
    setState(() {
      isLoadingFact = true;
      factError = '';
    });

    try {
      final fact = await _conversionService.getRandomFact();
      if (mounted) {
        setState(() {
          dailyFact = fact;
          isLoadingFact = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          factError = e.toString().replaceFirst("Exception: ", "");
          dailyFact = null;
          isLoadingFact = false;
        });
      }
    }
  }

  Future<void> startQuiz() async {
    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap pilih kategori terlebih dahulu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      List<QuizModel> questions = await _controller.loadQuestions(
        amount: selectedAmount,
        category: selectedCategory!,
        difficulty: selectedDifficulty,
      );

      debugPrint('GET DATA SUCCESS: GOT ${questions.length} QUESTIONS!');

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => QuizView(questions: questions)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat kuis: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _goToMultiplayer() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MultiplayerLobbyView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOverallLoading =
        isLoading || isLoadingFact || isLoadingCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuizVerse'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildModeCard(
                    icon: Icons.person,
                    title: 'Single Player',
                    description: 'Main sendiri',
                    color: Theme.of(context).primaryColor,
                    isSelected: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _goToMultiplayer,
                    borderRadius: BorderRadius.circular(12),
                    child: _buildModeCard(
                      icon: Icons.groups,
                      title: 'Multiplayer',
                      description: 'Main bersama',
                      color: Colors.green,
                      isSelected: false,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'Single Player',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Pilih Kategori'),
            _buildCategoryList(isOverallLoading),
            if (categoryError != null) _buildCategoryError(),

            const SizedBox(height: 24),
            _buildSectionTitle('Tingkat Kesulitan'),
            Row(
              children: [
                Expanded(
                  child: _buildSelectionCard(
                    text: difficulties[0]['name']!,
                    icon: _getDifficultyIcon(difficulties[0]['id']!),
                    isSelected: selectedDifficulty == difficulties[0]['id'],
                    onTap: isOverallLoading
                        ? null
                        : () {
                            setState(() {
                              selectedDifficulty = difficulties[0]['id']!;
                            });
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSelectionCard(
                    text: difficulties[1]['name']!,
                    icon: _getDifficultyIcon(difficulties[1]['id']!),
                    isSelected: selectedDifficulty == difficulties[1]['id'],
                    onTap: isOverallLoading
                        ? null
                        : () {
                            setState(() {
                              selectedDifficulty = difficulties[1]['id']!;
                            });
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSelectionCard(
                    text: difficulties[2]['name']!,
                    icon: _getDifficultyIcon(difficulties[2]['id']!),
                    isSelected: selectedDifficulty == difficulties[2]['id'],
                    onTap: isOverallLoading
                        ? null
                        : () {
                            setState(() {
                              selectedDifficulty = difficulties[2]['id']!;
                            });
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Jumlah Soal'),
            Row(
              children: [
                Expanded(
                  child: _buildSelectionCard(
                    text: '${amountOptions[0]} Soal',
                    icon: Icons.format_list_numbered,
                    isSelected: selectedAmount == amountOptions[0],
                    onTap: isOverallLoading
                        ? null
                        : () {
                            setState(() {
                              selectedAmount = amountOptions[0];
                            });
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSelectionCard(
                    text: '${amountOptions[1]} Soal',
                    icon: Icons.format_list_numbered,
                    isSelected: selectedAmount == amountOptions[1],
                    onTap: isOverallLoading
                        ? null
                        : () {
                            setState(() {
                              selectedAmount = amountOptions[1];
                            });
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSelectionCard(
                    text: '${amountOptions[2]} Soal',
                    icon: Icons.format_list_numbered,
                    isSelected: selectedAmount == amountOptions[2],
                    onTap: isOverallLoading
                        ? null
                        : () {
                            setState(() {
                              selectedAmount = amountOptions[2];
                            });
                          },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _buildDailyFactWidget(),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: (isOverallLoading || selectedCategory == null)
                  ? null
                  : startQuiz,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text('Mulai Kuis'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? color : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
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

  Widget _buildCategoryList(bool isLoading) {
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
        padding: const EdgeInsets.only(right: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final bool isSelected = selectedCategory == category.id.toString();

          return _buildCategoryCard(
            category: category,
            isSelected: isSelected,
            onTap: isLoading
                ? null
                : () {
                    setState(() {
                      selectedCategory = category.id.toString();
                    });
                  },
          );
        },
      ),
    );
  }

  Widget _buildCategoryError() {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 12.0),
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
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required CategoryModel category,
    required bool isSelected,
    required VoidCallback? onTap,
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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

  Widget _buildSelectionCard({
    required String text,
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
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
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
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

  Widget _buildDailyFactWidget() {
    final theme = Theme.of(context);
    Widget content;

    if (isLoadingFact) {
      content = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(width: 15),
            Text(
              "Memuat fakta menarik...",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    } else if (factError.isNotEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                factError,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      );
    } else if (dailyFact != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "💡 Fakta Hari Ini:",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dailyFact!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    return Card(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: content,
    );
  }
}
