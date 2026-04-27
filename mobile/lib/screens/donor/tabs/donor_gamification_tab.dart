// mobile/lib/screens/donor/tabs/donor_gamification_tab.dart
//
// Gamification deneyimi: puanlar, madalyalar (kilitli/açık), rozet ilerlemesi.
// Kullanıcıyı bağışa teşvik eden kilit/açma mekanizması.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import '../../../../core/constants/api_constants.dart';
import '../../../models/donor.dart';

class DonorGamificationTab extends StatefulWidget {
  final Donor currentUser;
  const DonorGamificationTab({super.key, required this.currentUser});

  @override
  State<DonorGamificationTab> createState() => _DonorGamificationTabState();
}

class _DonorGamificationTabState extends State<DonorGamificationTab>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  int _toplamPuan  = 0;
  int _toplamBagis = 0;

  late AnimationController _shimmerCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _heartbeatCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _shimmerAnim;
  late Animation<double> _heartAnim;

  // ── Tema ───────────────────────────────────────────────────────────────────
  static const _bg       = Color(0xFF0F1624);
  static const _surface  = Color(0xFF1A2333);
  static const _surfaceL = Color(0xFF222E42);
  static const _accent   = Color(0xFFC0182A);
  static const _gold     = Color(0xFFFFD700);
  static const _silver   = Color(0xFFB0BEC5);
  static const _bronze   = Color(0xFFCD7F32);
  static const _purple   = Color(0xFF9C27B0);
  static const _teal     = Color(0xFF00BCD4);

  // ── Madalya Tanımları ─────────────────────────────────────────────────────
  // Her madalya: gerekli bağış sayısı, puan, isim, açıklama, renk, ikon, tier
  static final List<Map<String, dynamic>> _medals = [
    {
      'id': 'ilk_adim',
      'name': 'İlk Adım',
      'desc': 'İlk bağışını yap',
      'icon': Icons.volunteer_activism_rounded,
      'color': _bronze,
      'glow': _bronze,
      'requiredDonations': 1,
      'points': 100,
      'tier': 'bronze',
    },
    {
      'id': 'kahraman',
      'name': 'Kan Kahramanı',
      'desc': '3 bağış tamamla',
      'icon': Icons.military_tech_rounded,
      'color': _silver,
      'glow': _silver,
      'requiredDonations': 3,
      'points': 300,
      'tier': 'silver',
    },
    {
      'id': 'hayat_kurtaran',
      'name': 'Hayat Kurtaran',
      'desc': '5 bağış tamamla',
      'icon': Icons.favorite_rounded,
      'color': _accent,
      'glow': _accent,
      'requiredDonations': 5,
      'points': 500,
      'tier': 'silver',
    },
    {
      'id': 'efsane',
      'name': 'Efsane Donör',
      'desc': '10 bağış tamamla',
      'icon': Icons.workspace_premium_rounded,
      'color': _gold,
      'glow': _gold,
      'requiredDonations': 10,
      'points': 1000,
      'tier': 'gold',
    },
    {
      'id': 'elit',
      'name': 'Elit Savaşçı',
      'desc': '20 bağış ile seçkin zümreye katıl',
      'icon': Icons.shield_rounded,
      'color': _teal,
      'glow': _teal,
      'requiredDonations': 20,
      'points': 2000,
      'tier': 'special',
    },
    {
      'id': 'efsanevi',
      'name': 'Efsanevi Sembol',
      'desc': '50 bağış — Kalıcı bir iz bırak',
      'icon': Icons.auto_awesome_rounded,
      'color': _purple,
      'glow': _purple,
      'requiredDonations': 50,
      'points': 5000,
      'tier': 'legendary',
    },
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))..repeat();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))..repeat();
    _heartbeatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

    _shimmerAnim = Tween<double>(begin: -2, end: 2)
        .animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _heartAnim = Tween<double>(begin: 1.0, end: 1.22)
        .animate(CurvedAnimation(parent: _heartbeatCtrl, curve: Curves.easeInOut));

    _fetchGamification();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _fadeCtrl.dispose();
    _particleCtrl.dispose();
    _heartbeatCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGamification() async {
    try {
      final res = await http.get(
          Uri.parse(ApiConstants.donorGamificationEndpoint(widget.currentUser.userId)));
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        // Backend now returns correct toplam_bagis from DonationHistory
        final int puan  = (data['toplam_puan']  as num?)?.toInt() ?? 0;
        final int bagis = (data['toplam_bagis'] as num?)?.toInt() ?? 0;
        setState(() {
          _toplamPuan  = puan;
          _toplamBagis = bagis;
          _isLoading   = false;
        });
        _fadeCtrl.forward(from: 0);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[Gamification] $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }


  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildPuanCard(),
                    const SizedBox(height: 24),
                    _buildProgressSection(),
                    const SizedBox(height: 24),
                    _buildMedalGrid(),
                    const SizedBox(height: 24),
                    _buildMotivationBanner(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0A0F), Color(0xFF2D0E1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Animasyonlu parçacıklar
            AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ParticlePainter(_particleCtrl.value),
                child: const SizedBox(height: 220, width: double.infinity),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _accent.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  color: _gold, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'BAŞARILAR & MADALYALAR',
                                style: TextStyle(
                                  color: _gold,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // ── Kalp atışı ──────────────────────────────
                        AnimatedBuilder(
                          animation: _heartAnim,
                          builder: (_, child) => Transform.scale(
                            scale: _heartAnim.value,
                            child: child,
                          ),
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _accent.withValues(alpha: 0.18),
                              border: Border.all(
                                  color: _accent.withValues(alpha: 0.55),
                                  width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                    color: _accent.withValues(alpha: 0.5),
                                    blurRadius: 14,
                                    spreadRadius: 2),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: _accent,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Başarı Takibi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Her bağış seni bir adım daha öne taşıyor.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13),
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

  Widget _buildPuanCard() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(_shimmerAnim.value - 1, 0),
          end: Alignment(_shimmerAnim.value + 1, 0),
          colors: [
            Colors.transparent,
            Colors.white.withAlpha(20),
            Colors.transparent,
          ],
        ).createShader(bounds),
        child: child,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B0019), Color(0xFFC0182A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: _gold, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'TOPLAM PUAN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_toplamPuan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_toplamBagis başarılı bağış',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: _gold,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PROGRESS SECTION ───────────────────────────────────────────────────────

  Widget _buildProgressSection() {
    // Sonraki madalyayı bul
    Map<String, dynamic>? next;
    for (final m in _medals) {
      if (_toplamBagis < (m['requiredDonations'] as int)) {
        next = m;
        break;
      }
    }

    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: _gold, size: 32),
            SizedBox(width: 16),
            Expanded(child: Text(
              'Tüm madalyaları kazandın! Efsane donörsün! 🎉',
              style: TextStyle(color: _gold, fontWeight: FontWeight.w800),
            )),
          ],
        ),
      );
    }

    final required = next['requiredDonations'] as int;
    final double progress = (_toplamBagis / required).clamp(0.0, 1.0);
    final Color color = next['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(next['icon'] as IconData, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sonraki: ${next['name']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${next['desc']} (${next['points']} puan)',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '$_toplamBagis/$required',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${required - _toplamBagis} bağış daha lazım',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ── MADALYA GRID ──────────────────────────────────────────────────────────

  Widget _buildMedalGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Madalya Koleksiyonu'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: _medals.map((medal) => _buildMedalCard(medal)).toList(),
        ),
      ],
    );
  }

  Widget _buildMedalCard(Map<String, dynamic> medal) {
    final required = medal['requiredDonations'] as int;
    final bool unlocked = _toplamBagis >= required;
    final Color color = medal['color'] as Color;
    final IconData icon = medal['icon'] as IconData;
    final String tier = medal['tier'] as String;

    return Container(
      decoration: BoxDecoration(
        color: unlocked ? _surface : _surfaceL,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked
              ? color.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.05),
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Stack(
        children: [
          // Tier background watermark
          if (unlocked)
            Positioned(
              right: 0,
              top: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20)),
                child: Opacity(
                  opacity: 0.06,
                  child: Icon(
                    icon,
                    size: 70,
                    color: color,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ikon
                unlocked
                    ? Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.15),
                          boxShadow: [
                            BoxShadow(
                                color: color.withValues(alpha: 0.35),
                                blurRadius: 16),
                          ],
                        ),
                        child: Icon(icon, color: color, size: 22),
                      )
                    : Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Icon(Icons.lock_rounded,
                            color: Colors.white24, size: 20),
                      ),
                const SizedBox(height: 10),
                // İsim
                Text(
                  medal['name'] as String,
                  style: TextStyle(
                    color: unlocked ? Colors.white : Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Gereksinim
                Row(
                  children: [
                    Icon(
                      unlocked
                          ? Icons.check_circle_rounded
                          : Icons.volunteer_activism_outlined,
                      size: 10,
                      color: unlocked ? color : Colors.white24,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        unlocked
                            ? '${medal['points']} puan'
                            : '$required bağış',
                        style: TextStyle(
                          color: unlocked ? color : Colors.white24,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Tier badge
                const SizedBox(height: 4),
                _tierBadge(tier, unlocked),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierBadge(String tier, bool unlocked) {
    final configs = {
      'bronze': ('BRONZ', _bronze),
      'silver': ('GÜMÜŞ', _silver),
      'gold': ('ALTIN', _gold),
      'special': ('ÖZEL', _teal),
      'legendary': ('EFSANE', _purple),
    };
    final cfg = configs[tier] ?? ('—', Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (cfg.$2).withValues(alpha: unlocked ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: (cfg.$2).withValues(alpha: unlocked ? 0.4 : 0.1)),
      ),
      child: Text(
        cfg.$1,
        style: TextStyle(
          color: unlocked ? cfg.$2 : Colors.white24,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── MOTİVASYON BANNER ──────────────────────────────────────────────────────

  Widget _buildMotivationBanner() {
    final quotes = [
      '"Her 3 saniyede bir biri kan ihtiyacı duyuyor."',
      '"Bir ünite kan 3 hayat kurtarabilir."',
      '"Sen bir kahraman olmayı seçebilirsin — sadece bir bağışla."',
    ];
    final q = quotes[_toplamBagis % quotes.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _purple.withValues(alpha: 0.15),
            _teal.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.format_quote_rounded,
              color: _purple.withValues(alpha: 0.5), size: 32),
          const SizedBox(height: 8),
          Text(
            q,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── YARDIMCI ───────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: _bg,
      body: const Center(
        child: CircularProgressIndicator(
            color: _accent, strokeWidth: 2),
      ),
    );
  }
}

// ── Particle Painter ──────────────────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint();
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = rng.nextDouble() * 0.3 + 0.1;
      final y = (baseY - progress * speed * size.height) % size.height;
      final r = rng.nextDouble() * 2 + 0.5;
      final alpha = (rng.nextDouble() * 0.15 + 0.05);
      paint.color = const Color(0xFFFFD700).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}