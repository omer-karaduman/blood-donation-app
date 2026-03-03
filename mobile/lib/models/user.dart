enum UserRole { donor, healthcare, admin }

class User {
  final String id;
  final String email;
  final UserRole role;
  final bool isActive;

  User({required this.id, required this.email, required this.role, required this.isActive});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'],
      email: json['email'],
      role: UserRole.values.firstWhere((e) => e.name == json['role']),
      isActive: json['is_active'] ?? true,
    );
  }
}