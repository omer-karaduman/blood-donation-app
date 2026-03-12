class Donor {
  final String id;
  final String adSoyad;
  final String email;
  final String kanGrubu;
  final bool kanVerebilirMi;
  
  // YENİ EKLENEN ALANLAR
  final String mahalleAdi; 
  final DateTime? sonBagisTarihi; 

  Donor({
    required this.id,
    required this.adSoyad,
    required this.email,
    required this.kanGrubu,
    required this.kanVerebilirMi,
    required this.mahalleAdi,
    this.sonBagisTarihi,
  });

  factory Donor.fromJson(Map<String, dynamic> json) {
    // Backend'den gelen ISO 8601 tarih formatını Dart'ın DateTime objesine çeviriyoruz
    DateTime? parsedDate;
    if (json['son_bagis_tarihi'] != null) {
      parsedDate = DateTime.tryParse(json['son_bagis_tarihi'].toString());
    }

    return Donor(
      // UUID değerlerini güvenceye almak için toString() kullanıyoruz
      id: json['user_id']?.toString() ?? '',
      adSoyad: json['ad_soyad'] ?? 'İsimsiz',
      
      // Backend'den gelen iç içe 'user' paketini okuyoruz
      email: json['user'] != null ? json['user']['email'] ?? 'Email Yok' : 'Email Yok', 
      
      kanGrubu: json['kan_grubu'] ?? '?',
      kanVerebilirMi: json['kan_verebilir_mi'] ?? true,
      
      // YENİ: İç içe 'neighborhood' objesinden mahalle adını güvenli bir şekilde çekiyoruz
      mahalleAdi: json['neighborhood'] != null 
          ? json['neighborhood']['name'] ?? 'Mahalle Belirtilmemiş' 
          : 'Mahalle Belirtilmemiş',
          
      sonBagisTarihi: parsedDate,
    );
  }
}