// lib/services/staff_service.dart
//
// Personel ve Kan Talebi işlemlerine ait tüm HTTP çağrıları.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class StaffService {
  // ── Personel CRUD ───────────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchAllStaff() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.staffEndpoint));
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes)) as List;
    } catch (e) {
      debugPrint('[StaffService] fetchAllStaff hatasi: $e');
    }
    return [];
  }

  static Future<bool> createStaff(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.staffEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[StaffService] createStaff hatasi: $e');
      return false;
    }
  }

  static Future<bool> updateStaff(String userId, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse(ApiConstants.staffDetailEndpoint(userId)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[StaffService] updateStaff hatasi: $e');
      return false;
    }
  }

  static Future<bool> deleteStaff(String userId) async {
    try {
      final res = await http.delete(
        Uri.parse(ApiConstants.staffDetailEndpoint(userId)),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[StaffService] deleteStaff hatasi: $e');
      return false;
    }
  }

  // ── Kan Talepleri ───────────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchMyRequests(String personelId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.myRequestsEndpoint}?personel_id=$personelId'),
      );
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes)) as List;
    } catch (e) {
      debugPrint('[StaffService] fetchMyRequests hatasi: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> createBloodRequest(
      String personelId, Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.requestsEndpoint}?personel_id=$personelId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return json.decode(utf8.decode(res.bodyBytes));
      }
    } catch (e) {
      debugPrint('[StaffService] createBloodRequest hatasi: $e');
    }
    return null;
  }

  static Future<bool> cancelRequest(String talepId, String personelId) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiConstants.cancelRequestEndpoint(talepId)}?personel_id=$personelId'),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[StaffService] cancelRequest hatasi: $e');
      return false;
    }
  }

  static Future<bool> completeRequest(String talepId, String personelId) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiConstants.completeRequestEndpoint(talepId)}?personel_id=$personelId'),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[StaffService] completeRequest hatasi: $e');
      return false;
    }
  }

  static Future<bool> confirmDonation(String logId, {int alinanUnite = 1}) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.confirmDonationEndpoint(logId)}?alinan_unite=$alinanUnite'),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[StaffService] confirmDonation hatasi: $e');
      return false;
    }
  }
}
