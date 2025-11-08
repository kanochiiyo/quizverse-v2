import 'package:html_unescape/html_unescape.dart';

class QuizModel {
  final String type;
  final String difficulty;
  final String category;
  final String question;
  final String correctAnswer;
  final List<String> incorrectAnswers;

  // Constructor
  QuizModel({
    required this.type,
    required this.difficulty,
    required this.category,
    required this.question,
    required this.correctAnswer,
    required this.incorrectAnswers,
  });

  // biar dibuat cuman sekali agar tiap generate jadi 1 aja, kalo misalnya ga pake static, ketika API mengembalikan 10 soal, ada 10 ohjek HtmlUnescape
  static final _unescape = HtmlUnescape();

  // buat ngubah dari JSON jadi map karena Dart cuman bisa baca map
  factory QuizModel.fromJson(Map<String, dynamic> json) {
    // ambil incorrect_answers karena itu isinya banyak data
    var incorrectAnswersList = json['incorrect_answers'] as List;
    List<String> incorrectAnswers = incorrectAnswersList
        .map((answer) => _unescape.convert(answer))
        .toList();

    return QuizModel(
      // Decode semua string yang mungkin berisi HTML entities
      type: _unescape.convert(json['type']),
      difficulty: _unescape.convert(json['difficulty']),
      category: _unescape.convert(json['category']),
      question: _unescape.convert(json['question']),
      correctAnswer: _unescape.convert(json['correct_answer']),
      incorrectAnswers: incorrectAnswers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'difficulty': difficulty,
      'category': category,
      'question': question,
      'correct_answer': correctAnswer,
      'incorrect_answers': incorrectAnswers,
    };
  }
}
