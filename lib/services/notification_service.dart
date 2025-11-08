import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:quizverse/services/database_service.dart';
import 'package:quizverse/services/navigation_service.dart';
import 'package:quizverse/views/home/history_detail_view.dart';
import 'package:flutter/material.dart';

class NotificationService {
  // Ini singleton biar cuman dibuat sekali selama aplikasinya jalan
  static final NotificationService _notificationService =
      NotificationService._internal();
  factory NotificationService() => _notificationService;
  NotificationService._internal();

  // Inisialisasi pertama
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Pertama kali dipanggil saat aplikasi dijalankan
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

  // Jika misalnya user klik notifikasi (callback)

  @pragma('vm:entry-point')
  static void onNotificationTap(
    NotificationResponse notificationResponse,
  ) async {
    // Ambil payload dulu (id unik tiap notifikasi)
    final String? payload = notificationResponse.payload;

    if (payload == null) return;

    if (payload.startsWith('history_id_')) {
      try {
        // Kalo misalnya payloadnya ada history_id (id quiz history yang dikerjakan oleh user)
        final int historyId = int.parse(payload.split('_').last);

        final dbService = DatabaseService();
        await dbService.database;

        // Ambil data sesuai dengan historyId tadi
        final historyItem = await dbService.getHistoryItemById(historyId);

        if (historyItem != null) {
          // Arahin ke HistoryDetailView buat ditampilkan bersama dengan parameter historyItem yang udah diget berdasarkan historyId
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
    int historyId,
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
          ticker:  'ticker',
        );

    // agar 1 notifikasi bisa dipake semua
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: DarwinNotificationDetails(badgeNumber: 1),
    );

    await flutterLocalNotificationsPlugin.show(
      historyId,
      "Kuis Selesai!",
      "Skor Anda: $score dari $totalQuestions. Klik untuk melihat riwayat.",
      notificationDetails,

      payload: 'history_id_$historyId',
    );
  }
}
