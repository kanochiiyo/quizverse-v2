import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quizverse/services/firestore_service.dart';
import 'package:quizverse/services/navigation_service.dart';
import 'package:quizverse/views/home/history_detail_view.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();
  factory NotificationService() => _notificationService;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
    );
  }

  @pragma('vm:entry-point')
  static void onNotificationTap(
    NotificationResponse notificationResponse,
  ) async {
    final String? payload = notificationResponse.payload;

    if (payload == null) return;

    if (payload.startsWith('history_id_')) {
      try {
        final String historyId = payload.replaceFirst('history_id_', '');

        final firestoreService = FirestoreService();

        final historyItem = await firestoreService.getHistoryItemById(
          historyId,
        );

        if (historyItem != null) {
          NavigationService.navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => HistoryDetailView(historyItem: historyItem),
            ),
          );
        }
      } catch (e) {
        debugPrint("Error handling notification tap: $e");
      }
    }
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showQuizResultNotification(
    String historyId,
    int score,
    int totalQuestions,
  ) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'quiz_result_channel',
          'Hasil Kuis',
          channelDescription: 'Notifikasi yang muncul setelah kuis selesai.',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(badgeNumber: 1),
    );

    final int notificationId = historyId.hashCode;

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      "Kuis Selesai!",
      "Skor Anda: $score dari $totalQuestions. Klik untuk melihat riwayat.",
      notificationDetails,
      payload: 'history_id_$historyId',
    );
  }
}
