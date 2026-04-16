// mobile/lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final dynamic currentUser;

  const ProfileScreen({super.key, required this.currentUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // ── Renk Paleti (blood_request_detail_screen ile birebir uyumlu) ──
  static const Color _bg          = Color(0xFFF4F6F9);
  static const Color _surface     = Colors.white;
  static const Color _red         = Color(0xFFD32F2F);
  static const Color _redDark     = Color(0xFFB71C1C);
  static const Color _redLight    = Color(0xFFFFCDD2);
  static const Color _redSoft     = Color(0xFFFFF0F0);
  static const Color _blue        = Color(0xFF1565C0);
  static const Color _blueLight   = Color(0xFFBBDEFB);
  static const Color _blueSoft    = Color(0xFFEFF5FF);
  static const Color _green       = Color(0xFF2E7D32);
  static const Color _greenLight  = Color(0xFFC8E6C9);
  static const Color _greenSoft   = Color(0xFFF0FBF0);
  static const Color _orange      = Color(0xFFE65100);
  static const Color _orangeLight = Color(0xFFFFE0B2);
  static const Color _orangeSoft  = Color(0xFFFFF8F0);
  static const Color _teal        = Color(0xFF00695C);
  static const Color _tealLight   = Color(0xFFB2DFDB);
  static const Color _tealSoft    = Color(0xFFE0F2F1);
  static const Color _purple      = Color(0xFF4527A0);
  static const Color _purpleLight = Color(0xFFD1C4E9);
  static const Color _purpleSoft  = Color(0xFFF3F0FF);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecond  = Color(0xFF6B7280);
  static const Color _textMuted   = Color(0xFFB0B8C1);
  static const Color _border      = Color(0xFFEEF0F4);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fetchProfileData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _fetchProfileData() async {
    String userId = widget.currentUser.userId.toString();
    try {
      final response = await http.get(
          Uri.parse('${ApiConstants.baseUrl}/users/$userId/profile'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _profileData = data;
            _isLoading = false;
          });
          _fadeController.forward();
          _slideController.forward();
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          _fadeController.forward();
          _slideController.forward();
        }
      }
    } catch (e) {
      debugPrint("Profil verisi çekilemedi: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        _fadeController.forward();
        _slideController.forward();
      }
    }
  }

  // ── Veri okuma fonksiyonları ──
  String _getRole() {
    try {
      if (widget.currentUser == null || widget.currentUser.role == null) {
        return 'donor';
      }
      return widget.currentUser.role.toString().split('.').last.toLowerCase();
    } catch (e) {
      return 'donor';
    }
  }

  String _getName() {
    String role = _getRole();
    if (role == 'admin') return "Sistem Yöneticisi";
    if (_profileData.containsKey('ad_soyad') &&
        _profileData['ad_soyad'] != null) {
      return _profileData['ad_soyad'];
    }
    return widget.currentUser.email.split('@')[0].toUpperCase();
  }

  String _getBloodType() {
    if (_profileData.containsKey('kan_grubu') &&
        _profileData['kan_grubu'] != null) {
      return _profileData['kan_grubu'];
    }
    return "—";
  }

  String _getStaffTitle() {
    if (_profileData.containsKey('unvan') && _profileData['unvan'] != null) {
      return _profileData['unvan'];
    }
    return "Yükleniyor...";
  }

  String _getStaffNo() {
    if (_profileData.containsKey('personel_no') &&
        _profileData['personel_no'] != null) {
      return _profileData['personel_no'].toString();
    }
    return "-";
  }

  String _getStaffInstitution() {
    if (_profileData.containsKey('kurum_adi') &&
        _profileData['kurum_adi'] != null) {
      return _profileData['kurum_adi'];
    }
    return "Kurum Bilgisi Aranıyor...";
  }

  // ── Rol renkleri ──
  List<Color> _roleGradient(String role) {
    if (role == 'staff') {
      return [const Color(0xFF1565C0), const Color(0xFF0D47A1)];
    }
    if (role == 'admin') {
      return [const Color(0xFF4527A0), const Color(0xFF311B92)];
    }
    return [const Color(0xFFD32F2F), const Color(0xFFB71C1C)];
  }

  Color _roleAccent(String role) {
    if (role == 'staff') return _blue;
    if (role == 'admin') return _purple;
    return _red;
  }

  Color _roleAccentSoft(String role) {
    if (role == 'staff') return _blueSoft;
    if (role == 'admin') return _purpleSoft;
    return _redSoft;
  }

  Color _roleAccentLight(String role) {
    if (role == 'staff') return _blueLight;
    if (role == 'admin') return _purpleLight;
    return _redLight;
  }

  IconData _roleIcon(String role) {
    if (role == 'staff') return Icons.medical_services_rounded;
    if (role == 'admin') return Icons.admin_panel_settings_rounded;
    return Icons.favorite_rounded;
  }

  String _roleLabel(String role) {
    if (role == 'staff') return "SAĞLIK PERSONELİ";
    if (role == 'admin') return "SİSTEM YÖNETİCİSİ";
    return "KAN BAĞIŞÇISI";
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    if (widget.currentUser == null) {
      return const Scaffold(
          body: Center(child: Text("Oturum hatası. Lütfen giriş yapın.")));
    }

    final String role = _getRole();
    final String name = _getName();
    final String email = widget.currentUser.email ?? "E-posta bulunamadı";
    final List<Color> gradient = _roleGradient(role);
    final Color accent = _roleAccent(role);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Üst gradient şerit ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gradient[0],
                    gradient[1],
                    gradient[1].withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),

          // ── Dekoratif daireler ──
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: 30,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            top: 30,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // ── İçerik ──
          SafeArea(
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: const [
                      // Geri butonu kaldırıldı, başlık eklendi.
                      Expanded(
                        child: Text(
                          "Profilim",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Avatar + İsim Kartı ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.6)),
                      boxShadow: [
                        BoxShadow(
                          color: gradient[1].withOpacity(0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [gradient[0], gradient[1]],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: gradient[0].withOpacity(0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            _roleIcon(role),
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _roleAccentSoft(role),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: _roleAccentLight(role)),
                                ),
                                child: Text(
                                  _roleLabel(role),
                                  style: TextStyle(
                                    color: _roleAccent(role),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── İçerik alanı ──
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: accent,
                              strokeWidth: 2.5,
                            ),
                          )
                        : FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                    20, 24, 20, 32),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (role == 'admin') _buildAdminPanel(),
                                    if (role == 'staff')
                                      _buildStaffPanel(accent),
                                    if (role == 'donor')
                                      _buildDonorPanel(accent),
                                    const SizedBox(height: 28),
                                    _buildLogoutButton(accent),
                                  ],
                                ),
                              ),
                            ),
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

  // ── Panel Widgetları ──

  Widget _buildDonorPanel(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Sağlık & Bağış Bilgileri",
            Icons.favorite_border_rounded, _red),
        const SizedBox(height: 14),
        _buildDataCard(
          icon: Icons.bloodtype_rounded,
          iconColor: _red,
          iconBg: _redSoft,
          iconBgBorder: _redLight,
          title: "Kan Grubu",
          value: _getBloodType(),
          subtitle: "Sisteme Kayıtlı",
        ),
        _buildDataCard(
          icon: Icons.star_rounded,
          iconColor: _orange,
          iconBg: _orangeSoft,
          iconBgBorder: _orangeLight,
          title: "Bağış Puanı",
          value: "0 Puan",
          subtitle: "Gönüllü Bağışçı",
        ),
        _buildDataCard(
          icon: Icons.history_rounded,
          iconColor: _teal,
          iconBg: _tealSoft,
          iconBgBorder: _tealLight,
          title: "Son Bağış",
          value: "Henüz Yapılmadı",
          subtitle: null,
        ),
      ],
    );
  }

  Widget _buildStaffPanel(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            "Kurumsal Görev Bilgileri", Icons.badge_rounded, _blue),
        const SizedBox(height: 14),
        _buildDataCard(
          icon: Icons.badge_rounded,
          iconColor: _blue,
          iconBg: _blueSoft,
          iconBgBorder: _blueLight,
          title: "Görev Unvanı",
          value: _getStaffTitle(),
          subtitle: null,
        ),
        _buildDataCard(
          icon: Icons.local_hospital_rounded,
          iconColor: _teal,
          iconBg: _tealSoft,
          iconBgBorder: _tealLight,
          title: "Bağlı Kurum",
          value: _getStaffInstitution(),
          subtitle: null,
        ),
        _buildDataCard(
          icon: Icons.pin_rounded,
          iconColor: _green,
          iconBg: _greenSoft,
          iconBgBorder: _greenLight,
          title: "Sicil Numarası",
          value: _getStaffNo(),
          subtitle: null,
        ),
      ],
    );
  }

  Widget _buildAdminPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            "Sistem Yetkileri", Icons.security_rounded, _purple),
        const SizedBox(height: 14),
        _buildDataCard(
          icon: Icons.security_rounded,
          iconColor: _purple,
          iconBg: _purpleSoft,
          iconBgBorder: _purpleLight,
          title: "Yetki Seviyesi",
          value: "Super Admin",
          subtitle: "Tüm sistem erişimi açık",
        ),
        _buildDataCard(
          icon: Icons.data_usage_rounded,
          iconColor: _orange,
          iconBg: _orangeSoft,
          iconBgBorder: _orangeLight,
          title: "Sunucu Durumu",
          value: "Bağlantı Aktif",
          subtitle: null,
          trailing: _statusDot(),
        ),
      ],
    );
  }

  Widget _statusDot() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _green,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDataCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color iconBgBorder,
    required String title,
    required String value,
    String? subtitle,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: iconBgBorder.withOpacity(0.5)),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildLogoutButton(Color accent) {
    return GestureDetector(
      onTap: _handleLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _redSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _redLight),
          boxShadow: [
            BoxShadow(
              color: _red.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_rounded, color: _red, size: 18),
            SizedBox(width: 10),
            Text(
              "Hesaptan Çıkış Yap",
              style: TextStyle(
                color: _red,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}