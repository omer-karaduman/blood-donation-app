// mobile/lib/screens/admin/admin_logs_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import 'admin_log_detail_screen.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _logs = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  late AnimationController _animController;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fetchLogs();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await http.get(Uri.parse(ApiConstants.adminLogsEndpoint));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        if (mounted) {
          setState(() {
            _logs = data;
            _filtered = data;
            _isLoading = false;
          });
          _animController.forward(from: 0);
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Sunucu hatası: ${res.statusCode}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Bağlantı hatası. Lütfen tekrar deneyin.";
          _isLoading = false;
        });
      }
    }
  }

  void _applySearch(String query) {
    setState(() {
      _searchQuery = query;
      final q = query.toLowerCase();
      _filtered = _logs.where((log) {
        final kurum = (log['kurum_adi'] ?? '').toString().toLowerCase();
        final personel =
            (log['staff_ad_soyad'] ?? '').toString().toLowerCase();
        final kan = (log['istenen_kan_grubu'] ?? '').toString().toLowerCase();
        return kurum.contains(q) || personel.contains(q) || kan.contains(q);
      }).toList();
    });
  }

  // ─── RENK TANIMLARI ─────────────────────────────────────────────────────

  Color _urgencyColor(String? durum) {
    switch (durum) {
      case 'Afet':
        return const Color(0xFFB71C1C);
      case 'Acil':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFF00897B);
    }
  }

  Color _urgencyBg(String? durum) {
    switch (durum) {
      case 'Afet':
        return const Color(0xFFFFEBEE);
      case 'Acil':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFE0F2F1);
    }
  }

  Color _kanGrubuColor(String kan) {
    if (kan.contains('-')) return const Color(0xFF7B1FA2);
    return const Color(0xFFE53935);
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            floating: false,
            backgroundColor: const Color(0xFF7B1FA2),
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 56, bottom: 16),
              title: const Text(
                "Sistem Logları",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF9C27B0)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 24,
                      bottom: 20,
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: 70,
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: _fetchLogs,
          color: const Color(0xFF7B1FA2),
          child: CustomScrollView(
            slivers: [
              // Arama kutusu
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _buildSearchBar(),
                ),
              ),

              // Sonuç sayacı
              if (!_isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E5F5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${_filtered.length} talep kaydı",
                            style: const TextStyle(
                              color: Color(0xFF7B1FA2),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Yükleniyor
              if (_isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: Color(0xFF7B1FA2)),
                        const SizedBox(height: 16),
                        Text(
                          "Loglar yükleniyor...",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )

              // Hata
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              size: 64, color: Color(0xFF7B1FA2)),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _fetchLogs,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7B1FA2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text("Tekrar Dene"),
                          ),
                        ],
                      ),
                    ),
                  ),
                )

              // Boş sonuç
              else if (_filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          "Arama kriterine uygun log bulunamadı.",
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )

              // Liste
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final anim = CurvedAnimation(
                          parent: _animController,
                          curve: Interval(
                            (index * 0.05).clamp(0.0, 0.8),
                            ((index * 0.05) + 0.3).clamp(0.0, 1.0),
                            curve: Curves.easeOutCubic,
                          ),
                        );
                        return AnimatedBuilder(
                          animation: anim,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, 16 * (1 - anim.value)),
                            child: Opacity(
                              opacity: anim.value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildLogCard(_filtered[index], index),
                          ),
                        );
                      },
                      childCount: _filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _applySearch,
        decoration: InputDecoration(
          hintText: "Kurum, personel veya kan grubu ara...",
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Color(0xFF7B1FA2)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: Colors.grey, size: 20),
                  onPressed: () {
                    _searchCtrl.clear();
                    _applySearch('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildLogCard(dynamic log, int index) {
    final String kanGrubu = log['istened_kan_grubu'] ??
        log['istenen_kan_grubu'] ?.toString() ?? '?';
    final String kurum = log['kurum_adi'] ?? 'Bilinmiyor';
    final String personel = log['staff_ad_soyad'] ?? 'Sistem';
    final int donorSayisi = log['onerilen_donor_sayisi'] ?? 0;
    final String tarih = _formatTarih(log['olusturma_tarihi']);
    final String aciliyet = log['aciliyet_durumu'] ?? 'Normal';
    final String talepId = log['talep_id']?.toString() ?? '';

    return GestureDetector(
      onTap: talepId.isNotEmpty
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminLogDetailScreen(
                    talepId: talepId,
                    kanGrubu: kanGrubu,
                    kurumAdi: kurum,
                  ),
                ),
              )
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kan grubu badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _kanGrubuColor(kanGrubu).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _kanGrubuColor(kanGrubu).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bloodtype_rounded,
                      color: _kanGrubuColor(kanGrubu), size: 16),
                  const SizedBox(height: 2),
                  Text(
                    kanGrubu,
                    style: TextStyle(
                      color: _kanGrubuColor(kanGrubu),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          kurum,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Aciliyet chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _urgencyBg(aciliyet),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          aciliyet,
                          style: TextStyle(
                            color: _urgencyColor(aciliyet),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          personel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Tarih
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            tarih,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Donor sayısı badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline_rounded,
                                size: 12, color: Color(0xFF1E88E5)),
                            const SizedBox(width: 4),
                            Text(
                              "$donorSayisi donor önerildi",
                              style: const TextStyle(
                                color: Color(0xFF1E88E5),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
      if (diff.inMinutes < 60) return "${diff.inMinutes} dakika önce";
      if (diff.inHours < 24) return "${diff.inHours} saat önce";
      if (diff.inDays < 7) return "${diff.inDays} gün önce";
      return "${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
    } catch (_) {
      return tarihStr.toString().length > 10
          ? tarihStr.toString().substring(0, 10)
          : tarihStr.toString();
    }
  }
}
