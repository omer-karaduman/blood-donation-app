// mobile/lib/models/user.dart

enum UserRole {
  donor,
  staff,
  admin
}

class User {
  final String userId;
  final String email;
  final UserRole role;
  final bool isActive;

  User({
    required this.userId,
    required this.email,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      // Backend'den gelen rolü güvenli bir şekilde ayrıştıran özel fonksiyon
      role: _parseRole(json['role']),
      isActive: json['is_active'] ?? true,
    );
  }

  // Gelen string'i küçük harfe çevirip güvenli eşleştirme yapar
  static UserRole _parseRole(dynamic roleData) {
    if (roleData == null) return UserRole.donor; // Varsayılan değer
    
    String roleStr = roleData.toString().toLowerCase();

    if (roleStr.contains('admin')) {
      return UserRole.admin;
    } else if (roleStr.contains('health') || roleStr.contains('staff')) {
      // Backend'deki 'staff' rolünü Flutter'daki 'staff' rolüne eşler
      return UserRole.staff;
    } else {
      return UserRole.donor;
    }
  }
}