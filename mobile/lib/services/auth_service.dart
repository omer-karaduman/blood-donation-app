// mobile/lib/services/auth_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user.dart';
import '../models/donor.dart'; // 🚀 KRİTİK: Donor modelini içeri aktarıyoruz
import '../core/constants/api_constants.dart';

class AuthService {
  /// Kullanıcı girişi yapar ve rolüne göre (Donor veya User) nesne döndürür.
  /// Dönüş tipi 'dynamic' yapıldı çünkü Donor veya User dönebilir.
  static Future<dynamic> login(String email, String password) async {
    
    // 1. Cihazın Firebase FCM Token'ını (Bildirim Kimliği) alıyoruz
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint("📱 [FCM] Alınan Cihaz Token: $fcmToken");
    } catch (e) {
      debugPrint("⚠️ [FCM] Token alınırken hata oluştu: $e");
    }

    try {
      // 2. Backend'e giriş isteği atıyoruz
      final response = await http.post(
        Uri.parse(ApiConstants.loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email, 
          'password': password,
          'fcm_token': fcmToken,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> userData = json.decode(utf8.decode(response.bodyBytes));
        debugPrint("✅ Giriş Başarılı: ${userData['email']}");

        // 🚀 ROL BAZLI MODEL AYRIMI:
        // Backend'den gelen rol bilgisini kontrol ediyoruz.
        // Genellikle 'role' anahtarı içinde 'name' olarak veya doğrudan string olarak gelir.
        String roleStr = "";
        if (userData['role'] is Map) {
          roleStr = userData['role']['name'].toString().toLowerCase();
        } else {
          roleStr = userData['role'].toString().toLowerCase();
        }

        if (roleStr.contains('donor')) {
          // 🩸 Donör ise Donor modeline çevir (Böylece sonBagisTarihi vb. veriler kaybolmaz)
          debugPrint("ℹ️ Donör nesnesi oluşturuluyor...");
          return Donor.fromJson(userData);
        } else {
          // 🏥 Staff veya Admin ise standart User modeline çevir
          debugPrint("ℹ️ Personel/Admin nesnesi oluşturuluyor...");
          return User.fromJson(userData);
        }
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