// mobile/lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../constants/api_constants.dart';

class AuthService {
  static Future<User?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      // Backend'den gelen veriyi User modeline çevir
      return User.fromJson(jsonDecode(response.body));
    }
    return null;
  }
}