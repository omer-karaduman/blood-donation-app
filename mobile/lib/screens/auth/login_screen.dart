// mobile/lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  bool _isLoading     = false;
  bool _obscurePass   = true;
  int _roleIndex      = 0; // 0 = Donör, 1 = Personel
  String? _errMsg;

  late AnimationController _bgCtrl;
  late AnimationController _formCtrl;
  late Animation<double> _bgAnim;
  late Animation<double> _formAnim;

  // Renk paleti
  Color get _primary => _roleIndex == 0
      ? const Color(0xFFD32F2F)
      : const Color(0xFF1565C0);
  Color get _primaryDark => _roleIndex == 0
      ? const Color(0xFFB71C1C)
      : const Color(0xFF0D47A1);
  Color get _primaryLight => _roleIndex == 0
      ? const Color(0xFFEF5350)
      : const Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _formCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
    _formAnim = CurvedAnimation(parent: _formCtrl, curve: Curves.easeOutBack);
    _formCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _bgCtrl.dispose();
    _formCtrl.dispose();
    super.dispose();
  }

  // ==========================================================================
  // GİRİŞ İŞLEMİ
  // ==========================================================================
  Future<void> _handleLogin() async {
    setState(() { _isLoading = true; _errMsg = null; });
    final user = await AuthService.login(
      _emailCtrl.text.trim(),
      _passCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      final isDonorTab = _roleIndex == 0;
      final isUserDonor = user.role == UserRole.donor;

      if (isDonorTab && !isUserDonor) {
        setState(() => _errMsg =
            'Bu hesap bir personel hesabı. Lütfen "Personel Girişi" sekmesini kullanın.');
        return;
      }
      if (!isDonorTab && isUserDonor) {
        setState(() => _errMsg =
            'Bu hesap bir donör hesabı. Lütfen "Donör Girişi" sekmesini kullanın.');
        return;
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => MainNavigationScreen(currentUser: user)),
        );
      }
    } else {
      setState(
          () => _errMsg = 'E-posta veya şifre hatalı. Lütfen tekrar deneyin.');
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(children: [
        // ── Animasyonlu arkaplan ──────────────────────────────────────────
        AnimatedBuilder(
          animation: _bgAnim,
          builder: (_, __) {
            return CustomPaint(
              size: Size(size.width, size.height),
              painter: _BlobPainter(_bgAnim.value, _primary),
            );
          },
        ),

        // ── İçerik ───────────────────────────────────────────────────────
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const SizedBox(height: 56),

              // Logo + başlık
              ScaleTransition(
                scale: _formAnim,
                child: Column(children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryDark, _primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: _primary.withValues(alpha: 0.4),
                        blurRadius: 24, offset: const Offset(0, 8),
                      )],
                    ),
                    child: const Icon(Icons.bloodtype_rounded,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 20),
                  const Text('Kan Bağışı AI',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 6),
                  Text(
                    _roleIndex == 0
                        ? 'Hayat kurtarmak için giriş yapın'
                        : 'Kurumsal sisteme erişim sağlayın',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14),
                  ),
                ]),
              ),

              const SizedBox(height: 36),

              // ── Sekme ────────────────────────────────────────────────────
              FadeTransition(
                opacity: _formAnim,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(children: [
                    _tab(0, Icons.volunteer_activism_rounded, 'Donör Girişi'),
                    _tab(1, Icons.local_hospital_rounded, 'Personel Girişi'),
                  ]),
                ),
              ),

              const SizedBox(height: 32),

              // ── Form kartı ────────────────────────────────────────────────
              FadeTransition(
                opacity: _formAnim,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(children: [
                    // E-posta
                    _field(
                      ctrl: _emailCtrl,
                      label: _roleIndex == 0
                          ? 'E-posta Adresi'
                          : 'Kurumsal E-posta',
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Şifre
                    _field(
                      ctrl: _passCtrl,
                      label: 'Şifre',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                    ),

                    // Hata mesajı
                    if (_errMsg != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_errMsg!,
                                style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    height: 1.4)),
                          ),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Giriş butonu
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _roleIndex == 0
                                          ? Icons.login_rounded
                                          : Icons.shield_rounded,
                                      size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      _roleIndex == 0
                                          ? 'Donör Olarak Giriş Yap'
                                          : 'Sisteme Giriş Yap',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 24),

              // ── Alt metin ─────────────────────────────────────────────────
              if (_roleIndex == 0)
                FadeTransition(
                  opacity: _formAnim,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Hesabın yok mu? ',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14)),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        ),
                        child: Text('Hemen Donör Ol',
                            style: TextStyle(
                                color: _primaryLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                )
              else
                FadeTransition(
                  opacity: _formAnim,
                  child: Text(
                    'Personel hesapları yalnızca sistem\nyöneticileri tarafından oluşturulabilir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        height: 1.6),
                  ),
                ),

              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }

  // ==========================================================================
  // SEKME WIDGET
  // ==========================================================================
  Widget _tab(int idx, IconData icon, String label) {
    final selected = _roleIndex == idx;
    final Color tabColor = idx == 0
        ? const Color(0xFFD32F2F)
        : const Color(0xFF1565C0);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _roleIndex = idx;
            _emailCtrl.clear();
            _passCtrl.clear();
            _errMsg = null;
          });
          _formCtrl.forward(from: 0);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: double.infinity,
          decoration: BoxDecoration(
            color: selected ? tabColor : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: selected
                ? [BoxShadow(
                    color: tabColor.withValues(alpha: 0.35),
                    blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : Colors.white38),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : Colors.white38,
                      fontWeight: selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // INPUT FIELD
  // ==========================================================================
  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool isPassword = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword && _obscurePass,
      onChanged: (_) => setState(() => _errMsg = null),
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: _primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _primary, width: 1.5)),
      ),
    );
  }
}

// ─── Arkaplan Blob Painter ─────────────────────────────────────────────────────

class _BlobPainter extends CustomPainter {
  final double t;
  final Color color;
  _BlobPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Blob 1
    paint.color = color.withValues(alpha: 0.12);
    final cx1 = size.width * 0.85 + math.sin(t * math.pi) * 30;
    final cy1 = size.height * 0.1 + math.cos(t * math.pi * 0.7) * 20;
    canvas.drawCircle(Offset(cx1, cy1), 180, paint);

    // Blob 2
    paint.color = color.withValues(alpha: 0.07);
    final cx2 = size.width * 0.1 + math.cos(t * math.pi * 0.8) * 20;
    final cy2 = size.height * 0.75 + math.sin(t * math.pi) * 25;
    canvas.drawCircle(Offset(cx2, cy2), 220, paint);

    // Blob 3 — small accent
    paint.color = color.withValues(alpha: 0.09);
    final cx3 = size.width * 0.5 + math.sin(t * math.pi * 1.2) * 40;
    final cy3 = size.height * 0.5 + math.cos(t * math.pi * 0.9) * 30;
    canvas.drawCircle(Offset(cx3, cy3), 100, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t || old.color != color;
}