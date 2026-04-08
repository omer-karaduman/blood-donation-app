import 'package:flutter/foundation.dart'; 

class ApiConstants {
  // 🚀 ARTIK CANLI SUNUCUDAYIZ! (RENDER)
  // Web, Android, iOS fark etmez; hepsi bu adrese gidecek.
  static String get baseUrl => 'https://blood-donation-app-lhrk.onrender.com';

  // ==========================================
  // ENDPOINT'LER (Aşağıya hiç dokunmuyoruz, hepsi aynı)
  // ==========================================

  // --- Auth (Kimlik Doğrulama) ---
  static String get loginEndpoint => '$baseUrl/auth/login';

  // --- Donors (Donör İşlemleri) ---
  static String get donorsEndpoint => '$baseUrl/donors';
  static String get donorRegisterEndpoint => '$baseUrl/donors/register';

  // --- Staff (Personel ve Kan Talebi İşlemleri) ---
  static String get staffEndpoint => '$baseUrl/staff/'; 
  static String get requestsEndpoint => '$baseUrl/staff/requests';
  static String get myRequestsEndpoint => '$baseUrl/staff/my-requests';

  // --- Institutions (Kurum ve Hastaneler) ---
  static String get institutionsEndpoint => '$baseUrl/institutions/';

  // --- Locations (Konum, İlçe, Mahalle) ---
  static String get locationsEndpoint => '$baseUrl/locations';

  // --- Admin (Sistem Özeti ve Loglar) ---
  static String get adminSummaryEndpoint => '$baseUrl/admin/summary';
  static String get adminLogsEndpoint => '$baseUrl/admin/system-logs';
}