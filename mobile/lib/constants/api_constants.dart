// mobile/lib/constants/api_constants.dart

import 'package:flutter/foundation.dart'; // TargetPlatform ve kIsWeb için gerekli

class ApiConstants {
  /// Çalışma Ortamına Göre Dinamik Base URL Seçimi
  /// Web için -> localhost
  /// Android Emulator için -> 10.0.2.2
  /// Windows/iOS Simulator için -> 127.0.0.1
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  // ==========================================
  // YENİ MODÜLER YAPIYA GÖRE ENDPOINT'LER
  // ==========================================

  // --- Auth (Kimlik Doğrulama) ---
  static String get loginEndpoint => '$baseUrl/auth/login';

  // --- Donors (Donör İşlemleri) ---
  static String get donorsEndpoint => '$baseUrl/donors';
  static String get donorRegisterEndpoint => '$baseUrl/donors/register';
  // Not: Donör feed için URL'yi dinamik olarak şu şekilde kuracaksın:
  // '$donorsEndpoint/$userId/feed'

  // --- Staff (Personel ve Kan Talebi İşlemleri) ---
  // DÜZELTME: Sonuna slash (/) eklendi! (307 Redirect hatasını çözer)
  static String get staffEndpoint => '$baseUrl/staff/'; 
  static String get requestsEndpoint => '$baseUrl/staff/requests';
  static String get myRequestsEndpoint => '$baseUrl/staff/my-requests';

  // --- Institutions (Kurum ve Hastaneler) ---
  // DÜZELTME: Sonuna slash (/) eklendi!
  static String get institutionsEndpoint => '$baseUrl/institutions/';

  // --- Locations (Konum, İlçe, Mahalle) ---
  static String get locationsEndpoint => '$baseUrl/locations';

  // --- Admin (Sistem Özeti ve Loglar) ---
  static String get adminSummaryEndpoint => '$baseUrl/admin/summary';
  static String get adminLogsEndpoint => '$baseUrl/admin/system-logs';
}