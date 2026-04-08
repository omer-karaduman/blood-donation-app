import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user.dart';
import '../constants/api_constants.dart';

class AuthService {
  /// Kullanıcı girişi yapar ve Firebase bildirim token'ını backend'e iletir.
  static Future<User?> login(String email, String password) async {
    
    // 1. Cihazın Firebase FCM Token'ını (Bildirim Kimliği) alıyoruz
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint("📱 [FCM] Alınan Cihaz Token: $fcmToken");
    } catch (e) {
      debugPrint("⚠️ [FCM] Token alınırken hata oluştu (Emülatörde normal olabilir): $e");
    }

    try {
      // 2. Backend'e (Docker API) login isteği atıyoruz
      final response = await http.post(
        Uri.parse(ApiConstants.loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email, 
          'password': password,
          'fcm_token': fcmToken, // Backend bu anahtarı kullanarak bildirim gönderecek
        }),
      ).timeout(const Duration(seconds: 10)); // Bağlantı zaman aşımı ekledik

      if (response.statusCode == 200) {
        // UTF-8 Decode kullanarak Türkçe karakterleri (Ö, Ü, Ş vb.) garantiye alıyoruz
        final Map<String, dynamic> userData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("✅ Giriş Başarılı: ${userData['email']}");
        return User.fromJson(userData);
      } else {
        debugPrint("❌ Giriş Başarısız: Durum Kodu ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Sunucuya bağlanırken hata: $e");
      return null;
    }
  }
}