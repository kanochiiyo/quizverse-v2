import 'package:flutter/material.dart';
import 'package:quizverse/models/achievement_model.dart';
import 'package:quizverse/services/firestore_service.dart';

class AchievementService {
  final FirestoreService _firestoreService = FirestoreService();

  List<AchievementModel> get allAchievements => [
    AchievementModel(
      id: 'first_quiz',
      title: 'First Steps',
      description: 'Selesaikan quiz pertamamu',
      icon: '🎯',
      requiredValue: 1,
    ),
    AchievementModel(
      id: 'quiz_10',
      title: 'Quiz Enthusiast',
      description: 'Selesaikan 10 quiz',
      icon: '🌟',
      requiredValue: 10,
    ),
    AchievementModel(
      id: 'quiz_50',
      title: 'Quiz Master',
      description: 'Selesaikan 50 quiz',
      icon: '👑',
      requiredValue: 50,
    ),
    AchievementModel(
      id: 'quiz_100',
      title: 'Quiz Legend',
      description: 'Selesaikan 100 quiz',
      icon: '🏆',
      requiredValue: 100,
    ),
    AchievementModel(
      id: 'perfect_score',
      title: 'Perfectionist',
      description: 'Dapatkan skor sempurna (100%)',
      icon: '💯',
      requiredValue: 1,
    ),
    AchievementModel(
      id: 'perfect_5',
      title: 'Flawless',
      description: 'Dapatkan 5 skor sempurna',
      icon: '✨',
      requiredValue: 5,
    ),
    AchievementModel(
      id: 'all_categories',
      title: 'Explorer',
      description: 'Coba semua kategori quiz',
      icon: '🗺️',
      requiredValue: 24,
    ),
    AchievementModel(
      id: 'speed_demon',
      title: 'Speed Demon',
      description: 'Selesaikan quiz dalam 1 menit',
      icon: '⚡',
      requiredValue: 1,
    ),
    AchievementModel(
      id: 'hard_mode',
      title: 'Challenge Accepted',
      description: 'Selesaikan 10 quiz dengan tingkat Hard',
      icon: '🔥',
      requiredValue: 10,
    ),
  ];

  Future<List<AchievementModel>> getUserAchievements(String userId) async {
    try {
      final achievements = await _firestoreService.getUserAchievements(
        userId,
        allAchievements,
      );
      return achievements;
    } catch (e) {
      debugPrint("Error getting user achievements: $e");
      return allAchievements;
    }
  }

  Future<List<AchievementModel>> recalculateAndSaveProgress(
    String userId,
  ) async {
    try {
      final history = await _firestoreService.getQuizHistory(userId);

      final savedAchievements = await getUserAchievements(userId);

      final finalAchievements = <AchievementModel>[];

      for (var template in allAchievements) {
        final saved = savedAchievements.firstWhere(
          (a) => a.id == template.id,
          orElse: () => template,
        );

        if (saved.isUnlocked) {
          finalAchievements.add(saved);
          continue;
        }

        int currentValue = 0;

        switch (template.id) {
          case 'first_quiz':
          case 'quiz_5':
          case 'quiz_10':
          case 'quiz_50':
          case 'quiz_100':
            currentValue = history.length;
            break;

          case 'perfect_score':
          case 'perfect_5':
            currentValue = history.where((h) {
              final score = h['score'] as int? ?? 0;
              final total = h['total_questions'] as int? ?? 0;

              return total > 0 && score == total;
            }).length;
            break;

          case 'all_categories':
            final uniqueCategories = history
                .map((h) => h['category'] as String?)
                .where((c) => c != null)
                .toSet()
                .length;
            currentValue = uniqueCategories;
            break;

          case 'speed_demon':
            currentValue = history.where((h) {
              final duration = h['duration'] as int? ?? 0;
              return duration <= 60;
            }).length;
            break;

          case 'hard_mode':
            currentValue = history.where((h) {
              final difficulty = h['difficulty'] as String? ?? '';
              return difficulty.toLowerCase() == 'hard';
            }).length;
            break;
        }

        final bool isNowUnlocked = currentValue >= template.requiredValue;

        finalAchievements.add(
          template.copyWith(
            currentValue: currentValue,
            isUnlocked: isNowUnlocked,
            unlockedAt: isNowUnlocked ? DateTime.now() : null,
          ),
        );
      }

      await _firestoreService.saveUserAchievements(userId, finalAchievements);

      return finalAchievements;
    } catch (e) {
      debugPrint("Error recalculating achievements: $e");
      return allAchievements;
    }
  }

  Future<List<AchievementModel>> getNewlyUnlockedAchievements(
    String userId,
    List<AchievementModel> previousAchievements,
  ) async {
    final currentAchievements = await recalculateAndSaveProgress(userId);

    final newlyUnlocked = <AchievementModel>[];

    for (var i = 0; i < currentAchievements.length; i++) {
      final current = currentAchievements[i];

      final previous = previousAchievements.firstWhere(
        (a) => a.id == current.id,
        orElse: () => current,
      );

      if (current.isUnlocked && !previous.isUnlocked) {
        newlyUnlocked.add(current);
      }
    }

    return newlyUnlocked;
  }

  Map<String, int> getAchievementStats(List<AchievementModel> achievements) {
    final unlocked = achievements.where((a) => a.isUnlocked).length;
    final total = achievements.length;

    final percentage = (total == 0) ? 0 : ((unlocked / total) * 100).round();

    return {'unlocked': unlocked, 'total': total, 'percentage': percentage};
  }
}
