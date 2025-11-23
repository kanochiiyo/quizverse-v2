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
        // ⬇️ kirim lokasi dari participant
        latitude: _currentUserData!.latitude,
        longitude: _currentUserData!.longitude,
        address: _currentUserData!.address,
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
                  const SizedBox(height: 16),

                  if (_currentUserData != null)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 30,
                                    backgroundImage:
                                        _currentUserData!.profilePhotoUrl !=
                                            null
                                        ? NetworkImage(
                                            _currentUserData!.profilePhotoUrl!,
                                          )
                                        : null,
                                    backgroundColor: Colors.white,
                                    child:
                                        _currentUserData!.profilePhotoUrl ==
                                            null
                                        ? Icon(
                                            Icons.person,
                                            size: 35,
                                            color: colorScheme.primary,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentUserData!.username,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Text(
                                          'Statistik Anda',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            Container(
                              height: 1,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildImprovedStatItem(
                                  'Peringkat',
                                  '#$_userRank',
                                  Icons.military_tech,
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                _buildImprovedStatItem(
                                  'Skor',
                                  '${_currentUserData!.score}',
                                  Icons.star,
                                ),
                                Container(
                                  width: 1,
                                  height: 50,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                _buildImprovedStatItem(
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

  Widget _buildImprovedStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
        ),
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

    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
    } else if (rank == 3) {
      rankColor = Colors.brown[300]!;
    } else {
      rankColor = Colors.grey[600]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: theme.colorScheme.primary, width: 2.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: isCurrentUser
                ? theme.colorScheme.primary.withOpacity(0.2)
                : Colors.black.withOpacity(0.05),
            blurRadius: isCurrentUser ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                  fontSize: isCurrentUser ? 16 : 15,
                ),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Anda',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${participant.correctAnswers}/${room.questionAmount} benar',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${participant.score}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
