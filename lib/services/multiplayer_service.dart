import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quizverse/models/room_model.dart';
import 'package:quizverse/models/quiz_model.dart';

class MultiplayerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _roomsCollection =>
      _firestore.collection('quiz_rooms');

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<RoomModel> createRoom({
    required String hostId,
    required String hostName,
    required String category,
    required String categoryName,
    required String difficulty,
    required int questionAmount,
    String? hostPhotoUrl,
  }) async {
    try {
      String roomCode;
      bool isUnique = false;

      do {
        roomCode = _generateRoomCode();
        final existing = await _roomsCollection
            .where('room_code', isEqualTo: roomCode)
            .where('status', whereIn: ['waiting', 'playing'])
            .get();
        isUnique = existing.docs.isEmpty;
      } while (!isUnique);

      final docRef = _roomsCollection.doc();

      final room = RoomModel(
        roomId: docRef.id,
        roomCode: roomCode,
        hostId: hostId,
        hostName: hostName,
        category: category,
        categoryName: categoryName,
        difficulty: difficulty,
        questionAmount: questionAmount,
        status: RoomStatus.waiting,
        participants: [
          RoomParticipant(
            userId: hostId,
            username: hostName,
            profilePhotoUrl: hostPhotoUrl,
            joinedAt: DateTime.now(),
            isReady: true,
          ),
        ],
        createdAt: DateTime.now(),
      );

      await docRef.set(room.toMap());

      debugPrint('Room created: ${room.roomCode}');
      return room;
    } catch (e) {
      debugPrint('Error creating room: $e');
      rethrow;
    }
  }

  Future<RoomModel> joinRoom({
    required String roomCode,
    required String userId,
    required String username,
    String? profilePhotoUrl,
  }) async {
    try {
      final querySnapshot = await _roomsCollection
          .where('room_code', isEqualTo: roomCode.toUpperCase())
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Room tidak ditemukan atau sudah dimulai');
      }

      final roomDoc = querySnapshot.docs.first;
      final room = RoomModel.fromMap(
        roomDoc.data() as Map<String, dynamic>,
        roomDoc.id,
      );

      if (room.participants.any((p) => p.userId == userId)) {
        return room;
      }

      if (room.participants.length >= room.maxParticipants) {
        throw Exception('Room sudah penuh');
      }

      final newParticipant = RoomParticipant(
        userId: userId,
        username: username,
        profilePhotoUrl: profilePhotoUrl,
        joinedAt: DateTime.now(),
      );

      final updatedParticipants = [...room.participants, newParticipant];

      await roomDoc.reference.update({
        'participants': updatedParticipants.map((p) => p.toMap()).toList(),
      });

      debugPrint('User $username joined room: $roomCode');

      return room.copyWith(participants: updatedParticipants);
    } catch (e) {
      debugPrint('Error joining room: $e');
      rethrow;
    }
  }

  Future<void> startQuiz({
    required String roomId,
    required List<QuizModel> questions,
  }) async {
    try {
      final questionsJson = jsonEncode(
        questions.map((q) => q.toJson()).toList(),
      );

      await _roomsCollection.doc(roomId).update({
        'status': 'playing',
        'started_at': FieldValue.serverTimestamp(),
        'quiz_data_json': questionsJson,
      });

      debugPrint('Quiz started for room: $roomId');
    } catch (e) {
      debugPrint('Error starting quiz: $e');
      rethrow;
    }
  }

  Future<void> updateParticipantScore({
    required String roomId,
    required String userId,
    required int score,
    required int correctAnswers,
  }) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();
      final room = RoomModel.fromMap(
        roomDoc.data() as Map<String, dynamic>,
        roomDoc.id,
      );

      final updatedParticipants = room.participants.map((p) {
        if (p.userId == userId) {
          return p.copyWith(
            score: score,
            correctAnswers: correctAnswers,
            hasFinished: true,
          );
        }
        return p;
      }).toList();

      await _roomsCollection.doc(roomId).update({
        'participants': updatedParticipants.map((p) => p.toMap()).toList(),
      });

      final allFinished = updatedParticipants.every((p) => p.hasFinished);
      if (allFinished) {
        await _roomsCollection.doc(roomId).update({
          'status': 'finished',
          'finished_at': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('Score updated for user: $userId in room: $roomId');
    } catch (e) {
      debugPrint('Error updating score: $e');
      rethrow;
    }
  }

  Future<void> leaveRoom({
    required String roomId,
    required String userId,
  }) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomId).get();
      final room = RoomModel.fromMap(
        roomDoc.data() as Map<String, dynamic>,
        roomDoc.id,
      );

      final updatedParticipants = room.participants
          .where((p) => p.userId != userId)
          .toList();

      if (room.hostId == userId && updatedParticipants.isNotEmpty) {
        final newHost = updatedParticipants.first;
        await _roomsCollection.doc(roomId).update({
          'host_id': newHost.userId,
          'host_name': newHost.username,
          'participants': updatedParticipants.map((p) => p.toMap()).toList(),
        });
      } else if (updatedParticipants.isEmpty) {
        await _roomsCollection.doc(roomId).delete();
      } else {
        await _roomsCollection.doc(roomId).update({
          'participants': updatedParticipants.map((p) => p.toMap()).toList(),
        });
      }

      debugPrint('User $userId left room: $roomId');
    } catch (e) {
      debugPrint('Error leaving room: $e');
      rethrow;
    }
  }

  Stream<RoomModel> getRoomStream(String roomId) {
    return _roomsCollection.doc(roomId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('Room tidak ditemukan');
      }
      return RoomModel.fromMap(
        snapshot.data() as Map<String, dynamic>,
        snapshot.id,
      );
    });
  }

  List<RoomParticipant> getLeaderboard(RoomModel room) {
    final sorted = List<RoomParticipant>.from(room.participants);
    sorted.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return b.correctAnswers.compareTo(a.correctAnswers);
    });
    return sorted;
  }

  Future<String> saveMultiplayerHistory({
    required String userId,
    required RoomModel room,
    required int userScore,
    required int userCorrectAnswers,
    required int userRank,
    required int duration,
  }) async {
    try {
      final historyRef = _firestore.collection('quiz_history').doc();

      await historyRef.set({
        'user_id': userId,
        'category': room.categoryName,
        'difficulty': room.difficulty,
        'score': userCorrectAnswers,
        'duration': duration,
        'total_questions': room.questionAmount,
        'quiz_data_json': room.quizDataJson,
        'quiz_date': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),

        'is_multiplayer': true,
        'room_code': room.roomCode,
        'room_id': room.roomId,
        'total_players': room.participants.length,
        'user_rank': userRank,
        'multiplayer_score': userScore,
      });

      debugPrint('Multiplayer history saved: ${historyRef.id}');
      return historyRef.id;
    } catch (e) {
      debugPrint('Error saving multiplayer history: $e');
      rethrow;
    }
  }

  Future<void> cleanupOldRooms() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));

      final querySnapshot = await _roomsCollection
          .where('created_at', isLessThan: Timestamp.fromDate(cutoff))
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Cleaned up ${querySnapshot.docs.length} old rooms');
    } catch (e) {
      debugPrint('Error cleaning up rooms: $e');
    }
  }
}
