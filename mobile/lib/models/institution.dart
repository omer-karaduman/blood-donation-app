// 1. İlçe (District) Modeli
class District {
  final String id;
  final String name;

  District({required this.id, required this.name});

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['district_id']?.toString() ?? '',
      name: json['name'] ?? '',
    );
  }
}

// 2. Mahalle (Neighborhood) Modeli
class Neighborhood {
  final String id;
  final String name;

  Neighborhood({required this.id, required this.name});

  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    return Neighborhood(
      id: json['neighborhood_id']?.toString() ?? '',
      name: json['name'] ?? '',
    );
  }
}

// 3. Ana Kurum (Institution) Modeli
class Institution {
  final dynamic id; 
  final String ad;
  final String tipi;
  final String tamAdres;
  final double enlem;
  final double boylam;
  final dynamic parentId; 
  
  // YENİ: İlişkisel Konum Objeleri
  final District? district;
  final Neighborhood? neighborhood;
  
  // YENİ: Alt Birimler (Ek hizmet binaları vb.)
  final List<Institution>? subUnits;

  // UI tarafında eski kodların (Text widget'ları vb.) patlamaması için pratik getter'lar:
  String get ilceAdi => district?.name ?? "İlçe Bilinmiyor";
  String get mahalleAdi => neighborhood?.name ?? "Mahalle Bilinmiyor";

  Institution({
    required this.id,
    required this.ad,
    required this.tipi,
    required this.tamAdres,
    required this.enlem,
    required this.boylam,
    this.parentId,
    this.district,
    this.neighborhood,
    this.subUnits,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    // Alt birimleri (sub_units) parse etmek için liste kontrolü
    var subUnitsList = json['sub_units'] as List?;
    List<Institution>? parsedSubUnits;
    if (subUnitsList != null) {
      parsedSubUnits = subUnitsList.map((i) => Institution.fromJson(i)).toList();
    }

    return Institution(
      id: json['kurum_id']?.toString() ?? json['ID']?.toString() ?? json['id']?.toString() ?? '',
      ad: json['kurum_adi'] ?? json['ADI'] ?? "Bilinmiyor",
      tipi: json['tipi'] ?? json['TIPI'] ?? "Hastane",
      tamAdres: json['tam_adres'] ?? json['TAM_ADRES'] ?? "",
      enlem: (json['enlem'] ?? json['ENLEM'] ?? 0.0).toDouble(),
      boylam: (json['boylam'] ?? json['BOYLAM'] ?? 0.0).toDouble(),
      parentId: json['parent_id']?.toString() ?? json['PARENT_ID']?.toString(),
      
      // İç içe JSON (Nested Objects) Parsing
      district: json['district'] != null ? District.fromJson(json['district']) : null,
      neighborhood: json['neighborhood'] != null ? Neighborhood.fromJson(json['neighborhood']) : null,
      
      subUnits: parsedSubUnits,
    );
  }
}