// mobile/lib/screens/donor/tabs/donor_requests_tab.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../constants/api_constants.dart';
import '../../../models/donor.dart';

class DonorRequestsTab extends StatefulWidget {
  final Donor currentUser;

  const DonorRequestsTab({
    super.key,
    required this.currentUser,
  });

  @override
  State<DonorRequestsTab> createState() => _DonorRequestsTabState();
}

class _DonorRequestsTabState extends State<DonorRequestsTab> {
  bool _isLoading = true;
  bool _isBackgroundFetching = false;
  List<dynamic> _requests = [];
  bool _hasActiveAcceptedRequest = false;

  Timer? _cooldownTimer;
  Timer? _autoRefreshTimer;
  Duration _timeLeft = Duration.zero;
  bool _isCooldown = false;

  // ── Tema renkleri (home_tab ile birebir) ───────────────────────────────────
  static const _crimson = Color(0xFFC0182A);
  static const _crimsonDark = Color(0xFF8B0000);
  static const _bg = Color(0xFFF5F5F7);
  static const _surface = Colors.white;
  static const _textPrimary = Color(0xFF1C1C1E);
  static const _textSecondary = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _checkCooldown();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isCooldown && !_isLoading && !_isBackgroundFetching) {
        _fetchRequests(isSilent: true);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // ── MANTIK ─────────────────────────────────────────────────────────────────

  Future<void> _checkCooldown() async {
    try {
      final url = ApiConstants.donorProfileEndpoint(widget.currentUser.userId);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final String? sonBagisTarihiStr = data['son_bagis_tarihi'];

        if (sonBagisTarihiStr != null && sonBagisTarihiStr.isNotEmpty) {
          String safeDateStr = sonBagisTarihiStr;
          if (!safeDateStr.endsWith('Z')) safeDateStr += 'Z';

          DateTime sonBagis = DateTime.parse(safeDateStr).toLocal();
          int waitDays = widget.currentUser.cinsiyet == 'K' ? 120 : 90;
          final nextDate = sonBagis.add(Duration(days: waitDays));
          final now = DateTime.now();

          if (now.isBefore(nextDate)) {
            if (mounted) {
              setState(() {
                _isCooldown = true;
                _isLoading = false;
              });
              _startCooldownTimer(nextDate);
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Sayaç için güncel profil çekilemedi: $e");
    }

    if (mounted) {
      setState(() => _isCooldown = false);
      _fetchRequests();
    }
  }

  void _startCooldownTimer(DateTime target) {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = target.difference(DateTime.now());
      if (diff.isNegative) {
        if (mounted) {
          setState(() => _isCooldown = false);
          _cooldownTimer?.cancel();
          _fetchRequests();
        }
      } else {
        if (mounted) setState(() => _timeLeft = diff);
      }
    });
  }

  Future<void> _fetchRequests({bool isSilent = false}) async {
    if (!isSilent && mounted) {
      setState(() => _isLoading = true);
    } else {
      _isBackgroundFetching = true;
    }

    try {
      final url = ApiConstants.donorFeedEndpoint(widget.currentUser.userId);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            final List<dynamic> rawList =
                data is List ? data : (data['items'] ?? []);

            _hasActiveAcceptedRequest = rawList.any((req) {
              final reaksiyon = req['reaksiyon'] ?? req['kullanici_reaksiyonu'];
              return reaksiyon == 'Kabul';
            });

            _requests = rawList.where((req) {
              final reaksiyon = req['reaksiyon'] ?? req['kullanici_reaksiyonu'];
              return reaksiyon == 'Bekliyor' || reaksiyon == null;
            }).toList();

            _isLoading = false;
            _isBackgroundFetching = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isBackgroundFetching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBackgroundFetching = false;
        });
      }
    }
  }

  Future<void> _respondToRequest(String logId, String reaction) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: _crimson)),
      );

      final url =
          "${ApiConstants.donorsEndpoint}/${widget.currentUser.userId}/respond/$logId?reaksiyon=$reaction";
      final response = await http.post(Uri.parse(url));

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reaction == 'Kabul'
                  ? "Harika! Hastaneye bekleniyorsunuz."
                  : "Talep listenizden gizlendi."),
              behavior: SnackBarBehavior.floating,
              backgroundColor: reaction == 'Kabul'
                  ? Colors.green.shade600
                  : Colors.blueGrey.shade800,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          _fetchRequests();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text("İşlem gerçekleştirilemedi. Lütfen tekrar deneyin."),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _confirmAccept(String logId, String hastaneAdi) async {
    if (_hasActiveAcceptedRequest) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: _crimson)),
      );

      await _fetchRequests(isSilent: true);

      if (mounted) Navigator.pop(context);

      if (_hasActiveAcceptedRequest) {
        _showAlreadyHasRequestWarning();
        return;
      }
    }

    _showConfirmSheet(logId, hastaneAdi);
  }

  void _showAlreadyHasRequestWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        surfaceTintColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: Colors.orange.shade800, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              "Aktif Göreviniz Var",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              "Şu anda kabul ettiğiniz bir kan talebi bulunuyor. "
              "Yeni talebi kabul etmek için önce mevcut görevinizi tamamlamalı veya iptal etmelisiniz.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _crimson,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Anladım",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isCooldown) return _buildTimerUI(key: const ValueKey('timer_view'));

    return Scaffold(
      key: const ValueKey('requests_view'),
      backgroundColor: _bg,
      body: RefreshIndicator(
        onRefresh: () => _fetchRequests(),
        color: _crimson,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeroHeader(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: _sectionLabel("Size Uygun Talepler"),
              ),
            ),
            if (_isLoading && _requests.isEmpty)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: _crimson)),
              )
            else if (_requests.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildRequestCard(_requests[index]),
                    childCount: _requests.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // ── HERO HEADER ────────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Kan Talepleri",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Size uygun talepler aşağıda",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        _buildCountBadge(),
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

  Widget _buildCountBadge() {
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
          const Icon(Icons.favorite, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            "${_requests.length} Talep",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

  // ── TALEP KARTI ────────────────────────────────────────────────────────────

  Widget _buildRequestCard(Map<String, dynamic> item) {
    final String logId = item['log_id']?.toString() ?? "";
    final String kurumAdi =
        item['kurum_adi']?.toString() ?? "Bilinmeyen Hastane";
    final String aciliyet =
        item['aciliyet_durumu']?.toString() ?? "NORMAL";
    final bool isUrgent =
        aciliyet.toUpperCase() == "ACIL" || aciliyet.toUpperCase() == "AFET";
    final String kanGrubu =
        item['istenen_kan_grubu']?.toString() ?? "";

    String remainingText = "Hesaplanıyor...";
    bool isExpired = false;
    try {
      if (item['olusturma_tarihi'] != null) {
        String dateStr = item['olusturma_tarihi'].toString();
        if (!dateStr.endsWith('Z')) dateStr += 'Z';
        DateTime createdAt = DateTime.parse(dateStr).toLocal();
        int durationHours = item['gecerlilik_suresi_saat'] ?? 24;
        DateTime expiresAt = createdAt.add(Duration(hours: durationHours));
        Duration remaining = expiresAt.difference(DateTime.now());

        if (!remaining.isNegative) {
          remainingText =
              "${remaining.inHours}s ${remaining.inMinutes.remainder(60)}dk kaldı";
        } else {
          remainingText = "Süresi Doldu";
          isExpired = true;
        }
      }
    } catch (e) {
      remainingText = "Süre Bilgisi Yok";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: Colors.black.withOpacity(0.07), width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // ── Üst şerit: aciliyet + kan grubu ──────────────────────────────
          Container(
            color: isUrgent
                ? const Color(0xFFFFF5F5)
                : Colors.orange.shade50,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isUrgent ? _crimson : Colors.orange.shade600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      aciliyet.toUpperCase(),
                      style: TextStyle(
                        color: isUrgent ? _crimson : Colors.orange.shade800,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                if (kanGrubu.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFCA5A5), width: 0.8),
                    ),
                    child: Text(
                      kanGrubu,
                      style: const TextStyle(
                        color: _crimson,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(
              height: 0.5,
              color: Color(0xFFF0F0F0)),

          // ── Orta içerik ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kurumAdi,
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
                      item['ilce'] ?? "Bölge Bilinmiyor",
                      style: const TextStyle(
                          fontSize: 12, color: _textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 0.5, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 12),

                // Kalan süre satırı
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: isExpired
                          ? Colors.red.shade400
                          : _textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      remainingText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isExpired
                            ? Colors.red.shade400
                            : _textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Butonlar ─────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => _showIgnoreSheet(logId),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            alignment: Alignment.center,
                            child: Text(
                              "İlgilenmiyorum",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Material(
                        color: _crimson,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () =>
                              _confirmAccept(logId, kurumAdi),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            alignment: Alignment.center,
                            child: const Text(
                              "Kabul Et",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
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
        ],
      ),
    );
  }

  // ── BOTTOM SHEET: GIZLE ────────────────────────────────────────────────────

  void _showIgnoreSheet(String logId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.visibility_off_rounded,
                  color: Colors.blueGrey.shade400, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              "Talebi Gizle",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              "Bu talebi listenizden kaldırmak istediğinize emin misiniz? Gizlenen talepler tekrar gösterilmez.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade200),
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Vazgeç",
                        style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _respondToRequest(logId, "Red");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade800,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Gizle",
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

  // ── BOTTOM SHEET: KABUL ────────────────────────────────────────────────────

  void _showConfirmSheet(String logId, String hastane) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: _crimson, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              "Harika Bir Adım!",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              "$hastane kurumuna bağış yapmayı kabul ederek bir can kurtaracaksınız. Onaylıyor musunuz?",
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: _textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade200),
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Vazgeç",
                        style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _respondToRequest(logId, "Kabul");
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _crimson,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Onaylıyorum",
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

  // ── BOŞ DURUM ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_rounded,
                size: 56, color: Colors.green.shade400),
          ),
          const SizedBox(height: 24),
          const Text(
            "Şu An Her Şey Yolunda",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            "Size uygun aktif bir kan talebi bulunmuyor.",
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── SAYAÇ EKRANI ───────────────────────────────────────────────────────────

  Widget _buildTimerUI({Key? key}) {
    return Scaffold(
      key: key,
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Gradient başlık
          SliverToBoxAdapter(
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
                  Positioned(
                    top: -40,
                    right: -40,
                    child: _decorCircle(180, opacity: 0.06),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Kan Talepleri",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Dinlenme süreciniz devam ediyor",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
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

          // İçerik
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // İkon
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.timer_rounded,
                        size: 56, color: Colors.orange.shade600),
                  ),
                  const SizedBox(height: 28),

                  // Başlık
                  const Text(
                    "Dinlenme Sürecindesiniz",
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Vücudunuzun toparlanması için gereken süreyi bekliyorsunuz. "
                    "Bir sonraki kan bağışınızı yapabilmenize kalan süre:",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _textSecondary, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 36),

                  // Sayaç kartları
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: Colors.black.withOpacity(0.07), width: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _timeBox("${_timeLeft.inDays}", "GÜN"),
                        _timeDivider(),
                        _timeBox(
                            "${_timeLeft.inHours.remainder(24)}", "SAAT"),
                        _timeDivider(),
                        _timeBox(
                            "${_timeLeft.inMinutes.remainder(60)}", "DAKİKA"),
                        _timeDivider(),
                        _timeBox(
                            "${_timeLeft.inSeconds.remainder(60)}", "SANİYE"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeDivider() {
    return Text(
      ":",
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: Colors.grey.shade300,
      ),
    );
  }

  Widget _timeBox(String value, String label) {
    return Column(
      children: [
        Text(
          value.padLeft(2, '0'),
          style: const TextStyle(
            color: _crimson,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
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