import 'package:flutter/material.dart';
import 'package:quizverse/models/achievement_model.dart';
import 'package:quizverse/services/database_service.dart';

class AchievementService {
  final DatabaseService _databaseService = DatabaseService();

  // Getter template List Achievement saat ini yang tersedia
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
      requiredValue: 24, // Total kategori dari API
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

  // Ambil user achievement dari DB
  Future<List<AchievementModel>> getUserAchievements(int userId) async {
    try {
      final achievements = await _databaseService.getUserAchievements(
        userId,
        allAchievements,
      );
      return achievements;
    } catch (e) {
      debugPrint("Error getting user achievements: $e");
      return allAchievements;
    }
  }

  // Kalkulasi ulang progress user
  Future<List<AchievementModel>> recalculateAndSaveProgress(int userId) async {
    try {
      // Ambil riwayat quiz yang udah diselesaikan oleh user
      final history = await _databaseService.getQuizHistory(userId);

      // Ambil dulu achievement yang user udah punya dan juga progressnya
      final savedAchievements = await getUserAchievements(userId);

      final finalAchievements = <AchievementModel>[];

      // Update berdasdarkan data yang udah diambil tadi
      for (var template in allAchievements) {
        // Kita bikin variabel saved terus
        final saved = savedAchievements.firstWhere(
          (a) => a.id == template.id,
          orElse: () => template, // Gunakan template jika tidak ada
        );

        // Kalo udah ke-unlocked, skip aja
        if (saved.isUnlocked) {
          finalAchievements.add(saved);
          continue; // Lanjut ke achievement berikutnya
        }

        // Untuk update nilainya
        int currentValue = 0;
        // Ini untuk achievement tentang berapa quiz yang udah diselesaikan
        switch (template.id) {
          case 'first_quiz':
          case 'quiz_5':
          case 'quiz_10':
          case 'quiz_50':
          case 'quiz_100':
            currentValue = history.length;
            break;
          // Ini untuk achievement tentang berapa skor sempurna yang didapatkan user
          case 'perfect_score':
          case 'perfect_5':
            currentValue = history.where((h) {
              final score = h['score'] as int? ?? 0;
              final total = h['total_questions'] as int? ?? 0;

              return total > 0 && score == total;
            }).length;
            break;

          // Ini untuk achievement tentang jumlah quiz unik yang udah dikerjakan oleh user
          case 'all_categories':
            final uniqueCategories = history
                .map((h) => h['category'] as String?)
                .where((c) => c != null)
                .toSet()
                .length;
            currentValue = uniqueCategories;
            break;

          // Ini untuk achievement tentang kecepatan user dalam mengerjakan quiz
          case 'speed_demon':
            currentValue = history.where((h) {
              final duration = h['duration'] as int? ?? 0;
              return duration <= 60;
            }).length;
            break;

          // Ini untuk achievement tentang berapa hard quiz yang udah diselesaikan oleh user
          case 'hard_mode':
            currentValue = history.where((h) {
              final difficulty = h['difficulty'] as String? ?? '';
              return difficulty.toLowerCase() == 'hard';
            }).length;
            break;
        }

        // Apakah setelah dicek current value udah memenuhi required value
        final bool isNowUnlocked = currentValue >= template.requiredValue;

        // Update progress
        finalAchievements.add(
          template.copyWith(
            currentValue: currentValue,
            isUnlocked: isNowUnlocked,

            unlockedAt: isNowUnlocked ? DateTime.now() : null,
          ),
        );
      }

      // Simpan ke DB
      await _databaseService.saveUserAchievements(userId, finalAchievements);

      return finalAchievements;
    } catch (e) {
      debugPrint("Error recalculating achievements: $e");
      return allAchievements;
    }
  }

  Future<List<AchievementModel>> getNewlyUnlockedAchievements(
    int userId,
    List<AchievementModel> previousAchievements,
  ) async {
    final currentAchievements = await recalculateAndSaveProgress(userId);

    final newlyUnlocked = <AchievementModel>[];

    // Looping untuk membandingkan progress yang lama dengan yang baru
    for (var i = 0; i < currentAchievements.length; i++) {
      final current = currentAchievements[i];

      final previous = previousAchievements.firstWhere(
        (a) => a.id == current.id,
        orElse: () => current, // fallback
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
