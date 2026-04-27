// mobile/lib/screens/admin/admin_log_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';

class AdminLogDetailScreen extends StatefulWidget {
  final String talepId;
  final String kanGrubu;
  final String kurumAdi;

  const AdminLogDetailScreen({
    super.key,
    required this.talepId,
    required this.kanGrubu,
    required this.kurumAdi,
  });

  @override
  State<AdminLogDetailScreen> createState() => _AdminLogDetailScreenState();
}

class _AdminLogDetailScreenState extends State<AdminLogDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final res = await http.get(
        Uri.parse(ApiConstants.adminRequestDetailEndpoint(widget.talepId)),
      );
      if (res.statusCode == 200) {
        if (mounted) setState(() { _detail = jsonDecode(utf8.decode(res.bodyBytes)); _isLoading = false; });
      } else {
        if (mounted) setState(() { _errorMessage = "Sunucu hatası: ${res.statusCode}"; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = "Bağlantı hatası."; _isLoading = false; });
    }
  }

  // ─── RENK YARDIMCILARI ─────────────────────────────────────────────────

  Color _kanGrubuColor(String k) =>
      k.contains('-') ? const Color(0xFF7B1FA2) : const Color(0xFFE53935);

  Color _reaksiyonColor(String r) {
    switch (r) {
      case 'Kabul': return const Color(0xFF00897B);
      case 'Tamamlandi': return const Color(0xFF1E88E5);
      case 'Red': return const Color(0xFFE53935);
      case 'Gormezden_Geldi': return const Color(0xFF9E9E9E);
      default: return const Color(0xFFFF8F00);
    }
  }

  Color _reaksiyonBg(String r) {
    switch (r) {
      case 'Kabul': return const Color(0xFFE0F2F1);
      case 'Tamamlandi': return const Color(0xFFE3F2FD);
      case 'Red': return const Color(0xFFFFEBEE);
      case 'Gormezden_Geldi': return const Color(0xFFF5F5F5);
      default: return const Color(0xFFFFF8E1);
    }
  }

  IconData _reaksiyonIcon(String r) {
    switch (r) {
      case 'Kabul': return Icons.check_circle_rounded;
      case 'Tamamlandi': return Icons.favorite_rounded;
      case 'Red': return Icons.cancel_rounded;
      case 'Gormezden_Geldi': return Icons.visibility_off_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String _reaksiyonLabel(String r) {
    switch (r) {
      case 'Kabul': return 'Kabul Etti';
      case 'Tamamlandi': return 'Bağış Yaptı';
      case 'Red': return 'Reddetti';
      case 'Gormezden_Geldi': return 'Görmezden Geldi';
      default: return 'Yanıt Bekliyor';
    }
  }

  Color _aciliyetColor(String a) {
    switch (a) {
      case 'Afet': return const Color(0xFFB71C1C);
      case 'Acil': return const Color(0xFFE53935);
      default: return const Color(0xFF00897B);
    }
  }

  Color _durumColor(String d) {
    switch (d) {
      case 'Aktif': return const Color(0xFF00897B);
      case 'Tamamlandi': return const Color(0xFF1E88E5);
      default: return const Color(0xFF9E9E9E);
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final headerColor = _kanGrubuColor(widget.kanGrubu);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          // ── HERO HEADER ──────────────────────────────────────────────
          _buildHeroHeader(headerColor),

          // ── BODY ─────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _errorMessage != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  // ─── HERO HEADER ───────────────────────────────────────────────────────

  Widget _buildHeroHeader(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(230),
            color,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              right: -20, top: -20,
              child: Container(width: 160, height: 160,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(15)),
              ),
            ),
            Positioned(
              right: 24, bottom: 16,
              child: Icon(Icons.bloodtype_rounded, size: 55, color: Colors.white.withAlpha(30)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.kanGrubu,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        "Talep Detayı",
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LOADING / ERROR ───────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFFE53935)),
          SizedBox(height: 16),
          Text("Detaylar yükleniyor...", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 60, color: Color(0xFFE53935)),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text("Tekrar Dene"),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ANA İÇERİK ────────────────────────────────────────────────────────

  Widget _buildContent() {
    final d = _detail!;
    final bildirimler = (d['bildirimler'] as List<dynamic>?) ?? [];
    final bagislar = (d['bagislar'] as List<dynamic>?) ?? [];

    // Bildirim sıralaması
    final sortedBildirimler = List.from(bildirimler)..sort((a, b) {
      const order = {'Tamamlandi': 0, 'Kabul': 1, 'Bekliyor': 2, 'Red': 3, 'Gormezden_Geldi': 4};
      final aO = order[a['reaksiyon']] ?? 5;
      final bO = order[b['reaksiyon']] ?? 5;
      if (aO != bO) return aO.compareTo(bO);
      return ((b['ml_skoru'] ?? 0) as num).compareTo((a['ml_skoru'] ?? 0) as num);
    });

    return Column(
      children: [
        // ── Bilgi kartı + istatistikler (kaydırılabilir değil, sabit) ──
        _buildInfoCard(d),
        _buildStatRow(d, bildirimler, bagislar),

        // ── Tab Bar ───────────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: _kanGrubuColor(widget.kanGrubu),
            unselectedLabelColor: Colors.grey,
            indicatorColor: _kanGrubuColor(widget.kanGrubu),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: "Donörler (${bildirimler.length})"),
              Tab(text: "Bağışlar (${bagislar.length})"),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),

        // ── Tab İçeriği ───────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBildirimlerList(sortedBildirimler),
              _buildBagislarList(bagislar),
            ],
          ),
        ),
      ],
    );
  }

  // ─── BİLGİ KARTI ───────────────────────────────────────────────────────

  Widget _buildInfoCard(Map<String, dynamic> d) {
    final aciliyet = d['aciliyet_durumu'] ?? 'Normal';
    final durum = d['durum'] ?? '-';
    final tarih = _formatTarih(d['olusturma_tarihi']);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kurum satırı
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF1E88E5), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['kurum_adi'] ?? 'Bilinmiyor',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A2E)),
                        overflow: TextOverflow.ellipsis),
                    if ((d['kurum_adres'] ?? '').isNotEmpty)
                      Text(d['kurum_adres'], style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _infoRow(Icons.person_outline_rounded, "Talep Eden", d['olusturan_personel'] ?? 'Sistem'),
          const SizedBox(height: 8),
          _infoRow(Icons.bloodtype_rounded, "Kan & Ünite",
              "${d['istenen_kan_grubu'] ?? '?'}  •  ${d['unite_sayisi'] ?? '?'} ünite"),
          const SizedBox(height: 8),
          _infoRow(Icons.access_time_rounded, "Tarih", tarih),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _chip(aciliyet, _aciliyetColor(aciliyet)),
              _chip(durum, _durumColor(durum)),
              _chip("${d['gecerlilik_suresi_saat'] ?? '?'} saat", const Color(0xFF7B1FA2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Text("$label: ", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  // ─── İSTATİSTİK SATIRI ─────────────────────────────────────────────────

  Widget _buildStatRow(Map<String, dynamic> d, List bildirimler, List bagislar) {
    final kabulSayisi = bildirimler.where((b) {
      final r = b['reaksiyon'] ?? '';
      return r == 'Kabul' || r == 'Tamamlandi';
    }).length;
    final redSayisi = bildirimler.where((b) => b['reaksiyon'] == 'Red').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          _statMini("${bildirimler.length}", "Bildirim", const Color(0xFF7B1FA2), Icons.notifications_rounded),
          const SizedBox(width: 8),
          _statMini("$kabulSayisi", "Kabul", const Color(0xFF00897B), Icons.check_circle_rounded),
          const SizedBox(width: 8),
          _statMini("$redSayisi", "Red", const Color(0xFFE53935), Icons.cancel_rounded),
          const SizedBox(width: 8),
          _statMini("${bagislar.length}", "Bağış", const Color(0xFF1E88E5), Icons.favorite_rounded),
        ],
      ),
    );
  }

  Widget _statMini(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: color.withAlpha(18), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 9.5)),
          ],
        ),
      ),
    );
  }

  // ─── BİLDİRİMLER LİSTESİ ───────────────────────────────────────────────

  Widget _buildBildirimlerList(List<dynamic> sorted) {
    if (sorted.isEmpty) {
      return _emptyState(Icons.notifications_off_rounded, "Bu talep için bildirim kaydı bulunamadı.");
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _bildirimKart(sorted[i]),
      ),
    );
  }

  Widget _bildirimKart(dynamic b) {
    final reaksiyon = b['reaksiyon'] ?? 'Bekliyor';
    final mlSkoru = (b['ml_skoru'] ?? 0.0) as num;
    final adSoyad = b['donor_ad_soyad'] ?? 'Bilinmiyor';
    final kanGrubu = b['kan_grubu']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(7), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _reaksiyonBg(reaksiyon), shape: BoxShape.circle),
              child: Center(
                child: Text(
                  adSoyad.isNotEmpty ? adSoyad[0].toUpperCase() : '?',
                  style: TextStyle(color: _reaksiyonColor(reaksiyon), fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(adSoyad,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A1A2E)),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: _reaksiyonBg(reaksiyon), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_reaksiyonIcon(reaksiyon), color: _reaksiyonColor(reaksiyon), size: 11),
                            const SizedBox(width: 3),
                            Text(_reaksiyonLabel(reaksiyon),
                                style: TextStyle(color: _reaksiyonColor(reaksiyon), fontSize: 10, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (kanGrubu.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kanGrubuColor(kanGrubu).withAlpha(20),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(kanGrubu,
                              style: TextStyle(color: _kanGrubuColor(kanGrubu), fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(Icons.psychology_rounded, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text("ML: ${mlSkoru.toStringAsFixed(1)}%",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      if (b['reaksiyon_zamani'] != null) ...[
                        const Spacer(),
                        Text(_formatTarih(b['reaksiyon_zamani']),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (mlSkoru / 100).clamp(0.0, 1.0).toDouble(),
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(_reaksiyonColor(reaksiyon)),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BAĞIŞLAR LİSTESİ ──────────────────────────────────────────────────

  Widget _buildBagislarList(List<dynamic> bagislar) {
    if (bagislar.isEmpty) {
      return _emptyState(Icons.favorite_border_rounded, "Bu talep için henüz gerçekleşen bağış kaydı bulunmuyor.");
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      itemCount: bagislar.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _bagisKart(bagislar[i]),
      ),
    );
  }

  Widget _bagisKart(dynamic bg) {
    final adSoyad = bg['donor_ad_soyad'] ?? 'Bilinmiyor';
    final kanGrubu = bg['kan_grubu']?.toString() ?? '';
    final tarih = _formatTarih(bg['bagis_tarihi']);
    final sonuc = bg['islem_sonucu'] ?? '-';
    final isBasarili = sonuc == 'Basarili';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isBasarili ? const Color(0xFF00897B) : const Color(0xFFE53935)).withAlpha(60),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: isBasarili ? const Color(0xFFE0F2F1) : const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isBasarili ? Icons.favorite_rounded : Icons.heart_broken_rounded,
                color: isBasarili ? const Color(0xFF00897B) : const Color(0xFFE53935),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(adSoyad,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (kanGrubu.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kanGrubuColor(kanGrubu).withAlpha(20),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(kanGrubu,
                              style: TextStyle(color: _kanGrubuColor(kanGrubu), fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(tarih, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isBasarili ? const Color(0xFFE0F2F1) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isBasarili ? "✓ Başarılı" : "✗ Başarısız",
                style: TextStyle(
                  color: isBasarili ? const Color(0xFF00897B) : const Color(0xFFE53935),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOŞ DURUM ──────────────────────────────────────────────────────────

  Widget _emptyState(IconData icon, String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(msg, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ─── YARDIMCI ───────────────────────────────────────────────────────────

  String _formatTarih(dynamic tarihStr) {
    if (tarihStr == null) return "-";
    try {
      String tStr = tarihStr.toString();
      if (!tStr.endsWith('Z')) tStr += 'Z';
      final dt = DateTime.parse(tStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return "${diff.inMinutes}dk önce";
      if (diff.inHours < 24) return "${diff.inHours}sa önce";
      if (diff.inDays < 7) return "${diff.inDays} gün önce";
      return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
    } catch (_) {
      return tarihStr.toString().length > 10
          ? tarihStr.toString().substring(0, 10)
          : tarihStr.toString();
    }
  }
}
