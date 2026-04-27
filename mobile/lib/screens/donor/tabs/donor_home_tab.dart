// mobile/lib/screens/donor/tabs/donor_home_tab.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import '../../../../../core/constants/api_constants.dart';
import '../../../models/donor.dart';
import '../ai_agent/ai_chat_screen.dart';

class DonorHomeTab extends StatefulWidget {
  final Donor currentUser;
  final Function(int) onTabChange;

  const DonorHomeTab({
    super.key,
    required this.currentUser,
    required this.onTabChange,
  });

  @override
  State<DonorHomeTab> createState() => _DonorHomeTabState();
}

class _DonorHomeTabState extends State<DonorHomeTab>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────

  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _gamification;
  List<dynamic> _feed = [];

  bool get _kanVerebilirMi => _profile?['kan_verebilir_mi'] ?? true;
  String get _adSoyad => _profile?['ad_soyad'] ?? widget.currentUser.adSoyad;
  String get _kanGrubu => _profile?['kan_grubu'] ?? widget.currentUser.kanGrubu;
  int get _toplamBagis => _gamification?['toplam_bagis'] ?? 0;
  int get _toplamPuan => _gamification?['toplam_puan'] ?? 0;
  int get _aktifTalepSayisi {
    return _feed.where((f) {
      // Feed API 'reaksiyon' alanını döndürüyor
      final r = (f['reaksiyon'] ?? '').toString().toLowerCase();
      return r == 'bekliyor' || r == 'kabul';
    }).length;
  }

  // Dinlenme süresi hesaplama
  DateTime? _nextDonationDate;
  Duration get _remaining => (_nextDonationDate != null && _nextDonationDate!.isAfter(DateTime.now()))
      ? _nextDonationDate!.difference(DateTime.now())
      : Duration.zero;
  bool get _isResting => _remaining > Duration.zero;

  Timer? _refreshTimer;
  Timer? _uiTimer;

  // ── Animasyonlar ───────────────────────────────────────────────────────────

  late AnimationController _pulseCtrl; // AI bubble pulse
  late AnimationController _waveCtrl;  // Dinlenme halkası
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _waveAnim;

  // ── Temalar ────────────────────────────────────────────────────────────────

  // -- Aktif (bağış yapabilir) Teması
  static const _activeGrad1 = Color(0xFFC0182A);
  static const _activeGrad2 = Color(0xFF7B0019);
  static const _activePrimary = Color(0xFFC0182A);
  static const _activeSurface = Colors.white;
  static const _activeBg = Color(0xFFF5F5F7);

  // -- Dinlenme Teması (mor-lacivert tonu)
  static const _restGrad1 = Color(0xFF1A237E);
  static const _restGrad2 = Color(0xFF283593);
  static const _restAccent = Color(0xFF5C6BC0);
  static const _restSurface = Color(0xFFF8F9FF);
  static const _restBg = Color(0xFFEEF0FB);

  Color get _headerGrad1 => _isResting ? _restGrad1 : _activeGrad1;
  Color get _headerGrad2 => _isResting ? _restGrad2 : _activeGrad2;
  Color get _primary => _isResting ? _restAccent : _activePrimary;
  Color get _surface => _isResting ? _restSurface : _activeSurface;
  Color get _bg => _isResting ? _restBg : _activeBg;

  static const _textPrimary = Color(0xFF1C1C1E);
  static const _textSecondary = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _waveAnim = Tween<double>(begin: 0, end: 2 * math.pi)
        .animate(_waveCtrl);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _fetchAll();

    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _fetchAll(silent: true);
    });
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _fadeCtrl.dispose();
    _refreshTimer?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DonorHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchAll(silent: true);
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _fetchAll({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);

    try {
      final userId = widget.currentUser.userId;
      final resList = await Future.wait([
        http.get(Uri.parse(ApiConstants.donorProfileEndpoint(userId))),
        http.get(Uri.parse(ApiConstants.donorGamificationEndpoint(userId))),
        http.get(Uri.parse(ApiConstants.donorFeedEndpoint(userId))),
      ]);

      if (!mounted) return;
      if (resList[0].statusCode == 200) {
        _profile = json.decode(utf8.decode(resList[0].bodyBytes));
        _computeNextDate();
      }
      if (resList[1].statusCode == 200) {
        _gamification = json.decode(utf8.decode(resList[1].bodyBytes));
      }
      if (resList[2].statusCode == 200) {
        _feed = json.decode(utf8.decode(resList[2].bodyBytes));
      }
    } catch (e) {
      debugPrint('[DonorHomeTab] fetch error: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
      _fadeCtrl.forward(from: 0);
    }
  }

  void _computeNextDate() {
    final dateStr = _profile?['son_bagis_tarihi']?.toString();
    if (dateStr == null || dateStr.isEmpty) { _nextDonationDate = null; return; }
    try {
      final safe = dateStr.endsWith('Z') ? dateStr : '${dateStr}Z';
      final last = DateTime.parse(safe).toLocal();
      final waitDays = (widget.currentUser.cinsiyet == 'K') ? 120 : 90;
      _nextDonationDate = last.add(Duration(days: waitDays));
    } catch (_) { _nextDonationDate = null; }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          FadeTransition(
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
                        _isResting ? _buildRestingBody() : _buildActiveBody(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // AI Bubble
          Positioned(
            bottom: 24,
            right: 20,
            child: _buildAiBubble(),
          ),
        ],
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_headerGrad1, _headerGrad2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Dekoratif daireler
            ..._buildDecorCircles(),
            if (_isResting) _buildWaveDecor(),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderTop(),
                    const SizedBox(height: 24),
                    _isResting ? _buildRestingHeroCard() : _buildActiveHeroCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDecorCircles() => [
    Positioned(top: -40, right: -40,
      child: _decorCircle(180, opacity: _isResting ? 0.07 : 0.06)),
    Positioned(bottom: -30, left: -20,
      child: _decorCircle(160, opacity: _isResting ? 0.05 : 0.04)),
    Positioned(top: 60, right: 80,
      child: _decorCircle(60, opacity: 0.04)),
  ];

  Widget _buildWaveDecor() {
    return AnimatedBuilder(
      animation: _waveAnim,
      builder: (_, __) => CustomPaint(
        painter: _WavePainter(_waveAnim.value),
        child: const SizedBox(height: 260, width: double.infinity),
      ),
    );
  }

  Widget _buildHeaderTop() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isResting ? 'Dinlenme Süreci' : 'Merhaba 👋',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _adSoyad.split(' ').first,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Kan grubu badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.water_drop_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 5),
              Text(
                _kanGrubu,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── AKTIF HERO ─────────────────────────────────────────────────────────────

  Widget _buildActiveHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bağışa Hazırsın!',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2)),
                    SizedBox(height: 2),
                    Text('Hayat kurtarmak için talepler seni bekliyor.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _statPill(Icons.bloodtype_outlined, '$_aktifTalepSayisi Aktif Talep'),
              const SizedBox(width: 10),
              _statPill(Icons.star_rounded, '$_toplamPuan Puan'),
              const SizedBox(width: 10),
              _statPill(Icons.favorite_rounded, '$_toplamBagis Bağış'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => widget.onTabChange(1),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _activePrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bloodtype_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Talepleri Gör',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── DİNLENME HERO ──────────────────────────────────────────────────────────

  Widget _buildRestingHeroCard() {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Countdown ring
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_rounded, color: Colors.white70, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    '$days',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1),
                  ),
                  const Text('gün', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bir Sonraki Bağışa ${days}g ${hours}s ${minutes}dk',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vücudun yenileniyor. Bu süre sağlığın için gerekli.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statPill(Icons.favorite_rounded, '$_toplamBagis Bağış'),
              const SizedBox(width: 10),
              _statPill(Icons.star_rounded, '$_toplamPuan Puan'),
            ],
          ),
        ],
      ),
    );
  }

  // ── AKTİF BODY ─────────────────────────────────────────────────────────────

  Widget _buildActiveBody() {
    // Kabul edilen aktif talep varsa ayır
    final acceptedItems = _feed.where(
        (f) => (f['reaksiyon'] ?? '').toString().toLowerCase() == 'kabul').toList();
    final pendingItems = _feed.where(
        (f) => (f['reaksiyon'] ?? '').toString().toLowerCase() == 'bekliyor').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // │ Aktif onaylanmış talep bannerı │
        if (acceptedItems.isNotEmpty) ...[
          _sectionHeader(Icons.check_circle_rounded, 'Onayladığım Bağış', const Color(0xFF2E7D32)),
          const SizedBox(height: 10),
          ...acceptedItems.map((item) => _buildAcceptedBanner(item)).toList(),
          const SizedBox(height: 20),
        ],

        _sectionHeader(Icons.flash_on_rounded, 'Sana Özel Talepler', _activePrimary),
        const SizedBox(height: 12),
        if (pendingItems.isEmpty)
          _emptyState(
            icon: Icons.inbox_rounded,
            title: 'Bekleyen talep yok',
            subtitle: 'Kan grubuna uygun yeni talepler gelince seni bilgilendireceğiz.',
            color: _activePrimary,
          )
        else
          ...pendingItems.take(3).map((item) => _buildFeedCard(item)).toList(),
        if (pendingItems.length > 3) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => widget.onTabChange(1),
              child: Text(
                '+${pendingItems.length - 3} daha fazla talep',
                style: const TextStyle(
                    color: _activePrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _sectionHeader(Icons.bar_chart_rounded, 'Bağış İstatistiklerin', _activePrimary),
        const SizedBox(height: 12),
        _buildStatsGrid(),
      ],
    );
  }

  // ── DİNLENME BODY ──────────────────────────────────────────────────────────

  Widget _buildRestingBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Motivasyon bölümü
        _sectionHeader(Icons.self_improvement_rounded, 'Dinlenme Tavsiyesi', _restAccent),
        const SizedBox(height: 12),
        _buildRestingTipsCard(),
        const SizedBox(height: 24),
        _sectionHeader(Icons.bar_chart_rounded, 'Bağış İstatistiklerin', _restAccent),
        const SizedBox(height: 12),
        _buildStatsGrid(),
        const SizedBox(height: 24),
        _sectionHeader(Icons.history_rounded, 'Son Bağışlarım', _restAccent),
        const SizedBox(height: 12),
        _buildLastDonationCard(),
      ],
    );
  }

  Widget _buildRestingTipsCard() {
    final tips = [
      (Icons.water_drop_outlined, 'Günde en az 2-3 litre su için'),
      (Icons.restaurant_outlined, 'Demir açısından zengin besinler tüketin'),
      (Icons.bedtime_outlined, 'Düzenli ve kaliteli uyku önemli'),
      (Icons.self_improvement_rounded, 'Hafif egzersizler yapabilirsiniz'),
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _restAccent.withValues(alpha: 0.08),
            _restGrad1.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _restAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: tips.map((t) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _restAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(t.$1, color: _restAccent, size: 18),
              ),
              const SizedBox(width: 14),
              Text(t.$2,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildLastDonationCard() {
    final dateStr = _profile?['son_bagis_tarihi']?.toString();
    if (dateStr == null || dateStr.isEmpty) {
      return _emptyState(
        icon: Icons.volunteer_activism_rounded,
        title: 'Henüz bağış yapılmadı',
        subtitle: 'İlk bağışını yaptıktan sonra burada görünecek.',
        color: _restAccent,
      );
    }

    DateTime? date;
    try {
      final safe = dateStr.endsWith('Z') ? dateStr : '${dateStr}Z';
      date = DateTime.parse(safe).toLocal();
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _restAccent.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: _restAccent.withValues(alpha: 0.07),
              blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _restAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.volunteer_activism_rounded,
                color: _restAccent, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Son Bağış Tarihi',
                  style: TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                date != null
                    ? '${date.day}.${date.month}.${date.year}'
                    : dateStr,
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text('Toplam $_toplamBagis bağış tamamlandı',
                  style: TextStyle(
                      color: _restAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ── FEED KARTI ─────────────────────────────────────────────────────────────

  Widget _buildFeedCard(Map<String, dynamic> item) {
    final aciliyetStr = (item['aciliyet_durumu'] ?? '').toString();
    final isAfet   = aciliyetStr == 'Afet';
    final isAcil   = aciliyetStr == 'Acil';
    final blood    = item['istenen_kan_grubu']?.toString() ?? '?';
    final kurum    = item['kurum_adi'] ?? 'Bilinmiyor';
    final ilce     = item['ilce']?.toString() ?? '';
    final logId    = item['log_id']?.toString() ?? '';
    final unite    = item['unite_sayisi']?.toString() ?? '1';
    final reaksiyon = (item['reaksiyon'] ?? '').toString().toLowerCase();
    final isAccepted = reaksiyon == 'kabul';

    // Renk paleti: Acil=kırmızı, Afet=koyu kırmızı, Normal=turuncu-kırmızı
    final Color cardColor = isAfet
        ? const Color(0xFF7B0019)
        : isAcil
            ? const Color(0xFFC0182A)
            : const Color(0xFFE53935);
    final Color cardAccent = isAfet
        ? const Color(0xFFB71C1C)
        : isAcil
            ? const Color(0xFFE53935)
            : const Color(0xFFEF5350);
    final String aciliyetLabel = isAfet ? 'AFET' : isAcil ? 'ACİL' : 'NORMAL';
    final Color badgeColor = isAfet
        ? const Color(0xFF7B0019)
        : isAcil
            ? const Color(0xFFB71C1C)
            : const Color(0xFF1565C0);
    final Color badgeBg = isAfet
        ? const Color(0xFFFFCDD2)
        : isAcil
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFE3F2FD);
    final IconData acilIcon = isAfet
        ? Icons.crisis_alert_rounded
        : isAcil
            ? Icons.warning_amber_rounded
            : Icons.water_drop_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardColor.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Üst kısım - renkli şerit
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardColor.withValues(alpha: 0.05), cardAccent.withValues(alpha: 0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(21),
                topRight: Radius.circular(21),
              ),
            ),
            child: Row(
              children: [
                // Kan grubu kutusu - her zaman canlı kırmızı
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cardColor, cardAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.water_drop_rounded, color: Colors.white60, size: 12),
                      Text(
                        blood,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            height: 1.1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst satır: aciliyet badge + onay durumu
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(acilIcon, color: badgeColor, size: 11),
                                const SizedBox(width: 3),
                                Text(
                                  aciliyetLabel,
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isAccepted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF2E7D32), size: 11),
                                  SizedBox(width: 3),
                                  Text('ONAYLI',
                                      style: TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kurum,
                        style: const TextStyle(
                            color: Color(0xFF1C1C1E),
                            fontSize: 14,
                            fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.water_drop_rounded,
                              color: cardColor.withValues(alpha: 0.7), size: 11),
                          const SizedBox(width: 3),
                          Text(
                            '$blood · $unite Ünite',
                            style: TextStyle(
                                color: cardColor.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          if (ilce.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.location_on_rounded,
                                color: _textSecondary.withValues(alpha: 0.7), size: 11),
                            const SizedBox(width: 2),
                            Text(
                              ilce,
                              style: const TextStyle(
                                  color: _textSecondary, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Aksiyon butonları
          Container(
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: cardColor.withValues(alpha: 0.08))),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _confirmSkip(logId),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(22))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.thumb_down_alt_outlined, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          'İlgilenmiyorum',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                    width: 1,
                    height: 36,
                    color: cardColor.withValues(alpha: 0.08)),
                Expanded(
                  child: TextButton(
                    onPressed: isAccepted ? null : () => _confirmAccept(logId),
                    style: TextButton.styleFrom(
                      foregroundColor: isAccepted
                          ? const Color(0xFF2E7D32)
                          : cardColor,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(22))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAccepted
                              ? Icons.check_circle_rounded
                              : Icons.volunteer_activism_rounded,
                          size: 15,
                          color: isAccepted
                              ? const Color(0xFF2E7D32)
                              : cardColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isAccepted ? 'Bağış Onaylandı' : 'Bağış Yapacağım',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: isAccepted
                                  ? const Color(0xFF2E7D32)
                                  : cardColor),
                        ),
                      ],
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

  // Geç / İlgilenmiyorum onay dialogu
  Future<void> _confirmSkip(String logId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bu taleple ilgilenmiyorsun?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
            'Bu talebi geçersen sana bir daha gösterilmeyecek.',
            style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('İlgilenmiyorum'),
          ),
        ],
      ),
    );
    if (ok == true) await _respond(logId, 'Gormezden_Geldi', isAccept: false);
  }

  // Bagis yapacagim - cift kabul kontrolu ile
  Future<void> _confirmAccept(String logId) async {
    final alreadyAccepted = _feed.any(
        (f) => (f['reaksiyon'] ?? '').toString().toLowerCase() == 'kabul' &&
            f['log_id']?.toString() != logId);

    if (alreadyAccepted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.info_rounded, color: Color(0xFF1565C0), size: 36),
          title: const Text('Zaten aktif bir taahhudun var!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              textAlign: TextAlign.center),
          content: const Text(
              'Halihazirda bir kan bagisi taahhudun bulunuyor. '
              'Iki farkli talep icin ayni anda bagis yapamazsin. '
              'Bu yeni talebi kabul edersen oncekini iptal edip bu talebi onaylamak ister misin?',
              style: TextStyle(fontSize: 13, height: 1.5),
              textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgec'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _activePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Oncekini Iptal Et, Bunu Onayla'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      for (final f in List.from(_feed.where(
          (f) => (f['reaksiyon'] ?? '').toString().toLowerCase() == 'kabul' &&
              f['log_id']?.toString() != logId))) {
        final oldId = f['log_id']?.toString() ?? '';
        if (oldId.isNotEmpty) {
          await _respond(oldId, 'Gormezden_Geldi', isAccept: false, silent: true);
        }
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Bagis yapacagini onayliyor musun?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          content: const Text(
              'Kuruma giderek bu kan talebini karsilayacagini belirtiyorsun. Sag olasin!',
              style: TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgec'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _activePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Evet, Bagis Yapacagim'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _respond(logId, 'Kabul', isAccept: true);
  }



  // ── ONAYLANMIŞ TALEP BANNER ──────────────────────────────────────────────

  Widget _buildAcceptedBanner(Map<String, dynamic> item) {
    final blood = item['istenen_kan_grubu']?.toString() ?? '?';
    final kurum = item['kurum_adi'] ?? 'Bilinmiyor';
    final ilce  = item['ilce']?.toString() ?? '';
    final logId = item['log_id']?.toString() ?? '';
    final unite = item['unite_sayisi']?.toString() ?? '1';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ust renkli serit
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Bagisa Gitmeyi Onayladim',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    blood,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Alt detay kismi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kurum,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _infoPill(Icons.location_on_rounded, ilce.isNotEmpty ? ilce : 'Konum yok',
                        const Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    _infoPill(Icons.water_drop_rounded, '$unite Unite',
                        const Color(0xFF1565C0)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _confirmCancelAccept(logId),
                    icon: const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFD32F2F)),
                    label: const Text(
                      'Bagis Onayimi Iptal Et',
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEBEE),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _infoPill(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _greenPill(IconData icon, String text) => _infoPill(icon, text, const Color(0xFF2E7D32));

    // Kabul iptal dialogu
  Future<void> _confirmCancelAccept(String logId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
        title: const Text('Bağış onayını iptal et?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            textAlign: TextAlign.center),
        content: const Text(
            'Bağış onayını iptal edersen kan ihtiyacı olan hasta mağdur olabilir. '
            'Gerçekten vazgeçmek istiyor musun?',
            style: TextStyle(fontSize: 13, height: 1.5),
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hayır, Gidiyorum'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('İptal Et', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await _respond(logId, 'Gormezden_Geldi', isAccept: false);
  }

  Future<void> _respond(String logId, String reaksiyon,
      {bool isAccept = false, bool silent = false}) async {
    // Anında lokal state güncelle (optimistic UI)
    if (mounted) {
      setState(() {
        if (!isAccept) {
          _feed.removeWhere((f) => f['log_id']?.toString() == logId);
        } else {
          final idx = _feed.indexWhere((f) => f['log_id']?.toString() == logId);
          if (idx != -1) {
            // LinkedMap TypeError'ı önlemek için Map.from() kullan
            final updated = Map<String, dynamic>.from(_feed[idx]);
            updated['reaksiyon'] = 'Kabul';
            _feed[idx] = updated;
          }
        }
      });
    }

    try {
      final url = Uri.parse(
        '${ApiConstants.donorsEndpoint}/${widget.currentUser.userId}/respond/$logId?reaksiyon=$reaksiyon',
      );
      final res = await http.post(url);
      debugPrint('[respond] status: ${res.statusCode}, body: ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted && !silent) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isAccept
                ? 'Bağış onaylandı! Teşekkürler 🩸'
                : 'Talep listenden çıkarıldı.'),
            backgroundColor:
                isAccept ? Colors.green.shade700 : Colors.grey.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
        await _fetchAll(silent: true);
      } else {
        await _fetchAll(silent: true);
        if (mounted && !silent) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: ${res.body}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } catch (e) {
      debugPrint('[respond] error: $e');
      await _fetchAll(silent: true);
    }
  }

  // ── STATS GRID ─────────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final items = [
      (Icons.volunteer_activism_rounded, 'Toplam Bağış', '$_toplamBagis', _primary),
      (Icons.star_rounded, 'Puan', '$_toplamPuan', const Color(0xFFE65100)),
      (Icons.bloodtype_rounded, 'Kan Grubu', _kanGrubu, const Color(0xFF00695C)),
      (Icons.flash_on_rounded, 'Aktif Talep', '$_aktifTalepSayisi', const Color(0xFF1565C0)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: items.map((i) => _statCard(i.$1, i.$2, i.$3, i.$4)).toList(),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.07),
              blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
              Text(label,
                  style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ── AI BUBBLE ──────────────────────────────────────────────────────────────

  Widget _buildAiBubble() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: _isResting ? _pulseAnim.value : 1.0,
        child: child,
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a1, a2) =>
                AiChatScreen(currentUser: widget.currentUser),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
        ),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isResting
                  ? [_restAccent, _restGrad1]
                  : [_activeGrad1, _activeGrad2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.45),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 26),
        ),
      ),
    );
  }

  // ── YARDIMCI WİDGET'LAR ────────────────────────────────────────────────────

  Widget _statPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: TextStyle(
              color: _textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8),
        ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.3), size: 48),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 12)),
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
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: _activeBg,
      body: Column(
        children: [
          Container(
            height: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_activeGrad1, _activeGrad2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wave Painter (Dinlenme modu dekor) ────────────────────────────────────────

class _WavePainter extends CustomPainter {
  final double phase;
  _WavePainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final path = Path();
      final offset = i * 0.5;
      path.moveTo(0, size.height * 0.6);
      for (double x = 0; x <= size.width; x++) {
        final y = size.height * 0.6 +
            math.sin((x / size.width * 2 * math.pi) + phase + offset) *
                20 * (1 - i * 0.2);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.phase != phase;
}