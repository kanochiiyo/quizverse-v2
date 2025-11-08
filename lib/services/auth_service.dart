import 'package:flutter/material.dart';
import 'package:quizverse/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite/sqflite.dart';

class AuthService {
  final DatabaseService _dbHelper = DatabaseService();

  final String _loginStatusKey = 'isLoggedIn';
  final String _userIdKey = 'userId';
  final String _usernameKey = 'username';

  String _hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  bool _verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (e) {
      debugPrint("Error verifying password (mungkin format hash salah): $e");
      return false;
    }
  }

  Future<void> register({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || password.isEmpty) {
      throw 'Username dan Password tidak boleh kosong.';
    }
    if (password.length < 8) {
      throw "Password minimal 8 karakter!";
    }

    try {
      final Database db = await _dbHelper.database;

      final List<Map<String, dynamic>> existingUsers = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );

      if (existingUsers.isNotEmpty) {
        throw 'Username sudah digunakan.';
      }

      final String passwordHash = _hashPassword(password);

      await db.insert('users', {
        'username': username,
        'password_hash': passwordHash,
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw 'Username sudah digunakan.';
      }
      throw 'Gagal mendaftar. Terjadi masalah database. (${e.toString()})';
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || password.isEmpty) {
      throw 'Username dan Password tidak boleh kosong.';
    }
    try {
      final Database db = await _dbHelper.database;

      final List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );

      if (results.isEmpty) {
        throw 'Username tidak ditemukan.';
      }

      final userRow = results.first;

      final String storedHash = userRow['password_hash'] as String? ?? '';
      final int userId = userRow['id'] as int;

      if (storedHash.isEmpty) {
        throw 'Login gagal. Data pengguna tidak lengkap.';
      }

      final bool passwordMatch = _verifyPassword(password, storedHash);

      if (!passwordMatch) {
        throw 'Password salah.';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loginStatusKey, true);

      await prefs.setString(_userIdKey, userId.toString());
      await prefs.setString(_usernameKey, username);
    } on DatabaseException catch (e) {
      throw 'Gagal login. Terjadi masalah database. (${e.toString()})';
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loginStatusKey) ?? false;
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginStatusKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
  }
}
