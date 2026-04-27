// mobile/lib/screens/admin/ml_performance_screen.dart
//
// admin/system-logs endpoint'inden gelen verileri kullanarak
// ML modelinin gerçek performans metriklerini hesaplar ve gösterir.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../../../core/constants/api_constants.dart';

// ─── Veri Modeli ──────────────────────────────────────────────────────────────

class _MlMetrics {
  final int totalRequests;
  final int totalNotifications;  // Toplam ML önerisi
  final int acceptedDonors;      // reaksiyon == KABUL_ETTI
  final int completedDonors;     // reaksiyon == TAMAMLANDI
  final int rejectedDonors;      // reaksiyon == REDDETTI
  final int pendingDonors;       // reaksiyon == BEKLIYOR / GORMEZDEN_GELDI
  final double avgNotificationsPerRequest;
  final Map<String, int> bloodGroupDist;

  _MlMetrics({
    required this.totalRequests,
    required this.totalNotifications,
    required this.acceptedDonors,
    required this.completedDonors,
    required this.rejectedDonors,
    required this.pendingDonors,
    required this.avgNotificationsPerRequest,
    required this.bloodGroupDist,
  });

  // Recall ≈ Gerçekleşen bağış / Toplam kabul+tamamlanan
  double get donationRate {
    if (totalNotifications == 0) return 0;
    return (acceptedDonors + completedDonors) / totalNotifications * 100;
  }

  double get completionRate {
    final responded = acceptedDonors + completedDonors + rejectedDonors;
    if (responded == 0) return 0;
    return completedDonors / responded * 100;
  }

  double get responseRate {
    if (totalNotifications == 0) return 0;
    final responded = acceptedDonors + completedDonors + rejectedDonors;
    return responded / totalNotifications * 100;
  }

  // Basit F1 ≈ 2PR/(P+R) tahmini: P=completion, R=response
  double get f1Score {
    final p = completionRate / 100;
    final r = responseRate / 100;
    if (p + r == 0) return 0;
    return (2 * p * r) / (p + r) * 100;
  }
}

// ─── Ekran ────────────────────────────────────────────────────────────────────

class MlPerformanceScreen extends StatefulWidget {
  const MlPerformanceScreen({super.key});

  @override
  State<MlPerformanceScreen> createState() => _MlPerformanceScreenState();
}

class _MlPerformanceScreenState extends State<MlPerformanceScreen>
    with TickerProviderStateMixin {
  _MlMetrics? _metrics;
  List<dynamic> _rawLogs = [];
  bool _isLoading = true;
  String? _error;

  late AnimationController _pulseCtrl;
  late AnimationController _barCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _barAnim;

  static const Color _orange     = Color(0xFFFF6D00);
  static const Color _orangeDark = Color(0xFFE65100);
  static const Color _orangeLight= Color(0xFFFF8F00);
  static const Color _orangeBg   = Color(0xFFFFF3E0);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseAnim = Tween<double>(begin: 0.80, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _barAnim = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOutCubic);
    _fetchData();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  // ==========================================================================
  // VERİ ÇEKME + HESAPLAMA
  // ==========================================================================
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      // 1. Tüm logları çek
      final logsRes = await http.get(Uri.parse(ApiConstants.adminLogsEndpoint));
      if (logsRes.statusCode != 200) throw Exception('Log verisi alınamadı.');

      final logs = json.decode(utf8.decode(logsRes.bodyBytes)) as List;
      _rawLogs = logs;

      // 2. Her log için detay çek — reaksiyon verilerini derle
      int accepted = 0, completed = 0, rejected = 0, pending = 0;
      final Map<String, int> bloodDist = {};

      for (final log in logs) {
        final id = log['talep_id']?.toString() ?? '';
        if (id.isEmpty) continue;

        // Kan grubu dağılımı
        final kg = (log['istenen_kan_grubu'] ?? 'Bilinmiyor').toString();
        bloodDist[kg] = (bloodDist[kg] ?? 0) + 1;

        // Detay çek
        try {
          final detRes = await http.get(
            Uri.parse(ApiConstants.adminRequestDetailEndpoint(id)),
          );
          if (detRes.statusCode == 200) {
            final det = json.decode(utf8.decode(detRes.bodyBytes));
            final bildirimler = det['bildirimler'] as List? ?? [];
            for (final b in bildirimler) {
              final r = (b['reaksiyon'] ?? '').toString().toUpperCase();
              if (r.contains('KABUL') || r == 'KABUL_ETTI') {
                accepted++;
              } else if (r.contains('TAMAML')) {
                completed++;
              } else if (r.contains('REDDET')) {
                rejected++;
              } else {
                pending++;
              }
            }
          }
        } catch (_) {}
      }

      final totalNotif = accepted + completed + rejected + pending;
      final avgPerReq = logs.isNotEmpty
          ? logs.map((l) => (l['onerilen_donor_sayisi'] ?? 0) as int)
                .fold<int>(0, (a, b) => a + b) / logs.length
          : 0.0;

      if (mounted) {
        setState(() {
          _metrics = _MlMetrics(
            totalRequests:           logs.length,
            totalNotifications:      totalNotif,
            acceptedDonors:          accepted,
            completedDonors:         completed,
            rejectedDonors:          rejected,
            pendingDonors:           pending,
            avgNotificationsPerRequest: avgPerReq,
            bloodGroupDist:          bloodDist,
          );
        });
        _barCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: _orange,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: _orange),
                      SizedBox(height: 16),
                      Text('Bildirim geçmişi analiz ediliyor...',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(child: _buildError())
            else if (_metrics == null)
              const SliverFillRemaining(
                  child: Center(child: Text('Veri bulunamadı.')))
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildKpiRow()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                    child: _sectionTitle('Yanıt Dağılımı')),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildResponseCard()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                    child: _sectionTitle('Model Performans Metrikleri')),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: _buildMetricsCard()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                    child: _sectionTitle('Kan Grubu Dağılımı')),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                sliver: SliverToBoxAdapter(child: _buildBloodGroupCard()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================
  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        height: 200,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_orangeDark, _orange, _orangeLight],
          ),
        ),
        child: Stack(children: [
          Positioned(
            top: -28, right: -18,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  width: 175, height: 175,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07)),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -55, left: -35,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04)),
            ),
          ),
          Positioned(
            top: 18, right: 26,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value * 0.18,
                child: const Icon(Icons.psychology_rounded,
                    size: 110, color: Colors.white),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.17),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('Geri',
                            style: TextStyle(color: Colors.white,
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.psychology_rounded,
                          color: Colors.white, size: 12),
                      SizedBox(width: 5),
                      Text('ML MODELI',
                          style: TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  const Text('ML Performans Raporu',
                      style: TextStyle(color: Colors.white,
                          fontSize: 22, fontWeight: FontWeight.w900,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text(
                    _metrics != null
                        ? '${_metrics!.totalRequests} talep · ${_metrics!.totalNotifications} öneri analiz edildi'
                        : 'Bildirim geçmişinden hesaplanıyor...',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ==========================================================================
  // KPI SATIRI
  // ==========================================================================
  Widget _buildKpiRow() {
    final m = _metrics!;
    return Row(children: [
      _kpiCard(Icons.send_rounded, '${m.totalNotifications}',
          'Toplam Öneri', _orange, _orangeBg),
      const SizedBox(width: 12),
      _kpiCard(Icons.check_circle_rounded, '${m.acceptedDonors + m.completedDonors}',
          'Kabul', const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
      const SizedBox(width: 12),
      _kpiCard(Icons.star_rounded,
          m.avgNotificationsPerRequest.toStringAsFixed(1),
          'Ort/Talep', const Color(0xFF7B1FA2), const Color(0xFFF3E5F5)),
    ]);
  }

  Widget _kpiCard(IconData icon, String val, String lbl,
      Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(val, style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A2E))),
          Text(lbl, style: TextStyle(
              fontSize: 10, color: Colors.grey.shade500)),
        ]),
      ),
    );
  }

  // ==========================================================================
  // YANIT DAĞILIMI
  // ==========================================================================
  Widget _buildResponseCard() {
    final m = _metrics!;
    final total = m.totalNotifications;

    final bars = [
      _BarData('Tamamlanan', m.completedDonors, total, Colors.green.shade600, Icons.check_circle_rounded),
      _BarData('Kabul Eden', m.acceptedDonors, total, const Color(0xFF1565C0), Icons.thumb_up_rounded),
      _BarData('Reddeden', m.rejectedDonors, total, const Color(0xFFD32F2F), Icons.thumb_down_rounded),
      _BarData('Bekleyen', m.pendingDonors, total, Colors.grey.shade500, Icons.hourglass_empty_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: bars
          .map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildBar(b),
              ))
          .toList()),
    );
  }

  Widget _buildBar(_BarData b) {
    final ratio = b.total > 0 ? b.count / b.total : 0.0;
    final pct = (ratio * 100).toStringAsFixed(1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: b.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7)),
          child: Icon(b.icon, color: b.color, size: 13),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(b.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E))),
        ),
        Text('${b.count}  ($pct%)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 8),
      AnimatedBuilder(
        animation: _barAnim,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio * _barAnim.value,
            backgroundColor: Colors.grey.shade100,
            color: b.color,
            minHeight: 9,
          ),
        ),
      ),
    ]);
  }

  // ==========================================================================
  // PERFORMANS METRİKLERİ
  // ==========================================================================
  Widget _buildMetricsCard() {
    final m = _metrics!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        _metricRow('Yanıt Oranı', m.responseRate,
            'Bildirilen kişilerden yanıt veren oran',
            Colors.blue.shade600),
        const SizedBox(height: 18),
        _metricRow('Bağış Tamamlama', m.completionRate,
            'Yanıt verenler içinden bağışa dönüşme',
            Colors.green.shade600),
        const SizedBox(height: 18),
        _metricRow('ML Öneri Başarısı', m.donationRate,
            'Tüm bildirimlerin bağışa dönüşme oranı',
            _orange),
        const SizedBox(height: 18),
        _metricRow('F1 Skoru (tahmini)', m.f1Score,
            'Precision × Recall harmonik ortalaması',
            const Color(0xFF7B1FA2)),
      ]),
    );
  }

  Widget _metricRow(String title, double pct, String desc, Color color) {
    final clamped = pct.clamp(0.0, 100.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(title, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          Text(desc, style: TextStyle(fontSize: 11,
              color: Colors.grey.shade500)),
        ])),
        const SizedBox(width: 12),
        AnimatedBuilder(
          animation: _barAnim,
          builder: (_, __) {
            final shown = clamped * _barAnim.value;
            return Text(
              '${shown.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                  color: color),
            );
          },
        ),
      ]),
      const SizedBox(height: 8),
      AnimatedBuilder(
        animation: _barAnim,
        builder: (_, __) {
          // Radyal gösterge olarak arc çiziyoruz
          return SizedBox(
            height: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (clamped / 100) * _barAnim.value,
                backgroundColor: Colors.grey.shade100,
                color: color,
                minHeight: 10,
              ),
            ),
          );
        },
      ),
    ]);
  }

  // ==========================================================================
  // KAN GRUBU DAĞILIMI
  // ==========================================================================
  Widget _buildBloodGroupCard() {
    final m = _metrics!;
    if (m.bloodGroupDist.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(20)),
        child: const Center(child: Text('Kan grubu verisi yok.')),
      );
    }

    final sortedEntries = m.bloodGroupDist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = m.bloodGroupDist.values.fold<int>(0, (a, b) => a + b);

    final colors = [
      const Color(0xFFD32F2F),
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      const Color(0xFF7B1FA2),
      const Color(0xFFFF6D00),
      const Color(0xFF00838F),
      const Color(0xFF6D4C41),
      const Color(0xFF37474F),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        ...sortedEntries.asMap().entries.map((e) {
          final idx    = e.key;
          final entry  = e.value;
          final color  = colors[idx % colors.length];
          final ratio  = total > 0 ? entry.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(entry.key,
                      style: TextStyle(color: color,
                          fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text('${entry.value} talep',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E))),
                    const Spacer(),
                    Text('${(ratio * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12,
                            color: Colors.grey.shade500)),
                  ]),
                  const SizedBox(height: 6),
                  AnimatedBuilder(
                    animation: _barAnim,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: ratio * _barAnim.value,
                        backgroundColor: Colors.grey.shade100,
                        color: color,
                        minHeight: 7,
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ==========================================================================
  // HATA DURUMU
  // ==========================================================================
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded,
              color: _orange, size: 60),
          const SizedBox(height: 16),
          const Text('Veri yüklenemedi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_error ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
          ),
        ]),
      ),
    );
  }

  // ==========================================================================
  // YARDIMCILAR
  // ==========================================================================
  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
          color: Color(0xFF1A1A2E), letterSpacing: -0.3));
}

class _BarData {
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;
  const _BarData(this.label, this.count, this.total, this.color, this.icon);
}
