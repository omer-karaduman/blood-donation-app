// mobile/lib/screens/admin/staff_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/institution.dart';
import 'staff_settings_screen.dart';
import '../../../core/constants/api_constants.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen>
    with TickerProviderStateMixin {
  List<dynamic> _allStaff = [];
  List<Institution> _allInstitutions = [];
  List<District> _districts = [];
  bool _isLoading = true;

  final _searchCtrl = TextEditingController();
  Institution? _filterInst;
  District? _filterDistrict;

  late AnimationController _listCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Tema ──────────────────────────────────────────────────────────────────
  static const Color _primary    = Color(0xFF1565C0);
  static const Color _primaryDk  = Color(0xFF0D47A1);
  static const Color _primaryLt  = Color(0xFF1E88E5);
  static const Color _primaryBg  = Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _listCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.80, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fetchDistricts();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ==========================================================================
  // VERİ ÇEKME
  // ==========================================================================
  Future<void> _fetchDistricts() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.districtsEndpoint));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as List;
        if (mounted) setState(() => _districts = data.map((d) => District.fromJson(d)).toList());
      }
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse(ApiConstants.staffEndpoint)),
        http.get(Uri.parse(ApiConstants.institutionsEndpoint)),
      ]);
      if (mounted) {
        setState(() {
          if (results[0].statusCode == 200) {
            _allStaff = json.decode(utf8.decode(results[0].bodyBytes));
          }
          if (results[1].statusCode == 200) {
            final raw = json.decode(utf8.decode(results[1].bodyBytes)) as List;
            _allInstitutions = raw.map((d) => Institution.fromJson(d)).toList();
          }
        });
        _listCtrl.forward(from: 0);
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================================
  // FİLTRE
  // ==========================================================================
  String _norm(String t) => t
      .replaceAll('I', 'ı').replaceAll('İ', 'i')
      .replaceAll('Ş', 'ş').replaceAll('Ç', 'ç')
      .replaceAll('Ö', 'ö').replaceAll('Ğ', 'ğ')
      .replaceAll('Ü', 'ü').toLowerCase();

  List<dynamic> get _filtered {
    final q = _norm(_searchCtrl.text);
    return _allStaff.where((s) {
      final name = _norm(s['ad_soyad'] ?? '');
      final inst = _allInstitutions
          .where((i) => i.id == s['kurum_id'])
          .firstOrNull;
      final district = inst != null ? _norm(inst.ilceAdi) : '';

      final matchName     = name.contains(q);
      final matchDistrict = _filterDistrict == null ||
          district == _norm(_filterDistrict!.name);
      final matchInst     = _filterInst == null ||
          _filterInst!.id == s['kurum_id'];

      return matchName && matchDistrict && matchInst;
    }).toList();
  }

  // ==========================================================================
  // KURUM ARAMA DİALOGU
  // ==========================================================================
  void _showInstDialog({required bool isFilter}) {
    final sc = TextEditingController();
    List<Institution> filtered = List.from(_allInstitutions);
    final current = isFilter ? _filterInst : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(16),
          title: Text(isFilter ? 'Kuruma Göre Filtrele' : 'Kurum Seç',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(ctx).size.height * 0.5,
            child: Column(children: [
              _searchField(sc, 'Kurum veya ilçe ara...', (v) {
                final q = _norm(v);
                setD(() {
                  filtered = _allInstitutions
                      .where((i) => _norm(i.ad).contains(q) || _norm(i.ilceAdi).contains(q))
                      .toList();
                });
              }),
              const SizedBox(height: 8),
              if (isFilter)
                _clearTile('Tüm Kurumlar (Filtreyi Sıfırla)', () {
                  setState(() => _filterInst = null);
                  Navigator.pop(ctx);
                }),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('Sonuç bulunamadı',
                        style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final inst = filtered[i];
                          final sel  = current?.id == inst.id;
                          final isBlood = inst.tipi == 'Kan Merkezi';
                          return ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            tileColor: sel ? _primaryBg : null,
                            leading: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isBlood
                                    ? const Color(0xFFFFEBEE)
                                    : _primaryBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isBlood
                                    ? Icons.bloodtype_rounded
                                    : Icons.local_hospital_rounded,
                                size: 17,
                                color: isBlood
                                    ? const Color(0xFFD32F2F)
                                    : _primary,
                              ),
                            ),
                            title: Text(inst.ad,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.w800
                                        : FontWeight.w600)),
                            subtitle: Text(inst.ilceAdi,
                                style: const TextStyle(fontSize: 11)),
                            onTap: () {
                              if (isFilter) {
                                setState(() => _filterInst = inst);
                              }
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // İLÇE ARAMA DİALOGU
  // ==========================================================================
  void _showDistrictDialog() {
    final sc = TextEditingController();
    List<District> filtered = List.from(_districts);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(16),
          title: const Text('İlçeye Göre Filtrele',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(ctx).size.height * 0.5,
            child: Column(children: [
              _searchField(sc, 'İlçe ara...', (v) {
                final q = _norm(v);
                setD(() {
                  filtered = _districts
                      .where((d) => _norm(d.name).contains(q))
                      .toList();
                });
              }),
              const SizedBox(height: 8),
              _clearTile('Tüm İlçeler (Filtreyi Sıfırla)', () {
                setState(() => _filterDistrict = null);
                Navigator.pop(ctx);
              }),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('Sonuç bulunamadı',
                        style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final dist = filtered[i];
                          final sel  = _filterDistrict?.id == dist.id;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            tileColor: sel ? _primaryBg : null,
                            leading: Icon(Icons.location_on_rounded,
                                color: sel ? _primary : Colors.grey.shade400,
                                size: 20),
                            title: Text(dist.name,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: sel
                                        ? FontWeight.w800
                                        : FontWeight.normal)),
                            onTap: () {
                              setState(() => _filterDistrict = dist);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PERSONEL EKLEME FORMU
  // ==========================================================================
  void _showAddStaffForm() {
    final nameCtrl   = TextEditingController();
    final emailCtrl  = TextEditingController();
    final passCtrl   = TextEditingController();
    final customCtrl = TextEditingController();

    const titles = [
      'Kan Merkezi Sorumlusu', 'Başhekim', 'Doktor',
      'Hemşire', 'Laborant', 'Diğer',
    ];
    String selTitle = titles.first;
    Institution? selInst;
    String? errMsg;
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          height: MediaQuery.of(ctx).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(children: [
            // Gradient başlık
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_primaryDk, _primary, _primaryLt]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
              child: Column(children: [
                Container(
                  width: 44, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.person_add_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sisteme Personel Ekle',
                          style: TextStyle(color: Colors.white,
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('Görev yapacağı kurumu seçin',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  )),
                ]),
              ]),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                    left: 24, right: 24, top: 24,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kurum seçici
                    _formLabel('Görev Yapacağı Kurum'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: submitting ? null : () {
                        final sc2 = TextEditingController();
                        List<Institution> flt = List.from(_allInstitutions);
                        showDialog(
                          context: ctx,
                          builder: (d) => StatefulBuilder(
                            builder: (d, sd) => AlertDialog(
                              backgroundColor: Colors.white,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              contentPadding: const EdgeInsets.all(16),
                              title: const Text('Kurum Seç',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17)),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: MediaQuery.of(d).size.height * 0.5,
                                child: Column(children: [
                                  _searchField(sc2, 'Kurum veya ilçe ara...', (v) {
                                    final q = _norm(v);
                                    sd(() {
                                      flt = _allInstitutions
                                          .where((i) =>
                                              _norm(i.ad).contains(q) ||
                                              _norm(i.ilceAdi).contains(q))
                                          .toList();
                                    });
                                  }),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: flt.length,
                                      itemBuilder: (_, i) {
                                        final inst = flt[i];
                                        final isBlood = inst.tipi == 'Kan Merkezi';
                                        return ListTile(
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10)),
                                          tileColor: selInst?.id == inst.id ? _primaryBg : null,
                                          leading: Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: isBlood
                                                  ? const Color(0xFFFFEBEE)
                                                  : _primaryBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              isBlood
                                                  ? Icons.bloodtype_rounded
                                                  : Icons.local_hospital_rounded,
                                              size: 17,
                                              color: isBlood
                                                  ? const Color(0xFFD32F2F)
                                                  : _primary,
                                            ),
                                          ),
                                          title: Text(inst.ad,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          subtitle: Text(inst.ilceAdi,
                                              style: const TextStyle(fontSize: 11)),
                                          onTap: () {
                                            setM(() {
                                              selInst = inst;
                                              errMsg  = null;
                                            });
                                            Navigator.pop(d);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                      child: _instPickerWidget(selInst, errMsg),
                    ),
                    const SizedBox(height: 16),

                    _formLabel('Ad Soyad'),
                    const SizedBox(height: 8),
                    _fld(nameCtrl, 'Personelin tam adı', Icons.person_outline_rounded,
                        formatters: [FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))],
                        enabled: !submitting),
                    const SizedBox(height: 16),

                    _formLabel('E-posta'),
                    const SizedBox(height: 8),
                    _fld(emailCtrl, 'ornek@kurum.com', Icons.email_outlined,
                        enabled: !submitting),
                    const SizedBox(height: 16),

                    _formLabel('Geçici Şifre'),
                    const SizedBox(height: 8),
                    _fld(passCtrl, 'En az 6 karakter', Icons.lock_outline_rounded,
                        isPassword: true, enabled: !submitting),
                    const SizedBox(height: 16),

                    _formLabel('Ünvan'),
                    const SizedBox(height: 8),
                    _ddl(value: selTitle, items: titles,
                        onChanged: submitting ? null
                            : (v) => setM(() => selTitle = v!)),

                    if (selTitle == 'Diğer') ...[
                      const SizedBox(height: 16),
                      _formLabel('Özel Ünvan'),
                      const SizedBox(height: 8),
                      _fld(customCtrl, 'Ünvanı yazın', Icons.edit_outlined,
                          enabled: !submitting),
                    ],

                    if (errMsg != null) ...[
                      const SizedBox(height: 16),
                      _errBanner(errMsg!),
                    ],

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity, height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white, elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: submitting ? null : () async {
                          setM(() => errMsg = null);
                          if (selInst == null) {
                            setM(() => errMsg = 'Lütfen kurum seçin.');
                            return;
                          }
                          if (nameCtrl.text.trim().isEmpty ||
                              emailCtrl.text.trim().isEmpty ||
                              passCtrl.text.isEmpty) {
                            setM(() => errMsg = 'Tüm alanları doldurun.');
                            return;
                          }
                          if (passCtrl.text.length < 6) {
                            setM(() => errMsg = 'Şifre en az 6 karakter.');
                            return;
                          }
                          final t = selTitle == 'Diğer'
                              ? customCtrl.text.trim()
                              : selTitle;
                          if (t.isEmpty) {
                            setM(() => errMsg = 'Ünvan gerekli.');
                            return;
                          }
                          setM(() => submitting = true);
                          try {
                            final res = await http.post(
                              Uri.parse(ApiConstants.staffEndpoint),
                              headers: {'Content-Type': 'application/json'},
                              body: json.encode({
                                'email': emailCtrl.text.trim(),
                                'password': passCtrl.text.trim(),
                                'ad_soyad': nameCtrl.text.trim(),
                                'kurum_id': selInst!.id.toString(),
                                'unvan': t,
                                'personel_no':
                                    'P-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                              }),
                            );
                            if (res.statusCode == 200) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              _fetchData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Text('Personel eklendi!'),
                                  backgroundColor: Colors.green.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ));
                              }
                            } else {
                              String det = 'Hata (${res.statusCode})';
                              try {
                                final e = json.decode(utf8.decode(res.bodyBytes));
                                if (e['detail'] is String) det = e['detail'];
                              } catch (_) {}
                              setM(() => errMsg = det);
                            }
                          } catch (_) {
                            setM(() => errMsg = 'Bağlantı hatası.');
                          } finally {
                            setM(() => submitting = false);
                          }
                        },
                        child: submitting
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Sisteme Kaydet',
                                style: TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffForm,
        backgroundColor: _primary,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Yeni Personel',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: _primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero Header ───────────────────────────────────────────────
            _buildHeader(),

            // ── Filtre Paneli ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _buildFilterPanel(),
              ),
            ),

            // ── İstatistik satırı ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _buildStatsRow(list),
              ),
            ),

            // ── Liste başlığı ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Personel Listesi',
                        style: TextStyle(fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: -0.3)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                          color: _primaryBg,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${list.length} kayıt',
                          style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),

            // ── Liste ─────────────────────────────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(color: _primary)))
            else if (list.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildCard(list[i], i),
                    childCount: list.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HERO HEADER
  // ==========================================================================
  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        height: 185,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryDk, _primary, _primaryLt],
          ),
        ),
        child: Stack(children: [
          Positioned(
            top: -28, right: -18,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 170, height: 170,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07)),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -55, left: -35,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04)),
            ),
          ),
          Positioned(
            top: 20, right: 28,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value * 0.15,
                child: const Icon(Icons.manage_accounts_rounded,
                    size: 110, color: Colors.white),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.17),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text('Geri',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.manage_accounts_rounded,
                          color: Colors.white, size: 12),
                      SizedBox(width: 5),
                      Text('YÖNETİM PANELİ',
                          style: TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  const Text('Personel Yönetimi',
                      style: TextStyle(color: Colors.white,
                          fontSize: 22, fontWeight: FontWeight.w900,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text('Tüm hastane ve kan merkezi çalışanları',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ==========================================================================
  // FİLTRE PANELİ
  // ==========================================================================
  Widget _buildFilterPanel() {
    return Column(children: [
      // İsim arama
      Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Personel ismiyle ara...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded,
                color: _primary, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
      ),
      const SizedBox(height: 10),
      // İlçe + Kurum satırı
      Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _showDistrictDialog,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _filterDistrict != null ? _primaryBg : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _filterDistrict != null
                        ? _primary.withValues(alpha: 0.4)
                        : Colors.grey.shade200),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6)],
              ),
              child: Row(children: [
                Icon(Icons.location_city_rounded,
                    size: 17,
                    color: _filterDistrict != null ? _primary : Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _filterDistrict?.name ?? 'İlçe seç...',
                    style: TextStyle(
                        fontSize: 12,
                        color: _filterDistrict != null
                            ? _primary
                            : Colors.grey.shade500,
                        fontWeight: _filterDistrict != null
                            ? FontWeight.w700
                            : FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_filterDistrict != null)
                  GestureDetector(
                    onTap: () => setState(() => _filterDistrict = null),
                    child: const Icon(Icons.close_rounded,
                        size: 15, color: _primary),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => _showInstDialog(isFilter: true),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _filterInst != null ? _primaryBg : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _filterInst != null
                        ? _primary.withValues(alpha: 0.4)
                        : Colors.grey.shade200),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6)],
              ),
              child: Row(children: [
                Icon(Icons.local_hospital_rounded,
                    size: 17,
                    color: _filterInst != null ? _primary : Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _filterInst?.ad ?? 'Kurum seç...',
                    style: TextStyle(
                        fontSize: 12,
                        color: _filterInst != null
                            ? _primary
                            : Colors.grey.shade500,
                        fontWeight: _filterInst != null
                            ? FontWeight.w700
                            : FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_filterInst != null)
                  GestureDetector(
                    onTap: () => setState(() => _filterInst = null),
                    child: const Icon(Icons.close_rounded,
                        size: 15, color: _primary),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    ]);
  }

  // ==========================================================================
  // İSTATİSTİK SATIRI
  // ==========================================================================
  Widget _buildStatsRow(List<dynamic> list) {
    final active = list.where((s) => s['is_active'] == true).length;
    final passive = list.length - active;

    return Row(children: [
      _mini(Icons.people_rounded, '${list.length}', 'Toplam',
          _primary, _primaryBg),
      const SizedBox(width: 10),
      _mini(Icons.check_circle_rounded, '$active', 'Aktif',
          const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      const SizedBox(width: 10),
      _mini(Icons.block_rounded, '$passive', 'Pasif',
          const Color(0xFF757575), Colors.grey.shade100),
    ]);
  }

  Widget _mini(IconData icon, String val, String lbl,
      Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 6),
          Text(val, style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A2E))),
          Text(lbl, style: TextStyle(
              fontSize: 10, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  // ==========================================================================
  // PERSONEL KARTI
  // ==========================================================================
  Widget _buildCard(dynamic staff, int idx) {
    final String ad    = staff['ad_soyad'] ?? 'İsimsiz';
    final String unvan = staff['unvan'] ?? '—';
    final String email = staff['email'] ?? '';
    final bool active  = staff['is_active'] ?? true;
    final String kurum = staff['kurum_adi'] ?? 'Kurum Atanmamış';

    final inst = _allInstitutions
        .where((i) => i.id == staff['kurum_id'])
        .firstOrNull;
    final isBlood = inst?.tipi == 'Kan Merkezi';
    final Color cardColor = isBlood
        ? const Color(0xFFD32F2F)
        : _primary;
    final Color cardBg = isBlood
        ? const Color(0xFFFFEBEE)
        : _primaryBg;

    final anim = CurvedAnimation(
      parent: _listCtrl,
      curve: Interval(
        (idx * 0.08).clamp(0.0, 0.7),
        ((idx * 0.08) + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - anim.value)),
        child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              final res = await Navigator.push(context,
                  MaterialPageRoute(
                    builder: (_) => StaffSettingsScreen(
                        staff: staff,
                        allInstitutions: _allInstitutions),
                  ));
              if (res == true) _fetchData();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(children: [
                // Avatar
                Stack(children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: cardBg,
                    child: Text(
                      ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: cardColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 20),
                    ),
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 13, height: 13,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.green.shade500
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(width: 14),
                // Bilgi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(ad,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF1A1A2E))),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFE8F5E9)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            active ? 'Aktif' : 'Pasif',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 5),
                      // Kurum badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            isBlood
                                ? Icons.bloodtype_rounded
                                : Icons.local_hospital_rounded,
                            size: 11, color: cardColor),
                          const SizedBox(width: 4),
                          Flexible(child: Text(kurum,
                              style: TextStyle(fontSize: 11,
                                  color: cardColor,
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                      const SizedBox(height: 5),
                      Row(children: [
                        Icon(Icons.badge_outlined,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(unvan,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.email_outlined,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(email,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: cardBg, shape: BoxShape.circle),
                  child: Icon(Icons.chevron_right_rounded,
                      color: cardColor, size: 18),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // BOŞ DURUM
  // ==========================================================================
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(color: _primaryBg, shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded,
                size: 40, color: _primary),
          ),
          const SizedBox(height: 16),
          const Text('Personel Bulunamadı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text('Arama kriterlerinizle eşleşen personel yok.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ==========================================================================
  // YARDIMCILAR
  // ==========================================================================
  Widget _searchField(TextEditingController ctrl, String hint,
      ValueChanged<String> onChanged) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _clearTile(String label, VoidCallback onTap) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: const Color(0xFFFFEBEE),
      leading: const Icon(Icons.clear_all_rounded,
          color: Color(0xFFD32F2F)),
      title: Text(label,
          style: const TextStyle(
              color: Color(0xFFD32F2F),
              fontWeight: FontWeight.bold, fontSize: 13)),
      onTap: onTap,
    );
  }

  Widget _instPickerWidget(Institution? inst, String? err) {
    final hasErr = err != null && inst == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: inst != null ? _primaryBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasErr
              ? const Color(0xFFEF9A9A)
              : inst != null
                  ? _primary.withValues(alpha: 0.4)
                  : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: inst != null ? _primaryBg : Colors.grey.shade100,
              shape: BoxShape.circle),
          child: Icon(
            inst?.tipi == 'Kan Merkezi'
                ? Icons.bloodtype_rounded
                : Icons.local_hospital_rounded,
            color: inst != null ? _primary : Colors.grey.shade400,
            size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            inst != null
                ? '${inst.ad} (${inst.ilceAdi})'
                : 'Kurumu ara ve seç...',
            style: TextStyle(
                fontSize: 14,
                fontWeight: inst != null ? FontWeight.w700 : FontWeight.normal,
                color: inst != null ? const Color(0xFF0D47A1) : Colors.grey.shade500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(Icons.search_rounded,
            color: inst != null ? _primary : Colors.grey.shade400,
            size: 18),
      ]),
    );
  }

  Widget _formLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E)));

  Widget _fld(TextEditingController ctrl, String hint, IconData icon, {
    bool isPassword = false,
    List<TextInputFormatter>? formatters,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        inputFormatters: formatters,
        enabled: enabled,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, size: 20, color: _primary),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _ddl({
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _primary),
          items: items.map((u) => DropdownMenuItem(
              value: u,
              child: Text(u, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _errBanner(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEF9A9A)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE53935), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
              style: const TextStyle(color: Color(0xFFC62828),
                  fontSize: 13, fontWeight: FontWeight.w500))),
        ]),
      );
}