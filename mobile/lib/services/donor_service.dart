// lib/services/donor_service.dart
//
// Donör işlemlerine ait tüm HTTP çağrıları.
// Ekranların doğrudan http paketi kullanması yerine bu servis üzerinden çağrı yapması gerekir.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class DonorService {
  // ── Profil ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.donorProfileEndpoint(userId)));
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes));
    } catch (e) {
      debugPrint('[DonorService] fetchProfile hatasi: $e');
    }
    return null;
  }

  static Future<bool> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse(ApiConstants.donorProfileUpdateEndpoint(userId)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[DonorService] updateProfile hatasi: $e');
      return false;
    }
  }

  // ── Feed ────────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchFeed(String userId) async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.donorFeedEndpoint(userId)));
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes)) as List;
    } catch (e) {
      debugPrint('[DonorService] fetchFeed hatasi: $e');
    }
    return [];
  }

  static Future<bool> respondToRequest(String userId, String logId, String reaksiyon) async {
    try {
      final url = Uri.parse(
        '${ApiConstants.donorRespondEndpoint(userId, logId)}?reaksiyon=$reaksiyon',
      );
      final res = await http.post(url);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[DonorService] respondToRequest hatasi: $e');
      return false;
    }
  }

  // ── Geçmiş ─────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchHistory(String userId) async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.donorHistoryEndpoint(userId)));
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes)) as List;
    } catch (e) {
      debugPrint('[DonorService] fetchHistory hatasi: $e');
    }
    return [];
  }

  // ── Oyunlaştırma ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> fetchGamification(String userId) async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.donorGamificationEndpoint(userId)));
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes));
    } catch (e) {
      debugPrint('[DonorService] fetchGamification hatasi: $e');
    }
    return null;
  }
}
