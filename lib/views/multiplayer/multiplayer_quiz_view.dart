import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quizverse/models/room_model.dart';
import 'package:quizverse/models/quiz_model.dart';
import 'package:quizverse/services/multiplayer_service.dart';
import 'package:quizverse/views/multiplayer/leaderboard_view.dart';

class MultiplayerQuizView extends StatefulWidget {
  final RoomModel room;
  final Position? userLocation;
  final String? userAddress;

  const MultiplayerQuizView({
    super.key,
    required this.room,
    this.userLocation,
    this.userAddress,
  });

  @override
  State<MultiplayerQuizView> createState() => _MultiplayerQuizViewState();
}

class _MultiplayerQuizViewState extends State<MultiplayerQuizView> {
  final MultiplayerService _multiplayerService = MultiplayerService();

  List<QuizModel> _questions = [];
  int _currentIndex = 0;
  String? _selectedAnswer;
  final Map<int, String?> _userAnswers = {};
  final Map<int, int> _questionTimes = {};
  late List<String> _shuffledAnswers;

  bool _isSubmitting = false;
  late DateTime _quizStartTime;
  late DateTime _questionStartTime;
  Timer? _questionTimer;
  static const int _maxDurationPerQuestion = 15;
  int _timerSecond = _maxDurationPerQuestion;

  StreamSubscription<RoomModel>? _roomSubscription;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _quizStartTime = DateTime.now();
    _questionStartTime = DateTime.now();
    _startQuestionTimer();
    _listenToRoom();
  }

  void _listenToRoom() {
    _roomSubscription = _multiplayerService
        .getRoomStream(widget.room.roomId)
        .listen((room) {
          if (room.status == RoomStatus.finished) {
            _navigateToLeaderboard(room);
          }
        });
  }

  void _loadQuestions() {
    try {
      if (widget.room.quizDataJson != null) {
        final List<dynamic> decoded = jsonDecode(widget.room.quizDataJson!);
        _questions = decoded.map((q) => QuizModel.fromJson(q)).toList();

        if (_questions.isNotEmpty) {
          _setupQuestion();
        }
      }
    } catch (e) {
      debugPrint('Error loading questions: $e');
    }
  }

  void _setupQuestion() {
    final q = _questions[_currentIndex];
    _shuffledAnswers = [q.correctAnswer, ...q.incorrectAnswers];
    _shuffledAnswers.shuffle();
    _selectedAnswer = _userAnswers[_currentIndex];
    _questionStartTime = DateTime.now();
  }

  void _nextQuestion() {
    final timeTaken = DateTime.now().difference(_questionStartTime).inSeconds;
    _questionTimes[_currentIndex] = timeTaken;

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _setupQuestion();
      });
      _startQuestionTimer();
    } else {
      _submitQuiz();
    }
  }

  void _startQuestionTimer() {
    _timerSecond = _maxDurationPerQuestion;
    _questionTimer?.cancel();

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_timerSecond > 0) {
        setState(() {
          _timerSecond--;
        });
      } else {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _userAnswers.putIfAbsent(_currentIndex, () => null);

    if (_currentIndex < _questions.length - 1) {
      _nextQuestion();
    } else {
      _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    _questionTimer?.cancel();
    setState(() => _isSubmitting = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User tidak ditemukan');

      int correctAnswers = 0;
      int totalScore = 0;

      for (int i = 0; i < _questions.length; i++) {
        if (_userAnswers[i] == _questions[i].correctAnswer) {
          correctAnswers++;

          final timeTaken = _questionTimes[i] ?? _maxDurationPerQuestion;
          final timeBonus =
              (((_maxDurationPerQuestion - timeTaken) /
                          _maxDurationPerQuestion) *
                      50)
                  .round();
          final questionScore = 100 + timeBonus.clamp(0, 50);

          totalScore += questionScore;
        }
      }

      // Kirim score beserta data lokasi
      await _multiplayerService.updateParticipantScore(
        roomId: widget.room.roomId,
        userId: userId,
        score: totalScore,
        correctAnswers: correctAnswers,
        latitude: widget.userLocation?.latitude,
        longitude: widget.userLocation?.longitude,
        address: widget.userAddress,
      );

      debugPrint('Quiz submitted with location. Waiting for other players...');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateToLeaderboard(RoomModel room) {
    _roomSubscription?.cancel();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              LeaderboardView(room: room, userAnswers: _userAnswers),
        ),
      );
    }
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _roomSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Gagal memuat pertanyaan. Silakan coba lagi.'),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Soal ${_currentIndex + 1} dari ${_questions.length}'),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTimerWidget(theme),
              const SizedBox(height: 24),

              if (_isSubmitting)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Menunggu pemain lain menyelesaikan quiz...',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  q.question,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),

              ...(_shuffledAnswers.map((answer) {
                return _buildAnswerTile(answer, theme);
              }).toList()),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 24.0,
          ),
          child: ElevatedButton.icon(
            onPressed: _isSubmitting
                ? null
                : (_currentIndex < _questions.length - 1
                      ? _nextQuestion
                      : _submitQuiz),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Icon(
                    _currentIndex < _questions.length - 1
                        ? Icons.navigate_next
                        : Icons.check,
                  ),
            label: Text(
              _isSubmitting
                  ? "Mengirim..."
                  : (_currentIndex < _questions.length - 1
                        ? "Lanjut"
                        : "Selesai"),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerWidget(ThemeData theme) {
    final double progressPercent = _timerSecond / _maxDurationPerQuestion;
    final bool isCritical = _timerSecond <= 5;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Waktu Tersisa",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(179),
                ),
              ),
              Text(
                "${_timerSecond}s",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isCritical
                      ? Colors.redAccent
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progressPercent,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                isCritical ? Colors.redAccent : theme.colorScheme.primary,
              ),
              minHeight: 10.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerTile(String answer, ThemeData theme) {
    final bool isSelected = _selectedAnswer == answer;
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isSelected ? 4.0 : 1.5,
      color: isSelected ? colorScheme.primary.withAlpha(26) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.grey.shade300,
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: _isSubmitting
            ? null
            : () {
                setState(() {
                  _selectedAnswer = answer;
                  _userAnswers[_currentIndex] = answer;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  answer,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
