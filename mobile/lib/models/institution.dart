class Institution {
  final dynamic id; // Backend UUID gönderiyorsa String, JSON ise int olabilir
  final String ad;
  final String tipi;
  final String ilce;
  final String tamAdres;
  final double enlem;
  final double boylam;
  final dynamic parentId; // Alt birim değilse null olur

  Institution({
    required this.id,
    required this.ad,
    required this.tipi,
    required this.ilce,
    required this.tamAdres,
    required this.enlem,
    required this.boylam,
    this.parentId,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(

      id: json['ID'] ?? json['kurum_id'] ?? json['id'],
      ad: json['ADI'] ?? json['kurum_adi'] ?? "Bilinmiyor",
      tipi: json['TIPI'] ?? json['tipi'] ?? "Hastane",
      ilce: json['ILCE'] ?? json['ilce'] ?? "",
      tamAdres: json['TAM_ADRES'] ?? json['tam_adres'] ?? "",
      enlem: (json['ENLEM'] ?? json['enlem'] ?? 0.0).toDouble(),
      boylam: (json['BOYLAM'] ?? json['boylam'] ?? 0.0).toDouble(),
      parentId: json['PARENT_ID'] ?? json['parent_id'],
    );
  }
}