import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:quizverse/models/achievement_model.dart';

class DatabaseService {
  // Bikin instance DB dulu
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'quizverse.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createUsersTable(db);
    await _createQuizHistoryTable(db);
    await _createAchievementsTable(db);
  }

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _createQuizHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE quiz_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        quiz_date TEXT DEFAULT CURRENT_TIMESTAMP,
        latitude REAL, 
        longitude REAL,
        address TEXT,
        quiz_data_json TEXT,
        user_answers_json TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createAchievementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE user_achievements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        achievement_id TEXT NOT NULL,
        current_value INTEGER DEFAULT 0,
        is_unlocked INTEGER DEFAULT 0,
        unlocked_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        UNIQUE(user_id, achievement_id) 
      )
    ''');
  }

  // Inisialisasi achievement pertama kali untuk user baru
  Future<void> _initializeUserAchievements(
    int userId,
    List<AchievementModel> allAchievements,
  ) async {
    final db = await database;
    // Biar lebih efisien menjalankan quernya karena data achievement ada banyak
    final batch = db.batch();

    // Set semua data achievement ke 0
    for (final achievement in allAchievements) {
      final achievementData = achievement.toJson();
      batch.insert('user_achievements', {
        'user_id': userId,
        'achievement_id': achievementData['id'],
        'current_value': 0,
        'is_unlocked': 0,
        'unlocked_at': null,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    // Biar insert cepet
    await batch.commit(noResult: true);
  }

  Future<List<AchievementModel>> getUserAchievements(
    int userId,
    List<AchievementModel> allAchievements,
  ) async {
    final db = await database;
    // Ambil data mentah dari DB dulu 
    final List<Map<String, dynamic>> maps = await db.query(
      'user_achievements',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    // Kalo misalnya achievementnya belum ada (user baru)
    if (maps.isEmpty) {
      // Inisialisasi dulu achievementnya
      await _initializeUserAchievements(userId, allAchievements);

      // Jalankan lagi getUserAchievement
      return getUserAchievements(userId, allAchievements);
    }

    // Cocokkan data di DB sama di template, 
    // Ini buat nimpa progressnya user tiap kali user buka page profile
    return allAchievements.map((template) {
      final savedData = maps.firstWhere(
        (map) => map['achievement_id'] == template.id,
        orElse: () => <String, dynamic>{},
      );

      if (savedData.isEmpty) {
        return template;
      }

      // Kalo ketemu yang sama, update achievementnya dengan template tadi
      return template.copyWith(
        currentValue: savedData['current_value'] as int?,
        isUnlocked: (savedData['is_unlocked'] as int?) == 1,
        unlockedAt: savedData['unlocked_at'] != null
            ? DateTime.parse(savedData['unlocked_at'] as String)
            : null,
      );
    }).toList();
  }

  Future<void> saveUserAchievements(
    int userId,
    List<AchievementModel> achievements,
  ) async {
    final db = await database;
    final batch = db.batch();

// Update semua achievement untuk dimasukkan ke DB 
    for (final achievement in achievements) {
      final achievementData = achievement.toJson();
      batch.insert('user_achievements', {
        'user_id': userId,
        'achievement_id': achievement.id,
        'current_value': achievementData['current_value'],
        'is_unlocked': achievementData['is_unlocked'],
        'unlocked_at': achievementData['unlocked_at'],
      }, conflictAlgorithm: ConflictAlgorithm.replace); // Timpa kalo ada data yang sama 
    }
    await batch.commit(noResult: true);
  }

  Future<int> saveQuizResult({
    required int userId,
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
    final db = await database;

    return await db.insert('quiz_history', {
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
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getQuizHistory(int userId) async {
    final db = await database;

    return await db.query(
      'quiz_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'quiz_date DESC',
    );
  }

  Future<Map<String, dynamic>?> getHistoryItemById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'quiz_history',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
}
