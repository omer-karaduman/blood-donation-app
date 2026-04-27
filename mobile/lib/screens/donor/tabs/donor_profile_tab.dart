// mobile/lib/screens/donor/tabs/donor_profile_tab.dart
//
// Modern profil ekranı: cam-efekti header, düzenlenebilir alanlar,
// mahalle seçici, çıkış.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../../core/constants/api_constants.dart';
import '../../auth/login_screen.dart';

class DonorProfileTab extends StatefulWidget {
  final dynamic currentUser;
  const DonorProfileTab({super.key, required this.currentUser});

  @override
  State<DonorProfileTab> createState() => _DonorProfileTabState();
}

class _DonorProfileTabState extends State<DonorProfileTab>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading    = true;
  bool _isSaving     = false;
  Map<String, dynamic>? _profile;

  List<dynamic> _districts     = [];
  List<dynamic> _neighborhoods = [];
  bool _loadingNbh = false;

  String? _selectedDistrictId;
  String? _selectedNbhId;
  String? _selectedNbhName;
  String? _selectedDistrictName;

  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _weightCtrl  = TextEditingController();

  bool _editMode = false;
  String? _errMsg;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Tema ───────────────────────────────────────────────────────────────────
  static const _primary   = Color(0xFFC0182A);
  static const _primaryDk = Color(0xFF8B0019);
  static const _bg        = Color(0xFFF5F5F7);
  static const _surface   = Colors.white;
  static const _textP     = Color(0xFF1C1C1E);
  static const _textS     = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetchProfile();
    _fetchDistricts();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _fetchProfile() async {
    try {
      final res = await http.get(
          Uri.parse(ApiConstants.donorProfileEndpoint(widget.currentUser.userId)));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _profile    = data;
          _isLoading  = false;
          _nameCtrl.text   = data['ad_soyad']  ?? '';
          _phoneCtrl.text  = data['telefon']   ?? '';
          _weightCtrl.text = (data['kilo'] ?? '').toString();
          _selectedNbhId        = data['neighborhood_id']?.toString();
          _selectedDistrictId   = data['neighborhood']?['district_id']?.toString();
          _selectedNbhName      = data['neighborhood']?['name'];
          _selectedDistrictName = data['neighborhood']?['district']?['name'];
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      debugPrint('[Profile] $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDistricts() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.districtsEndpoint));
      if (res.statusCode == 200 && mounted) {
        setState(() => _districts = json.decode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      debugPrint('[Districts] $e');
    }
  }

  Future<void> _fetchNeighborhoods(String districtId) async {
    setState(() { _loadingNbh = true; _neighborhoods = []; });
    try {
      final res = await http.get(
          Uri.parse(ApiConstants.neighborhoodsEndpoint(districtId)));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _neighborhoods = json.decode(utf8.decode(res.bodyBytes));
          _loadingNbh = false;
        });
      }
    } catch (e) {
      debugPrint('[Neighborhoods] $e');
      if (mounted) setState(() => _loadingNbh = false);
    }
  }

  Future<void> _save() async {
    setState(() { _isSaving = true; _errMsg = null; });
    try {
      final payload = <String, dynamic>{
        'ad_soyad': _nameCtrl.text.trim(),
        'telefon':  _phoneCtrl.text.trim(),
      };
      final w = double.tryParse(_weightCtrl.text.trim());
      if (w != null) payload['kilo'] = w;
      if (_selectedNbhId != null) payload['neighborhood_id'] = _selectedNbhId;

      final res = await http.put(
        Uri.parse(ApiConstants.donorProfileUpdateEndpoint(widget.currentUser.userId)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      if (res.statusCode == 200) {
        await _fetchProfile();
        if (mounted) setState(() => _editMode = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Profil güncellendi!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      } else {
        setState(() => _errMsg = 'Güncelleme başarısız (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _errMsg = 'Bağlantı hatası');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    _buildHealthCard(),
                    const SizedBox(height: 16),
                    _buildLocationCard(),
                    if (_errMsg != null) ...[
                      const SizedBox(height: 16),
                      _errorBanner(_errMsg!),
                    ],
                    if (_editMode) ...[
                      const SizedBox(height: 20),
                      _buildSaveButton(),
                    ],
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final name = _profile?['ad_soyad'] ?? widget.currentUser.adSoyad;
    final blood = _profile?['kan_grubu'] ?? widget.currentUser.kanGrubu;
    final email = _profile?['user']?['email'] ?? '';

    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryDk, _primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -30, right: -30,
              child: _decorCircle(180, 0.07)),
            Positioned(
              bottom: -20, left: 20,
              child: _decorCircle(100, 0.04)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Avatar
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2),
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // İsim ve email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Kan grubu + Düzenle
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.water_drop_rounded,
                                      color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    blood,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => setState(() {
                                _editMode = !_editMode;
                                _errMsg = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _editMode
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _editMode
                                          ? Icons.close_rounded
                                          : Icons.edit_rounded,
                                      size: 12,
                                      color: _editMode ? _primary : Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _editMode ? 'Vazgeç' : 'Düzenle',
                                      style: TextStyle(
                                        color: _editMode ? _primary : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

  // ── BİLGİ KARTI ────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return _card(
      icon: Icons.person_outline_rounded,
      title: 'Kişisel Bilgiler',
      color: _primary,
      child: Column(
        children: [
          _editMode
              ? _inputField('Ad Soyad', _nameCtrl,
                  icon: Icons.badge_outlined)
              : _infoRow(Icons.badge_outlined, 'Ad Soyad',
                  _profile?['ad_soyad'] ?? '—'),
          _divider(),
          _editMode
              ? _inputField('Telefon', _phoneCtrl,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone)
              : _infoRow(Icons.phone_outlined, 'Telefon',
                  _profile?['telefon'] ?? '—'),
          _divider(),
          _infoRow(Icons.email_outlined, 'E-posta',
              _profile?['user']?['email'] ?? '—',
              readOnly: true),
        ],
      ),
    );
  }

  // ── SAĞLIK KARTI ───────────────────────────────────────────────────────────

  Widget _buildHealthCard() {
    final blood = _profile?['kan_grubu'] ?? '—';
    final kilo  = _profile?['kilo']?.toString() ?? '—';
    final cinsiyet = _profile?['cinsiyet'] == 'E' ? 'Erkek' :
                     _profile?['cinsiyet'] == 'K' ? 'Kadın' : '—';
    final canDonate = _profile?['kan_verebilir_mi'] ?? true;
    final lastDonate = _profile?['son_bagis_tarihi'];

    DateTime? lastDate;
    if (lastDonate != null) {
      try {
        final safe = lastDonate.toString().endsWith('Z')
            ? lastDonate.toString() : '${lastDonate}Z';
        lastDate = DateTime.parse(safe).toLocal();
      } catch (_) {}
    }

    return _card(
      icon: Icons.favorite_outline_rounded,
      title: 'Sağlık Bilgileri',
      color: const Color(0xFFD32F2F),
      child: Column(
        children: [
          _infoRow(Icons.water_drop_outlined, 'Kan Grubu', blood, readOnly: true),
          _divider(),
          _editMode
              ? _inputField('Kilo (kg)', _weightCtrl,
                  icon: Icons.monitor_weight_outlined,
                  keyboardType: TextInputType.number)
              : _infoRow(Icons.monitor_weight_outlined, 'Kilo', kilo == '—' ? '—' : '$kilo kg'),
          _divider(),
          _infoRow(Icons.wc_outlined, 'Cinsiyet', cinsiyet, readOnly: true),
          _divider(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.favorite_rounded,
                    color: const Color(0xFFD32F2F), size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bağış Durumu', style: TextStyle(
                        color: _textS, fontSize: 11, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      lastDate != null
                          ? '${lastDate.day}.${lastDate.month}.${lastDate.year} — Son bağış'
                          : 'Henüz bağış yapılmadı',
                      style: const TextStyle(
                          color: _textP, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: canDonate
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  canDonate ? 'Verebilir' : 'Dinleniyor',
                  style: TextStyle(
                    color: canDonate
                        ? Colors.green.shade700
                        : _primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── KONUM KARTI ────────────────────────────────────────────────────────────

  Widget _buildLocationCard() {
    // Önce state'teki seçili mahalleye bak, yoksa profil datasından oku
    String displayLocation;
    if (_selectedNbhName != null && _selectedNbhName!.isNotEmpty) {
      displayLocation = _selectedDistrictName != null && _selectedDistrictName!.isNotEmpty
          ? '$_selectedNbhName, $_selectedDistrictName'
          : _selectedNbhName!;
    } else {
      final nbhName  = _profile?['neighborhood']?['name'];
      final distName = _profile?['neighborhood']?['district']?['name'];
      if (nbhName != null && nbhName.toString().isNotEmpty) {
        displayLocation = distName != null && distName.toString().isNotEmpty
            ? '$nbhName, $distName'
            : nbhName.toString();
      } else {
        displayLocation = 'Konum belirlenmemiş';
      }
    }

    return _card(
      icon: Icons.location_on_outlined,
      title: 'Konum Bilgisi',
      color: const Color(0xFF1565C0),
      child: Column(
        children: [
          _infoRow(
            Icons.location_on_outlined,
            'Mahalle / İlçe',
            displayLocation,
            readOnly: !_editMode,
            onTap: _editMode ? _showLocationDialog : null,
          ),
          if (_editMode) ...[
            _divider(),
            GestureDetector(
              onTap: _showLocationDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_location_outlined,
                        color: Color(0xFF1565C0), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Konumu Değiştir',
                      style: TextStyle(
                        color: Color(0xFF1565C0),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── KONUM DİALOĞU ──────────────────────────────────────────────────────────

  void _showLocationDialog() {
    // Diyalog açılırken temiz bir başlangıç: kayıtlı ilçe seçimi olmadan başla
    String? selDistId;
    String? selNbhId;
    String? selDistName;
    String? selNbhName;
    List<dynamic> nbhs = [];
    bool loadingNbh = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setM) => Container(
          height: MediaQuery.of(ctx2).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFFF4F6F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Text(
                      'Konum Seç',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    if (selNbhId != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDistrictId   = selDistId;
                            _selectedNbhId        = selNbhId;
                            _selectedNbhName      = selNbhName;
                            _selectedDistrictName = selDistName;
                            // Mahalleleri güncelle
                            _neighborhoods        = nbhs;
                          });
                          Navigator.pop(ctx2);
                        },
                        child: const Text('Uygula',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1565C0))),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // İlçe seçimi
                    const Text('İlçe Seçin',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _textS, fontSize: 11)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                       children: _districts.map((d) {
                        final id = d['district_id']?.toString() ?? d['id']?.toString() ?? '';
                        final name = d['name']?.toString() ?? '';
                        final isSelected = selDistId == id;
                        return GestureDetector(
                          onTap: () async {
                            setM(() {
                              selDistId = id;
                              selDistName = name;
                              selNbhId = null;
                              selNbhName = null;
                              nbhs = [];
                              loadingNbh = true;
                            });
                            try {
                              final res = await http.get(Uri.parse(
                                  ApiConstants.neighborhoodsEndpoint(id)));
                              if (res.statusCode == 200) {
                                setM(() {
                                  nbhs = json.decode(utf8.decode(res.bodyBytes));
                                  loadingNbh = false;
                                });
                              }
                            } catch (_) {
                              setM(() => loadingNbh = false);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? _primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? _primary
                                    : Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                color: isSelected ? Colors.white : _textP,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (selDistId != null) ...[
                      const SizedBox(height: 16),
                      const Text('Mahalle Seçin',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _textS, fontSize: 11)),
                      const SizedBox(height: 8),
                      if (loadingNbh)
                        const Center(child: CircularProgressIndicator(
                            color: _primary, strokeWidth: 2))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                            children: nbhs.map((n) {
                            final nId = n['neighborhood_id']?.toString() ?? n['id']?.toString() ?? '';
                            final nName = n['name']?.toString() ?? '';
                            // Geçerli bir ID varsa seçili mi kontrol et
                            final isSelected = nId.isNotEmpty && selNbhId == nId;
                            return GestureDetector(
                              onTap: () => setM(() {
                                selNbhId   = nId;
                                selNbhName = nName;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? _primary : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? _primary
                                        : Colors.grey.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  nName,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : _textP,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ÇIKIŞ ──────────────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: const Row(children: [
            Icon(Icons.logout_rounded, color: _primary, size: 22),
            SizedBox(width: 10),
            Text('Çıkış Yap',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          content: const Text(
            'Hesabınızdan çıkış yapmak istediğinizden emin misiniz?',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İptal',
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              },
              child: const Text('Çıkış Yap',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _primary.withValues(alpha: 0.2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: _primary, size: 18),
            SizedBox(width: 10),
            Text(
              'Hesaptan Çıkış Yap',
              style: TextStyle(
                  color: _primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  // ── KAYDET BUTONU ──────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
        ),
        icon: _isSaving
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_rounded, size: 19),
        label: Text(
          _isSaving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  // ── YARDIMCI WİDGET'LAR ────────────────────────────────────────────────────

  Widget _card({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                  bottom: BorderSide(
                      color: color.withValues(alpha: 0.1))),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _textP),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool readOnly = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: _primary, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _textS,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          color: _textP,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (readOnly && onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: _textS, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl,
      {IconData? icon,
      TextInputType keyboardType = TextInputType.text}) {
    // Telefon: max 11 hane, Kilo: max 3 hane, diğerleri sınırsız
    final bool isPhone  = keyboardType == TextInputType.phone;
    final bool isNumber = keyboardType == TextInputType.number;
    final bool isText   = keyboardType == TextInputType.text;
    final int? maxLen   = isPhone ? 11 : (isNumber ? 3 : null);

    final List<TextInputFormatter> formatters = [];
    if (isPhone || isNumber) {
      formatters.add(FilteringTextInputFormatter.digitsOnly);
    } else if (isText) {
      // İsim alanı: sadece harf ve boşluk (Türkçe karakterler dahil)
      formatters.add(FilteringTextInputFormatter.allow(
        RegExp(r'[a-zA-ZğüşöçıİĞÜŞÖÇ\s]'),
      ));
    }
    if (maxLen != null) {
      formatters.add(LengthLimitingTextInputFormatter(maxLen));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        inputFormatters: formatters.isNotEmpty ? formatters : null,
        style: const TextStyle(
            color: _textP, fontSize: 14, fontWeight: FontWeight.w600),
        cursorColor: _primary,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _textS, fontSize: 12),
          prefixIcon: icon != null
              ? Icon(icon, color: _primary, size: 18)
              : null,
          filled: true,
          fillColor: const Color(0xFFF4F6F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: _primary.withValues(alpha: 0.5), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _primary, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
              style: const TextStyle(color: _primary, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.grey.withValues(alpha: 0.1));

  Widget _decorCircle(double size, double alpha) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryDk, _primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }
}