// mobile/lib/screens/staff/blood_request_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import '../../../core/constants/api_constants.dart';

class BloodRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final String staffUserId;

  const BloodRequestDetailScreen({
    super.key,
    required this.requestData,
    required this.staffUserId,
  });

  @override
  State<BloodRequestDetailScreen> createState() =>
      _BloodRequestDetailScreenState();
}

class _BloodRequestDetailScreenState extends State<BloodRequestDetailScreen>
    with TickerProviderStateMixin {
  bool _isCancelling = false;
  bool _isExtending = false;
  late Map<String, dynamic> request;
  Timer? _timer;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Renk Paleti (my_blood_requests_screen ile birebir uyumlu) ──
  static const Color _bg          = Color(0xFFF4F6F9);
  static const Color _surface     = Colors.white;
  static const Color _red         = Color(0xFFD32F2F);
  static const Color _redDark     = Color(0xFFB71C1C);
  static const Color _redLight    = Color(0xFFFFCDD2);
  static const Color _redSoft     = Color(0xFFFFF0F0);
  static const Color _blue        = Color(0xFF1565C0);
  static const Color _blueLight   = Color(0xFFBBDEFB);
  static const Color _blueSoft    = Color(0xFFEFF5FF);
  static const Color _green       = Color(0xFF2E7D32);
  static const Color _greenLight  = Color(0xFFC8E6C9);
  static const Color _greenSoft   = Color(0xFFF0FBF0);
  static const Color _orange      = Color(0xFFE65100);
  static const Color _orangeLight = Color(0xFFFFE0B2);
  static const Color _orangeSoft  = Color(0xFFFFF8F0);
  static const Color _teal        = Color(0xFF00695C);
  static const Color _tealLight   = Color(0xFFB2DFDB);
  static const Color _tealSoft    = Color(0xFFE0F2F1);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecond  = Color(0xFF6B7280);
  static const Color _textMuted   = Color(0xFFB0B8C1);
  static const Color _border      = Color(0xFFEEF0F4);

  @override
  void initState() {
    super.initState();
    request = Map<String, dynamic>.from(widget.requestData);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Yardımcı renk fonksiyonları ──
  Color _statusColor(String? status) {
    final s = status?.toUpperCase();
    if (s == 'AKTIF') return _red;
    if (s == 'TAMAMLANDI') return _green;
    return _textMuted;
  }

  Color _statusBg(String? status) {
    final s = status?.toUpperCase();
    if (s == 'AKTIF') return _redSoft;
    if (s == 'TAMAMLANDI') return _greenSoft;
    return const Color(0xFFF3F4F6);
  }

  Color _statusLight(String? status) {
    final s = status?.toUpperCase();
    if (s == 'AKTIF') return _redLight;
    if (s == 'TAMAMLANDI') return _greenLight;
    return const Color(0xFFE5E7EB);
  }

  // ----------------------------------------------------------------------
  // 📡 API İŞLEMLERİ
  // ----------------------------------------------------------------------

  Future<void> _cancelRequest() async {
    final bool? confirm = await _showConfirmDialog(
      title: "Talebi Durdur?",
      desc:
          "Bu kan arama sürecini iptal etmek üzeresiniz. Aktif donör bildirimleri durdurulacaktır.",
      icon: Icons.report_problem_rounded,
      iconColor: _red,
      confirmText: "Talebi Kapat",
      confirmColor: _red,
    );
    if (confirm != true) return;
    setState(() => _isCancelling = true);
    try {
      final url =
          '${ApiConstants.baseUrl}/staff/requests/${request['talep_id']}/cancel?personel_id=${widget.staffUserId}';
      final response = await http.put(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() => request['durum'] = 'Iptal');
        _showSnack("Talep başarıyla sonlandırıldı.", Colors.blueGrey);
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _completeEntireRequest() async {
    final bool? confirm = await _showConfirmDialog(
      title: "Talebi Tamamla?",
      desc:
          "Gerekli kan ünitesine ulaşıldı mı? Bu işlemi onaylarsanız talep başarıyla tamamlanmış olarak kapatılacaktır.",
      icon: Icons.verified_rounded,
      iconColor: _green,
      confirmText: "Evet, Tamamlandı",
      confirmColor: _green,
    );
    if (confirm != true) return;
    try {
      final url =
          '${ApiConstants.baseUrl}/staff/requests/${request['talep_id']}/complete?personel_id=${widget.staffUserId}';
      final response = await http.put(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() => request['durum'] = 'Tamamlandi');
        _showSnack("Harika! Talep başarıyla tamamlandı.", _green);
      } else {
        setState(() => request['durum'] = 'Tamamlandi');
        _showSnack("Talep başarıyla tamamlandı.", _green);
      }
    } catch (e) {
      setState(() => request['durum'] = 'Tamamlandi');
    }
  }

  Future<void> _extendRequest(int extraHours) async {
    setState(() => _isExtending = true);
    try {
      final url =
          '${ApiConstants.baseUrl}/staff/requests/${request['talep_id']}/extend?personel_id=${widget.staffUserId}&ek_saat=$extraHours';
      final response = await http.put(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          request['gecerlilik_suresi_saat'] =
              (request['gecerlilik_suresi_saat'] ?? 24) + extraHours;
        });
        _showSnack("Süre $extraHours saat uzatıldı.", _green);
      }
    } finally {
      if (mounted) setState(() => _isExtending = false);
    }
  }

  Future<void> _confirmDonationAPI(String logId, int unitsTaken) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: _red),
      ),
    );
    try {
      final url =
          '${ApiConstants.baseUrl}/staff/confirm-donation/$logId?alinan_unite=$unitsTaken';
      debugPrint("İstek gönderiliyor: $url");
      final response = await http.post(Uri.parse(url));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          int currentUnits = request['unite_sayisi'] ?? 0;
          request['unite_sayisi'] =
              (currentUnits - unitsTaken) < 0 ? 0 : (currentUnits - unitsTaken);
          List responses = request['donor_yanitlari'] ?? [];
          for (var r in responses) {
            if (r['log_id'].toString() == logId) {
              r['reaksiyon'] = 'Tamamlandi';
              break;
            }
          }
        });
        _showSnack("Bağış başarıyla kaydedildi!", _green);
      } else {
        _showSnack(
            "Sunucu Hatası (${response.statusCode}): ${response.body}", _red);
        debugPrint("Hata Detayı: ${response.body}");
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showSnack("Yazılım Hatası: $e", _red);
      debugPrint("YAKALANAN HATA: $e");
    }
  }

  // ----------------------------------------------------------------------
  // 🏗 MAIN BUILD
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final String statusRaw = request['durum'] ?? '';
    final bool isAktif =
        statusRaw.toUpperCase() == 'AKTIF';

    final List dynamicResponses = request['donor_yanitlari'] ?? [];
    final List filteredDonors = dynamicResponses.where((r) {
      final String name = (r['donor_ad_soyad'] ?? "").toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    final String bloodGroup =
        request['istened_kan_grubu'] ?? request['istenen_kan_grubu'] ?? '—';
    final Color sColor = _statusColor(statusRaw);

    final timeData = _calculateTimeLeft();

    // Stats
    final int totalDonors = dynamicResponses.length;
    final int acceptedDonors = dynamicResponses
        .where((r) =>
            r['reaksiyon'] == 'Kabul' ||
            r['reaksiyon'] == 'Tamamlandi' ||
            r['reaksiyon'] == 'Tamamlandı')
        .length;
    final int completedDonors = dynamicResponses
        .where((r) =>
            r['reaksiyon'] == 'Tamamlandi' || r['reaksiyon'] == 'Tamamlandı')
        .length;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Üst gradient şerit ──
          Positioned(
            top: 0, left: 0, right: 0,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFB71C1C),
                    Color(0xFFD32F2F),
                    Color(0xFFEF5350),
                  ],
                ),
              ),
            ),
          ),

          // ── Dekoratif daireler ──
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            top: 60, right: 20,
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // ── İçerik ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.25)),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Talep Detayı",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    timeData['icon'] as IconData,
                                    color: Colors.white70,
                                    size: 11,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeData['text'] as String,
                                    style: TextStyle(
                                      color: timeData['color'] as Color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Kan grubu rozeti
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.12),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.35),
                                width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              bloodGroup,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Stat Kartları ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildStatCard(
                          label: "Kalan İhtiyaç",
                          value:
                              "${request['unite_sayisi'] ?? 0}",
                          unit: "Ünite",
                          color: request['unite_sayisi'] == 0 ? _green : _red,
                          lightColor: request['unite_sayisi'] == 0
                              ? _greenLight
                              : _redLight,
                          icon: Icons.opacity_rounded,
                        ),
                        const SizedBox(width: 10),
                        _buildStatCard(
                          label: "Bilgilendirilen",
                          value: "$totalDonors",
                          unit: "Donör",
                          color: _blue,
                          lightColor: _blueLight,
                          icon: Icons.notifications_active_outlined,
                        ),
                        const SizedBox(width: 10),
                        _buildStatCard(
                          label: "Tamamlanan",
                          value: "$completedDonors",
                          unit: "Bağış",
                          color: _teal,
                          lightColor: _tealLight,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Beyaz içerik alanı ──
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          // ── Üst panel (aksiyonlar + arama) ──
                          Container(
                            decoration: const BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(28),
                                topRight: Radius.circular(28),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x08000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Tutaç
                                Container(
                                  margin: const EdgeInsets.only(top: 10),
                                  width: 36, height: 4,
                                  decoration: BoxDecoration(
                                    color: _border,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // ── Talep Bilgi Şeridi ──
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Row(
                                    children: [
                                      _infoCell(
                                        "Oluşturulma",
                                        _formatDateTime(
                                            request['olusturma_tarihi']),
                                      ),
                                      _dividerV(),
                                      _infoCell(
                                        "Geçerlilik",
                                        "${request['gecerlilik_suresi_saat'] ?? 24} Saat",
                                      ),
                                      _dividerV(),
                                      _infoCell(
                                        "Durum",
                                        _statusLabel(statusRaw),
                                        valueColor: sColor,
                                      ),
                                    ],
                                  ),
                                ),

                                // ── Aksiyon Butonları (sadece aktifse) ──
                                if (isAktif) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                      height: 1, color: _border),
                                  const SizedBox(height: 14),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: Row(
                                      children: [
                                        _actionButton(
                                          label: "Süreyi Uzat",
                                          icon: Icons.add_alarm_rounded,
                                          color: _blue,
                                          bg: _blueSoft,
                                          border: _blueLight,
                                          onTap: _showExtendSheet,
                                          loading: _isExtending,
                                        ),
                                        const SizedBox(width: 10),
                                        _actionButton(
                                          label: "İptal Et",
                                          icon: Icons.cancel_outlined,
                                          color: _red,
                                          bg: _redSoft,
                                          border: _redLight,
                                          onTap: _cancelRequest,
                                          loading: _isCancelling,
                                        ),
                                        const SizedBox(width: 10),
                                        _actionButton(
                                          label: "Tamamla",
                                          icon: Icons.check_circle_outline_rounded,
                                          color: _green,
                                          bg: _greenSoft,
                                          border: _greenLight,
                                          onTap: _completeEntireRequest,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // ── Donör başlığı + Arama ──
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Row(
                                    children: [
                                      const Text(
                                        "DONÖR EŞLEŞMELERİ",
                                        style: TextStyle(
                                          color: _textPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _blueSoft,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "${filteredDonors.length} Kayıt",
                                          style: const TextStyle(
                                            color: _blue,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 0, 20, 16),
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(
                                        fontSize: 14, color: _textPrimary),
                                    decoration: InputDecoration(
                                      hintText: "Donör ismi ile ara...",
                                      hintStyle: const TextStyle(
                                          color: _textMuted, fontSize: 13),
                                      prefixIcon: const Icon(Icons.search,
                                          color: _textMuted, size: 20),
                                      filled: true,
                                      fillColor: _bg,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 0),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide:
                                            const BorderSide(color: _border),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide:
                                            const BorderSide(color: _blue),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Donör Listesi ──
                          Expanded(
                            child: dynamicResponses.isEmpty
                                ? _noDataState()
                                : filteredDonors.isEmpty
                                    ? const Center(
                                        child: Text(
                                          "Aranan donör bulunamadı.",
                                          style:
                                              TextStyle(color: _textMuted),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 14, 16, 80),
                                        itemCount: filteredDonors.length,
                                        itemBuilder: (context, index) =>
                                            _buildDonorCard(
                                                filteredDonors[index],
                                                isAktif),
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
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // 🛠 WIDGETLAR
  // ----------------------------------------------------------------------

  Widget _buildStatCard({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required Color lightColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            const BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: lightColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: TextStyle(
                color: color.withOpacity(0.6),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    )
                  : Icon(icon, size: 18, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonorCard(dynamic r, bool isRequestActive) {
    final double mlScore =
        (r['ml_score'] ?? (80 + (r['donor_ad_soyad'].length % 15))).toDouble();
    final String reaction = r['reaksiyon'] ?? 'Bekliyor';

    Color reactionColor = _orange;
    Color reactionBg = _orangeSoft;
    Color reactionLight = _orangeLight;
    IconData reactionIcon = Icons.hourglass_top_rounded;
    String reactionLabel = "Bekleniyor";

    if (reaction == 'Kabul') {
      reactionColor = _blue;
      reactionBg = _blueSoft;
      reactionLight = _blueLight;
      reactionIcon = Icons.thumb_up_alt_rounded;
      reactionLabel = "Kabul Etti";
    } else if (reaction == 'Gormezden_Geldi') {
      reactionColor = _textSecond;
      reactionBg = const Color(0xFFF3F4F6);
      reactionLight = const Color(0xFFE5E7EB);
      reactionIcon = Icons.do_not_disturb_rounded;
      reactionLabel = "İlgilenmedi";
    } else if (reaction == 'Red') {
      reactionColor = _red;
      reactionBg = _redSoft;
      reactionLight = _redLight;
      reactionIcon = Icons.thumb_down_alt_rounded;
      reactionLabel = "Reddetti";
    } else if (reaction == 'Tamamlandi' || reaction == 'Tamamlandı') {
      reactionColor = _green;
      reactionBg = _greenSoft;
      reactionLight = _greenLight;
      reactionIcon = Icons.check_circle_rounded;
      reactionLabel = "Tamamlandı";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: reactionColor.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Üst şerit ──
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: reactionBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        reactionColor,
                        reactionColor.withOpacity(0.7)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: reactionColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['donor_ad_soyad'] ?? "İsimsiz Donör",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: reactionLight.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Icon(reactionIcon,
                                color: reactionColor, size: 10),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            reactionLabel.toUpperCase(),
                            style: TextStyle(
                              color: reactionColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Sağ taraf
                if (reaction == 'Kabul' && isRequestActive)
                  GestureDetector(
                    onTap: () {
                      final dynamic rawId =
                          r['log_id'] ?? r['id'] ?? r['notification_id'];
                      final String? logId = rawId?.toString();
                      if (logId != null &&
                          logId != "null" &&
                          logId.isNotEmpty) {
                        _showDonationUnitDialog(
                            logId,
                            r['donor_ad_soyad'] ??
                                "Bilinmeyen Donör");
                      } else {
                        _showSnack("Kayıt ID'si bulunamadı!", _red);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: _blue,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: const Text(
                        "Bağışı Al",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else if (reaction == 'Tamamlandi' ||
                    reaction == 'Tamamlandı')
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _greenSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: _greenLight),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: _green, size: 16),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: _textMuted, size: 16),
                  ),
              ],
            ),
          ),

          // ── Alt ML skoru (Kabul ve Tamamlandı dışındakiler için) ──
          if (reaction != 'Tamamlandi' && reaction != 'Tamamlandı')
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Text(
                    "ML Eşleşme Skoru",
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "%${mlScore.toStringAsFixed(1)}",
                    style: TextStyle(
                      color: reactionColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: mlScore / 100,
                        minHeight: 5,
                        backgroundColor: _border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            reactionColor.withOpacity(0.6)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showDonationUnitDialog(String logId, String donorName) {
    int selectedUnits = 1;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _blueSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bloodtype_rounded,
                        color: _blue, size: 32),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Bağışı Onayla",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$donorName adlı bağışçıdan kaç ünite kan alındı?",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textSecond,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: selectedUnits > 1
                            ? () => setDialogState(() => selectedUnits--)
                            : null,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: selectedUnits > 1 ? _redSoft : _bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color:
                                  selectedUnits > 1 ? _redLight : _border,
                            ),
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            color: selectedUnits > 1 ? _red : _textMuted,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        width: 72,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "$selectedUnits",
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: _textPrimary,
                                height: 1,
                              ),
                            ),
                            const Text(
                              "Ünite",
                              style: TextStyle(
                                fontSize: 9,
                                color: _textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedUnits++),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: _greenSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _greenLight),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: _green,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: _bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: const Center(
                              child: Text(
                                "İptal",
                                style: TextStyle(
                                  color: _textSecond,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _confirmDonationAPI(logId, selectedUnits);
                          },
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_blue, Color(0xFF1976D2)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _blue.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                "Onayla ve Kaydet",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String desc,
    required IconData icon,
    required Color iconColor,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecond,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: const Center(
                          child: Text(
                            "Vazgeç",
                            style: TextStyle(
                              color: _textSecond,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: confirmColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: confirmColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            confirmText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExtendSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "SÜREYİ UZAT",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _textPrimary,
                letterSpacing: 1.2,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Kan talebine ne kadar süre eklemek istiyorsunuz?",
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _extendTile(6, "6 Saat Ekle", "Kısa sürelik uzatma"),
            const SizedBox(height: 8),
            _extendTile(12, "12 Saat Ekle", "Yarım günlük uzatma"),
            const SizedBox(height: 8),
            _extendTile(24, "24 Saat Ekle", "Tam gün uzatma"),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _extendTile(int hours, String title, String subtitle) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _extendRequest(hours);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: _blueSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _blueLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_alarm_rounded,
                  color: _blue, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: _textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _blue, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Yardımcılar ──

  Widget _infoCell(String label, String value, {Color? valueColor}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? _textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _dividerV() {
    return Container(
      width: 1, height: 32,
      color: _border,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _noDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: const Icon(Icons.group_off_outlined,
                size: 30, color: _textMuted),
          ),
          const SizedBox(height: 16),
          const Text(
            "Donör eşleşmesi bulunamadı",
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Henüz bilgilendirilen donör yok.",
            style: TextStyle(color: _textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateTimeLeft() {
    final String s = (request['durum'] ?? '').toUpperCase();
    if (s == 'IPTAL') {
      return {
        "text": "Talep İptal Edildi",
        "color": _red,
        "icon": Icons.cancel_outlined,
      };
    }
    if (s == 'TAMAMLANDI') {
      return {
        "text": "Başarıyla Tamamlandı",
        "color": Colors.white70,
        "icon": Icons.check_circle_outline_rounded,
      };
    }
    try {
      final DateTime start =
          DateTime.parse("${request['olusturma_tarihi']}Z").toLocal();
      final DateTime end =
          start.add(Duration(hours: request['gecerlilik_suresi_saat'] ?? 24));
      final Duration diff = end.difference(DateTime.now());
      if (diff.isNegative) {
        return {
          "text": "Süresi Doldu",
          "color": _red,
          "icon": Icons.timer_off_outlined
        };
      }
      return {
        "text":
            "${diff.inHours}s ${diff.inMinutes.remainder(60)}dk kaldı",
        "color": Colors.white70,
        "icon": Icons.schedule_rounded,
      };
    } catch (e) {
      return {
        "text": "-",
        "color": Colors.white54,
        "icon": Icons.schedule_rounded
      };
    }
  }

  String _statusLabel(String status) {
    final s = status.toUpperCase();
    if (s == 'AKTIF') return "● Aktif";
    if (s == 'TAMAMLANDI') return "✓ Tamamlandı";
    return "✕ İptal";
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return "-";
    try {
      final DateTime dt =
          DateTime.parse("${iso}Z").toLocal();
      return DateFormat('dd.MM.yy · HH:mm').format(dt);
    } catch (e) {
      return iso;
    }
  }

  void _showSnack(String msg, Color col) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: col,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}