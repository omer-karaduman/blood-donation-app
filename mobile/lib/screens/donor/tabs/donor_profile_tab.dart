// mobile/lib/screens/donor/tabs/donor_profile_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants/api_constants.dart';

class DonorProfileTab extends StatefulWidget {
  final dynamic currentUser;
  const DonorProfileTab({super.key, required this.currentUser});

  @override
  State<DonorProfileTab> createState() => _DonorProfileTabState();
}

class _DonorProfileTabState extends State<DonorProfileTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<dynamic> _districts = [];

  @override
  void initState() {
    super.initState();
    _fetchProfileFromServer();
    _fetchDistricts();
  }

  // 📡 İLÇELERİ ÇEK
  Future<void> _fetchDistricts() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.districtsEndpoint));
      if (res.statusCode == 200) {
        setState(() => _districts = json.decode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      debugPrint("❌ İlçeler çekilemedi: $e");
    }
  }

  // 📡 PROFİL VERİSİNİ ÇEK
  Future<void> _fetchProfileFromServer() async {
    try {
      final url = ApiConstants.donorProfileEndpoint(widget.currentUser.userId);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          _profileData = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Profil hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  // 📝 AD, TELEFON, KİLO DÜZENLEME MODALI
  void _showEditModal(String label, String key, String initialValue) {
    final TextEditingController editController = TextEditingController(text: initialValue);
    List<TextInputFormatter> formatters = [];
    TextInputType keyboardType = TextInputType.text;

    // Kısıtlamalar
    if (key == 'ad_soyad') {
      formatters = [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))];
    } else if (key == 'kilo') {
      formatters = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)];
      keyboardType = TextInputType.number;
    } else if (key == 'telefon') {
      formatters = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)];
      keyboardType = TextInputType.phone;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$label Düzenle", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: editController,
              keyboardType: keyboardType,
              inputFormatters: formatters,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.edit, color: Color(0xFFE53935)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Modalı kapat
                _updateProfile({key: editController.text});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("GÜNCELLE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // 📍 KONUM GÜNCELLEME + GEOCODING
  void _showLocationModal() {
    String? sDId;
    String? sNId;
    
    // Güvenli ID okuma
    if (_profileData?['neighborhood'] != null && _profileData?['neighborhood'] is Map) {
      if (_profileData!['neighborhood']['district_id'] != null) {
        sDId = _profileData!['neighborhood']['district_id'].toString();
      }
      sNId = _profileData!['neighborhood_id']?.toString();
    } else {
      sNId = _profileData?['neighborhood_id']?.toString();
    }

    List<dynamic> nList = [];
    bool isNLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Bölge Güncelle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: sDId,
                decoration: const InputDecoration(labelText: "İlçe"),
                items: _districts.map((d) => DropdownMenuItem(value: d['district_id'].toString(), child: Text(d['name']))).toList(),
                onChanged: (val) async {
                  setModalState(() { sDId = val; sNId = null; isNLoading = true; });
                  final res = await http.get(Uri.parse(ApiConstants.neighborhoodsEndpoint(val!)));
                  setModalState(() { nList = json.decode(utf8.decode(res.bodyBytes)); isNLoading = false; });
                },
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: sNId,
                decoration: const InputDecoration(labelText: "Mahalle"),
                items: nList.map((n) => DropdownMenuItem(value: n['neighborhood_id'].toString(), child: Text(n['name']))).toList(),
                onChanged: isNLoading ? null : (val) => setModalState(() => sNId = val),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: sNId == null ? null : () async {
                  // Seçilen mahalle ve ilçe isimlerini bulup koordinat hesapla
                  final dName = _districts.firstWhere((d) => d['district_id'].toString() == sDId)['name'];
                  final nName = nList.firstWhere((n) => n['neighborhood_id'].toString() == sNId)['name'];
                  _processLocationAndSave(sNId!, dName, nName);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), minimumSize: const Size(double.infinity, 50)),
                child: const Text("KONUMU KAYDET", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🌍 OSM ÜZERİNDEN KOORDİNAT BULMA
  Future<void> _processLocationAndSave(String neighborhoodId, String districtName, String neighborhoodName) async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    double? lat;
    double? lon;
    try {
      String cleanN = neighborhoodName.replaceAll(RegExp(r'\s+Mah\.?$|\s+Mahallesi$', caseSensitive: false), '').trim();
      final url = "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent('$cleanN Mahallesi, $districtName, İzmir')}&format=json&limit=1";
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'BloodApp/1.0'});
      final data = json.decode(res.body);
      if (data.isNotEmpty) {
        lat = double.parse(data[0]['lat']);
        lon = double.parse(data[0]['lon']);
      } else {
        debugPrint("OSM Koordinat bulamadı, sadece neighborhood_id güncellenecek.");
      }
    } catch (e) { 
      debugPrint("❌ Geocoding hatası: $e"); 
    }

    Map<String, dynamic> updateData = {
      "neighborhood_id": neighborhoodId,
    };
    
    // Sadece koordinat bulabildiysek gönderiyoruz, yoksa null gitmesin.
    if (lat != null && lon != null) {
      updateData["latitude"] = lat;
      updateData["longitude"] = lon;
    }

    await _updateProfile(updateData);
  }

  // 💾 GENEL GÜNCELLEME İŞLEMİ
  Future<void> _updateProfile(Map<String, dynamic> newData) async {
    if (!_isLoading) setState(() => _isLoading = true);

    try {
      final url = ApiConstants.donorProfileUpdateEndpoint(widget.currentUser.userId);
      
      // Mevcut verileri KESİN OLARAK koru, gelenleri üstüne yaz. Null ezmesini engelle.
      final Map<String, dynamic> payload = {
        "ad_soyad": newData['ad_soyad'] ?? _profileData?['ad_soyad'],
        "telefon": newData['telefon'] ?? _profileData?['telefon'],
        "kilo": newData.containsKey('kilo') ? double.tryParse(newData['kilo'].toString()) : _profileData?['kilo'],
        "neighborhood_id": newData['neighborhood_id'] ?? _profileData?['neighborhood_id'],
        "latitude": newData['latitude'] ?? _profileData?['latitude'], 
        "longitude": newData['longitude'] ?? _profileData?['longitude'],
      };

      final response = await http.put(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        await _fetchProfileFromServer(); // Başarılıysa veriyi tekrar sunucudan çekip UI günceller
      } else {
        debugPrint("Hata: Backend ${response.statusCode} döndürdü.");
      }
    } catch (e) {
      debugPrint("❌ Güncelleme hatası: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))));
    }

    // Gerçek İlçe ve Mahalle İsimleri (Güvenli Çekim)
    String mahalle = "Bilinmiyor";
    String ilce = "İlçe Seçilmedi";

    if (_profileData?['neighborhood'] != null && _profileData?['neighborhood'] is Map) {
      mahalle = _profileData!['neighborhood']['name'] ?? "Bilinmiyor";
      if (_profileData!['neighborhood']['district'] != null) {
        ilce = _profileData!['neighborhood']['district']['name'] ?? "İlçe Seçilmedi";
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                _buildInfoTile("Ad Soyad", _profileData?['ad_soyad'] ?? "İsimsiz", Icons.person_outline, "ad_soyad"),
                _buildInfoTile("Telefon (11 Hane)", _profileData?['telefon'] ?? "Eklenmemiş", Icons.phone_android, "telefon"),
                _buildInfoTile("Kilo (kg)", "${_profileData?['kilo'] ?? 0}", Icons.monitor_weight_outlined, "kilo"),
                
                // 📍 KONUM KARTI
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined, color: Color(0xFFE53935)),
                    title: const Text("Bölge (İlçe / Mahalle)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    subtitle: Text("$ilce / $mahalle", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.edit, color: Colors.grey, size: 18),
                    onTap: _showLocationModal,
                  ),
                ),

                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Text("Sistem Bilgileri", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                _buildStaticTile("Kan Grubu", _profileData?['kan_grubu'] ?? "?", Icons.bloodtype, const Color(0xFFE53935)),
                _buildStaticTile("E-posta", widget.currentUser.email, Icons.email_outlined, Colors.blueGrey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Column(
        children: [
          const CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Icon(Icons.person, size: 45, color: Color(0xFFE53935))),
          const SizedBox(height: 12),
          Text(_profileData?['ad_soyad'] ?? "Donör", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("Gönüllü Bağışçı", style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, String key) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE53935)),
        title: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.edit, color: Colors.grey, size: 18),
        onTap: () => _showEditModal(label, key, value),
      ),
    );
  }

  Widget _buildStaticTile(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[100]!)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        subtitle: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}