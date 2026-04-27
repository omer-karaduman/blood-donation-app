// mobile/lib/screens/staff/my_blood_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
import 'blood_request_detail_screen.dart';

class MyBloodRequestsScreen extends StatefulWidget {
  final String staffUserId;

  const MyBloodRequestsScreen({super.key, required this.staffUserId});

  @override
  State<MyBloodRequestsScreen> createState() => _MyBloodRequestsScreenState();
}

class _MyBloodRequestsScreenState extends State<MyBloodRequestsScreen>
    with TickerProviderStateMixin {
  List<dynamic> _allRequests = [];
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  String _selectedUrgencyFilter = "Hepsi";
  final List<String> _urgencyLevels = ["Hepsi", "Normal", "Acil", "Afet"];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Renk Paleti (staff_dashboard ile uyumlu) ──
  static const Color _bg           = Color(0xFFF4F6F9);
  static const Color _surface      = Colors.white;
  static const Color _red          = Color(0xFFD32F2F);
  static const Color _redDark      = Color(0xFFB71C1C);
  static const Color _redLight     = Color(0xFFFFCDD2);
  static const Color _redSoft      = Color(0xFFFFF0F0);
  static const Color _blue         = Color(0xFF1565C0);
  static const Color _blueLight    = Color(0xFFBBDEFB);
  static const Color _blueSoft     = Color(0xFFEFF5FF);
  static const Color _green        = Color(0xFF2E7D32);
  static const Color _greenLight   = Color(0xFFC8E6C9);
  static const Color _greenSoft    = Color(0xFFF0FBF0);
  static const Color _orange       = Color(0xFFE65100);
  static const Color _orangeLight  = Color(0xFFFFE0B2);
  static const Color _orangeSoft   = Color(0xFFFFF8F0);
  static const Color _purple       = Color(0xFF6A1B9A);
  static const Color _purpleLight  = Color(0xFFE1BEE7);
  static const Color _purpleSoft   = Color(0xFFF9F0FF);
  static const Color _textPrimary  = Color(0xFF1A1A2E);
  static const Color _textSecond   = Color(0xFF6B7280);
  static const Color _textMuted    = Color(0xFFB0B8C1);
  static const Color _border       = Color(0xFFEEF0F4);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _fetchMyRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConstants.baseUrl}/staff/my-requests?personel_id=${widget.staffUserId}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _allRequests = jsonDecode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Talepler yüklenemedi. (${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Sunucuya bağlanılamadı.";
        _isLoading = false;
      });
    }
  }

  List<dynamic> _filterRequests(String targetTab) {
    return _allRequests.where((req) {
      final String status = (req['durum'] ?? "").toString().toUpperCase();
      bool statusMatch = false;
      if (targetTab == 'AKTIF') {
        statusMatch = status == 'AKTIF';
      } else if (targetTab == 'TAMAMLANDI') {
        statusMatch = status == 'TAMAMLANDI';
      } else if (targetTab == 'IPTAL') {
        statusMatch = (status == 'IPTAL' || status == 'SURESI_DOLDU');
      }
      final String urgency = (req['aciliyet_durumu'] ?? "Normal").toString();
      bool urgencyMatch = _selectedUrgencyFilter == "Hepsi" ||
          urgency.toLowerCase() == _selectedUrgencyFilter.toLowerCase();
      return statusMatch && urgencyMatch;
    }).toList();
  }

  // ── Renk yardımcıları ──
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

  Color _urgencyColor(String? urgency) {
    final u = urgency?.toLowerCase();
    if (u == 'afet') return _purple;
    if (u == 'acil') return _orange;
    return _blue;
  }

  Color _urgencyBg(String? urgency) {
    final u = urgency?.toLowerCase();
    if (u == 'afet') return _purpleSoft;
    if (u == 'acil') return _orangeSoft;
    return _blueSoft;
  }

  Color _urgencyLight(String? urgency) {
    final u = urgency?.toLowerCase();
    if (u == 'afet') return _purpleLight;
    if (u == 'acil') return _orangeLight;
    return _blueLight;
  }

  String _formatDate(String isoDate) {
    try {
      DateTime date = DateTime.parse("${isoDate}Z").toLocal();
      return DateFormat('dd MMM yy · HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  Map<String, int> _getStats() {
    int aktif = 0, tamamlandi = 0, iptal = 0;
    for (final req in _allRequests) {
      final s = (req['durum'] ?? "").toString().toUpperCase();
      if (s == 'AKTIF') aktif++;
      else if (s == 'TAMAMLANDI') tamamlandi++;
      else iptal++;
    }
    return {'aktif': aktif, 'tamamlandi': tamamlandi, 'iptal': iptal};
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getStats();

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Üst gradient şerit (dashboard ile aynı)
          Positioned(
            top: 0, left: 0, right: 0,
            height: 200,
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

          // Dekoratif daireler
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

          // İçerik
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _red,
                      strokeWidth: 2.5,
                    ),
                  )
                : FadeTransition(
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
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Talep Yönetimi",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      "Tüm kan talepleriniz",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _fetchMyRequests,
                                child: Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.25)),
                                  ),
                                  child: const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
                                    size: 18,
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
                                label: "Aktif",
                                count: stats['aktif']!,
                                color: _red,
                                lightColor: _redLight,
                                icon: Icons.favorite_rounded,
                              ),
                              const SizedBox(width: 10),
                              _buildStatCard(
                                label: "Tamamlanan",
                                count: stats['tamamlandi']!,
                                color: _green,
                                lightColor: _greenLight,
                                icon: Icons.check_circle_rounded,
                              ),
                              const SizedBox(width: 10),
                              _buildStatCard(
                                label: "İptal",
                                count: stats['iptal']!,
                                color: _textSecond,
                                lightColor: const Color(0xFFE5E7EB),
                                icon: Icons.cancel_rounded,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ── Alt beyaz kart alanı ──
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
                                // ── Filtre + Tab alanı ──
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
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // ── Aciliyet Filtresi ──
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Row(
                                          children: [
                                            const Text(
                                              "Filtre:",
                                              style: TextStyle(
                                                color: _textSecond,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: SizedBox(
                                                height: 32,
                                                child: ListView.builder(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  itemCount:
                                                      _urgencyLevels.length,
                                                  itemBuilder: (context, i) {
                                                    final level =
                                                        _urgencyLevels[i];
                                                    final bool sel =
                                                        _selectedUrgencyFilter ==
                                                            level;
                                                    Color chipColor = _red;
                                                    if (level == "Acil")
                                                      chipColor = _orange;
                                                    if (level == "Afet")
                                                      chipColor = _purple;
                                                    if (level == "Normal")
                                                      chipColor = _blue;
                                                    return GestureDetector(
                                                      onTap: () => setState(
                                                          () => _selectedUrgencyFilter =
                                                              level),
                                                      child: AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    200),
                                                        margin:
                                                            const EdgeInsets
                                                                .only(right: 8),
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 14,
                                                            vertical: 6),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: sel
                                                              ? chipColor
                                                              : _bg,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          border: Border.all(
                                                            color: sel
                                                                ? chipColor
                                                                : _border,
                                                          ),
                                                          boxShadow: sel
                                                              ? [
                                                                  BoxShadow(
                                                                    color: chipColor
                                                                        .withOpacity(
                                                                            0.25),
                                                                    blurRadius:
                                                                        8,
                                                                    offset:
                                                                        const Offset(
                                                                            0,
                                                                            3),
                                                                  )
                                                                ]
                                                              : [],
                                                        ),
                                                        child: Text(
                                                          level,
                                                          style: TextStyle(
                                                            color: sel
                                                                ? Colors.white
                                                                : _textSecond,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 14),

                                      // ── Tab Bar ──
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: _bg,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: TabBar(
                                            controller: _tabController,
                                            indicator: BoxDecoration(
                                              color: _surface,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x14000000),
                                                  blurRadius: 8,
                                                  offset: Offset(0, 2),
                                                )
                                              ],
                                            ),
                                            indicatorSize:
                                                TabBarIndicatorSize.tab,
                                            indicatorPadding:
                                                const EdgeInsets.all(3),
                                            labelColor: _red,
                                            unselectedLabelColor: _textSecond,
                                            dividerColor: Colors.transparent,
                                            labelStyle: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                            unselectedLabelStyle:
                                                const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                            tabs: [
                                              _buildTab("Aktif",
                                                  stats['aktif']!, _red),
                                              _buildTab("Tamamlanan",
                                                  stats['tamamlandi']!, _green),
                                              _buildTab("İptal",
                                                  stats['iptal']!, _textMuted),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  ),
                                ),

                                // ── Liste ──
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildRequestList(
                                          _filterRequests('AKTIF')),
                                      _buildRequestList(
                                          _filterRequests('TAMAMLANDI')),
                                      _buildRequestList(
                                          _filterRequests('IPTAL')),
                                    ],
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

  Widget _buildTab(String text, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required int count,
    required Color color,
    required Color lightColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
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
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: lightColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              "$count",
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestList(List<dynamic> requests) {
    if (requests.isEmpty) {
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
              child: const Icon(Icons.inbox_outlined,
                  size: 30, color: _textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              "Kayıt bulunamadı",
              style: TextStyle(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Filtre kriterlerinizi değiştirmeyi deneyin",
              style: TextStyle(color: _textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: requests.length,
      itemBuilder: (context, index) => _buildRequestCard(requests[index]),
    );
  }

  Widget _buildRequestCard(dynamic request) {
    final String status =
        (request['durum'] ?? "").toString().toUpperCase();
    final String urgency =
        (request['aciliyet_durumu'] ?? "Normal").toString();

    final Color sColor = _statusColor(status);
    final Color sBg = _statusBg(status);
    final Color sLight = _statusLight(status);
    final Color uColor = _urgencyColor(urgency);
    final Color uBg = _urgencyBg(urgency);
    final Color uLight = _urgencyLight(urgency);

    final int notifiedCount =
        (request['donor_yanitlari'] as List?)?.length ?? 0;
    final String bloodGroup =
        request['istened_kan_grubu'] ?? request['istenen_kan_grubu'] ?? '—';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BloodRequestDetailScreen(
              requestData: request,
              staffUserId: widget.staffUserId,
            ),
          ),
        );
        _fetchMyRequests();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: sColor.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Üst şerit ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: sBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Kan grubu rozeti
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [sColor, sColor.withOpacity(0.75)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: sColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        bloodGroup,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _tag(
                              status == 'AKTIF'
                                  ? "● Aktif"
                                  : status == 'TAMAMLANDI'
                                      ? "✓ Tamamlandı"
                                      : "✕ İptal",
                              sColor,
                              sLight,
                            ),
                            const SizedBox(width: 6),
                            _tag(urgency, uColor, uLight),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formatDate(request['olusturma_tarihi'] ?? ''),
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: sColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chevron_right_rounded,
                        color: sColor, size: 16),
                  ),
                ],
              ),
            ),

            // ── Alt detay ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (status == 'IPTAL' || status == 'SURESI_DOLDU')
                        _infoCell("Kan Grubu", bloodGroup)
                      else
                        _infoCell(
                            "Miktar", "${request['unite_sayisi'] ?? '—'} Ünite"),
                      _dividerV(),
                      _infoCell(
                        "Talep No",
                        "#${(request['id'] ?? request['talep_id'] ?? '—').toString().substring(0, 8).toUpperCase()}",
                      ),
                      _dividerV(),
                      _infoCell(
                        "Geçerlilik",
                        "${request['gecerlilik_suresi_saat'] ?? 24} Saat",
                      ),
                    ],
                  ),
                  if (status == 'AKTIF') ...[
                    const SizedBox(height: 12),
                    Container(height: 1, color: _border),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildRemainingTime(request),
                        const Spacer(),
                        if (notifiedCount > 0)
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _blueSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                    Icons.notifications_active_outlined,
                                    size: 12,
                                    color: _blue),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "$notifiedCount donör bilgilendirildi",
                                style: const TextStyle(
                                  color: _blue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _orangeSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(Icons.warning_amber_rounded,
                                    size: 12, color: _orange),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Uygun donör yok",
                                style: TextStyle(
                                  color: _orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoCell(String label, String value) {
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
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerV() {
    return Container(
      width: 1,
      height: 32,
      color: _border,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _buildRemainingTime(Map<String, dynamic> request) {
    try {
      DateTime createdAt =
          DateTime.parse("${request['olusturma_tarihi']}Z").toLocal();
      int durationHours = request['gecerlilik_suresi_saat'] ?? 24;
      DateTime expiresAt = createdAt.add(Duration(hours: durationHours));
      Duration remaining = expiresAt.difference(DateTime.now());

      if (remaining.isNegative) {
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _redSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.timer_off_outlined, size: 12, color: _red),
            ),
            const SizedBox(width: 6),
            Text(
              "Süresi doldu",
              style: TextStyle(
                  color: _red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ],
        );
      }

      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.schedule_rounded,
                size: 12, color: _textSecond),
          ),
          const SizedBox(width: 6),
          Text(
            "${remaining.inHours}s ${remaining.inMinutes.remainder(60)}dk kaldı",
            style: const TextStyle(
              color: _textSecond,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}