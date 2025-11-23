import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quizverse/controllers/auth_controller.dart';
import 'package:quizverse/services/firestore_service.dart';
import 'package:quizverse/views/home/history_detail_view.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthController _authController = AuthController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _quizHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadHistory();

    _searchController.addListener(() {
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String? userId = _authController.firebaseUser?.uid;
      if (userId != null) {
        final history = await _firestoreService.getQuizHistory(userId);
        if (!mounted) return;
        setState(() {
          _quizHistory = history;
          _applyFilters();
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = "Tidak dapat memuat riwayat: User tidak ditemukan.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Gagal memuat riwayat: ${e.toString()}";
        _isLoading = false;
      });
      debugPrint("Error loading history: $e");
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    var filtered = _quizHistory.where((item) {
      final isMultiplayer = item['is_multiplayer'] as bool? ?? false;

      bool modeMatch = true;
      if (_selectedFilter == 'single' && isMultiplayer) {
        modeMatch = false;
      } else if (_selectedFilter == 'multi' && !isMultiplayer) {
        modeMatch = false;
      }

      if (!modeMatch) return false;

      if (query.isEmpty) return true;

      final category = (item['category'] as String?)?.toLowerCase() ?? '';
      final difficulty = (item['difficulty'] as String?)?.toLowerCase() ?? '';
      final roomCode = (item['room_code'] as String?)?.toLowerCase() ?? '';

      return category.contains(query) ||
          difficulty.contains(query) ||
          roomCode.contains(query);
    }).toList();

    setState(() {
      _filteredHistory = filtered;
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Tanggal tidak diketahui';
    try {
      final isoUtcString = "${dateString.replaceFirst(' ', 'T')}Z";
      final utcDateTime = DateTime.parse(isoUtcString);
      final localDateTime = utcDateTime.toLocal();

      return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(localDateTime);
    } catch (e) {
      return dateString;
    }
  }

  String _formatDuration(int? totalSeconds) {
    if (totalSeconds == null || totalSeconds < 0) return '?';
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes;
    final seconds = totalSeconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Kuis'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari kategori, kesulitan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
              ),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Semua'),
                  selected: _selectedFilter == 'all',
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = 'all';
                      _applyFilters();
                    });
                  },
                  selectedColor: theme.primaryColor.withOpacity(0.2),
                  checkmarkColor: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Single Player'),
                  selected: _selectedFilter == 'single',
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = 'single';
                      _applyFilters();
                    });
                  },
                  selectedColor: theme.primaryColor.withOpacity(0.2),
                  checkmarkColor: theme.primaryColor,
                  avatar: Icon(
                    Icons.person,
                    size: 16,
                    color: _selectedFilter == 'single'
                        ? theme.primaryColor
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Multiplayer'),
                  selected: _selectedFilter == 'multi',
                  onSelected: (selected) {
                    setState(() {
                      _selectedFilter = 'multi';
                      _applyFilters();
                    });
                  },
                  selectedColor: Colors.green.withOpacity(0.2),
                  checkmarkColor: Colors.green,
                  avatar: Icon(
                    Icons.groups,
                    size: 16,
                    color: _selectedFilter == 'multi'
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_quizHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Belum ada riwayat kuis',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Mulai quiz untuk melihat riwayat',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_filteredHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tidak ada hasil',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Coba ubah filter atau kata kunci',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredHistory.length,
      itemBuilder: (context, index) {
        return _buildHistoryCard(_filteredHistory[index]);
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> historyItem) {
    final theme = Theme.of(context);

    final score = historyItem['score'] as int?;
    final totalQuestions = historyItem['total_questions'] as int?;
    final category = historyItem['category'] as String?;
    final difficulty = historyItem['difficulty'] as String?;
    final date = historyItem['quiz_date'] as String?;
    final durationInSeconds = historyItem['duration'] as int?;

    final isMultiplayer = historyItem['is_multiplayer'] as bool? ?? false;
    final roomCode = historyItem['room_code'] as String?;
    final userRank = historyItem['user_rank'] as int?;
    final multiplayerScore = historyItem['multiplayer_score'] as int?;

    final address = historyItem['address'] as String?;
    final latitude = historyItem['latitude'] as double?;
    final longitude = historyItem['longitude'] as double?;

    Color difficultyColor;
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        difficultyColor = Colors.green;
        break;
      case 'medium':
        difficultyColor = Colors.orange;
        break;
      case 'hard':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (historyItem['quiz_data_json'] != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    HistoryDetailView(historyItem: historyItem),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Detail untuk riwayat ini tidak tersedia.'),
                backgroundColor: Colors.grey,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category ?? 'Kategori Tidak Diketahui',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isMultiplayer
                          ? Colors.green.withOpacity(0.1)
                          : theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMultiplayer
                            ? Colors.green
                            : theme.primaryColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isMultiplayer ? Icons.groups : Icons.person,
                          size: 14,
                          color: isMultiplayer
                              ? Colors.green
                              : theme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isMultiplayer ? 'Multi' : 'Solo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isMultiplayer
                                ? Colors.green
                                : theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: difficultyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed, size: 12, color: difficultyColor),
                        const SizedBox(width: 4),
                        Text(
                          difficulty != null ? capitalize(difficulty) : '?',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: difficultyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDate(date),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (address != null && address.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ] else if (latitude != null && longitude != null) ...[
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Text(
                      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              const Divider(height: 1),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMultiplayer) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$multiplayerScore pts',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (userRank != null && userRank <= 3) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.emoji_events,
                                  size: 16,
                                  color: userRank == 1
                                      ? Colors.amber
                                      : userRank == 2
                                      ? Colors.grey[400]
                                      : Colors.brown[300],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${score ?? 0}/$totalQuestions benar • Rank #$userRank',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (roomCode != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Room: $roomCode',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$score dari $totalQuestions',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${((score ?? 0) / (totalQuestions ?? 1) * 100).toStringAsFixed(0)}% benar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (durationInSeconds != null && durationInSeconds > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer, size: 14, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(durationInSeconds),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              if (historyItem['quiz_data_json'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Tap untuk lihat detail',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.primaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: theme.primaryColor,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
