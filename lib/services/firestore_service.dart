import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quizverse/models/achievement_model.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _quizHistoryCollection =>
      _firestore.collection('quiz_history');
  CollectionReference get _achievementsCollection =>
      _firestore.collection('user_achievements');

  Future<String> saveQuizResult({
    required String userId,
    required String category,
    required String difficulty,
    required int score,
    required int duration,
    required int totalQuestions,
    double? latitude,
    double? longitude,
    String? address,
    String? quizDataJson,
    String? userAnswersJson,
  }) async {
    try {
      final docRef = await _quizHistoryCollection.add({
        'user_id': userId,
        'category': category,
        'difficulty': difficulty,
        'score': score,
        'duration': duration,
        'total_questions': totalQuestions,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'quiz_data_json': quizDataJson,
        'user_answers_json': userAnswersJson,
        'quiz_date': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });

      debugPrint("Quiz result saved with ID: ${docRef.id}");
      return docRef.id;
    } catch (e) {
      debugPrint("Error saving quiz result: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getQuizHistory(String userId) async {
    try {
      final querySnapshot = await _quizHistoryCollection
          .where('user_id', isEqualTo: userId)
          .orderBy('quiz_date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        if (data['quiz_date'] != null && data['quiz_date'] is Timestamp) {
          data['quiz_date'] = (data['quiz_date'] as Timestamp)
              .toDate()
              .toIso8601String();
        }

        return data;
      }).toList();
    } catch (e) {
      debugPrint("Error getting quiz history: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> getHistoryItemById(String docId) async {
    try {
      final docSnapshot = await _quizHistoryCollection.doc(docId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        data['id'] = docSnapshot.id;

        if (data['quiz_date'] != null && data['quiz_date'] is Timestamp) {
          data['quiz_date'] = (data['quiz_date'] as Timestamp)
              .toDate()
              .toIso8601String();
        }

        return data;
      }
      return null;
    } catch (e) {
      debugPrint("Error getting history item: $e");
      return null;
    }
  }

  Future<void> initializeUserAchievements(
    String userId,
    List<AchievementModel> allAchievements,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final achievement in allAchievements) {
        final docRef = _achievementsCollection.doc(
          '${userId}_${achievement.id}',
        );

        batch.set(docRef, {
          'user_id': userId,
          'achievement_id': achievement.id,
          'current_value': 0,
          'is_unlocked': false,
          'unlocked_at': null,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint(
        "Initialized ${allAchievements.length} achievements for user $userId",
      );
    } catch (e) {
      debugPrint("Error initializing achievements: $e");
      rethrow;
    }
  }

  Future<List<AchievementModel>> getUserAchievements(
    String userId,
    List<AchievementModel> allAchievements,
  ) async {
    try {
      final querySnapshot = await _achievementsCollection
          .where('user_id', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        await initializeUserAchievements(userId, allAchievements);
        return getUserAchievements(userId, allAchievements);
      }

      final achievementsMap = <String, Map<String, dynamic>>{};
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        achievementsMap[data['achievement_id']] = data;
      }

      return allAchievements.map((template) {
        final savedData = achievementsMap[template.id];

        if (savedData == null) {
          return template;
        }

        return template.copyWith(
          currentValue: savedData['current_value'] as int? ?? 0,
          isUnlocked: savedData['is_unlocked'] as bool? ?? false,
          unlockedAt: savedData['unlocked_at'] != null
              ? (savedData['unlocked_at'] as Timestamp).toDate()
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint("Error getting user achievements: $e");
      return allAchievements;
    }
  }

  Future<void> saveUserAchievements(
    String userId,
    List<AchievementModel> achievements,
  ) async {
    try {
      final batch = _firestore.batch();

      for (final achievement in achievements) {
        final docRef = _achievementsCollection.doc(
          '${userId}_${achievement.id}',
        );

        batch.set(docRef, {
          'user_id': userId,
          'achievement_id': achievement.id,
          'current_value': achievement.currentValue,
          'is_unlocked': achievement.isUnlocked,
          'unlocked_at': achievement.unlockedAt != null
              ? Timestamp.fromDate(achievement.unlockedAt!)
              : null,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint("Saved ${achievements.length} achievements for user $userId");
    } catch (e) {
      debugPrint("Error saving achievements: $e");
      rethrow;
    }
  }

  Future<void> deleteUserData(String userId) async {
    try {
      final batch = _firestore.batch();

      final historyDocs = await _quizHistoryCollection
          .where('user_id', isEqualTo: userId)
          .get();
      for (var doc in historyDocs.docs) {
        batch.delete(doc.reference);
      }

      final achievementDocs = await _achievementsCollection
          .where('user_id', isEqualTo: userId)
          .get();
      for (var doc in achievementDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint("Deleted all data for user $userId");
    } catch (e) {
      debugPrint("Error deleting user data: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    try {
      final history = await getQuizHistory(userId);

      if (history.isEmpty) {
        return {
          'total_quizzes': 0,
          'total_score': 0,
          'total_questions': 0,
          'total_duration': 0,
          'avg_score_percent': 0.0,
        };
      }

      int totalScore = 0;
      int totalQuestions = 0;
      int totalDuration = 0;

      for (var item in history) {
        totalScore += (item['score'] as int? ?? 0);
        totalQuestions += (item['total_questions'] as int? ?? 0);
        totalDuration += (item['duration'] as int? ?? 0);
      }

      final avgScorePercent = totalQuestions > 0
          ? (totalScore / totalQuestions) * 100
          : 0.0;

      return {
        'total_quizzes': history.length,
        'total_score': totalScore,
        'total_questions': totalQuestions,
        'total_duration': totalDuration,
        'avg_score_percent': avgScorePercent,
      };
    } catch (e) {
      debugPrint("Error getting user statistics: $e");
      return {
        'total_quizzes': 0,
        'total_score': 0,
        'total_questions': 0,
        'total_duration': 0,
        'avg_score_percent': 0.0,
      };
    }
  }
}
