// mobile/lib/models/donor.dart (Güncellenmiş hali)

class Donor {
  final String id;
  final String adSoyad;
  final String email;
  final String telefon; 
  final double kilo;     
  final String cinsiyet; // 🚀 YENİ EKLENDİ
  final String kanGrubu;
  final bool kanVerebilirMi;
  final String mahalleAdi; 
  final DateTime? sonBagisTarihi; 

  Donor({
    required this.id,
    required this.adSoyad,
    required this.email,
    required this.telefon,
    required this.kilo,
    required this.cinsiyet, // 🚀 YENİ EKLENDİ
    required this.kanGrubu,
    required this.kanVerebilirMi,
    required this.mahalleAdi,
    this.sonBagisTarihi,
  });

  factory Donor.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['son_bagis_tarihi'] != null) {
      parsedDate = DateTime.tryParse(json['son_bagis_tarihi'].toString());
    }

    return Donor(
      id: json['user_id']?.toString() ?? '',
      adSoyad: json['ad_soyad'] ?? 'İsimsiz',
      telefon: json['telefon'] ?? '', 
      kilo: (json['kilo'] ?? 0.0).toDouble(), 
      cinsiyet: json['cinsiyet'] ?? 'E', // 🚀 JSON'dan alındı
      email: json['user'] != null ? json['user']['email'] ?? 'Email Yok' : 'Email Yok', 
      kanGrubu: json['kan_grubu'] ?? '?',
      kanVerebilirMi: json['kan_verebilir_mi'] ?? true,
      mahalleAdi: json['neighborhood'] != null 
          ? json['neighborhood']['name'] ?? 'Mahalle Belirtilmemiş' 
          : 'Mahalle Belirtilmemiş',
      sonBagisTarihi: parsedDate,
    );
  }
}