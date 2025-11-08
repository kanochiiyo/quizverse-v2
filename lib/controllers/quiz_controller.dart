import 'package:quizverse/models/category_model.dart';
import 'package:quizverse/models/quiz_model.dart';
import 'package:quizverse/services/quiz_service.dart';

class QuizController {
  final QuizService _service = QuizService();

  Future<List<CategoryModel>> loadCategories() async {
    final categories = await _service.fetchCategories();
    categories.sort((a, b) => a.name.compareTo(b.name));
    return categories;
  }

  Future<List<QuizModel>> loadQuestions({
    required int amount,
    required String category,
    required String difficulty,
  }) async {
    // Get quiz data from API service
    return await _service.fetchQuizData(
      amount: amount,
      category: category,
      difficulty: difficulty,
    );
  }
}
