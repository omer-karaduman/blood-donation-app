class Donor {
  final String id;
  final String adSoyad;
  final String email;
  final String telefon; // YENİ EKLENDİ
  final double kilo;     // YENİ EKLENDİ
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
      ad_soyad: json['ad_soyad'] ?? 'İsimsiz',
      telefon: json['telefon'] ?? '', // Backend'den gelen veri
      kilo: (json['kilo'] ?? 0.0).toDouble(), // Backend'den gelen veri
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