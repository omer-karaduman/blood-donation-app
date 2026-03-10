// mobile/lib/constants/api_constants.dart

class ApiConstants {
  /// Çalışma Ortamına Göre Base URL Seçimi:
  /// Windows/Web/iOS Simulator için -> 'http://127.0.0.1:8000'
  /// Android Emulator için          -> 'http://10.0.2.2:8000'
  /// Canlı Sunucu (Production) için -> 'https://api.seninsiten.com'
  
  static const String baseUrl = 'http://127.0.0.1:8000';

  // İleride tüm endpoint'leri (istek atılan uç noktaları) de burada toplayabiliriz:
  static const String staffEndpoint = '$baseUrl/staff/';
  static const String donorsEndpoint = '$baseUrl/donors/';
  static const String institutionsEndpoint = '$baseUrl/institutions/';
  static const String requestsEndpoint = '$baseUrl/requests/';
  static const String myRequestsEndpoint = '$baseUrl/staff/my-requests';
  static const String adminLogsEndpoint = '$baseUrl/admin/system-logs';
}