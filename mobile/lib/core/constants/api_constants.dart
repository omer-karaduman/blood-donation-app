// lib/core/constants/api_constants.dart
//
// Tüm backend API endpoint'lerinin tek kaynak noktası.
// Trailing slash eklendi — FastAPI router prefixleri "/" ile bitiyor,
// aksi hâlde 307 Temporary Redirect döner ve POST/PUT body kaybolur.

import 'package:flutter/foundation.dart';

class ApiConstants {
  // ── Sunucu Adresi ─────────────────────────────────────────────────────────
  static String get baseUrl {
    // Render deployment URL'i
    return 'https://blood-donation-app-lhrk.onrender.com';
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static String get loginEndpoint => '$baseUrl/auth/login';

  // ── Donors ────────────────────────────────────────────────────────────────
  static String get donorsEndpoint        => '$baseUrl/donors';
  static String get donorRegisterEndpoint => '$baseUrl/donors/register';

  static String donorProfileEndpoint(String userId)       => '$donorsEndpoint/$userId/profile';
  static String donorHistoryEndpoint(String userId)       => '$donorsEndpoint/$userId/history';
  static String donorGamificationEndpoint(String userId)  => '$donorsEndpoint/$userId/gamification';
  static String donorProfileUpdateEndpoint(String userId) => '$donorsEndpoint/$userId/update';
  static String donorFeedEndpoint(String userId)          => '$donorsEndpoint/$userId/feed';
  static String donorRespondEndpoint(String userId, String logId) =>
      '$donorsEndpoint/$userId/respond/$logId';

  // ── Staff & Blood Requests ────────────────────────────────────────────────
  // Trailing slash: FastAPI "/staff/" prefix'i ile eşleşmesi için
  static String get staffEndpoint       => '$baseUrl/staff/';
  static String get requestsEndpoint    => '$baseUrl/staff/requests';
  static String get myRequestsEndpoint  => '$baseUrl/staff/my-requests';

  // Bireysel staff: /staff/{id}
  static String staffDetailEndpoint(String userId) => '$baseUrl/staff/$userId';

  static String confirmDonationEndpoint(String logId)   => '$baseUrl/staff/confirm-donation/$logId';
  static String cancelRequestEndpoint(String talepId)   => '$requestsEndpoint/$talepId/cancel';
  static String extendRequestEndpoint(String talepId)   => '$requestsEndpoint/$talepId/extend';
  static String completeRequestEndpoint(String talepId) => '$requestsEndpoint/$talepId/complete';

  // ── Institutions ──────────────────────────────────────────────────────────
  // Trailing slash: GET liste ve POST için
  static String get institutionsEndpoint => '$baseUrl/institutions/';

  // Bireysel kurum: /institutions/{id}
  static String institutionDetailEndpoint(String id) => '$baseUrl/institutions/$id';

  static String institutionStaffEndpoint(String institutionId) =>
      '$baseUrl/institutions/$institutionId/staff';

  // ── Locations ─────────────────────────────────────────────────────────────
  static String get locationsEndpoint => '$baseUrl/locations';
  static String get districtsEndpoint => '$locationsEndpoint/districts';
  static String neighborhoodsEndpoint(String districtId) =>
      '$locationsEndpoint/districts/$districtId/neighborhoods';

  // ── Admin ─────────────────────────────────────────────────────────────────
  static String get adminSummaryEndpoint => '$baseUrl/admin/summary';
  static String get adminLogsEndpoint    => '$baseUrl/admin/system-logs';
  static String adminRequestDetailEndpoint(String talepId) =>
      '$baseUrl/admin/requests/$talepId/detail';

  // ── Users ─────────────────────────────────────────────────────────────────
  static String userProfileEndpoint(String userId) => '$baseUrl/users/$userId/profile';

  // ── AI Agent ──────────────────────────────────────────────────────────────
  static String get aiChatEndpoint => '$baseUrl/api/ai/chat';
}