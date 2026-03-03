class Donor {
  final String id;
  final String adSoyad;
  final String email;
  final String kanGrubu;
  final bool kanVerebilirMi;

  Donor({
    required this.id,
    required this.adSoyad,
    required this.email,
    required this.kanGrubu,
    required this.kanVerebilirMi,
  });

  factory Donor.fromJson(Map<String, dynamic> json) {
    return Donor(
      id: json['user_id'] ?? '',
      adSoyad: json['ad_soyad'] ?? 'İsimsiz',
      // Backend'den gelen iç içe user paketini okuyoruz
      email: json['user'] != null ? json['user']['email'] : 'Email Yok', 
      kanGrubu: json['kan_grubu'] ?? '?',
      kanVerebilirMi: json['kan_verebilir_mi'] ?? true,
    );
  }
}