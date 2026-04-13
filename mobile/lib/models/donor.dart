import 'user.dart'; // 🚀 KRİTİK: UserRole bu dosyanın içinde, bu satırı mutlaka ekle!

class Donor {
  final String userId; // MainNavigationScreen ile uyum için 'id' yerine 'userId' yapıldı
  final String adSoyad;
  final String email;
  final String telefon; 
  final double kilo;     
  final String cinsiyet; 
  final String kanGrubu;
  final bool kanVerebilirMi;
  final String mahalleAdi; 
  final DateTime? sonBagisTarihi; 
  final UserRole role; // Artık hata vermeyecek

  Donor({
    required this.userId,
    required this.adSoyad,
    required this.email,
    required this.telefon,
    required this.kilo,
    required this.cinsiyet,
    required this.kanGrubu,
    required this.kanVerebilirMi,
    required this.mahalleAdi,
    required this.role,
    this.sonBagisTarihi,
  });

  factory Donor.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['son_bagis_tarihi'] != null) {
      parsedDate = DateTime.tryParse(json['son_bagis_tarihi'].toString());
    }

    return Donor(
      // Backend'den gelen farklı id isimlendirmelerine karşı güvenli atama
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      adSoyad: json['ad_soyad'] ?? 'İsimsiz',
      telefon: json['telefon'] ?? '', 
      kilo: (json['kilo'] ?? 0.0).toDouble(), 
      cinsiyet: json['cinsiyet'] ?? 'E', 
      email: json['user'] != null ? json['user']['email'] ?? 'Email Yok' : 'Email Yok', 
      kanGrubu: json['kan_grubu'] ?? '?',
      kanVerebilirMi: json['kan_verebilir_mi'] ?? true,
      mahalleAdi: json['neighborhood'] != null 
          ? json['neighborhood']['name'] ?? 'Bilinmiyor' 
          : 'Bilinmiyor',
      sonBagisTarihi: parsedDate,
      role: UserRole.donor, // user.dart'tan gelen enum kullanılıyor
    );
  }
}