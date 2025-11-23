import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import 'package:quizverse/models/room_model.dart';
import 'package:quizverse/services/multiplayer_service.dart';

class LeaderboardView extends StatefulWidget {
  final RoomModel room;
  final Map<int, String?> userAnswers;

  const LeaderboardView({
    super.key,
    required this.room,
    required this.userAnswers,
  });

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  final MultiplayerService _multiplayerService = MultiplayerService();
  late ConfettiController _confettiController;

  List<RoomParticipant> _leaderboard = [];
  int _userRank = 0;
  RoomParticipant? _currentUserData;
  bool _isSavingHistory = false;
  bool _historySaved = false;
  bool _confettiPlayed = false;

  StreamSubscription<RoomModel>? _roomSubscription;
  RoomModel? _latestRoom;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _latestRoom = widget.room;
    _prepareLeaderboard(widget.room);

    _listenToRoomUpdates();
  }

  void _listenToRoomUpdates() {
    _roomSubscription = _multiplayerService
        .getRoomStream(widget.room.roomId)
        .listen((updatedRoom) {
          if (!mounted) return;

          setState(() {
            _latestRoom = updatedRoom;
            _prepareLeaderboard(updatedRoom);
          });

          if (updatedRoom.status == RoomStatus.finished && !_historySaved) {
            _saveHistory(updatedRoom);
          }
        });
  }

  void _prepareLeaderboard(RoomModel room) {
    _leaderboard = _multiplayerService.getLeaderboard(room);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _userRank = _leaderboard.indexWhere((p) => p.userId == userId) + 1;
      _currentUserData = _leaderboard.firstWhere(
        (p) => p.userId == userId,
        orElse: () => _leaderboard.first,
      );

      if (_userRank <= 3 && _userRank > 0 && !_confettiPlayed) {
        _confettiPlayed = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _confettiController.play();
        });
      }
    }
  }

  Future<void> _saveHistory(RoomModel finalRoom) async {
    if (_isSavingHistory || _historySaved) return;

    setState(() => _isSavingHistory = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || _currentUserData == null) return;

      final quizDuration =
          finalRoom.finishedAt != null && finalRoom.startedAt != null
          ? finalRoom.finishedAt!.difference(finalRoom.startedAt!).inSeconds
          : 0;

      String? answersJson;
      try {
        final Map<String, String?> stringKeyedAnswers = widget.userAnswers.map((
          key,
          value,
        ) {
          return MapEntry(key.toString(), value);
        });
        answersJson = jsonEncode(stringKeyedAnswers);
      } catch (e) {
        debugPrint("Gagal encode user answers ke JSON: $e");
      }

      await _multiplayerService.saveMultiplayerHistory(
        userId: userId,
        room: finalRoom,
        userScore: _currentUserData!.score,
        userCorrectAnswers: _currentUserData!.correctAnswers,
        userRank: _userRank,
        duration: quizDuration,
        userAnswersJson: answersJson,
      );

      debugPrint('Multiplayer history saved successfully');

      setState(() {
        _historySaved = true;
      });
    } catch (e) {
      debugPrint('Error saving history: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingHistory = false);
      }
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _roomSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayRoom = _latestRoom ?? widget.room;

    return WillPopScope(
      onWillPop: () async {
        return displayRoom.status == RoomStatus.finished;
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('Leaderboard'),
              automaticallyImplyLeading:
                  displayRoom.status == RoomStatus.finished,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (displayRoom.status != RoomStatus.finished)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Menunggu pemain lain...',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ranking akan berubah saat semua pemain selesai',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  Icon(
                    Icons.emoji_events,
                    size: 80,
                    color: _userRank == 1
                        ? Colors.amber
                        : _userRank == 2
                        ? Colors.grey[400]
                        : _userRank == 3
                        ? Colors.brown[300]
                        : colorScheme.primary,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    _userRank == 1
                        ? '🎉 Selamat, Anda Juara! 🎉'
                        : _userRank <= 3
                        ? '🎊 Hebat! Posisi $_userRank 🎊'
                        : 'Quiz Selesai!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  if (_currentUserData != null)
                    Card(
                      color: colorScheme.primary.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  'Peringkat',
                                  '#$_userRank',
                                  Icons.military_tech,
                                ),
                                _buildStatItem(
                                  'Skor',
                                  '${_currentUserData!.score}',
                                  Icons.star,
                                ),
                                _buildStatItem(
                                  'Benar',
                                  '${_currentUserData!.correctAnswers}/${displayRoom.questionAmount}',
                                  Icons.check_circle,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  Text(
                    'Ranking Pemain',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_leaderboard.length >= 3) _buildPodium(displayRoom),
                  const SizedBox(height: 16),

                  ..._leaderboard.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final participant = entry.value;
                    final isCurrentUser =
                        participant.userId ==
                        FirebaseAuth.instance.currentUser?.uid;

                    return _buildLeaderboardCard(
                      rank: rank,
                      participant: participant,
                      isCurrentUser: isCurrentUser,
                      theme: theme,
                      room: displayRoom,
                    );
                  }).toList(),

                  const SizedBox(height: 24),

                  if (displayRoom.status == RoomStatus.finished)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('Kembali ke Home'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tombol akan muncul setelah semua pemain selesai',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 30,
              gravity: 0.3,
              emissionFrequency: 0.05,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.amber,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildPodium(RoomModel room) {
    final first = _leaderboard[0];
    final second = _leaderboard.length > 1 ? _leaderboard[1] : null;
    final third = _leaderboard.length > 2 ? _leaderboard[2] : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (second != null)
              _buildPodiumItem(
                participant: second,
                rank: 2,
                height: 80,
                color: Colors.grey[400]!,
              ),

            _buildPodiumItem(
              participant: first,
              rank: 1,
              height: 120,
              color: Colors.amber,
            ),

            if (third != null)
              _buildPodiumItem(
                participant: third,
                rank: 3,
                height: 60,
                color: Colors.brown[300]!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumItem({
    required RoomParticipant participant,
    required int rank,
    required double height,
    required Color color,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withOpacity(0.2),
          backgroundImage: participant.profilePhotoUrl != null
              ? NetworkImage(participant.profilePhotoUrl!)
              : null,
          child: participant.profilePhotoUrl == null
              ? Icon(Icons.person, size: 30, color: color)
              : null,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            participant.username,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${participant.score} pts',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard({
    required int rank,
    required RoomParticipant participant,
    required bool isCurrentUser,
    required ThemeData theme,
    required RoomModel room,
  }) {
    Color rankColor;
    IconData rankIcon;

    if (rank == 1) {
      rankColor = Colors.amber;
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = Colors.brown[300]!;
      rankIcon = Icons.emoji_events;
    } else {
      rankColor = Colors.grey[600]!;
      rankIcon = Icons.person;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentUser ? 4 : 1,
      color: isCurrentUser ? theme.primaryColor.withOpacity(0.1) : null,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: rankColor, width: 2),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              backgroundImage: participant.profilePhotoUrl != null
                  ? NetworkImage(participant.profilePhotoUrl!)
                  : null,
              child: participant.profilePhotoUrl == null
                  ? Icon(Icons.person, color: theme.primaryColor)
                  : null,
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                participant.username,
                style: TextStyle(
                  fontWeight: isCurrentUser
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Anda',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${participant.correctAnswers}/${room.questionAmount} benar',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${participant.score}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'poin',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
