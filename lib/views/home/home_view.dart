import 'package:flutter/material.dart';
import 'package:quizverse/controllers/quiz_controller.dart';
import 'package:quizverse/models/quiz_model.dart';
import 'package:quizverse/models/category_model.dart';
import 'package:quizverse/views/home/quiz_view.dart';
import 'package:quizverse/services/conversion_service.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // Inisialisasi controller dan service
  final QuizController _controller = QuizController();
  final ConversionService _conversionService = ConversionService();

  // State untuk data dari API/Service
  String? selectedCategory;
  bool isLoadingCategories = true;
  String? categoryError;
  List<CategoryModel> categories = [];

  // State pilihan user
  String selectedDifficulty = 'easy';
  int selectedAmount = 10;

  // State untuk UI
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
        // Ambil data dari API controller
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
    // Kalo misal belum milih kategori apa-apa
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
      // Load soal dari controller quiz
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

  @override
  Widget build(BuildContext context) {
    final bool isOverallLoading =
        isLoading || isLoadingFact || isLoadingCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mulai Kuis Baru'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Panggil widget untuk build section title dan widget category card
            _buildSectionTitle('Pilih Kategori'),
            _buildCategoryList(isOverallLoading),
            if (categoryError != null) _buildCategoryError(),

            const SizedBox(height: 24),
            _buildSectionTitle('Tingkat Kesulitan'),
            // Panggil widget dofficulty card
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
            // Panggil widget selection jumlah soal card
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

            // Row(
            //   mainAxisAlignment: MainAxisAlignment.end,
            //   children: [
            // Tombol mulai kuis
            ElevatedButton(
              // Kalo belum milih kategori atau lagi loading, null in dulu (biar ga bisa diteken)
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
        // ],
        // ),
      ),
    );
  }

  // Helper untuk bikin selection title
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

  // Helper untuk bikin category list yang bisa discroll itu (keseluruhan dan banyak card)
  Widget _buildCategoryList(bool isLoading) {
    if (isLoadingCategories) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: CircularProgressIndicator(),
      );
    }

    if (categories.isEmpty && categoryError == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: Text("Tidak ada kategori ditemukan."),
      );
    }

    return SizedBox(
      height: 105,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(right: 16),
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

  // Category Card (per 1 biji)
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
        margin: EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          // Ngatur kalo selected, kalo dipilih, ubah BG card,
          color: isSelected ? colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            // Untuk border, kalo ga dipilih, ganti warna border
            color: isSelected ? colorScheme.primary : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category.iconData,
              size: 30,
              // Kalo dipilih, iconnya ubah jadi warna putih
              color: isSelected ? Colors.white : colorScheme.primary,
            ),
            SizedBox(height: 8),
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

  // Widget builder card untuk tingkat kesulitan dan jumlah soal (kategori dibedain karena dari API/model)
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
        padding: EdgeInsets.symmetric(vertical: 16),
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
            SizedBox(height: 8),
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

  // Ambil data Icon
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
