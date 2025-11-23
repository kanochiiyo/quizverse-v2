import 'dart:convert';
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quizverse/controllers/auth_controller.dart';
import 'package:quizverse/models/quiz_model.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:quizverse/services/firestore_service.dart';
import 'package:quizverse/services/notification_service.dart';

class QuizView extends StatefulWidget {
  final List<QuizModel> questions;
  const QuizView({super.key, required this.questions});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  // State controller
  final FirestoreService _firestoreService = FirestoreService();
  final AuthController _authController = AuthController();
  late ConfettiController _confettiController;

  int _curIndex = 0;
  String? selectedAnswer;
  final Map<int, String?> _userAnswers = {};
  late List<String> _shuffledAnswers;
  Position? _currentPosition;
  bool _isSubmitting = false;
  late DateTime _quizStartTime;
  Timer? _questionTimer;
  static const int _maxDurationPerQuestion = 15;
  int _timerSecond = _maxDurationPerQuestion;

  @override
  void initState() {
    super.initState();
    if (widget.questions.isNotEmpty) {
      // Kalo soal berhasil diambil, panggil fungsi untuk mengambil tiap item soal
      _setupQuestion();
    }
    // Simpan kapan quiz dimulai dengan fungsi DateTime
    _quizStartTime = DateTime.now();
    // Mulai timer
    _startQuestionTimer();

    // Setup controller conffeti ketika user selesai submit quiz
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
  }

  void _setupQuestion() {
    // Panggil soal sesuai index
    final q = widget.questions[_curIndex];
    // Acak jawaban yang didapat dari API, ambil dulu data jawaban benar dan salah, lalu acak
    _shuffledAnswers = [q.correctAnswer, ...q.incorrectAnswers];
    _shuffledAnswers.shuffle();
    // Perbarui jawaban user berdasarkan jawaban di soal sesuai index
    selectedAnswer = _userAnswers[_curIndex];
  }

  void nextQuestion() {
    // Kalo soalnya masih ada, increment index dan build soal lagi, jangan lupa ulang lagi timernya dengan manggil startQuestionTimer
    if (_curIndex < widget.questions.length - 1) {
      setState(() {
        _curIndex++;
        _setupQuestion();
      });
      _startQuestionTimer();
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        debugPrint(
          "Location obtained: ${position.latitude}, ${position.longitude}",
        );
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapatkan lokasi: ${e.toString()}')),
        );
      }
    }
  }

  // BAGIAN submitQuiz() yang diperbaiki
  // Letakkan di lib/views/home/quiz_view.dart

  void submitQuiz() async {
    final quizDuration = DateTime.now().difference(_quizStartTime);
    final int durationInSeconds = quizDuration.inSeconds;

    _questionTimer?.cancel();

    setState(() => _isSubmitting = true);

    int score = 0;

    for (int i = 0; i < widget.questions.length; i++) {
      if (_userAnswers[i] == widget.questions[i].correctAnswer) {
        score++;
      }
    }

    if (_currentPosition == null) {
      await _getCurrentLocation();
    }

    String? address;

    if (_currentPosition != null) {
      try {
        List<geocoding.Placemark> placemarks = await geocoding
            .placemarkFromCoordinates(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
            );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          address =
              "${placemark.subLocality}, ${placemark.locality}, ${placemark.subAdministrativeArea}";
          address = address
              .replaceAll("null, ", "")
              .replaceAll("Kecamatan ", "");
          debugPrint("Address obtained: $address");
        }
      } catch (e) {
        debugPrint("Error getting address from geocoding: $e");
        address = null;
      }
    }

    String? questionsJson;
    try {
      List<Map<String, dynamic>> questionsMap = widget.questions
          .map((q) => q.toJson())
          .toList();

      questionsJson = jsonEncode(questionsMap);
    } catch (e) {
      debugPrint("Gagal encode questions ke JSON: $e");
    }

    String? answersJson;
    try {
      final Map<String, String?> stringKeyedAnswers = _userAnswers.map((
        key,
        value,
      ) {
        return MapEntry(key.toString(), value);
      });
      answersJson = jsonEncode(stringKeyedAnswers);
    } catch (e) {
      debugPrint("Gagal encode user answers ke JSON: $e");
    }

    // Variable untuk menyimpan historyId
    String? savedHistoryId;

    try {
      final String? userId = _authController.firebaseUser?.uid;
      if (userId != null && widget.questions.isNotEmpty) {
        savedHistoryId = await _firestoreService.saveQuizResult(
          userId: userId,
          category: widget.questions.first.category,
          difficulty: widget.questions.first.difficulty,
          score: score,
          duration: durationInSeconds,
          totalQuestions: widget.questions.length,
          latitude: _currentPosition?.latitude,
          longitude: _currentPosition?.longitude,
          address: address,
          quizDataJson: questionsJson,
          userAnswersJson: answersJson,
        );

        debugPrint(
          "Quiz result saved successfully! History ID: $savedHistoryId",
        );
      } else {
        debugPrint(
          "User ID not found or questions empty, couldn't save history.",
        );
      }
    } catch (e) {
      debugPrint("Error saving quiz result: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan riwayat: ${e.toString()}')),
        );
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }

    // ========== KIRIM NOTIFIKASI ==========
    // Kirim notifikasi SETELAH save berhasil dan SEBELUM dialog
    if (savedHistoryId != null) {
      try {
        await NotificationService().showQuizResultNotification(
          savedHistoryId,
          score,
          widget.questions.length,
        );
        debugPrint("✅ Notification sent successfully!");
      } catch (notifError) {
        debugPrint("❌ Error sending notification: $notifError");
        // Tidak throw error agar dialog tetap muncul
      }
    } else {
      debugPrint("⚠️ Cannot send notification: historyId is null");
    }
    // ======================================

    _confettiController.play();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Kuis Selesai!"),
        content: Text("Skor Anda: $score dari ${widget.questions.length}"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Widget helper untuk list jawaban
  Widget _buildAnswerTile(String answer) {
    final bool isSelected = selectedAnswer == answer;
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 4.0 : 1.5,
      color: isSelected ? theme.primaryColor.withAlpha(26) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? theme.primaryColor : Colors.grey.shade300,
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedAnswer = answer;
            _userAnswers[_curIndex] = answer;
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
                Icon(Icons.check_circle, color: theme.primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // WIdget helper untuk timer
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

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Gagal memuat pertanyaan. Silakan coba lagi.'),
        ),
      );
    }

    final q = widget.questions[_curIndex];
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              'Soal ${_curIndex + 1} dari ${widget.questions.length}',
            ),
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [
                _buildTimerWidget(theme),
                const SizedBox(height: 24),

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
                  // Question
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
                ..._shuffledAnswers.map((answer) {
                  return _buildAnswerTile(answer);
                }),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Kalo mau dibikin rata kanan (hapus expanded)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : (_curIndex < widget.questions.length - 1
                              ? nextQuestion
                              : submitQuiz),
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
                            _curIndex < widget.questions.length - 1
                                ? Icons.navigate_next
                                : Icons.check,
                          ),
                    label: Text(
                      _isSubmitting
                          ? "Menyimpan..."
                          : (_curIndex < widget.questions.length - 1
                                ? "Lanjut"
                                : "Selesai"),
                    ),
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
            numberOfParticles: 20,
            gravity: 0.3,
            emissionFrequency: 0.05,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
            ],
          ),
        ),
      ],
    );
  }

  void _startQuestionTimer() {
    // Bikin timer sesuai maks durasi per soal
    _timerSecond = _maxDurationPerQuestion;

    // Batalkan timer soal sebelumnya (kalo ada, makanya pake ?, kalo soal pertama ya berarti nanti diskip)
    _questionTimer?.cancel();

    // Setup timer dengan interval 1 detik, dia bakal update UI / panggil callback timer
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Kalo widgetnya dah ilang (misal user pencet back ke halaman lain), cancel timer
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Ketika timernya masih berjalan, decrement
      if (_timerSecond > 0) {
        setState(() {
          _timerSecond--;
        });
      } else {
        timer.cancel();

        // Ketika timernya dah habis, handle TO
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    // Kalo ternyata timer dah abis tapi user ga jawab, set jawaban ke null (berarti ga terjawab)
    _userAnswers.putIfAbsent(_curIndex, () => null);

    // Kalo misal index yg sekarang masih lebih kecil dari index max soal (soalnya belum sampe akhir)
    if (_curIndex < widget.questions.length - 1) {
      // Panggil nextQuestion
      nextQuestion();
    } else {
      // Kalo ternyata udah soal terakhir, langsung submit paksa
      submitQuiz();
    }
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }
}
