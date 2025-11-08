import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class ConversionService {
  final String _currencyApiUrl =
      'https://v6.exchangerate-api.com/v6/54d9aaec75a7f6531106d463/latest/IDR';

  static bool _timezoneInitialized = false;

  Future<void> _initializeTimezone() async {
    // Kalo udah pernah, gausah lagi diinisialisasi
    if (_timezoneInitialized) return;

    try {
      tz_data.initializeTimeZones();

      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      _timezoneInitialized = true;
      debugPrint("Timezone initialized by ConversionService.");
    } catch (e) {
      debugPrint("Failed to initialize timezone in ConversionService: $e");

      if (!_timezoneInitialized) {
        tz.setLocalLocation(tz.UTC);
        _timezoneInitialized = true;
      }
    }
  }

  // Untuk ambil conversion rate dari API exchangerate-api
  Future<Map<String, dynamic>> _getExchangeRates() async {
    final url = Uri.parse(_currencyApiUrl);
    try {
      final response = await http.get(url);
      // Kalau berhasil, simpan ke list data
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'success') {
          if (data.containsKey('conversion_rates')) {
            return data['conversion_rates'];
          } else {
            throw Exception(
              'Format API tidak sesuai: key "conversion_rates" tidak ditemukan.',
            );
          }
        } else {
          throw Exception(
            'API Error: ${data.containsKey('error-type') ? data['error-type'] : 'Unknown error'}',
          );
        }
      } else {
        throw Exception('HTTP Error: Status Code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching exchange rates: $e");
      throw Exception('Gagal mendapatkan kurs mata uang.');
    }
  }

  Future<String> getCurrencyFact() async {
    // Ambil rate dari API, masukin ke map rates
    try {
      final rates = await _getExchangeRates();
      // Inisialisasi targetnya, kalo USD per 1 USD, kalo JPY dikonversi per 100 JPY, dst
      final targetCurrencies = {
        'USD': 1.0,
        'EUR': 1.0,
        'JPY': 100.0,
        'KRW': 1000.0,
      };

      // Ambil random kode dari key targetCurrencies
      final randomCurrencyCode = targetCurrencies.keys.elementAt(
        Random().nextInt(targetCurrencies.length),
      );

      // Ambil value dari yang udah dirandom tadi masukin ke amount
      final amount = targetCurrencies[randomCurrencyCode]!;
      // Ambil rate dari API masukin ke rate
      final rate = rates[randomCurrencyCode];

      if (rate == null) {
        return "Info kurs untuk $randomCurrencyCode tidak tersedia saat ini.";
      }

      // Hitung nilai IDR nya
      final idrValue = amount / (rate as num);
      final formattedAmount = NumberFormat("#,##0", "en_US").format(amount);
      final formattedIdrValue = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(idrValue);
      // Format menjadi misal Rp 16.000 (tanpa decimal)

      return "Tahukah kamu? $formattedAmount $randomCurrencyCode saat ini setara dengan $formattedIdrValue! 💰";
    } catch (e) {
      return "Gagal memuat fakta mata uang: ${e.toString().replaceFirst("Exception: ", "")}";
    }
  }

  String _getTimezoneName(String zoneAbbreviation) {
    switch (zoneAbbreviation.toUpperCase()) {
      case 'WIB':
        return 'Asia/Jakarta';
      case 'WITA':
        return 'Asia/Makassar';
      case 'WIT':
        return 'Asia/Jayapura';
      case 'LONDON':
        return 'Europe/London';
      case 'ASIA/TOKYO':
        return 'Asia/Tokyo';
      default:
        try {
          tz.getLocation(zoneAbbreviation);
          return zoneAbbreviation;
        } catch (_) {
          debugPrint(
            "Warning: Timezone abbreviation '$zoneAbbreviation' not recognized, falling back to WIB.",
          );
          return 'Asia/Jakarta';
        }
    }
  }

  Future<String> getTimeFact() async {
    try {
      await _initializeTimezone();

      //  Buat dapetin waktu saat ini sesuai lokasi lokal (aku set Asia/Jakarta)
      final sourceLocation = tz.local;
      final nowInSource = tz.TZDateTime.now(sourceLocation);

      // Bikin list untuk target biar bisa dirandom nanti
      final targetZones = ['WITA', 'WIT', 'London', 'Asia/Tokyo'];

      // Pilih waktu random antara targetZones list
      final randomTargetAbbreviation =
          targetZones[Random().nextInt(targetZones.length)];
      final targetZoneName = _getTimezoneName(randomTargetAbbreviation);

      // Konversi waktu dari WIB ke targetZoneName menggunakan TZDateTime
      final targetLocation = tz.getLocation(targetZoneName);
      final timeInTarget = tz.TZDateTime.from(nowInSource, targetLocation);

      final sourceTimeString = DateFormat('HH:mm').format(nowInSource);
      final targetTimeString = DateFormat('HH:mm').format(timeInTarget);

      final sourceAbbreviation = nowInSource.timeZoneName;

      return "Tahukah kamu? Pukul $sourceTimeString $sourceAbbreviation saat ini sama dengan pukul $targetTimeString di $randomTargetAbbreviation! 🌍⏰";
    } catch (e) {
      debugPrint("Error generating time fact: $e");

      return "Gagal memuat fakta waktu.";
    }
  }

  // Ngerandom antara currency atau time
  Future<String> getRandomFact() async {
    bool showFact = Random().nextBool();

    if (showFact) {
      return await getCurrencyFact();
    } else {
      return await getTimeFact();
    }
  }
}
