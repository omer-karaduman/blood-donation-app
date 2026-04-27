// mobile/lib/screens/donor/tabs/donor_requests_tab.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import '../../../../../core/constants/api_constants.dart';
import '../../../models/donor.dart';

class DonorRequestsTab extends StatefulWidget {
  final Donor currentUser;
  const DonorRequestsTab({super.key, required this.currentUser});

  @override
  State<DonorRequestsTab> createState() => _DonorRequestsTabState();
}

class _DonorRequestsTabState extends State<DonorRequestsTab>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────

  bool _isLoading = true;
  bool _isCooldown = false;
  List<dynamic> _requests = [];
  Duration _remaining = Duration.zero;

  Timer? _cooldownTimer;
  Timer? _refreshTimer;

  // ── Animasyonlar ───────────────────────────────────────────────────────────

  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;

  // ── Tema ───────────────────────────────────────────────────────────────────

  // Aktif (bağış yapılabilir)
  static const _activePrimary  = Color(0xFFC0182A);
  static const _activeGrad1    = Color(0xFFC0182A);
  static const _activeGrad2    = Color(0xFF8B0019);
  static const _activeBg       = Color(0xFFF5F5F7);
  static const _activeSurface  = Colors.white;

  // Cooldown (dinlenme)
  static const _coolBg         = Color(0xFFEEF0FB);
  static const _coolSurface    = Color(0xFFF8F9FF);
  static const _coolAccent     = Color(0xFF5C6BC0);
  static const _coolGrad1      = Color(0xFF1A237E);
  static const _coolGrad2      = Color(0xFF283593);

  Color get _bg      => _isCooldown ? _coolBg      : _activeBg;
  Color get _surface => _isCooldown ? _coolSurface : _activeSurface;
  Color get _primary => _isCooldown ? _coolAccent  : _activePrimary;
  Color get _hGrad1  => _isCooldown ? _coolGrad1   : _activeGrad1;
  Color get _hGrad2  => _isCooldown ? _coolGrad2   : _activeGrad2;

  static const _textPrimary   = Color(0xFF1C1C1E);
  static const _textSecondary = Color(0xFF8E8E93);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _pulseAnim =
        Tween<double>(begin: 1.0, end: 1.12).animate(
            CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _checkAndLoad();
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && !_isCooldown && !_isLoading) _fetchRequests(silent: true);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _cooldownTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _checkAndLoad() async {
    try {
      final res = await http.get(
          Uri.parse(ApiConstants.donorProfileEndpoint(widget.currentUser.userId)));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        final dateStr = data['son_bagis_tarihi']?.toString();

        if (dateStr != null && dateStr.isNotEmpty) {
          final safe = dateStr.endsWith('Z') ? dateStr : '${dateStr}Z';
          final last = DateTime.parse(safe).toLocal();
          final waitDays = widget.currentUser.cinsiyet == 'K' ? 120 : 90;
          final nextDate = last.add(Duration(days: waitDays));

          if (nextDate.isAfter(DateTime.now())) {
            if (!mounted) return;
            setState(() {
              _isCooldown = true;
              _remaining = nextDate.difference(DateTime.now());
              _isLoading = false;
            });
            _startTimer(nextDate);
            _fadeCtrl.forward(from: 0);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('[DonorRequestsTab] checkAndLoad: $e');
    }
    _fetchRequests();
  }

  void _startTimer(DateTime target) {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = target.difference(DateTime.now());
      if (left <= Duration.zero) {
        _cooldownTimer?.cancel();
        setState(() { _isCooldown = false; });
        _fetchRequests();
      } else {
        setState(() => _remaining = left);
      }
    });
  }

  Future<void> _fetchRequests({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final res = await http.get(
          Uri.parse(ApiConstants.donorFeedEndpoint(widget.currentUser.userId)));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _requests = json.decode(utf8.decode(res.bodyBytes));
          _isLoading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      debugPrint('[DonorRequestsTab] fetchRequests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(String logId, String reaksiyon, {bool isAccept = false}) async {
    // Anında lokal state güncelle (optimistic UI)
    if (mounted) {
      setState(() {
        if (!isAccept) {
          _requests.removeWhere((f) => f['log_id']?.toString() == logId);
        } else {
          final idx = _requests.indexWhere((f) => f['log_id']?.toString() == logId);
          if (idx != -1) {
            final updated = Map<String, dynamic>.from(_requests[idx]);
            updated['reaksiyon'] = 'Kabul';
            _requests[idx] = updated;
          }
        }
      });
    }

    try {
      final res = await http.post(Uri.parse(
        '${ApiConstants.donorsEndpoint}/${widget.currentUser.userId}/respond/$logId?reaksiyon=$reaksiyon',
      ));
      debugPrint('[respond] ${res.statusCode}: ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAccept
              ? 'Bağış onaylandı! Teşekkürler 🩸'
              : 'Talep listenden çıkarıldı.'),
          backgroundColor:
              isAccept ? Colors.green.shade700 : Colors.grey.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        await _fetchRequests(silent: true);
      } else {
        // Hata varsa geri al
        await _fetchRequests(silent: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: ${res.body}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      }
    } catch (e) {
      debugPrint('[DonorRequestsTab] respond: $e');
      await _fetchRequests(silent: true);
    }
  }

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('İlgilenmiyorum'),
          ),
        ],
      ),
    );
    if (ok == true) await _respond(logId, 'Gormezden_Geldi', isAccept: false);
  }

  Future<void> _confirmAccept(String logId, Color urgentColor) async {
    // Zaten kabul edilmis baska talep var mi?
    final alreadyAccepted = _requests.any(
        (f) => (f['reaksiyon'] ?? '').toString().toLowerCase() == 'kabul' &&
            f['log_id']?.toString() != logId);

    if (alreadyAccepted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.info_rounded, color: Color(0xFF1565C0), size: 36),
          title: const Text('Zaten onayladığın bir bağış var!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              textAlign: TextAlign.center),
          content: const Text(
              'Halihazırda bir kan bağışını onaylamışsın. '
              'İki farklı talep için aynı anda bağış yapamazsın. '
              'Önceki onayını iptal edip bu talebi onaylamak ister misin?',
              style: TextStyle(fontSize: 13, height: 1.5),
              textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: urgentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Öncekini İptal Et, Bunu Onayla'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      // Onceki kabul edilen talepleri iptal et
      for (final f in List.from(_requests.where(
          (f) => (f['reaksiyon'] ?? '').toString().toLowerCase() == 'kabul' &&
              f['log_id']?.toString() != logId))) {
        final oldId = f['log_id']?.toString() ?? '';
        if (oldId.isNotEmpty) {
          await _respond(oldId, 'Gormezden_Geldi', isAccept: false);
        }
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Bağışa gitmeyi onaylıyor musun?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          content: const Text(
              'Kuruma giderek bu kan talebini karşılayacağını belirtiyorsun. Sağ olasın!',
              style: TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: urgentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Evet, Gidiyorum'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _respond(logId, 'Kabul', isAccept: true);
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();

    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: FadeTransition(
          opacity: _fadeAnim,
          child: _isCooldown ? _buildCooldownBody() : _buildRequestsBody(),
        ),
      ),
    );
  }

  // ── APP BAR ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: _hGrad1,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_hGrad1, _hGrad2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Dekor daireler
              Positioned(
                top: -30, right: -30,
                child: _circle(160, opacity: 0.07)),
              Positioned(
                bottom: -20, left: 20,
                child: _circle(100, opacity: 0.05)),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _isCooldown
                              ? Icons.timer_rounded
                              : Icons.bloodtype_rounded,
                          color: Colors.white, size: 22,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isCooldown ? 'Dinlenme Süreci' : 'Kan Talepleri',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isCooldown
                            ? 'Vücudun yenileniyor. Biraz bekle!'
                            : '${_requests.length} talep seni bekliyor',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── COOLDOWN (DİNLENME) EKRANI ─────────────────────────────────────────────

  Widget _buildCooldownBody() {
    final days    = _remaining.inDays;
    final hours   = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        children: [
          // Ana sayaç kartı
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_coolGrad1, _coolGrad2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _coolAccent.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.self_improvement_rounded,
                      color: Colors.white70, size: 48),
                  const SizedBox(height: 16),
                  const Text('Sonraki Bağışa Kalan Süre',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  // Countdown tiles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _countdownTile('$days', 'Gün'),
                      _countdownSep(),
                      _countdownTile('${hours.toString().padLeft(2, '0')}', 'Saat'),
                      _countdownSep(),
                      _countdownTile('${minutes.toString().padLeft(2, '0')}', 'Dak'),
                      _countdownSep(),
                      _countdownTile('${seconds.toString().padLeft(2, '0')}', 'Sn'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // İpuçları
          _buildTipsList(),
          const SizedBox(height: 24),
          // Neden beklemelisin
          _buildWhyWaitCard(),
        ],
      ),
    );
  }

  Widget _countdownTile(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _countdownSep() => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 20),
    child: Text(':',
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 28,
            fontWeight: FontWeight.w300)),
  );

  Widget _buildTipsList() {
    final tips = [
      (Icons.water_drop_outlined, 'Bol su içmeye devam edin'),
      (Icons.restaurant_outlined, 'Demir açısından zengin beslening'),
      (Icons.bedtime_outlined, 'Düzenli uyku önemli'),
      (Icons.fitness_center_outlined, 'Hafif egzersiz yapabilirsiniz'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _coolAccent.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: tips.asMap().entries.map((e) {
          final isLast = e.key == tips.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _coolAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(e.value.$1,
                          color: _coolAccent, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Text(e.value.$2,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    color:
                        _coolAccent.withValues(alpha: 0.08)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWhyWaitCard() {
    final waitDays = widget.currentUser.cinsiyet == 'K' ? 120 : 90;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _coolAccent.withValues(alpha: 0.08),
            _coolGrad1.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _coolAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _coolAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: _coolAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Neden Bekliyorum?',
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Vücudunuzun kan ve hücre değerlerini yenilemesi için $waitDays günlük bekleme süreci uygulanmaktadır.',
                  style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AKTIF TALEPLER LİSTESİ ─────────────────────────────────────────────────

  Widget _buildRequestsBody() {
    if (_requests.isEmpty) {
      return _buildEmptyState();
    }

    // Acil önce, sonra normal
    final sorted = [..._requests]..sort((a, b) {
        final aU = (a['aciliyet_durumu'] ?? '').toString();
        final bU = (b['aciliyet_durumu'] ?? '').toString();
        final aScore = (aU == 'Afet') ? 2 : (aU == 'Acil') ? 1 : 0;
        final bScore = (bU == 'Afet') ? 2 : (bU == 'Acil') ? 1 : 0;
        return bScore.compareTo(aScore);
      });

    return RefreshIndicator(
      onRefresh: () => _fetchRequests(),
      color: _activePrimary,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: sorted.length,
        itemBuilder: (_, i) => _buildRequestCard(sorted[i]),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> item) {
    // API'den doğru field adlarını kullan
    final aciliyetStr = (item['aciliyet_durumu'] ?? '').toString();
    final isAfet   = aciliyetStr == 'Afet';
    final isAcil   = aciliyetStr == 'Acil' || isAfet;
    final blood    = item['istenen_kan_grubu']?.toString() ?? '?';
    final kurum    = item['kurum_adi'] ?? 'Bilinmiyor';
    final ilce     = item['ilce']?.toString() ?? '';
    final unite    = item['unite_sayisi']?.toString() ?? '1';
    final logId    = item['log_id']?.toString() ?? '';
    final reaksiyon = (item['reaksiyon'] ?? '').toString().toLowerCase();
    final isAccepted = reaksiyon == 'kabul';

    // Renk paleti
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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                // Kan grubu kutusu
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cardColor, cardAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: cardColor.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.water_drop_rounded, color: Colors.white54, size: 13),
                      Text(
                        blood,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(7),
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cardColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '$unite Ünite',
                              style: TextStyle(
                                color: cardColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isAccepted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(7),
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
                      const SizedBox(height: 7),
                      Text(
                        kurum,
                        style: const TextStyle(
                            color: Color(0xFF1C1C1E),
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (ilce.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                color: cardColor.withValues(alpha: 0.6), size: 12),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                ilce,
                                style: TextStyle(
                                    color: cardColor.withValues(alpha: 0.75),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(22))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.thumb_down_alt_outlined,
                          size: 15,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'İlgilenmiyorum',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                    width: 1, height: 40,
                    color: cardColor.withValues(alpha: 0.08)),
                Expanded(
                  child: TextButton(
                    onPressed: isAccepted ? null : () => _confirmAccept(logId, cardColor),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isAccepted ? const Color(0xFF2E7D32) : cardColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                          color: isAccepted ? const Color(0xFF2E7D32) : cardColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAccepted ? 'Bağış Onaylandı' : 'Bağış Yapacağım',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
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

  // ── YARDIMCI ───────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _activePrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite_border_rounded,
                  color: _activePrimary.withValues(alpha: 0.4), size: 52),
            ),
            const SizedBox(height: 20),
            const Text('Şu an uygun talep yok',
                style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Kan grubuna uygun yeni bir talep geldiğinde bildirim alacaksın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _fetchRequests(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Yenile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _activePrimary,
                side: BorderSide(color: _activePrimary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: _activeBg,
      body: Column(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
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
          Expanded(
            child: Center(
              child: CircularProgressIndicator(
                  color: _activePrimary, strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, {required double opacity}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}