// lib/services/admin_service.dart
//
// Admin paneli işlemlerine ait tüm HTTP çağrıları.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';

class AdminService {
  static Future<Map<String, dynamic>?> fetchSummary() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.adminSummaryEndpoint));
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes));
    } catch (e) {
      debugPrint('[AdminService] fetchSummary hatasi: $e');
    }
    return null;
  }

  static Future<List<dynamic>> fetchSystemLogs() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.adminLogsEndpoint));
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes)) as List;
    } catch (e) {
      debugPrint('[AdminService] fetchSystemLogs hatasi: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchRequestDetail(String talepId) async {
    try {
      final res = await http.get(
        Uri.parse(ApiConstants.adminRequestDetailEndpoint(talepId)),
      );
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes));
    } catch (e) {
      debugPrint('[AdminService] fetchRequestDetail hatasi: $e');
    }
    return null;
  }
}
