import 'package:flutter/material.dart';
import 'package:quizverse/controllers/auth_controller.dart';
import 'package:quizverse/views/auth/login_view.dart';
import 'package:quizverse/services/database_service.dart';
import 'package:quizverse/services/achievement_service.dart';
import 'package:quizverse/models/achievement_model.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final AuthController _authController = AuthController();
  final DatabaseService _databaseService = DatabaseService();
  final AchievementService _achievementService = AchievementService();

  // State untuk statistik
  String? _username;
  bool _isLoadingStats = true;
  int _totalQuizzes = 0;
  String _avgScoreString = "0%";
  String _timePlayedString = "0m";

  // State untuk achievements
  List<AchievementModel> _achievements = [];
  bool _isLoadingAchievements = true;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadStats();
    _recalculateAchievements();
  }

  Future<void> _loadUsername() async {
    final username = await _authController.getLoggedInUsername();
    if (mounted) {
      setState(() {
        _username = username ?? 'Pengguna';
      });
    }
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _isLoadingStats = true);

    try {
      final String? userIdString = await _authController.getLoggedInUserId();
      if (userIdString == null) return;

      final history = await _databaseService.getQuizHistory(
        int.parse(userIdString),
      );
      if (!mounted) return;

      if (history.isEmpty) {
        setState(() {
          _isLoadingStats = false;
        });
        return;
      }

      // Hitung berdasarkan ada berapa data history quiz
      final totalQuizzes = history.length;
      // Hitung berdasarkan durasi di tiap data history quiz
      final totalDurationSeconds = history.fold<int>(
        0,
        (sum, item) => sum + (item['duration'] as int? ?? 0),
      );
      final duration = Duration(seconds: totalDurationSeconds);

      String timePlayed;
      if (duration.inHours > 0) {
        timePlayed =
            "${duration.inHours}j ${duration.inMinutes.remainder(60)}m";
      } else {
        timePlayed = "${duration.inMinutes}m";
      }

      int totalScore = 0;
      int totalQuestions = 0;

      for (var item in history) {
        totalScore += (item['score'] as int? ?? 0);
        // Hitung berapa skor yang didapat dari tiap data
        // Hitung berapa soal yang dikerjakan dari tiap data
        totalQuestions += (item['total_questions'] as int? ?? 0);
      }

      // Hitung rata-ratanya dan jadikan persen
      final avgScore = (totalQuestions > 0)
          ? (totalScore / totalQuestions) * 100
          : 0.0;
      final avgScoreString = "${avgScore.toStringAsFixed(0)}%";

      setState(() {
        _totalQuizzes = totalQuizzes;
        _timePlayedString = timePlayed;
        _avgScoreString = avgScoreString;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
      debugPrint("Gagal load stats: $e");
    }
  }

  // Method untuk cek ulang achievement user
  Future<void> _recalculateAchievements() async {
    if (mounted) setState(() => _isLoadingAchievements = true);
    try {
      final String? userIdString = await _authController.getLoggedInUserId();
      if (userIdString == null) {
        if (mounted) setState(() => _isLoadingAchievements = false);
        return;
      }

      final achievements = await _achievementService.recalculateAndSaveProgress(
        int.parse(userIdString),
      );

      if (mounted) {
        setState(() {
          _achievements = achievements;
          _isLoadingAchievements = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal recalculate achievements: $e");
      if (mounted) setState(() => _isLoadingAchievements = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal sinkronisasi achievements: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      try {
        await _authController.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginView()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
        }
      }
    }
  }

  // Method untuk show modal semua achievements
  void _showAllAchievements() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Semua Achievement',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _achievements.length,
                  itemBuilder: (context, index) {
                    final achievement = _achievements[index];

                    return _buildAchievementCard(achievement, expanded: true);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        color: color.withAlpha(26),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withAlpha(77)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
              Text(
                _isLoadingStats ? "..." : value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Statistik Kuis",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              context,
              icon: Icons.quiz,
              label: "Total Kuis",
              value: _totalQuizzes.toString(),
              color: theme.primaryColor,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              context,
              icon: Icons.check_circle_outline,
              label: "Rata-rata Skor",
              value: _avgScoreString,
              color: Colors.amber.shade800,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard(
              context,
              icon: Icons.timer,
              label: "Waktu Bermain",
              value: _timePlayedString,
              color: Colors.blue.shade700,
            ),
          ],
        ),
      ],
    );
  }

  // Widget section untuk menampilkan achievements
  Widget _buildAchievementsSection(BuildContext context) {
    final theme = Theme.of(context);
    // Hitung statistik achievement menggunakan service
    final stats = _achievementService.getAchievementStats(_achievements);
    // Filter hanya achievement yang sudah unlocked, ini buat ditampilin sebagai 3 teratas
    final unlockedAchievements = _achievements
        .where((a) => a.isUnlocked)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header dengan tombol lihat semua
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Achievements",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: _showAllAchievements,
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Card progress achievement
        Card(
          color: theme.primaryColor.withAlpha(26),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.primaryColor.withAlpha(77)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Row untuk tampilkan angka unlocked dan persentase
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${stats['unlocked']} / ${stats['total']} Terbuka',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    Text(
                      '${stats['percentage']}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar untuk visualisasi persentase
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: stats['percentage']! / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.primaryColor,
                    ),
                    minHeight: 10.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // List achievements yang sudah unlocked (3 teratas)
        if (_isLoadingAchievements)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (unlockedAchievements.isEmpty)
          // Pesan jika belum ada achievement terbuka
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  'Belum ada achievement terbuka.\nAyo mulai quiz untuk membuka achievement!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          )
        else
          // Tampilkan 3 achievement terbaru yang unlocked
          ...unlockedAchievements.take(3).map((achievement) {
            return _buildAchievementCard(achievement);
          }),
      ],
    );
  }

  // Widget builder untuk achievement card
  Widget _buildAchievementCard(
    AchievementModel achievement, {
    bool expanded = false,
  }) {
    final theme = Theme.of(context);
    final isUnlocked = achievement.isUnlocked;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // Beda warna untuk locked dan unlocked
      color: isUnlocked ? Colors.white : Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Icon emoji achievement
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? theme.primaryColor.withAlpha(26)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  achievement.icon,
                  style: TextStyle(
                    fontSize: 32,
                    // Grayscale jika locked
                    color: isUnlocked ? null : Colors.grey[500],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Content (title, description, progress)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? Colors.black : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isUnlocked ? Colors.grey[700] : Colors.grey[500],
                    ),
                  ),
                  // Tampilkan progress bar jika expanded dan belum unlocked
                  if (expanded && !isUnlocked) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: achievement.progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryColor,
                        ),
                        minHeight: 6.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Text progress (X / Y)
                    Text(
                      '${achievement.currentValue} / ${achievement.requiredValue}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),

            // Status icon (check untuk unlocked, lock untuk locked)
            if (isUnlocked)
              Icon(Icons.check_circle, color: theme.primaryColor, size: 28)
            else if (!expanded)
              Icon(Icons.lock_outline, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Pengguna'),
        automaticallyImplyLeading: false,
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadStats(), _recalculateAchievements()]);
        },
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            const SizedBox(height: 20),
            // Avatar pengguna
            CircleAvatar(
              radius: 60,
              backgroundColor: theme.primaryColor.withAlpha(26),
              child: Icon(Icons.person, size: 70, color: theme.primaryColor),
            ),
            const SizedBox(height: 16),
            // Username
            Text(
              _username ?? 'Memuat...',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Section statistik quiz
            _buildStatsSection(context),
            const SizedBox(height: 24),
            // Section achievements (NEW)
            _buildAchievementsSection(context),
            const SizedBox(height: 24),
            // Tombol logout
            ElevatedButton.icon(
              onPressed: _logout,
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
