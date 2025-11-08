import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:quizverse/models/quiz_model.dart';
import 'package:quizverse/models/category_model.dart';

class QuizService {
  final String _baseUrl = 'https://opentdb.com';

  Future<List<CategoryModel>> fetchCategories() async {
    final url = Uri.parse('$_baseUrl/api_category.php');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('trivia_categories')) {
          final List categoriesList = data['trivia_categories'];

          return categoriesList
              .map((catJson) => CategoryModel.fromJson(catJson))
              .toList();
        } else {
          throw Exception('Format API kategori tidak valid.');
        }
      } else {
        throw Exception('Gagal memuat kategori: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Gagal memuat kategori: ${e.toString()}');
    }
  }

  Future<List<QuizModel>> fetchQuizData({
    required int amount,
    required String category,
    required String difficulty,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/api.php?amount=$amount&category=$category&difficulty=$difficulty&type=multiple', // sebenernya bisa milih antara true of false atau multiple
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['response_code'] == 0) {
        List questions = data['results'];
        return questions.map((v) => QuizModel.fromJson(v)).toList();
      } else {
        throw Exception('No questions found for these settings');
      }
    } else {
      throw Exception('FETCH API FALIED!');
    }
  }
}
