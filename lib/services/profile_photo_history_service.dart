import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ProfilePhotoHistoryService {
  static const String _historyKey = 'profile_photo_history';
  static const int _maxHistoryCount = 10;

  Future<void> savePhotoToHistory(String photoUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      List<String> history = await getPhotoHistory();

      history.remove(photoUrl);

      history.insert(0, photoUrl);

      if (history.length > _maxHistoryCount) {
        history = history.sublist(0, _maxHistoryCount);
      }

      await prefs.setStringList(_historyKey, history);

      debugPrint('Photo saved to history: $photoUrl');
      debugPrint('Total history: ${history.length}');
    } catch (e) {
      debugPrint('Error saving photo to history: $e');
    }
  }

  Future<List<String>> getPhotoHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? history = prefs.getStringList(_historyKey);

      return history ?? [];
    } catch (e) {
      debugPrint('Error getting photo history: $e');
      return [];
    }
  }

  Future<void> removePhotoFromHistory(String photoUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = await getPhotoHistory();

      history.remove(photoUrl);

      await prefs.setStringList(_historyKey, history);

      debugPrint('Photo removed from history: $photoUrl');
    } catch (e) {
      debugPrint('Error removing photo from history: $e');
    }
  }

  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);

      debugPrint('Photo history cleared');
    } catch (e) {
      debugPrint('Error clearing photo history: $e');
    }
  }

  Future<bool> isInHistory(String photoUrl) async {
    final history = await getPhotoHistory();
    return history.contains(photoUrl);
  }
}
