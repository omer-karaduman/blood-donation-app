// mobile/lib/screens/donor/tabs/donor_home_tab.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../constants/api_constants.dart';
import '../../../models/donor.dart';
import '../ai_agent/ai_chat_screen.dart'; // 🚀 YENİ EKLENDİ: Chat ekranı bağlantısı

class DonorHomeTab extends StatefulWidget {
  final Donor currentUser;
  final Function(int) onTabChange;

  const DonorHomeTab({
    super.key,
    required this.currentUser,
    required this.onTabChange,
  });

  @override
  State<DonorHomeTab> createState() => _DonorHomeTabState();
}

class _DonorHomeTabState extends State<DonorHomeTab> {
  bool _isLoading = true;
  String _userName = "Bağışçı";
  String _kanGrubu = "A+";
  bool _kanVerebilirMi = true;

  int _toplamPuan = 0;
  int _seviye = 1;
  int _toplamBagis = 0;
  int _aktifTalepSayisi = 0;

  Map<String, dynamic>? _activeAcceptedRequest;
  Timer? _refreshTimer;

  // ── Tema renkleri ──────────────────────────────────────────────────────────
  static const _crimson = Color(0xFFC0182A);
  static const _crimsonDark = Color(0xFF8B0000);
  static const _bg = Color(0xFFF5F5F7);
  static const _surface = Colors.white;
  static const _textPrimary = Color(0xFF1C1C1E);
  static const _textSecondary = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _fetchDashboardData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DonorHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchDashboardData(isSilent: true);
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _fetchDashboardData({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) setState(() => _isLoading = true);

    try {
      final userId = widget.currentUser.userId;

      final profileRes =
          await http.get(Uri.parse(ApiConstants.donorProfileEndpoint(userId)));
      final gamificationRes = await http
          .get(Uri.parse(ApiConstants.donorGamificationEndpoint(userId)));

      if (profileRes.statusCode == 200) {
        final pData = json.decode(utf8.decode(profileRes.bodyBytes));
        _userName = pData['ad_soyad'] ?? "Bağışçı";
        _kanVerebilirMi = pData['kan_verebilir_mi'] ?? true;
        _kanGrubu = pData['kan_grubu'] ?? "A+";
        _toplamBagis = pData['toplam_bagis'] ?? 0;
      }

      if (gamificationRes.statusCode == 200) {
        final gData = json.decode(utf8.decode(gamificationRes.bodyBytes));
        _toplamPuan = gData['toplam_puan'] ?? 0;
        _seviye = gData['seviye'] ?? 1;
      }

      final feedRes =
          await http.get(Uri.parse(ApiConstants.donorFeedEndpoint(userId)));
      if (feedRes.statusCode == 200) {
        final dynamic rawData = json.decode(utf8.decode(feedRes.bodyBytes));
        List<dynamic> feedList =
            rawData is List ? rawData : (rawData['items'] ?? []);

        final accepted = feedList
            .where((req) =>
                (req['reaksiyon'] ?? req['kullanici_reaksiyonu']) == 'Kabul')
            .toList();

        if (mounted) {
          setState(() {
            _activeAcceptedRequest = accepted.isNotEmpty
                ? Map<String, dynamic>.from(accepted.first)
                : null;
            _aktifTalepSayisi = feedList
                .where((req) =>
                    (req['reaksiyon'] ?? req['kullanici_reaksiyonu']) ==
                    'Bekliyor')
                .length;
          });
        }
      }
    } catch (e) {
      debugPrint("Dashboard hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelRequest(String logId) async {
    final backup = _activeAcceptedRequest;
    setState(() => _activeAcceptedRequest = null);

    try {
      final url =
          "${ApiConstants.donorsEndpoint}/${widget.currentUser.userId}/respond/$logId?reaksiyon=Red";
      final response = await http.post(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          _showSnack("Görev iptal edildi, kuruma bildirildi.",
              color: Colors.blueGrey.shade800);
        }
        _fetchDashboardData(isSilent: true);
      } else {
        setState(() => _activeAcceptedRequest = backup);
        if (mounted) {
          _showSnack("İptal Başarısız! Sunucu Hatası: ${response.statusCode}",
              color: Colors.red.shade800);
        }
      }
    } catch (_) {
      setState(() => _activeAcceptedRequest = backup);
    }
  }

  void _showSnack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _getRemainingTimeText(Map<String, dynamic> req) {
    try {
      final created =
          DateTime.parse("${req['olusturma_tarihi']}Z").toLocal();
      final expires =
          created.add(Duration(hours: req['gecerlilik_suresi_saat'] ?? 24));
      final diff = expires.difference(DateTime.now());
      if (diff.isNegative) return "Süresi Doldu";
      return "${diff.inHours}sa ${diff.inMinutes.remainder(60)}dk";
    } catch (_) {
      return "--";
    }
  }

  String _getSeviyeLabel(int seviye) {
    if (seviye >= 5) return "Platin";
    if (seviye >= 4) return "Altın";
    if (seviye >= 3) return "Gümüş";
    if (seviye >= 2) return "Bronz";
    return "Başlangıç";
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      
      // 🚀 YENİ EKLENDİ: Sağ altta duracak olan AI Asistan Balonu
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AiChatScreen(currentUser: widget.currentUser),
            ),
          );
        },
        backgroundColor: _crimson, // Tema kırmızımız
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.auto_awesome, color: Colors.white), // Yapay zeka ikonu
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _crimson))
          : RefreshIndicator(
              onRefresh: () => _fetchDashboardData(),
              color: _crimson,
              child: CustomScrollView(
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
                          _buildStatRow(),
                          if (_activeAcceptedRequest != null) ...[
                            const SizedBox(height: 24),
                            _sectionLabel("Aktif Görev"),
                            const SizedBox(height: 10),
                            _buildActiveTaskCard(),
                          ],
                          const SizedBox(height: 24),
                          _sectionLabel("Hızlı İşlemler"),
                          const SizedBox(height: 10),
                          _buildQuickGrid(),
                          if (_kanVerebilirMi &&
                              _aktifTalepSayisi > 0 &&
                              _activeAcceptedRequest == null) ...[
                            const SizedBox(height: 24),
                            _buildEligibilityBanner(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── HERO HEADER ────────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    final firstName = _userName.split(' ').first;
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
            // Dekoratif daireler
            Positioned(
              top: -40, right: -40,
              child: _decorCircle(180, opacity: 0.06),
            ),
            Positioned(
              bottom: -20, left: 50,
              child: _decorCircle(120, opacity: 0.04),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst satır: selamlama + bildirim
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Hoş geldiniz 👋",
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
                        _notifButton(),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Kan grubu + uygunluk
                    Row(
                      children: [
                        _bloodTypePill(),
                        const SizedBox(width: 12),
                        _eligibilityBadge(),
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

  Widget _notifButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: const Icon(Icons.notifications_outlined,
          color: Colors.white, size: 20),
    );
  }

  Widget _bloodTypePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.water_drop, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            _kanGrubu,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eligibilityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            _kanVerebilirMi ? "Bağışa Uygun" : "Dinlenme Süreci",
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

  // ── İSTATİSTİK KARTLARI ────────────────────────────────────────────────────

  Widget _buildStatRow() {
    return Row(
      children: [
        Expanded(
            child: _statCard(
          icon: Icons.water_drop,
          iconColor: _crimson,
          iconBg: const Color(0xFFFFF0F0),
          value: "$_toplamBagis",
          label: "Toplam Bağış",
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(
          icon: Icons.bolt_rounded,
          iconColor: Colors.orange.shade700,
          iconBg: Colors.orange.shade50,
          value: "$_toplamPuan",
          label: "Puan",
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _statCard(
          icon: Icons.military_tech_rounded,
          iconColor: Colors.blue.shade700,
          iconBg: Colors.blue.shade50,
          value: _getSeviyeLabel(_seviye),
          label: "Seviye",
          smallValue: true,
        )),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    bool smallValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.07), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: smallValue ? 13 : 18,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: _textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── AKTİF GÖREV KARTI ─────────────────────────────────────────────────────

  Widget _buildActiveTaskCard() {
    final req = _activeAcceptedRequest!;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.07), width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Başlık şeridi
          Container(
            color: const Color(0xFFFFF5F5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: _crimson, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                const Text(
                  "AKTİF BAĞIŞ GÖREVİ",
                  style: TextStyle(
                    color: _crimson,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0.5, color: Color(0x1FC0182A)),
          // İçerik
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req['kurum_adi'] ?? "Hastane",
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 13, color: _textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                req['ilce'] ?? "İzmir",
                                style: const TextStyle(
                                    fontSize: 12, color: _textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFFCA5A5), width: 0.8),
                      ),
                      child: Text(
                        req['istenen_kan_grubu'] ?? "A+",
                        style: const TextStyle(
                          color: _crimson,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 0.5, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("KALAN SÜRE",
                            style: TextStyle(
                                fontSize: 10,
                                color: _textSecondary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined,
                                size: 15, color: _crimson),
                            const SizedBox(width: 5),
                            Text(
                              _getRemainingTimeText(req),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Material(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => _showCancelConfirmDialog(
                            req['log_id'].toString()),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          child: Text(
                            "İptal Et",
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmDialog(String logId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade800, size: 40),
            ),
            const SizedBox(height: 20),
            const Text("Görevi İptal Et?",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            const SizedBox(height: 12),
            const Text(
              "Bu talebi iptal ettiğinizde hastane yeni bir donör aramak zorunda kalacak. Vazgeçmek istediğinize emin misiniz?",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Hayır, Geri Dön",
                        style: TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelRequest(logId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _crimson,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Evet, İptal Et",
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

  // ── HIZLI İŞLEMLER ────────────────────────────────────────────────────────

  Widget _buildQuickGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _quickCard(
          label: "Kan Talepleri",
          subtitle: _aktifTalepSayisi > 0
              ? "$_aktifTalepSayisi yeni talep"
              : "Aktif talep yok",
          icon: Icons.favorite_outline_rounded,
          iconColor: _crimson,
          iconBg: const Color(0xFFFFF0F0),
          onTap: () => widget.onTabChange(1),
          showBadge: _aktifTalepSayisi > 0,
          badgeCount: _aktifTalepSayisi,
        ),
        _quickCard(
          label: "Geçmişim",
          subtitle: "Bağış geçmişi",
          icon: Icons.history_rounded,
          iconColor: Colors.teal.shade700,
          iconBg: Colors.teal.shade50,
          onTap: () => widget.onTabChange(2),
        ),
        _quickCard(
          label: "Ödüller",
          subtitle: "Rozetler & hedefler",
          icon: Icons.emoji_events_outlined,
          iconColor: Colors.amber.shade700,
          iconBg: Colors.amber.shade50,
          onTap: () => widget.onTabChange(3),
        ),
        _quickCard(
          label: "Profil",
          subtitle: "Ayarlar",
          icon: Icons.person_outline_rounded,
          iconColor: Colors.purple.shade700,
          iconBg: Colors.purple.shade50,
          onTap: () => widget.onTabChange(4),
        ),
      ],
    );
  }

  Widget _quickCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.black.withOpacity(0.07), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  if (showBadge)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _crimson,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "$badgeCount",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: _textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // ── UYGUNLUK BANNER ────────────────────────────────────────────────────────

  Widget _buildEligibilityBanner() {
    return GestureDetector(
      onTap: () => widget.onTabChange(1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_crimson, _crimsonDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.favorite, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bağışa Uygunsunuz",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  SizedBox(height: 2),
                  Text("Bugün bir hayat kurtarabilirsiniz.",
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$_aktifTalepSayisi Talep",
                style: const TextStyle(
                    color: _crimson,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ],
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