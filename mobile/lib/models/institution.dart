class Institution {
  final String id; // int yerine String yapmalısın!
  final String ad;
  final String yetkili;
  final String iletisim;

  Institution({required this.id, required this.ad, required this.yetkili, required this.iletisim});

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      // Backend'den 'kurum_id' anahtarıyla gelen UUID'yi String'e çeviriyoruz
      id: json['kurum_id']?.toString() ?? '', 
      ad: json['kurum_adi'] ?? 'İsimsiz Kurum',
      yetkili: json['yetkili_kisi'] ?? 'Yetkili Belirtilmedi',
      iletisim: json['iletisim'] ?? 'Adres Bilgisi Yok',
    );
  }
}