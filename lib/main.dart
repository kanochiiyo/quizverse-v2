import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quizverse/views/auth/login_view.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:quizverse/services/notification_service.dart';
import 'package:quizverse/services/navigation_service.dart';

void main() async {
  // Bikin binding antara FLutter sama engine (diperlukan kita ada manggil fungsi sebelum runApp())
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  // Inisialisasi data timezone diperlukan untuk nanti di conversion_service.dart
  tz.initializeTimeZones();
  Intl.defaultLocale = 'id_ID';
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    debugPrint("Default location set to: ${tz.local.name}");
  } catch (e) {
    debugPrint("Error setting default location: $e. Using default UTC.");
    tz.setLocalLocation(tz.UTC);
  }

  // Setup awal notifikasi (pake await karena ini butuh waktu jadi biar aplikasinya gak freeze pas nunggu)
  await NotificationService().initNotifications();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inisialisasi warna biar ga beda-beda ntar
    const Color primaryColor = Color(0xFF00695C);
    const Color lightPrimaryColor = Color(0xFF00897B);
    const Color accentColor = Color(0xFF4DB6AC);
    const Color backgroundColor = Color(0xFFF5F5F5);

    return MaterialApp(
      // Remote untuk navigasi, karena biasanya kalo navigasi butuh context, tapi ada kalanya kita harus berpindah tapi ga punya context misalnya saat nge-tap notifikasi jadisi navigatorKey ini tinggal nyuruh pindah dari state saat ini
      navigatorKey: NavigationService.navigatorKey,
      title: 'QuizVerse',

      // Bikin root theme biar default
      theme: ThemeData(
        fontFamily: 'Inter',
        brightness: Brightness.light,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: accentColor,
          surface: backgroundColor,
          error: Colors.redAccent,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIconColor: lightPrimaryColor,
          suffixIconColor: lightPrimaryColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12.0)),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
        ),

        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),

        useMaterial3: true,
      ),
      // Ketika aplikasi dibuka, arahin langsung ke halaman login
      home: LoginView(),
    );
  }
}
