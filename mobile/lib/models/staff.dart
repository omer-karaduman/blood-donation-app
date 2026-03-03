import 'user.dart';
import 'institution.dart';

class StaffProfile {
  final String userId;
  final String adSoyad;
  final String unvan;
  final String? personelNo;
  final User user;
  final Institution? institution; // Bağlı olduğu hastane

  StaffProfile({
    required this.userId,
    required this.adSoyad,
    required this.unvan,
    this.personelNo,
    required this.user,
    this.institution,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    return StaffProfile(
      userId: json['user_id'],
      adSoyad: json['ad_soyad'],
      unvan: json['unvan'] ?? '',
      personelNo: json['personel_no'],
      user: User.fromJson(json['user']),
      institution: json['institution'] != null 
          ? Institution.fromJson(json['institution']) 
          : null,
    );
  }
}