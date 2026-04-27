// mobile/lib/screens/admin/staff_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/institution.dart';
import '../../../core/constants/api_constants.dart';

class StaffSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> staff;
  final List<Institution> allInstitutions;

  const StaffSettingsScreen(
      {super.key, required this.staff, required this.allInstitutions});

  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen>
    with SingleTickerProviderStateMixin {
  // ── Controller'lar ────────────────────────────────────────────────────────
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _customTitleCtrl;

  late bool _isActive;
  Institution? _selectedInst;
  String? _errMsg;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  static const _unvanlar = [
    'Kan Merkezi Sorumlusu',
    'Başhekim',
    'Doktor',
    'Hemşire',
    'Laborant',
    'Diğer',
  ];
  late String _selectedTitle;

  // ── Animasyon ─────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Renk ──────────────────────────────────────────────────────────────────
  static const Color _accent = Color(0xFF1565C0);
  static const Color _accentDark = Color(0xFF0D47A1);
  static const Color _accentLight = Color(0xFF1E88E5);
  static const Color _accentBg = Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _nameCtrl  = TextEditingController(text: s['ad_soyad'] ?? '');
    _emailCtrl = TextEditingController(text: s['email'] ?? '');
    _passCtrl  = TextEditingController();
    _customTitleCtrl = TextEditingController();

    _isActive = s['is_active'] ?? true;

    // Kurumu eşleştir
    final kidStr = s['kurum_id']?.toString();
    _selectedInst = widget.allInstitutions
        .where((i) => i.id.toString() == kidStr)
        .firstOrNull;

    // Ünvanı eşleştir
    final currentTitle = s['unvan'] ?? '';
    if (_unvanlar.contains(currentTitle) || currentTitle.isEmpty) {
      _selectedTitle =
          currentTitle.isEmpty ? _unvanlar.first : currentTitle;
    } else {
      _selectedTitle = 'Diğer';
      _customTitleCtrl.text = currentTitle;
    }

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _customTitleCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Türkçe normalize ──────────────────────────────────────────────────────
  String _norm(String t) => t
      .replaceAll('I', 'ı').replaceAll('İ', 'i')
      .replaceAll('Ş', 'ş').replaceAll('Ç', 'ç')
      .replaceAll('Ö', 'ö').replaceAll('Ğ', 'ğ')
      .replaceAll('Ü', 'ü').toLowerCase();

  // ==========================================================================
  // KURUM ARAMA DİALOGU
  // ==========================================================================
  void _showInstDialog() {
    final sc = TextEditingController();
    List<Institution> filtered = List.from(widget.allInstitutions);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(16),
          title: const Text('Kurum Seç',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 17)),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(ctx).size.height * 0.5,
            child: Column(children: [
              TextField(
                controller: sc,
                decoration: InputDecoration(
                  hintText: 'Kurum veya ilçe ara...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                onChanged: (v) {
                  final q = _norm(v);
                  setD(() {
                    filtered = widget.allInstitutions
                        .where((i) =>
                            _norm(i.ad).contains(q) ||
                            _norm(i.ilceAdi).contains(q))
                        .toList();
                  });
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('Sonuç bulunamadı',
                            style: TextStyle(
                                color: Colors.grey.shade500)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final inst = filtered[i];
                          final isBlood = inst.tipi == 'Kan Merkezi';
                          final isSel =
                              _selectedInst?.id == inst.id;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                            tileColor: isSel
                                ? const Color(0xFFE3F2FD)
                                : null,
                            leading: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isBlood
                                    ? const Color(0xFFFFEBEE)
                                    : const Color(0xFFE3F2FD),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isBlood
                                    ? Icons.bloodtype_rounded
                                    : Icons.local_hospital_rounded,
                                size: 18,
                                color: isBlood
                                    ? const Color(0xFFD32F2F)
                                    : const Color(0xFF1565C0),
                              ),
                            ),
                            title: Text(inst.ad,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSel
                                        ? FontWeight.w800
                                        : FontWeight.w600)),
                            subtitle: Text(inst.ilceAdi,
                                style: const TextStyle(
                                    fontSize: 11)),
                            onTap: () {
                              setState(() {
                                _selectedInst = inst;
                                _errMsg = null;
                              });
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
  // GÜNCELLEME
  // ==========================================================================
  Future<void> _update() async {
    setState(() => _errMsg = null);
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty) {
      setState(
          () => _errMsg = 'Ad Soyad ve E-posta boş bırakılamaz.');
      return;
    }
    if (_selectedInst == null) {
      setState(
          () => _errMsg = 'Lütfen görev yapılacak kurumu seçin.');
      return;
    }
    final title = _selectedTitle == 'Diğer'
        ? _customTitleCtrl.text.trim()
        : _selectedTitle;
    if (title.isEmpty) {
      setState(() => _errMsg = 'Geçerli bir ünvan girin.');
      return;
    }
    if (_passCtrl.text.isNotEmpty && _passCtrl.text.length < 6) {
      setState(() => _errMsg = 'Şifre en az 6 karakter olmalı.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final body = <String, dynamic>{
        'ad_soyad': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'unvan': title,
        'kurum_id': _selectedInst!.id.toString(),
        'is_active': _isActive,
      };
      if (_passCtrl.text.trim().isNotEmpty) {
        body['password'] = _passCtrl.text.trim();
      }
      final res = await http.put(
        Uri.parse(
            ApiConstants.staffDetailEndpoint(widget.staff['user_id'].toString())),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Değişiklikler kaydedildi!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ));
          Navigator.pop(context, true);
        }
      } else {
        String det = 'Güncelleme başarısız (${res.statusCode})';
        try {
          final e = json.decode(utf8.decode(res.bodyBytes));
          if (e['detail'] is String) det = e['detail'];
        } catch (_) {}
        setState(() => _errMsg = det);
      }
    } catch (_) {
      setState(
          () => _errMsg = 'Sunucuya bağlanılamadı. Bağlantınızı kontrol edin.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ==========================================================================
  // SİLME
  // ==========================================================================
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFE53935), size: 26),
          SizedBox(width: 10),
          Text('Kalıcı Silme',
              style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ]),
        content: const Text(
          'Bu personelin hesabı ve tüm sistem erişimi kalıcı olarak silinecek.\n\nBu işlem geri alınamaz.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
      _errMsg = null;
    });
    try {
      final res = await http.delete(Uri.parse(
          ApiConstants.staffDetailEndpoint(widget.staff['user_id'].toString())));
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Personel silindi.'),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ));
          Navigator.pop(context, true);
        }
      } else {
        setState(() =>
            _errMsg = 'Silme başarısız (${res.statusCode}).');
      }
    } catch (_) {
      setState(() => _errMsg = 'Sunucu bağlantı hatası.');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final bool busy = _isSubmitting || _isDeleting;
    final String ad = widget.staff['ad_soyad'] ?? 'Personel';
    final String unvan = widget.staff['unvan'] ?? '—';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: busy ? null : _update,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Değişiklikleri Kaydet',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(ad, unvan)),

            // ── Form içerikleri ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Hesap Durumu
                  _sectionLabel('Hesap Erişimi'),
                  const SizedBox(height: 10),
                  _buildStatusToggle(busy),
                  const SizedBox(height: 22),

                  // Kurum
                  _sectionLabel('Görev Yaptığı Kurum'),
                  const SizedBox(height: 10),
                  _buildInstPicker(busy),
                  const SizedBox(height: 22),

                  // Kişisel Bilgiler
                  _sectionLabel('Kişisel Bilgiler'),
                  const SizedBox(height: 10),
                  _buildInfoCard(busy),
                  const SizedBox(height: 22),

                  // Hata
                  if (_errMsg != null) ...[
                    _buildErrBanner(_errMsg!),
                    const SizedBox(height: 22),
                  ],

                  // Tehlikeli işlemler
                  _sectionLabel('Tehlikeli İşlemler',
                      color: const Color(0xFFE53935)),
                  const SizedBox(height: 10),
                  _buildDangerZone(busy),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================
  Widget _buildHeader(String ad, String unvan) {
    return Container(
      height: 190,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accentDark, _accent, _accentLight],
        ),
      ),
      child: Stack(children: [
        Positioned(
          top: -25, right: -15,
          child: Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07)),
          ),
        ),
        Positioned(
          bottom: -50, left: -30,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Geri
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
                // Avatar satırı
                Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('PERSONEL AYARLARI',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0)),
                      ),
                      const SizedBox(height: 6),
                      Text(ad,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(unvan,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13)),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ==========================================================================
  // HESAP DURUMU TOGGLE
  // ==========================================================================
  Widget _buildStatusToggle(bool busy) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isActive
              ? Colors.green.shade200
              : Colors.red.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: (_isActive ? Colors.green : Colors.red)
                  .withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _isActive
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFEBEE),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isActive
                ? Icons.check_circle_rounded
                : Icons.block_rounded,
            color: _isActive
                ? Colors.green.shade600
                : const Color(0xFFE53935),
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              _isActive
                  ? 'Hesap Aktif'
                  : 'Hesap Dondurulmuş',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _isActive
                    ? Colors.green.shade700
                    : const Color(0xFFE53935),
              ),
            ),
            Text(
              _isActive
                  ? 'Personel sisteme giriş yapabilir.'
                  : 'Giriş erişimi engellenmiş.',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade500),
            ),
          ]),
        ),
        Switch.adaptive(
          value: _isActive,
          activeColor: Colors.green.shade600,
          inactiveThumbColor: Colors.grey.shade400,
          onChanged: busy
              ? null
              : (v) => setState(() {
                    _isActive = v;
                    _errMsg = null;
                  }),
        ),
      ]),
    );
  }

  // ==========================================================================
  // KURUM SEÇİCİ
  // ==========================================================================
  Widget _buildInstPicker(bool busy) {
    final hasError = _errMsg != null && _selectedInst == null;
    return GestureDetector(
      onTap: busy ? null : _showInstDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _selectedInst != null
              ? const Color(0xFFE3F2FD)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasError
                ? const Color(0xFFEF9A9A)
                : _selectedInst != null
                    ? const Color(0xFF1565C0).withValues(alpha: 0.4)
                    : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _selectedInst != null
                  ? _accentBg
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedInst?.tipi == 'Kan Merkezi'
                  ? Icons.bloodtype_rounded
                  : Icons.local_hospital_rounded,
              color: _selectedInst != null
                  ? _accent
                  : Colors.grey.shade400,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                _selectedInst != null
                    ? _selectedInst!.ad
                    : 'Kurum seçiniz...',
                style: TextStyle(
                  fontWeight: _selectedInst != null
                      ? FontWeight.w700
                      : FontWeight.normal,
                  fontSize: 14,
                  color: _selectedInst != null
                      ? const Color(0xFF0D47A1)
                      : Colors.grey.shade500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_selectedInst != null) ...[
                const SizedBox(height: 2),
                Text(_selectedInst!.ilceAdi,
                    style: TextStyle(
                        fontSize: 11, color: Colors.blue.shade400)),
              ],
            ]),
          ),
          Icon(Icons.edit_outlined,
              color:
                  _selectedInst != null ? _accent : Colors.grey.shade400,
              size: 18),
        ]),
      ),
    );
  }

  // ==========================================================================
  // KİŞİSEL BİLGİLER KARTI
  // ==========================================================================
  Widget _buildInfoCard(bool busy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        _modernField(
          ctrl: _nameCtrl,
          label: 'Ad Soyad',
          icon: Icons.person_outline_rounded,
          formatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))
          ],
          enabled: !busy,
        ),
        const SizedBox(height: 14),
        _modernField(
          ctrl: _emailCtrl,
          label: 'E-posta Adresi',
          icon: Icons.email_outlined,
          enabled: !busy,
        ),
        const SizedBox(height: 14),
        _modernField(
          ctrl: _passCtrl,
          label: 'Yeni Şifre (boş = değişmez)',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
          enabled: !busy,
        ),
        const SizedBox(height: 14),
        // Ünvan dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTitle,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: _accent),
              items: _unvanlar
                  .map((u) => DropdownMenuItem(
                      value: u,
                      child: Text(u,
                          style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                        _selectedTitle = v!;
                        _errMsg = null;
                      }),
            ),
          ),
        ),
        if (_selectedTitle == 'Diğer') ...[
          const SizedBox(height: 14),
          _modernField(
            ctrl: _customTitleCtrl,
            label: 'Özel Ünvan',
            icon: Icons.edit_outlined,
            enabled: !busy,
          ),
        ],
      ]),
    );
  }

  // ==========================================================================
  // TEHLİKELİ BÖLGE
  // ==========================================================================
  Widget _buildDangerZone(bool busy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFE53935), size: 20),
          const SizedBox(width: 8),
          const Text('Hesabı Tamamen Sil',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Color(0xFFE53935))),
        ]),
        const SizedBox(height: 8),
        Text(
          'Bu işlem geri alınamaz. Personelin tümü sistem erişimi kalıcı olarak silinecektir.',
          style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade400,
              height: 1.5),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: busy ? null : _delete,
            icon: _isDeleting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.delete_forever_rounded, size: 20),
            label: Text(
                _isDeleting ? 'Siliniyor...' : 'Personeli Sistemden Sil',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  // ==========================================================================
  // HATA BANNERI
  // ==========================================================================
  Widget _buildErrBanner(String msg) {
    return Container(
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
  }

  // ==========================================================================
  // YARDIMCILAR
  // ==========================================================================
  Widget _sectionLabel(String text, {Color color = const Color(0xFF607D8B)}) =>
      Text(
        text,
        style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 12,
            letterSpacing: 0.5),
      );

  Widget _modernField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool isPassword = false,
    List<TextInputFormatter>? formatters,
    bool enabled = true,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      inputFormatters: formatters,
      enabled: enabled,
      onChanged: (_) => setState(() => _errMsg = null),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.grey.shade500, fontSize: 13),
        prefixIcon: Icon(icon, color: _accent, size: 20),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: Colors.grey.shade200, width: 1.0)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: _accent, width: 1.5)),
      ),
    );
  }
}