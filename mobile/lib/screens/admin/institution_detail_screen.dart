// mobile/lib/screens/admin/institution_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/institution.dart';
import 'staff_settings_screen.dart';
import '../../../core/constants/api_constants.dart';

class InstitutionDetailScreen extends StatefulWidget {
  final Institution institution;
  const InstitutionDetailScreen({super.key, required this.institution});

  @override
  State<InstitutionDetailScreen> createState() =>
      _InstitutionDetailScreenState();
}

class _InstitutionDetailScreenState extends State<InstitutionDetailScreen>
    with TickerProviderStateMixin {
  List<dynamic> _staffList = [];
  List<dynamic> _recentLogs = [];
  List<Institution> _allInstitutions = [];
  bool _isLoading = true;
  bool _detailsExpanded = false; // kurum detayları collapse

  late AnimationController _pulseCtrl;
  late AnimationController _listCtrl;
  late Animation<double> _pulseAnim;

  // ── Tema ──────────────────────────────────────────────────────────────────
  bool get _isBlood => widget.institution.tipi == 'Kan Merkezi';
  Color get _primary =>
      _isBlood ? const Color(0xFFD32F2F) : const Color(0xFF1565C0);
  Color get _primaryDark =>
      _isBlood ? const Color(0xFFB71C1C) : const Color(0xFF0D47A1);
  Color get _primaryLight =>
      _isBlood ? const Color(0xFFEF5350) : const Color(0xFF1E88E5);
  Color get _bg =>
      _isBlood ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _listCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pulseAnim = Tween<double>(begin: 0.80, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fetchAll();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  // ==========================================================================
  // VERİ ÇEKME
  // ==========================================================================
  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse(
            ApiConstants.institutionStaffEndpoint(widget.institution.id.toString()))),
        http.get(Uri.parse(ApiConstants.adminLogsEndpoint)),
        http.get(Uri.parse(ApiConstants.institutionsEndpoint)),
      ]);
      if (mounted) {
        setState(() {
          if (results[0].statusCode == 200) {
            _staffList =
                json.decode(utf8.decode(results[0].bodyBytes)) as List;
          }
          if (results[1].statusCode == 200) {
            final all =
                json.decode(utf8.decode(results[1].bodyBytes)) as List;
            _recentLogs = all
                .where((l) => l['kurum_adi'] == widget.institution.ad)
                .take(5)
                .toList();
          }
          if (results[2].statusCode == 200) {
            final raw =
                json.decode(utf8.decode(results[2].bodyBytes)) as List;
            _allInstitutions =
                raw.map((d) => Institution.fromJson(d)).toList();
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
  // PERSONEL EKLEME FORMU
  // ==========================================================================
  void _showAddStaffForm() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final customCtrl = TextEditingController();

    const titles = [
      'Kan Merkezi Sorumlusu', 'Başhekim', 'Doktor',
      'Hemşire', 'Laborant', 'Diğer',
    ];
    String selectedTitle = titles.first;
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
          child: Column(
            children: [
              // Başlık
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_primaryDark, _primary, _primaryLight]),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32)),
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
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Personel Ata',
                            style: TextStyle(color: Colors.white,
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        Text(widget.institution.ad,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
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
                      _lbl('Ad Soyad'), const SizedBox(height: 8),
                      _fld(nameCtrl, 'Tam adı girin',
                          Icons.person_outline_rounded,
                          formatters: [FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))],
                          enabled: !submitting),
                      const SizedBox(height: 16),

                      _lbl('E-posta'), const SizedBox(height: 8),
                      _fld(emailCtrl, 'ornek@kurum.com',
                          Icons.email_outlined, enabled: !submitting),
                      const SizedBox(height: 16),

                      _lbl('Geçici Şifre'), const SizedBox(height: 8),
                      _fld(passCtrl, 'En az 6 karakter',
                          Icons.lock_outline_rounded,
                          isPassword: true, enabled: !submitting),
                      const SizedBox(height: 16),

                      _lbl('Ünvan'), const SizedBox(height: 8),
                      _ddl(value: selectedTitle, items: titles,
                          onChanged: submitting ? null
                              : (v) => setM(() => selectedTitle = v!)),

                      if (selectedTitle == 'Diğer') ...[
                        const SizedBox(height: 16),
                        _lbl('Özel Ünvan'), const SizedBox(height: 8),
                        _fld(customCtrl, 'Ünvanı yazın',
                            Icons.edit_outlined, enabled: !submitting),
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
                            final t = selectedTitle == 'Diğer'
                                ? customCtrl.text.trim()
                                : selectedTitle;
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
                                  'kurum_id': widget.institution.id.toString(),
                                  'unvan': t,
                                  'personel_no':
                                      'P-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                }),
                              );
                              if (res.statusCode == 200) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                _fetchAll();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Personel eklendi!'),
                                      backgroundColor: Colors.green.shade600,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              } else {
                                String det = 'Hata (${res.statusCode})';
                                try {
                                  final e = json.decode(
                                      utf8.decode(res.bodyBytes));
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
                              : const Text('Kaydet ve Ata',
                                  style: TextStyle(fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final inst = widget.institution;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffForm,
        backgroundColor: _primary,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Personel Ata',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAll,
        color: _primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero Header ───────────────────────────────────────────────
            _buildHeader(inst),

            // ── Hızlı istatistikler ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _buildStats(),
              ),
            ),

            // ── Kurum Detayları (collapse paneli) ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildDetailsPanel(inst),
              ),
            ),

            // ── Personel başlığı ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _secLabel('Görevli Personeller',
                        Icons.people_rounded),
                    if (!_isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('${_staffList.length} kişi',
                            style: TextStyle(
                                color: _primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),

            // ── Personel listesi ──────────────────────────────────────────
            if (_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                      child: CircularProgressIndicator(color: _primary)),
                ),
              )
            else if (_staffList.isEmpty)
              SliverToBoxAdapter(
                  child: _buildEmptyStaff())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildStaffCard(_staffList[i], i),
                    childCount: _staffList.length,
                  ),
                ),
              ),

            // ── Son Kan Talepleri ─────────────────────────────────────────
            if (_recentLogs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _secLabel(
                      'Son Kan Talepleri', Icons.bloodtype_rounded),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildLogCard(_recentLogs[i]),
                    childCount: _recentLogs.length,
                  ),
                ),
              ),
            ] else
              const SliverToBoxAdapter(
                  child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HERO HEADER
  // ==========================================================================
  Widget _buildHeader(Institution inst) {
    return SliverToBoxAdapter(
      child: Container(
        height: 195,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryDark, _primary, _primaryLight],
          ),
        ),
        child: Stack(children: [
          Positioned(
            top: -30, right: -20,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07)),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -55, left: -40,
            child: Container(
              width: 210, height: 210,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04)),
            ),
          ),
          Positioned(
            top: 18, right: 26,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value * 0.18,
                child: Icon(
                  _isBlood
                      ? Icons.bloodtype_rounded
                      : Icons.local_hospital_rounded,
                  size: 110, color: Colors.white,
                ),
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
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
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
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _isBlood
                            ? Icons.bloodtype_rounded
                            : Icons.local_hospital_rounded,
                        color: Colors.white, size: 12),
                      const SizedBox(width: 5),
                      Text(inst.tipi.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text(inst.ad,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(inst.ilceAdi,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
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
  // İSTATİSTİK
  // ==========================================================================
  Widget _buildStats() {
    final activeCount =
        _staffList.where((s) => s['is_active'] == true).length;
    return Row(children: [
      _statCard(Icons.people_rounded, '${_staffList.length}',
          'Personel', _primary, _bg),
      const SizedBox(width: 12),
      _statCard(Icons.check_circle_rounded, '$activeCount',
          'Aktif', const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      const SizedBox(width: 12),
      _statCard(Icons.bloodtype_rounded, '${_recentLogs.length}',
          'Talep', const Color(0xFFD32F2F), const Color(0xFFFFEBEE)),
    ]);
  }

  Widget _statCard(IconData icon, String val, String lbl,
      Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 7),
          Text(val,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E))),
          Text(lbl,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  // ==========================================================================
  // DETAY PANELİ (COLLAPSE)
  // ==========================================================================
  Widget _buildDetailsPanel(Institution inst) {
    final parentInst = inst.parentId != null
        ? _allInstitutions
            .where((i) => i.id == inst.parentId)
            .firstOrNull
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _primary.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        // Başlık satırı — tıklanınca aç/kapat
        InkWell(
          borderRadius: _detailsExpanded
              ? const BorderRadius.vertical(top: Radius.circular(18))
              : BorderRadius.circular(18),
          onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.info_outline_rounded,
                    size: 18, color: _primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Kurum Detayları',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E))),
              ),
              AnimatedRotation(
                turns: _detailsExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: _primary, size: 22),
              ),
            ]),
          ),
        ),
        // İçerik
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: _detailsExpanded
              ? Column(children: [
                  Divider(height: 1, color: Colors.grey.shade100),
                  _infoRow(Icons.location_city_rounded, 'İlçe',
                      inst.ilceAdi),
                  _divider(),
                  _infoRow(Icons.map_outlined, 'Tam Adres',
                      inst.tamAdres.isNotEmpty
                          ? inst.tamAdres
                          : 'Belirtilmemiş'),
                  if (parentInst != null) ...[
                    _divider(),
                    _infoRow(Icons.account_tree_rounded, 'Bağlı Kurum',
                        parentInst.ad,
                        valueColor: _primary),
                  ],
                ])
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String lbl, String val,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: _bg, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 16, color: _primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(lbl,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(val,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF1A1A2E),
                    height: 1.3)),
          ]),
        ),
      ]),
    );
  }

  Widget _divider() => Divider(
      height: 1, indent: 48, endIndent: 16, color: Colors.grey.shade100);

  // ==========================================================================
  // PERSONEL KARTI
  // ==========================================================================
  Widget _buildStaffCard(dynamic staff, int idx) {
    final String ad    = staff['ad_soyad'] ?? 'İsimsiz';
    final String unvan = staff['unvan'] ?? '—';
    final String email = staff['email'] ?? '';
    final String no    = staff['personel_no'] ?? '';
    final bool active  = staff['is_active'] ?? true;

    final anim = CurvedAnimation(
      parent: _listCtrl,
      curve: Interval(
        (idx * 0.09).clamp(0.0, 0.7),
        ((idx * 0.09) + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );

    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 22 * (1 - anim.value)),
        child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
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
              if (res == true) _fetchAll();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(children: [
                // Avatar
                Stack(children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: _bg,
                    child: Text(
                      ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: _primary,
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
                        border:
                            Border.all(color: Colors.white, width: 2),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(unvan,
                          style: TextStyle(
                              fontSize: 11,
                              color: _primary,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.email_outlined,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(email,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    if (no.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.badge_outlined,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(no,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400)),
                      ]),
                    ],
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration:
                      BoxDecoration(color: _bg, shape: BoxShape.circle),
                  child: Icon(Icons.chevron_right_rounded,
                      color: _primary, size: 18),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // KAN TALEBİ KARTI
  // ==========================================================================
  Widget _buildLogCard(dynamic log) {
    final String kan = log['istenen_kan_grubu'] ?? '?';
    final String personel = log['staff_ad_soyad'] ?? 'Sistem';
    final int oneri = log['onerilen_donor_sayisi'] ?? 0;
    final String tarih = _fmtDate(log['olusturma_tarihi']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: Text(kan,
                style: const TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(personel,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 3),
            Text(tarih,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$oneri öneri',
              style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ==========================================================================
  // BOŞ DURUM
  // ==========================================================================
  Widget _buildEmptyStaff() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10, offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          Container(
            width: 76, height: 76,
            decoration:
                BoxDecoration(color: _bg, shape: BoxShape.circle),
            child: Icon(Icons.people_outline_rounded,
                size: 38, color: _primary),
          ),
          const SizedBox(height: 14),
          const Text('Henüz Personel Yok',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text(
            'Bu kuruma kayıtlı personel bulunmuyor.',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _showAddStaffForm,
            icon: Icon(Icons.person_add_rounded, color: _primary),
            label: Text('Personel Ata',
                style: TextStyle(
                    color: _primary, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _primary, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
          ),
        ]),
      ),
    );
  }

  // ==========================================================================
  // YARDIMCILAR
  // ==========================================================================
  Widget _secLabel(String text, IconData icon) => Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: _bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: _primary),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
                letterSpacing: -0.3)),
      ]);

  Widget _lbl(String t) => Text(t,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E)));

  Widget _fld(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool isPassword = false,
    List<TextInputFormatter>? formatters,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        inputFormatters: formatters,
        enabled: enabled,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, size: 20, color: _primary),
          filled: true,
          fillColor: Colors.white,
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: _primary),
          items: items
              .map((u) => DropdownMenuItem(
                  value: u,
                  child:
                      Text(u, style: const TextStyle(fontSize: 14))))
              .toList(),
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
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: Color(0xFFC62828),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      );

  String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    try {
      String tStr = raw.toString();
      if (!tStr.endsWith('Z')) tStr += 'Z';
      final dt = DateTime.parse(tStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
      if (diff.inHours < 24) return '${diff.inHours}sa önce';
      return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return raw.toString().substring(0, 10);
    }
  }
}