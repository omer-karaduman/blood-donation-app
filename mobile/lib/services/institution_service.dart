// lib/services/institution_service.dart
//
// Kurum ve Lokasyon işlemlerine ait tüm HTTP çağrıları.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/institution.dart';

class InstitutionService {
  // ── Kurumlar ────────────────────────────────────────────────────────────────

  static Future<List<Institution>> fetchInstitutions({
    String? districtId,
    String? tipi,
  }) async {
    try {
      var url = Uri.parse(ApiConstants.institutionsEndpoint);
      final params = <String, String>{};
      if (districtId != null) params['district_id'] = districtId;
      if (tipi       != null) params['tipi']         = tipi;
      if (params.isNotEmpty) url = url.replace(queryParameters: params);

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as List;
        return data.map((j) => Institution.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('[InstitutionService] fetchInstitutions hatasi: $e');
    }
    return [];
  }

  static Future<bool> createInstitution(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConstants.institutionsEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[InstitutionService] createInstitution hatasi: $e');
      return false;
    }
  }

  static Future<List<dynamic>> fetchInstitutionStaff(String institutionId) async {
    try {
      final res = await http.get(
        Uri.parse(ApiConstants.institutionStaffEndpoint(institutionId)),
      );
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes)) as List;
    } catch (e) {
      debugPrint('[InstitutionService] fetchInstitutionStaff hatasi: $e');
    }
    return [];
  }

  // ── Lokasyon ────────────────────────────────────────────────────────────────

  static Future<List<District>> fetchDistricts() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.districtsEndpoint));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as List;
        return data.map((d) => District.fromJson(d)).toList();
      }
    } catch (e) {
      debugPrint('[InstitutionService] fetchDistricts hatasi: $e');
    }
    return [];
  }

  static Future<List<Neighborhood>> fetchNeighborhoods(String districtId) async {
    try {
      final res = await http.get(
        Uri.parse(ApiConstants.neighborhoodsEndpoint(districtId)),
      );
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as List;
        return data.map((n) => Neighborhood.fromJson(n)).toList();
      }
    } catch (e) {
      debugPrint('[InstitutionService] fetchNeighborhoods hatasi: $e');
    }
    return [];
  }
}
