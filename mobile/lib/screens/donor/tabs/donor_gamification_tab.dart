// mobile/lib/screens/donor/tabs/donor_gamification_tab.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants/api_constants.dart';
import '../../../models/donor.dart';

// --- ROZET MODELİ ---
class BadgeMilestone {
  final String title;
  final String description;
  final int requiredDonations;
  final IconData icon;
  final Color color;

  BadgeMilestone({
    required this.title,
    required this.description,
    required this.requiredDonations,
    required this.icon,
    required this.color,
  });
}

class DonorGamificationTab extends StatefulWidget {
  final Donor currentUser;

  const DonorGamificationTab({super.key, required this.currentUser});

  @override
  State<DonorGamificationTab> createState() => _DonorGamificationTabState();
}

class _DonorGamificationTabState extends State<DonorGamificationTab> {
  bool _isLoading = true;
  int _toplamPuan = 0;
  int _seviye = 1;
  int _basariliBagisSayisi = 0;

  // ── Tema Renkleri (Home Tab ile uyumlu) ─────────────────────────
  static const _crimson = Color(0xFFC0182A);
  static const _crimsonDark = Color(0xFF8B0000);
  static const _bg = Color(0xFFF5F5F7);
  static const _surface = Colors.white;
  static const _textPrimary = Color(0xFF1C1C1E);
  static const _textSecondary = Color(0xFF8E8E93);

  // ── Hedef Rozetlerimiz ──────────────────────────────────────────
  final List<BadgeMilestone> _badges = [
    BadgeMilestone(
      title: "İlk Adım",
      description: "İlk kan bağışını tamamla.",
      requiredDonations: 1,
      icon: Icons.water_drop_rounded,
      color: Colors.pink,
    ),
    BadgeMilestone(
      title: "Umut Işığı",
      description: "Toplam 3 kez bağış yap.",
      requiredDonations: 3,
      icon: Icons.favorite_rounded,
      color: Colors.orange.shade600,
    ),
    BadgeMilestone(
      title: "Hayat Kurtarıcı",
      description: "Toplam 5 kez bağış yap.",
      requiredDonations: 5,
      icon: Icons.star_rounded,
      color: Colors.blue.shade600,
    ),
    BadgeMilestone(
      title: "Kahraman",
      description: "Toplam 10 kez bağış yap.",
      requiredDonations: 10,
      icon: Icons.military_tech_rounded,
      color: Colors.purple.shade600,
    ),
    BadgeMilestone(
      title: "Efsanevi Donör",
      description: "Toplam 25 kez bağış yap.",
      requiredDonations: 25,
      icon: Icons.diamond_rounded,
      color: Colors.teal.shade600,
    ),
    BadgeMilestone(
      title: "Kan Meleği",
      description: "Toplam 50 kez bağış yap.",
      requiredDonations: 50,
      icon: Icons.workspace_premium_rounded,
      color: Colors.amber.shade700,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchGamificationData();
  }

  // ── API İSTEKLERİ ───────────────────────────────────────────────
  Future<void> _fetchGamificationData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = widget.currentUser.userId;

      // 1. Puan ve Seviye bilgisini çek
      final gRes = await http.get(Uri.parse(ApiConstants.donorGamificationEndpoint(userId)));
      if (gRes.statusCode == 200) {
        final gData = json.decode(utf8.decode(gRes.bodyBytes));
        _toplamPuan = gData['toplam_puan'] ?? 0;
        _seviye = gData['seviye'] ?? 1;
      }

      // 2. Bağış sayısını hesaplamak için geçmişi çek (Sadece "Basarili" olanları sayacağız)
      final hRes = await http.get(Uri.parse(ApiConstants.donorHistoryEndpoint(userId)));
      if (hRes.statusCode == 200) {
        final List<dynamic> historyData = json.decode(utf8.decode(hRes.bodyBytes));
        
        // Sadece durumu başarılı olanları filtreleyip sayısını alıyoruz
        _basariliBagisSayisi = historyData.where((record) {
          final sonuc = record['islem_sonucu']?.toString().toLowerCase() ?? '';
          return sonuc == 'basarili' || sonuc == 'başarılı';
        }).length;
      }

    } catch (e) {
      debugPrint("Gamification fetch error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── YARDIMCI METOTLAR ───────────────────────────────────────────
  String _getSeviyeLabel(int seviye) {
    if (seviye >= 5) return "Platin Bağışçı";
    if (seviye >= 4) return "Altın Bağışçı";
    if (seviye >= 3) return "Gümüş Bağışçı";
    if (seviye >= 2) return "Bronz Bağışçı";
    return "Başlangıç Seviyesi";
  }

  // Bir sonraki seviye için rastgele veya formüle dayalı bir max puan hesabı
  int _getMaxPointsForCurrentLevel() {
    return _seviye * 500; // Örn: 1. seviye 500'de biter, 2. seviye 1000'de vb.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _crimson))
          : RefreshIndicator(
              onRefresh: _fetchGamificationData,
              color: _crimson,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildHeroHeader(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                      child: Text(
                        "BAŞARILAR & ROZETLER",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  _buildBadgesGrid(),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)), // Alt boşluk
                ],
              ),
            ),
    );
  }

  // ── 1. HERO HEADER (Home Tab Tasarımıyla Uyumlu) ────────────────
  Widget _buildHeroHeader() {
    final maxPoints = _getMaxPointsForCurrentLevel();
    final double progress = (_toplamPuan / maxPoints).clamp(0.0, 1.0);

    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_crimson, _crimsonDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -40, right: -40, child: _decorCircle(180, 0.06)),
            Positioned(bottom: -20, left: 50, child: _decorCircle(120, 0.04)),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Toplam Puan",
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "$_toplamPuan",
                          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "XP",
                          style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.military_tech_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Seviye $_seviye: ${_getSeviyeLabel(_seviye)}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Progress Bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Sv. $_seviye", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text("Sv. ${_seviye + 1}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${maxPoints - _toplamPuan} XP kaldı",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
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

  Widget _decorCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }

  // ── 2. ROZETLER GRID YAPISI ─────────────────────────────────────
  Widget _buildBadgesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85, // Kartların en/boy oranı
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final badge = _badges[index];
            final isUnlocked = _basariliBagisSayisi >= badge.requiredDonations;
            return _buildBadgeCard(badge, isUnlocked);
          },
          childCount: _badges.length,
        ),
      ),
    );
  }

  // ── 3. BİREYSEL ROZET KARTI TASARIMI ────────────────────────────
  Widget _buildBadgeCard(BadgeMilestone badge, bool isUnlocked) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isUnlocked ? badge.color.withOpacity(0.3) : Colors.black.withOpacity(0.05),
          width: isUnlocked ? 1.5 : 0.5,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: badge.color.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ]
            : [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // İKON ALANI
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isUnlocked ? badge.color.withOpacity(0.1) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    badge.icon,
                    size: 32,
                    color: isUnlocked ? badge.color : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                
                // BAŞLIK
                Text(
                  badge.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isUnlocked ? _textPrimary : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 6),
                
                // AÇIKLAMA
                Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11,
                    color: isUnlocked ? _textSecondary : Colors.grey.shade400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          
          // EĞER KİLİTLİYSE ÜZERİNE BİLGİ/KARARTMA EKLİYORUZ
          if (!isUnlocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6), // Hafif flu efekti
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$_basariliBagisSayisi / ${badge.requiredDonations}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey.shade700,
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
}