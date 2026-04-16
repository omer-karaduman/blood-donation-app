// mobile/lib/screens/donor/tabs/donor_profile_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants/api_constants.dart';
import '../../login_screen.dart';

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

  // ── Tema renkleri (home tab ile aynı) ─────────────────────────────────────
  static const _crimson = Color(0xFFC0182A);
  static const _crimsonDark = Color(0xFF8B0000);
  static const _bg = Color(0xFFF5F5F7);
  static const _surface = Colors.white;
  static const _textPrimary = Color(0xFF1C1C1E);
  static const _textSecondary = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _fetchProfileFromServer();
    _fetchDistricts();
  }

  // ── API ────────────────────────────────────────────────────────────────────

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

  Future<void> _fetchProfileFromServer() async {
    try {
      final url = ApiConstants.donorProfileEndpoint(widget.currentUser.userId);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _profileData = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Profil hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(Map<String, dynamic> newData) async {
    if (!_isLoading) setState(() => _isLoading = true);
    try {
      final url =
          ApiConstants.donorProfileUpdateEndpoint(widget.currentUser.userId);
      final Map<String, dynamic> payload = {
        "ad_soyad": newData['ad_soyad'] ?? _profileData?['ad_soyad'],
        "telefon": newData['telefon'] ?? _profileData?['telefon'],
        "kilo": newData.containsKey('kilo')
            ? double.tryParse(newData['kilo'].toString())
            : _profileData?['kilo'],
        "neighborhood_id":
            newData['neighborhood_id'] ?? _profileData?['neighborhood_id'],
        "latitude": newData['latitude'] ?? _profileData?['latitude'],
        "longitude": newData['longitude'] ?? _profileData?['longitude'],
      };

      final response = await http.put(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        await _fetchProfileFromServer();
      } else {
        debugPrint("Hata: Backend ${response.statusCode} döndürdü.");
      }
    } catch (e) {
      debugPrint("❌ Güncelleme hatası: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processLocationAndSave(
      String neighborhoodId, String districtName, String neighborhoodName) async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    double? lat;
    double? lon;
    try {
      String cleanN = neighborhoodName
          .replaceAll(
              RegExp(r'\s+Mah\.?$|\s+Mahallesi$', caseSensitive: false), '')
          .trim();
      final url =
          "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent('$cleanN Mahallesi, $districtName, İzmir')}&format=json&limit=1";
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'BloodApp/1.0'});
      final data = json.decode(res.body);
      if (data.isNotEmpty) {
        lat = double.parse(data[0]['lat']);
        lon = double.parse(data[0]['lon']);
      }
    } catch (e) {
      debugPrint("❌ Geocoding hatası: $e");
    }

    Map<String, dynamic> updateData = {"neighborhood_id": neighborhoodId};
    if (lat != null && lon != null) {
      updateData["latitude"] = lat;
      updateData["longitude"] = lon;
    }
    await _updateProfile(updateData);
  }

  // ── MODALS & DİYALOGLAR ───────────────────────────────────────────────────

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.logout_rounded,
                  color: Colors.red.shade700, size: 40),
            ),
            const SizedBox(height: 20),
            const Text("Çıkış Yap?",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            const SizedBox(height: 12),
            const Text(
              "Hesabınızdan çıkmak istediğinize emin misiniz?",
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: _textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("İptal",
                        style: TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                        (Route<dynamic> route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _crimson,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text("Çıkış Yap",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditModal(String label, String key, String initialValue) {
    final TextEditingController ctrl =
        TextEditingController(text: initialValue);
    List<TextInputFormatter> formatters = [];
    TextInputType keyboardType = TextInputType.text;

    if (key == 'ad_soyad') {
      formatters = [
        FilteringTextInputFormatter.allow(
            RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))
      ];
    } else if (key == 'kilo') {
      formatters = [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3)
      ];
      keyboardType = TextInputType.number;
    } else if (key == 'telefon') {
      formatters = [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11)
      ];
      keyboardType = TextInputType.phone;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text("$label Düzenle",
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: keyboardType,
              inputFormatters: formatters,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: _crimson, width: 1.5),
                ),
                prefixIcon:
                    const Icon(Icons.edit_outlined, color: _crimson),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateProfile({key: ctrl.text});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _crimson,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("Güncelle",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showLocationModal() {
    String? sDId;
    String? sNId;

    if (_profileData?['neighborhood'] != null &&
        _profileData?['neighborhood'] is Map) {
      if (_profileData!['neighborhood']['district_id'] != null) {
        sDId =
            _profileData!['neighborhood']['district_id'].toString();
      }
      sNId = _profileData?['neighborhood_id']?.toString();
    } else {
      sNId = _profileData?['neighborhood_id']?.toString();
    }

    List<dynamic> nList = [];
    bool isNLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Bölge Güncelle",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary)),
              const SizedBox(height: 16),
              _styledDropdown<String>(
                label: "İlçe Seçin",
                icon: Icons.location_city_outlined,
                value: sDId,
                items: _districts
                    .map((d) => DropdownMenuItem(
                        value: d['district_id'].toString(),
                        child: Text(d['name'])))
                    .toList(),
                onChanged: (val) async {
                  setModalState(() {
                    sDId = val;
                    sNId = null;
                    isNLoading = true;
                  });
                  final res = await http.get(
                      Uri.parse(ApiConstants.neighborhoodsEndpoint(val!)));
                  setModalState(() {
                    nList =
                        json.decode(utf8.decode(res.bodyBytes));
                    isNLoading = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              _styledDropdown<String>(
                label: "Mahalle Seçin",
                icon: Icons.holiday_village_outlined,
                value: sNId,
                items: nList
                    .map((n) => DropdownMenuItem(
                        value: n['neighborhood_id'].toString(),
                        child: Text(n['name'])))
                    .toList(),
                onChanged: isNLoading
                    ? null
                    : (val) => setModalState(() => sNId = val),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: sNId == null
                    ? null
                    : () async {
                        final dName = _districts.firstWhere((d) =>
                            d['district_id'].toString() == sDId)['name'];
                        final nName = nList.firstWhere((n) =>
                            n['neighborhood_id'].toString() == sNId)['name'];
                        _processLocationAndSave(sNId!, dName, nName);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _crimson,
                  disabledBackgroundColor: Colors.grey.shade200,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Konumu Kaydet",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _styledDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle:
              const TextStyle(color: _textSecondary, fontSize: 12),
          prefixIcon: Icon(icon, color: _crimson, size: 18),
          isDense: true,
        ),
        isExpanded: true,
        dropdownColor: _surface,
        style:
            const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
            child: CircularProgressIndicator(color: _crimson)),
      );
    }

    String mahalle = "Bilinmiyor";
    String ilce = "İlçe Seçilmedi";
    String email = widget.currentUser.email;

    if (_profileData != null) {
      if (_profileData!['neighborhood'] != null &&
          _profileData!['neighborhood'] is Map) {
        mahalle = _profileData!['neighborhood']['name'] ?? "Bilinmiyor";
        if (_profileData!['neighborhood']['district'] != null &&
            _profileData!['neighborhood']['district'] is Map) {
          ilce = _profileData!['neighborhood']['district']['name'] ??
              "İlçe Seçilmedi";
        }
      }
      if (_profileData!['user'] != null &&
          _profileData!['user'] is Map) {
        email =
            _profileData!['user']['email'] ?? widget.currentUser.email;
      }
    }

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHeroHeader(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _sectionLabel("Kişisel Bilgiler"),
                  const SizedBox(height: 10),
                  _buildEditableTile(
                    label: "Ad Soyad",
                    value: _profileData?['ad_soyad'] ?? "İsimsiz",
                    icon: Icons.person_outline_rounded,
                    iconColor: Colors.purple.shade700,
                    iconBg: Colors.purple.shade50,
                    editKey: "ad_soyad",
                  ),
                  const SizedBox(height: 10),
                  _buildEditableTile(
                    label: "Telefon",
                    value: _profileData?['telefon'] ?? "Eklenmemiş",
                    icon: Icons.phone_android_rounded,
                    iconColor: Colors.teal.shade700,
                    iconBg: Colors.teal.shade50,
                    editKey: "telefon",
                    subtitle: "11 haneli numara",
                  ),
                  const SizedBox(height: 10),
                  _buildEditableTile(
                    label: "Kilo",
                    value: "${_profileData?['kilo'] ?? 0} kg",
                    icon: Icons.monitor_weight_outlined,
                    iconColor: Colors.orange.shade700,
                    iconBg: Colors.orange.shade50,
                    editKey: "kilo",
                  ),
                  const SizedBox(height: 10),
                  _buildLocationTile(ilce, mahalle),
                  const SizedBox(height: 24),
                  _sectionLabel("Sistem Bilgileri"),
                  const SizedBox(height: 10),
                  _buildStaticTile(
                    label: "Kan Grubu",
                    value: _profileData?['kan_grubu'] ?? "?",
                    icon: Icons.water_drop_rounded,
                    iconColor: _crimson,
                    iconBg: const Color(0xFFFFF0F0),
                  ),
                  const SizedBox(height: 10),
                  _buildStaticTile(
                    label: "E-posta",
                    value: email,
                    icon: Icons.email_outlined,
                    iconColor: Colors.blueGrey.shade700,
                    iconBg: Colors.blueGrey.shade50,
                  ),
                  const SizedBox(height: 24),
                  _buildLogoutButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HERO HEADER ────────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    final adSoyad = _profileData?['ad_soyad'] ?? "Donör";
    final firstName = adSoyad.split(' ').first;
    final kanGrubu = _profileData?['kan_grubu'] ?? "?";
    final kanVerebilirMi = _profileData?['kan_verebilir_mi'] ?? true;

    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_crimson, _crimsonDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Dekoratif daireler (home tab ile aynı)
            Positioned(
              top: -40,
              right: -40,
              child: _decorCircle(180, opacity: 0.06),
            ),
            Positioned(
              bottom: -20,
              left: 50,
              child: _decorCircle(120, opacity: 0.04),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst satır: başlık + çıkış butonu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Profilim 👤",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              firstName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Çıkış butonu (home tab notif butonu stili)
                        GestureDetector(
                          onTap: _showLogoutDialog,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.14),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Avatar + rozetler
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.18),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2),
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adSoyad,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Kan grubu pill
                                _infoPill(
                                  icon: Icons.water_drop,
                                  text: kanGrubu,
                                  bold: true,
                                ),
                                const SizedBox(width: 8),
                                // Uygunluk badge
                                _dotBadge(kanVerebilirMi
                                    ? "Bağışa Uygun"
                                    : "Dinlenme Süreci"),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size, {required double opacity}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }

  Widget _infoPill({required IconData icon, required String text, bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dotBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF4ADE80),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── KARTLAR ────────────────────────────────────────────────────────────────

  Widget _buildEditableTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String editKey,
    String? subtitle,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _showEditModal(label, editKey, value.replaceAll(' kg', '')),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.black.withOpacity(0.07), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 10, color: _textSecondary)),
                    ],
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 15, color: _textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationTile(String ilce, String mahalle) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _showLocationModal,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.black.withOpacity(0.07), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.location_on_rounded,
                    color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Konum",
                      style: TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ilce,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mahalle,
                      style: const TextStyle(
                          fontSize: 12, color: _textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 15, color: _textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaticTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.black.withOpacity(0.07), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: iconColor)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text("Sabit",
                style: TextStyle(fontSize: 10, color: _textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _showLogoutDialog,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5F5),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: const Color(0xFFFCA5A5), width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: _crimson, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Çıkış Yap",
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _crimson)),
                    SizedBox(height: 2),
                    Text("Hesabınızdan güvenli çıkış yapın",
                        style: TextStyle(
                            fontSize: 11, color: _textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: _crimson, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── YARDIMCI ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}