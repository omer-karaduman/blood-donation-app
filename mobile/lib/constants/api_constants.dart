import 'package:flutter/foundation.dart'; 

class ApiConstants {
  // 🚀 CANLI SUNUCU ADRESİ (RENDER)
  static String get baseUrl => 'https://blood-donation-app-lhrk.onrender.com';

  // ==========================================
  // ENDPOINT'LER
  // ==========================================

  // --- Auth (Kimlik Doğrulama) ---
  static String get loginEndpoint => '$baseUrl/auth/login';

  // --- Donors (Donör İşlemleri) ---
  static String get donorsEndpoint => '$baseUrl/donors';
  static String get donorRegisterEndpoint => '$baseUrl/donors/register';
  
  // 🚀 YENİ EKLENEN DONÖR FONKSİYONLARI:
  // Bu fonksiyonlar, içine user_id alarak dinamik URL oluşturur.
  static String donorHistoryEndpoint(String userId) => '$donorsEndpoint/$userId/history';
  static String donorGamificationEndpoint(String userId) => '$donorsEndpoint/$userId/gamification';
  static String donorProfileUpdateEndpoint(String userId) => '$donorsEndpoint/$userId/update';

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