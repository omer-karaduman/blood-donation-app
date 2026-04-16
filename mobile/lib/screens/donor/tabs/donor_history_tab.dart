// mobile/lib/screens/donor/tabs/donor_history_tab.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants/api_constants.dart';

class DonorHistoryTab extends StatefulWidget {
  final dynamic currentUser;
  const DonorHistoryTab({super.key, required this.currentUser});

  @override
  State<DonorHistoryTab> createState() => _DonorHistoryTabState();
}

class _DonorHistoryTabState extends State<DonorHistoryTab> {
  bool _isLoading = true;
  List<dynamic> _historyData = [];
  List<dynamic> _filteredData = [];

  String _selectedFilter = 'Tümü';
  final List<String> _filters = ['Tümü', 'Son 3 Ay', 'Son 6 Ay', 'Bu Yıl'];

  // ── Tema renkleri (home tab ile aynı) ─────────────────────────────────────
  static const _crimson = Color(0xFFC0182A);
  static const _crimsonDark = Color(0xFF8B0000);
  static const _bg = Color(0xFFF5F5F7);
  static const _surface = Colors.white;
  static const _textPrimary = Color(0xFF1C1C1E);
  static const _textSecondary = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final url =
          ApiConstants.donorHistoryEndpoint(widget.currentUser.userId);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          _historyData = json.decode(utf8.decode(response.bodyBytes));
          _applyFilter(_selectedFilter);
          _isLoading = false;
        });
      } else {
        debugPrint("Hata: Backend ${response.statusCode} döndürdü.");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Bağış geçmişi çekilemedi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;

      if (filter == 'Tümü') {
        _filteredData = List.from(_historyData);
      } else {
        final now = DateTime.now();
        _filteredData = _historyData.where((item) {
          final dateStr = item['bagis_tarihi'];
          if (dateStr == null) return false;
          final date = DateTime.tryParse(dateStr);
          if (date == null) return false;

          if (filter == 'Son 3 Ay') return now.difference(date).inDays <= 90;
          if (filter == 'Son 6 Ay') return now.difference(date).inDays <= 180;
          if (filter == 'Bu Yıl') return date.year == now.year;
          return true;
        }).toList();
      }
    });
  }

  Map<String, dynamic> _getStatusConfig(String? status) {
    String s = (status ?? '').toLowerCase();
    if (s == 'basarili' || s == 'success' || s == 'basarılı') {
      return {
        "color": const Color(0xFF16A34A),
        "bgColor": const Color(0xFFDCFCE7),
        "icon": Icons.check_circle_rounded,
        "label": "Başarılı"
      };
    } else if (s == 'reddedildi' || s == 'red' || s == 'failed') {
      return {
        "color": _crimson,
        "bgColor": const Color(0xFFFFF0F0),
        "icon": Icons.cancel_rounded,
        "label": "Reddedildi"
      };
    } else {
      return {
        "color": const Color(0xFFD97706),
        "bgColor": const Color(0xFFFEF3C7),
        "icon": Icons.hourglass_empty_rounded,
        "label": "Beklemede"
      };
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Tarih Belirtilmemiş";
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        color: _crimson,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeroHeader(),
            SliverToBoxAdapter(child: _buildFilterChips()),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: _crimson)),
              )
            else if (_filteredData.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildHistoryCard(_filteredData[index], index),
                    childCount: _filteredData.length,
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
                    // Üst satır: başlık + toplam sayı rozeti
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Geçmişim",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Bağış Geçmişi",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (!_isLoading)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.14),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Center(
                              child: Text(
                                "${_historyData.length}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Alt bilgi satırı
                    Row(
                      children: [
                        _infoPill(
                          icon: Icons.water_drop_rounded,
                          text: _isLoading
                              ? "Yükleniyor..."
                              : "${_historyData.length} işlem kaydı",
                        ),
                        const SizedBox(width: 8),
                        if (!_isLoading && _historyData.isNotEmpty)
                          _infoPill(
                            icon: Icons.check_circle_outline_rounded,
                            text:
                                "${_historyData.where((i) => (i['islem_sonucu'] ?? '').toLowerCase().contains('basar')).length} başarılı",
                          ),
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

  Widget _infoPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(
            text,
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

  // ── FİLTRE CHİPLERİ ───────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () => _applyFilter(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? _crimson : _surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? _crimson
                          : Colors.black.withOpacity(0.1),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── GEÇMİŞ KARTI ──────────────────────────────────────────────────────────

  Widget _buildHistoryCard(Map<String, dynamic> item, int index) {
    final hospitalName =
        item['institution']?['kurum_adi'] ?? "Bilinmeyen Hastane";
    final rawDate = item['bagis_tarihi'];
    final rawStatus = item['islem_sonucu'];
    final statusConfig = _getStatusConfig(rawStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.black.withOpacity(0.07), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Sol ikon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.water_drop_rounded,
                  color: _crimson, size: 22),
            ),
            const SizedBox(width: 14),

            // Orta metinler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hospitalName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 12, color: _textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(rawDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Sağ durum rozeti
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusConfig['bgColor'],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusConfig['icon'],
                      size: 13, color: statusConfig['color']),
                  const SizedBox(width: 4),
                  Text(
                    statusConfig['label'],
                    style: TextStyle(
                      color: statusConfig['color'],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  // ── BOŞ DURUM ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.history_rounded,
                  size: 38, color: _crimson),
            ),
            const SizedBox(height: 20),
            Text(
              _selectedFilter == 'Tümü'
                  ? "Henüz Kayıt Yok"
                  : "$_selectedFilter İçin Kayıt Bulunamadı",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "Geçmiş kan bağışı ve red kayıtlarınız burada listelenir.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.5),
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