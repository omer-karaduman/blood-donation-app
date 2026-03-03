class Institution {
  final String id;
  final String ad;
  final String ilce;
  final String tamAdres;
  final String parentAdi;
  final String hiyerarsiTipi;
  final String tipi; // YENİ ALAN

  Institution({
    required this.id, 
    required this.ad, 
    required this.ilce, 
    required this.tamAdres, 
    required this.parentAdi, 
    required this.hiyerarsiTipi,
    required this.tipi,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: json['kurum_id'].toString(),
      ad: json['kurum_adi'] ?? "Bilinmiyor",
      ilce: json['ilce'] ?? "",
      tamAdres: json['tam_adres'] ?? "",
      parentAdi: json['parent_adi'] ?? "Bağımsız Kurum",
      hiyerarsiTipi: json['hiyerarsi_tipi'] ?? "Parent",
      tipi: json['tipi'] ?? "Hastane", // JSON'dan gelen tipi alanı
    );
  }
}