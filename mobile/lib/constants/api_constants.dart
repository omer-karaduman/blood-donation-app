// mobile/lib/constants/api_constants.dart
import 'package:flutter/foundation.dart'; 

class ApiConstants {
  // 🚀 SUNUCU ADRESİ
  // Canlı (Render) adresi veya yerel test adresi
  //static String get baseUrl => 'https://blood-donation-app-lhrk.onrender.com';
  static String get baseUrl => 'http://localhost:8000'; // Yerel test için

  // ==========================================
  // ENDPOINT'LER
  // ==========================================

  // --- Auth (Kimlik Doğrulama) ---
  static String get loginEndpoint => '$baseUrl/auth/login';

  // --- Donors (Donör İşlemleri) ---
  static String get donorsEndpoint => '$baseUrl/donors';
  static String get donorRegisterEndpoint => '$baseUrl/donors/register';
  
  // Dinamik Donör Endpoint'leri
  static String donorProfileEndpoint(String userId) => '$donorsEndpoint/$userId/profile';
  static String donorHistoryEndpoint(String userId) => '$donorsEndpoint/$userId/history';
  static String donorGamificationEndpoint(String userId) => '$donorsEndpoint/$userId/gamification';
  static String donorProfileUpdateEndpoint(String userId) => '$donorsEndpoint/$userId/update';
  static String donorFeedEndpoint(String userId) => '$donorsEndpoint/$userId/feed';

  // --- Staff (Personel ve Kan Talebi İşlemleri) ---
  static String get staffEndpoint => '$baseUrl/staff'; 
  static String get requestsEndpoint => '$baseUrl/staff/requests';
  static String get myRequestsEndpoint => '$baseUrl/staff/my-requests';

  // --- Institutions (Kurum ve Hastaneler) ---
  static String get institutionsEndpoint => '$baseUrl/institutions';

  // --- Locations (Konum, İlçe, Mahalle) ---
  static String get locationsEndpoint => '$baseUrl/locations';
  static String get districtsEndpoint => '$locationsEndpoint/districts';
  static String neighborhoodsEndpoint(String districtId) => '$locationsEndpoint/districts/$districtId/neighborhoods';

  // --- Admin (Sistem Özeti ve Loglar) ---
  static String get adminSummaryEndpoint => '$baseUrl/admin/summary';
  static String get adminLogsEndpoint => '$baseUrl/admin/system-logs';
}