// mobile/lib/screens/donor/tabs/donor_history_tab.dart
//
// Tüm bağış geçmişi: başarılı, reddedildi, görmezden gelindi, iptal dahil.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../core/constants/api_constants.dart';
import '../../../models/donor.dart';

class DonorHistoryTab extends StatefulWidget {
  final Donor currentUser;
  const DonorHistoryTab({super.key, required this.currentUser});

  @override
  State<DonorHistoryTab> createState() => _DonorHistoryTabState();
}

class _DonorHistoryTabState extends State<DonorHistoryTab>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<dynamic> _donations = []; // DonationHistory (successful/rejected)
  List<dynamic> _allLogs = [];   // NotificationLog (tüm reaksiyonlar)
  String _filter = 'Tümü';

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _bg      = Color(0xFFF1F3F8);
  static const _primary = Color(0xFFC0182A);
  static const _textP   = Color(0xFF1C1C1E);
  static const _textS   = Color(0xFF8E8E93);

  static const _filters = ['Tümü', 'Başarılı', 'Reddedildi', 'Görmezden', 'Bekliyor'];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fetch();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      // Bağış geçmişi (DonationHistory)
      final donRes = await http.get(Uri.parse(
          ApiConstants.donorHistoryEndpoint(widget.currentUser.userId)));
      // Tüm loglar (NotificationLog)
      final logRes = await http.get(Uri.parse(
          '${ApiConstants.donorsEndpoint}/${widget.currentUser.userId}/all-logs'));

      if (mounted) {
        setState(() {
          if (donRes.statusCode == 200) {
            _donations = json.decode(utf8.decode(donRes.bodyBytes));
          }
          if (logRes.statusCode == 200) {
            _allLogs = json.decode(utf8.decode(logRes.bodyBytes));
          }
          _isLoading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      debugPrint('[History] $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Tüm combined listeyi filtrele
  List<Map<String, dynamic>> get _filtered {
    // Donation history için: Basarili / Reddedildi
    // All logs için: Gormezden_Geldi, Bekliyor, Kabul, Tamamlandi
    final combined = <Map<String, dynamic>>[];

    // Önce DonationHistory kayıtlarını ekle
    for (final d in _donations) {
      final status = (d['islem_sonucu'] ?? '').toString();
      combined.add({
        'type': 'donation',
        'kurum_adi': d['institution']?['kurum_adi'] ?? 'Bilinmeyen Kurum',
        'tarih': d['bagis_tarihi'],
        'status': status,
        'display_status': _donationStatusLabel(status),
        'color': _donationStatusColor(status),
        'icon': _donationStatusIcon(status),
      });
    }

    // NotificationLog'dan Donation'da olmayan kayıtları ekle (Gormezden_Geldi, Bekliyor)
    for (final log in _allLogs) {
      final reaksiyon = (log['reaksiyon'] ?? '').toString();
      // Tamamlandi ve Kabul ise donation history'de zaten var
      if (reaksiyon == 'Tamamlandi' || reaksiyon == 'Tamamlandı') continue;
      if (reaksiyon == 'Kabul') continue; // aktif kabul, geçmişte değil
      combined.add({
        'type': 'log',
        'kurum_adi': log['kurum_adi'] ?? 'Bilinmeyen Kurum',
        'tarih': log['reaksiyon_zamani'] ?? log['gonderim_zamani'],
        'status': reaksiyon,
        'display_status': _logStatusLabel(reaksiyon),
        'color': _logStatusColor(reaksiyon),
        'icon': _logStatusIcon(reaksiyon),
      });
    }

    // Tarihe göre sırala (en yeni önce)
    combined.sort((a, b) {
      final ta = DateTime.tryParse(a['tarih'] ?? '') ?? DateTime(2000);
      final tb = DateTime.tryParse(b['tarih'] ?? '') ?? DateTime(2000);
      return tb.compareTo(ta);
    });

    if (_filter == 'Tümü') return combined;
    return combined.where((item) {
      if (_filter == 'Başarılı') return item['status'] == 'Basarili' || item['status'] == 'Başarılı';
      if (_filter == 'Reddedildi') return item['status'] == 'Reddedildi';
      if (_filter == 'Görmezden') return item['status'] == 'Gormezden_Geldi';
      if (_filter == 'Bekliyor') return item['status'] == 'Bekliyor';
      return true;
    }).toList();
  }

  String _donationStatusLabel(String s) {
    final l = s.toLowerCase();
    if (l == 'basarili' || l == 'başarılı') return 'Başarılı';
    if (l == 'reddedildi') return 'Reddedildi';
    return s;
  }

  Color _donationStatusColor(String s) {
    final l = s.toLowerCase();
    if (l == 'basarili' || l == 'başarılı') return const Color(0xFF2E7D32);
    return _primary;
  }

  IconData _donationStatusIcon(String s) {
    final l = s.toLowerCase();
    if (l == 'basarili' || l == 'başarılı') return Icons.check_circle_rounded;
    return Icons.cancel_rounded;
  }

  String _logStatusLabel(String s) {
    switch (s) {
      case 'Gormezden_Geldi': return 'Görmezden Gelindi';
      case 'Bekliyor': return 'Yanıt Bekleniyor';
      case 'Red': return 'Reddedildi';
      default: return s;
    }
  }

  Color _logStatusColor(String s) {
    switch (s) {
      case 'Gormezden_Geldi': return const Color(0xFF78909C);
      case 'Bekliyor': return const Color(0xFFE65100);
      case 'Red': return _primary;
      default: return _textS;
    }
  }

  IconData _logStatusIcon(String s) {
    switch (s) {
      case 'Gormezden_Geldi': return Icons.do_not_disturb_rounded;
      case 'Bekliyor': return Icons.hourglass_top_rounded;
      case 'Red': return Icons.thumb_down_rounded;
      default: return Icons.info_rounded;
    }
  }

  int get _successCount => _donations.where((d) {
    final s = (d['islem_sonucu'] ?? '').toString().toLowerCase();
    return s == 'basarili' || s == 'başarılı';
  }).length;

  int get _totalPuan => _successCount * 100;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();

    final list = _filtered;

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverHeader(),
            SliverToBoxAdapter(child: _buildFilterBar()),
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmpty(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildItem(list[i], i, list.length),
                    childCount: list.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8B0019), Color(0xFFC0182A), Color(0xFFEF5350)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -40, right: -40, child: _decCircle(180, 0.08)),
            Positioned(bottom: -30, left: 40, child: _decCircle(120, 0.05)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.history_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Bağış Geçmişim',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _fetch,
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white70, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _stat('$_successCount', 'Başarılı Bağış',
                            Icons.water_drop_rounded),
                        const SizedBox(width: 12),
                        _stat('${_allLogs.length}', 'Toplam Etkileşim',
                            Icons.notifications_rounded),
                        const SizedBox(width: 12),
                        _stat('$_totalPuan', 'Toplam Puan',
                            Icons.bolt_rounded),
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

  Widget _stat(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item, int idx, int total) {
    final isLast = idx == total - 1;
    final Color statusColor = item['color'] as Color;
    final IconData statusIcon = item['icon'] as IconData;
    final String statusLabel = item['display_status'] as String;
    final String kurumAdi = item['kurum_adi'] as String;
    final bool isSuccess = item['status'] == 'Basarili' || item['status'] == 'Başarılı';

    final String? dateStr = item['tarih']?.toString();
    DateTime? date;
    if (dateStr != null) {
      try {
        final safe = dateStr.endsWith('Z') ? dateStr : '${dateStr}Z';
        date = DateTime.parse(safe).toLocal();
      } catch (_) {}
    }



    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.1),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Icon(statusIcon, color: statusColor, size: 18),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withValues(alpha: 0.25),
                        statusColor.withValues(alpha: 0.03),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_hospital_rounded,
                          color: statusColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        kurumAdi,
                        style: const TextStyle(
                            color: _textP,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 11, color: _textS),
                    const SizedBox(width: 4),
                    Text(
                      date != null
                          ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}  '
                            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                          : 'Tarih bilinmiyor',
                      style: const TextStyle(color: _textS, fontSize: 11),
                    ),
                    if (isSuccess) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded,
                                size: 12, color: Color(0xFF1565C0)),
                            SizedBox(width: 2),
                            Text('+100 puan',
                                style: TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primary.withValues(alpha: 0.08),
              ),
              child: Icon(Icons.water_drop_outlined, size: 44,
                  color: _primary.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            Text(
              _filter == 'Tümü'
                  ? 'Henüz kayıt yok'
                  : '"$_filter" kategorisinde kayıt yok',
              style: const TextStyle(
                  color: _textP, fontSize: 16, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'İlk bağışını yaptığında geçmişin burada görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textS, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8B0019), _primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decCircle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );

  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFFF1F3F8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: _filters.map((f) {
            final isSelected = f == _filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textS,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
}