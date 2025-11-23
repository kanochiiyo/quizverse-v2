import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomStatus { waiting, playing, finished }

class RoomModel {
  final String roomId;
  final String roomCode;
  final String hostId;
  final String hostName;
  final String category;
  final String categoryName;
  final String difficulty;
  final int questionAmount;
  final RoomStatus status;
  final List<RoomParticipant> participants;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? quizDataJson;
  final int maxParticipants;

  RoomModel({
    required this.roomId,
    required this.roomCode,
    required this.hostId,
    required this.hostName,
    required this.category,
    required this.categoryName,
    required this.difficulty,
    required this.questionAmount,
    required this.status,
    required this.participants,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.quizDataJson,
    this.maxParticipants = 10,
  });

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'room_code': roomCode,
      'host_id': hostId,
      'host_name': hostName,
      'category': category,
      'category_name': categoryName,
      'difficulty': difficulty,
      'question_amount': questionAmount,
      'status': status.toString().split('.').last,
      'participants': participants.map((p) => p.toMap()).toList(),
      'created_at': Timestamp.fromDate(createdAt),
      'started_at': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'finished_at': finishedAt != null
          ? Timestamp.fromDate(finishedAt!)
          : null,
      'quiz_data_json': quizDataJson,
      'max_participants': maxParticipants,
    };
  }

  factory RoomModel.fromMap(Map<String, dynamic> map, String docId) {
    RoomStatus parseStatus(String status) {
      switch (status) {
        case 'waiting':
          return RoomStatus.waiting;
        case 'playing':
          return RoomStatus.playing;
        case 'finished':
          return RoomStatus.finished;
        default:
          return RoomStatus.waiting;
      }
    }

    return RoomModel(
      roomId: docId,
      roomCode: map['room_code'] as String,
      hostId: map['host_id'] as String,
      hostName: map['host_name'] as String,
      category: map['category'] as String,
      categoryName: map['category_name'] as String,
      difficulty: map['difficulty'] as String,
      questionAmount: map['question_amount'] as int,
      status: parseStatus(map['status'] as String),
      participants: (map['participants'] as List)
          .map((p) => RoomParticipant.fromMap(p as Map<String, dynamic>))
          .toList(),
      createdAt: (map['created_at'] as Timestamp).toDate(),
      startedAt: map['started_at'] != null
          ? (map['started_at'] as Timestamp).toDate()
          : null,
      finishedAt: map['finished_at'] != null
          ? (map['finished_at'] as Timestamp).toDate()
          : null,
      quizDataJson: map['quiz_data_json'] as String?,
      maxParticipants: map['max_participants'] as int? ?? 10,
    );
  }

  RoomModel copyWith({
    String? roomId,
    String? roomCode,
    String? hostId,
    String? hostName,
    String? category,
    String? categoryName,
    String? difficulty,
    int? questionAmount,
    RoomStatus? status,
    List<RoomParticipant>? participants,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? quizDataJson,
    int? maxParticipants,
  }) {
    return RoomModel(
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      category: category ?? this.category,
      categoryName: categoryName ?? this.categoryName,
      difficulty: difficulty ?? this.difficulty,
      questionAmount: questionAmount ?? this.questionAmount,
      status: status ?? this.status,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      quizDataJson: quizDataJson ?? this.quizDataJson,
      maxParticipants: maxParticipants ?? this.maxParticipants,
    );
  }
}

class RoomParticipant {
  final String userId;
  final String username;
  final String? profilePhotoUrl;
  final DateTime joinedAt;
  final int score;
  final int correctAnswers;
  final bool isReady;
  final bool hasFinished;

  RoomParticipant({
    required this.userId,
    required this.username,
    this.profilePhotoUrl,
    required this.joinedAt,
    this.score = 0,
    this.correctAnswers = 0,
    this.isReady = false,
    this.hasFinished = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'username': username,
      'profile_photo_url': profilePhotoUrl,
      'joined_at': Timestamp.fromDate(joinedAt),
      'score': score,
      'correct_answers': correctAnswers,
      'is_ready': isReady,
      'has_finished': hasFinished,
    };
  }

  factory RoomParticipant.fromMap(Map<String, dynamic> map) {
    return RoomParticipant(
      userId: map['user_id'] as String,
      username: map['username'] as String,
      profilePhotoUrl: map['profile_photo_url'] as String?,
      joinedAt: (map['joined_at'] as Timestamp).toDate(),
      score: map['score'] as int? ?? 0,
      correctAnswers: map['correct_answers'] as int? ?? 0,
      isReady: map['is_ready'] as bool? ?? false,
      hasFinished: map['has_finished'] as bool? ?? false,
    );
  }

  RoomParticipant copyWith({
    String? userId,
    String? username,
    String? profilePhotoUrl,
    DateTime? joinedAt,
    int? score,
    int? correctAnswers,
    bool? isReady,
    bool? hasFinished,
  }) {
    return RoomParticipant(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      score: score ?? this.score,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      isReady: isReady ?? this.isReady,
      hasFinished: hasFinished ?? this.hasFinished,
    );
  }
}
