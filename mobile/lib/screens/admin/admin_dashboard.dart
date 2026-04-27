// mobile/lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../../../core/constants/api_constants.dart';
import '../../models/admin_summary.dart';
import 'institution_management.dart';
import 'staff_management_screen.dart';
import 'admin_logs_screen.dart';
import 'ml_performance_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  AdminSummary? _summary;
  List<dynamic> _recentLogs = [];
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _headerPulseController;
  late AnimationController _cardsController;
  late Animation<double> _headerPulse;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();

    _headerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _headerPulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _headerPulseController, curve: Curves.easeInOut),
    );

    _cardAnimations = List.generate(8, (i) {
      final start = (i * 0.08).clamp(0.0, 1.0);
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _cardsController,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
    });

    _fetchData();
  }

  @override
  void dispose() {
    _headerPulseController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summaryRes =
          await http.get(Uri.parse(ApiConstants.adminSummaryEndpoint));
      final logsRes =
          await http.get(Uri.parse(ApiConstants.adminLogsEndpoint));

      if (summaryRes.statusCode == 200) {
        final data = jsonDecode(utf8.decode(summaryRes.bodyBytes));
        List<dynamic> logs = [];
        if (logsRes.statusCode == 200) {
          logs = jsonDecode(utf8.decode(logsRes.bodyBytes));
        }
        if (mounted) {
          setState(() {
            _summary = AdminSummary.fromJson(data);
            _recentLogs = logs.take(5).toList();
            _isLoading = false;
          });
          _cardsController.forward(from: 0);
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Sunucu hatası: ${summaryRes.statusCode}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Bağlantı hatası. Sunucuyu kontrol edin.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: const Color(0xFFE53935),
        displacement: 80,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeroHeader(),
            if (_errorMessage != null)
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                sliver: SliverToBoxAdapter(child: _buildErrorWidget()),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _buildSectionLabel("Sistem İstatistikleri"),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(child: _buildStatsGrid()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _buildSectionLabel("Hızlı Yönetim"),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(child: _buildActionGrid()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _buildRecentActivityHeader(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
              sliver: SliverToBoxAdapter(child: _buildRecentActivity()),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HERO HEADER ──────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    return SliverToBoxAdapter(
      child: Container(
        height: 220,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFC62828), Color(0xFFE53935), Color(0xFFEF5350)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Arka plan dekoratif daireler
            Positioned(
              top: -30,
              right: -20,
              child: AnimatedBuilder(
                animation: _headerPulse,
                builder: (context, child) => Transform.scale(
                  scale: _headerPulse.value,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              top: 30,
              right: 40,
              child: AnimatedBuilder(
                animation: _headerPulse,
                builder: (context, child) => Opacity(
                  opacity: _headerPulse.value * 0.3,
                  child: Icon(
                    Icons.favorite,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // İçerik
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text(
                            "SİSTEM YÖNETİCİSİ",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Yönetim Paneli",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Kan bağışı sistemini buradan yönetiyorsunuz.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
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

  // ─── İSTATİSTİK KARTI GRID ────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final stats = [
      _StatConfig(
        label: "Toplam Donör",
        value: _isLoading ? null : (_summary?.totalDonors ?? 0),
        icon: Icons.favorite_rounded,
        color: const Color(0xFFE53935),
        bgColor: const Color(0xFFFFEBEE),
        animIndex: 0,
      ),
      _StatConfig(
        label: "Aktif Talepler",
        value: _isLoading ? null : (_summary?.activeRequests ?? 0),
        icon: Icons.campaign_rounded,
        color: const Color(0xFFFF6D00),
        bgColor: const Color(0xFFFFF3E0),
        animIndex: 1,
      ),
      _StatConfig(
        label: "Sağlık Kurumu",
        value: _isLoading ? null : (_summary?.totalInstitutions ?? 0),
        icon: Icons.local_hospital_rounded,
        color: const Color(0xFF00897B),
        bgColor: const Color(0xFFE0F2F1),
        animIndex: 2,
      ),
      _StatConfig(
        label: "Kayıtlı Personel",
        value: _isLoading ? null : (_summary?.totalStaff ?? 0),
        icon: Icons.badge_rounded,
        color: const Color(0xFF1E88E5),
        bgColor: const Color(0xFFE3F2FD),
        animIndex: 3,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.25,
      children: stats.map((s) => _buildStatCard(s)).toList(),
    );
  }

  Widget _buildStatCard(_StatConfig cfg) {
    return AnimatedBuilder(
      animation: _cardAnimations[cfg.animIndex],
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - _cardAnimations[cfg.animIndex].value)),
        child: Opacity(
          opacity: _cardAnimations[cfg.animIndex].value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cfg.color.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cfg.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cfg.icon, color: cfg.color, size: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cfg.value == null
                      ? _buildShimmer(width: 50, height: 22)
                      : _AnimatedCounter(
                          value: cfg.value!,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A2E),
                            letterSpacing: -0.5,
                          ),
                        ),
                  const SizedBox(height: 1),
                  Text(
                    cfg.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
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

  // ─── AKSİYON GRID ─────────────────────────────────────────────────────────

  Widget _buildActionGrid() {
    final actions = [
      _ActionConfig(
        title: "Hastane & Kurumlar",
        sub: "Kurum ekle, koordinat yönet",
        icon: Icons.local_hospital_rounded,
        color: const Color(0xFF00897B),
        bgColor: const Color(0xFFE0F2F1),
        animIndex: 4,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InstitutionManagementScreen(),
          ),
        ),
      ),
      _ActionConfig(
        title: "Personel Yönetimi",
        sub: "Kullanıcı yetkilendir, düzenle",
        icon: Icons.manage_accounts_rounded,
        color: const Color(0xFF1E88E5),
        bgColor: const Color(0xFFE3F2FD),
        animIndex: 5,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StaffManagementScreen(),
          ),
        ),
      ),
      _ActionConfig(
        title: "Sistem Logları",
        sub: "Talep geçmişi & ML öneriler",
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF7B1FA2),
        bgColor: const Color(0xFFF3E5F5),
        animIndex: 6,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminLogsScreen(),
          ),
        ),
      ),
      _ActionConfig(
        title: "ML Performansı",
        sub: "Yanıt oranı, F1 skoru, kan grubu analizi",
        icon: Icons.psychology_rounded,
        color: const Color(0xFFFF6D00),
        bgColor: const Color(0xFFFFF3E0),
        animIndex: 7,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MlPerformanceScreen(),
          ),
        ),
      ),
    ];

    return Column(
      children: actions
          .map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildActionCard(a),
              ))
          .toList(),
    );
  }

  Widget _buildActionCard(_ActionConfig cfg) {
    return AnimatedBuilder(
      animation: _cardAnimations[cfg.animIndex],
      builder: (context, child) => Transform.translate(
        offset: Offset(30 * (1 - _cardAnimations[cfg.animIndex].value), 0),
        child: Opacity(
          opacity: _cardAnimations[cfg.animIndex].value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        shadowColor: cfg.color.withOpacity(0.12),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: cfg.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: cfg.bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(cfg.icon, color: cfg.color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cfg.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        cfg.sub,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cfg.bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_right_rounded,
                      color: cfg.color, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── SON AKTİVİTE ─────────────────────────────────────────────────────────

  Widget _buildRecentActivityHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionLabel("Son Aktivite"),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminLogsScreen()),
          ),
          child: const Text(
            "Tümünü Gör →",
            style: TextStyle(
              color: Color(0xFFE53935),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    if (_isLoading) {
      return Column(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildShimmer(width: double.infinity, height: 72),
          ),
        ),
      );
    }

    if (_recentLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.inbox_rounded, color: Colors.grey.shade400, size: 28),
            const SizedBox(width: 12),
            Text(
              "Henüz sistem logu bulunmuyor.",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentLogs.asMap().entries.map((entry) {
        final log = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildLogRow(log),
        );
      }).toList(),
    );
  }

  Widget _buildLogRow(dynamic log) {
    final String kanGrubu = log['istenen_kan_grubu'] ?? '?';
    final String kurum = log['kurum_adi'] ?? 'Bilinmiyor';
    final String personel = log['staff_ad_soyad'] ?? 'Sistem';
    final int donorSayisi = log['onerilen_donor_sayisi'] ?? 0;
    final String tarih = _formatTarih(log['olusturma_tarihi']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  kanGrubu,
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kurum,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "$personel • $tarih",
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$donorSayisi öneri",
                style: const TextStyle(
                  color: Color(0xFF1E88E5),
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

  // ─── YARDIMCI ─────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A1A2E),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildShimmer({required double width, required double height}) {
    return AnimatedBuilder(
      animation: _headerPulseController,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
              stops: [0.0, _headerPulseController.value, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE53935), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? "Bilinmeyen bir hata oluştu",
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _fetchData,
            child: const Text(
              "Yenile",
              style: TextStyle(
                  color: Color(0xFFE53935), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

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
      return "${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
    } catch (_) {
      return tarihStr.toString().substring(0, 10);
    }
  }
}

// ─── YARDIMCI SINIFLAR ────────────────────────────────────────────────────

class _StatConfig {
  final String label;
  final int? value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final int animIndex;

  const _StatConfig({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.animIndex,
  });
}

class _ActionConfig {
  final String title;
  final String sub;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final int animIndex;
  final VoidCallback onTap;

  const _ActionConfig({
    required this.title,
    required this.sub,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.animIndex,
    required this.onTap,
  });
}

// ─── ANİMATED COUNTER ─────────────────────────────────────────────────────

class _AnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle style;

  const _AnimatedCounter({required this.value, required this.style});

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutExpo),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) =>
          Text(_anim.value.toInt().toString(), style: widget.style),
    );
  }
}