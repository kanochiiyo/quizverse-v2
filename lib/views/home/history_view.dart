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

  @override
  void initState() {
    super.initState();
    _loadHistory();

    _searchController.addListener(() {
      _filterHistory(_searchController.text);
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
          _filteredHistory = history;
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

  void _filterHistory(String query) {
    final lowerCaseQuery = query.toLowerCase();

    final filteredList = _quizHistory.where((item) {
      final category = (item['category'] as String?)?.toLowerCase() ?? '';
      final difficulty = (item['difficulty'] as String?)?.toLowerCase() ?? '';
      final address = (item['address'] as String?)?.toLowerCase() ?? '';
      final roomCode = (item['room_code'] as String?)?.toLowerCase() ?? '';

      return category.contains(lowerCaseQuery) ||
          difficulty.contains(lowerCaseQuery) ||
          address.contains(lowerCaseQuery) ||
          roomCode.contains(lowerCaseQuery);
    }).toList();

    setState(() {
      _filteredHistory = filteredList;
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Tanggal tidak diketahui';
    try {
      final isoUtcString = "${dateString.replaceFirst(' ', 'T')}Z";
      final utcDateTime = DateTime.parse(isoUtcString);
      final localDateTime = utcDateTime.toLocal();

      return DateFormat('EEE, d MMM yyyy HH:mm', 'id_ID').format(localDateTime);
    } catch (e) {
      return dateString;
    }
  }

  String _formatDuration(int? totalSeconds) {
    if (totalSeconds == null || totalSeconds < 0) {
      return '?';
    }
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes;
    final seconds = totalSeconds % 60;

    String durationString = '';
    if (minutes > 0) {
      durationString += '${minutes}m ';
    }
    durationString += '${seconds}d';
    return durationString;
  }

  String capitalize(String s) => s[0].toUpperCase() + s.substring(1);

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey[700]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color ?? Colors.grey[700],
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Kuis'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari kategori, kesulitan, kode room...',
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
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_quizHistory.isEmpty) {
      return const Center(child: Text('Belum ada riwayat kuis.'));
    }

    if (_filteredHistory.isEmpty) {
      return const Center(
        child: Text('Tidak ada riwayat yang cocok dengan pencarian.'),
      );
    }

    return ListView.builder(
      itemCount: _filteredHistory.length,
      itemBuilder: (context, index) {
        final historyItem = _filteredHistory[index];

        final score = historyItem['score'] as int?;
        final totalQuestions = historyItem['total_questions'] as int?;
        final category = historyItem['category'] as String?;
        final difficulty = historyItem['difficulty'] as String?;
        final date = historyItem['quiz_date'] as String?;
        final latitude = historyItem['latitude'] as double?;
        final longitude = historyItem['longitude'] as double?;
        final address = historyItem['address'] as String?;
        final durationInSeconds = historyItem['duration'] as int?;

        final isMultiplayer = historyItem['is_multiplayer'] as bool? ?? false;
        final roomCode = historyItem['room_code'] as String?;
        final totalPlayers = historyItem['total_players'] as int?;
        final userRank = historyItem['user_rank'] as int?;
        final multiplayerScore = historyItem['multiplayer_score'] as int?;

        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: Stack(
                children: [
                  Icon(
                    isMultiplayer ? Icons.groups : Icons.history_edu,
                    color: isMultiplayer ? Colors.green : theme.primaryColor,
                    size: 36,
                  ),
                  if (isMultiplayer && userRank != null && userRank <= 3)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: userRank == 1
                              ? Colors.amber
                              : userRank == 2
                              ? Colors.grey[400]
                              : Colors.brown[300],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.emoji_events,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      category ?? 'Kategori Tidak Diketahui',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isMultiplayer)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: const Text(
                        'MULTI',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  _buildInfoRow(
                    Icons.layers_outlined,
                    'Kesulitan: ${difficulty != null ? capitalize(difficulty) : '?'}',
                  ),
                  _buildInfoRow(
                    Icons.calendar_today_outlined,
                    _formatDate(date),
                  ),
                  if (durationInSeconds != null && durationInSeconds > 0)
                    _buildInfoRow(
                      Icons.timer_outlined,
                      "Durasi: ${_formatDuration(durationInSeconds)}",
                    ),

                  if (isMultiplayer) ...[
                    if (roomCode != null)
                      _buildInfoRow(
                        Icons.tag,
                        'Room: $roomCode',
                        color: Colors.green,
                      ),
                    if (totalPlayers != null)
                      _buildInfoRow(
                        Icons.people,
                        '$totalPlayers pemain',
                        color: Colors.blue,
                      ),
                    if (userRank != null)
                      _buildInfoRow(
                        Icons.military_tech,
                        'Peringkat #$userRank',
                        color: userRank <= 3 ? Colors.amber : Colors.grey[600],
                      ),
                  ] else ...[
                    if (address != null && address.isNotEmpty)
                      _buildInfoRow(Icons.location_on_outlined, address)
                    else if (latitude != null && longitude != null)
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                      ),
                  ],

                  if (historyItem['quiz_data_json'] != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6.0),
                      child: Text(
                        'Klik untuk lihat detail...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label: Text(
                      isMultiplayer && multiplayerScore != null
                          ? '$multiplayerScore pts'
                          : '${score ?? '?'} / ${totalQuestions ?? '?'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: isMultiplayer
                        ? Colors.green
                        : theme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                  ),
                  if (isMultiplayer)
                    Text(
                      '${score ?? 0}/${totalQuestions ?? 0} benar',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                ],
              ),
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
            ),
          ),
        );
      },
    );
  }
}
