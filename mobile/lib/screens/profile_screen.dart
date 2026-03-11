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

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {}; // Arka plandan gelecek tüm gerçek veriler burada tutulacak

  @override
  void initState() {
    super.initState();
    _fetchProfileData(); // Sayfa açılır açılmaz verileri çek!
  }

  void _handleLogout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // ===========================================================================
  // BACKEND'DEN PROFİL VERİLERİNİ ÇEKEN FONKSİYON (KESİN ÇÖZÜM)
  // ===========================================================================
  Future<void> _fetchProfileData() async {
    String userId = widget.currentUser.userId.toString();
    
    try {
      // main.py'a eklediğimiz yeni endpoint'e istek atıyoruz
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/users/$userId/profile'));
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _profileData = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Profil verisi çekilemedi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // VERİ OKUMA FONKSİYONLARI (Artık doğrudan Backend datasını okur)
  // ===========================================================================
  String _getRole() {
    try {
      if (widget.currentUser == null || widget.currentUser.role == null) return 'donor';
      return widget.currentUser.role.toString().split('.').last.toLowerCase();
    } catch (e) { return 'donor'; }
  }

  String _getName() {
    String role = _getRole();
    if (role == 'admin') return "Sistem Yöneticisi";
    
    // Arkadan veri geldiyse direkt onu yaz
    if (_profileData.containsKey('ad_soyad') && _profileData['ad_soyad'] != null) {
      return _profileData['ad_soyad'];
    }
    
    // Veri gelene kadar e-postayı göster
    return widget.currentUser.email.split('@')[0].toUpperCase();
  }

  String _getBloodType() {
    if (_profileData.containsKey('kan_grubu') && _profileData['kan_grubu'] != null) {
      return _profileData['kan_grubu'];
    }
    return "Yükleniyor...";
  }

  String _getStaffTitle() {
    if (_profileData.containsKey('unvan') && _profileData['unvan'] != null) {
      return _profileData['unvan'];
    }
    return "Yükleniyor...";
  }

  String _getStaffNo() {
    if (_profileData.containsKey('personel_no') && _profileData['personel_no'] != null) {
      return _profileData['personel_no'].toString();
    }
    return "-";
  }

  String _getStaffInstitution() {
    if (_profileData.containsKey('kurum_adi') && _profileData['kurum_adi'] != null) {
      return _profileData['kurum_adi'];
    }
    return "Kurum Bilgisi Aranıyor...";
  }


  // ===========================================================================
  // ANA ARAYÜZ (UI) OLUŞTURUCU
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    if (widget.currentUser == null) return const Scaffold(body: Center(child: Text("Oturum hatası. Lütfen giriş yapın.")));

    String role = _getRole();
    String name = _getName();
    String email = widget.currentUser.email ?? "E-posta bulunamadı";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              _buildProfileHeader(role, name, email),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Column(
                        children: [
                          if (role == 'admin') _buildAdminPanel(),
                          if (role == 'staff') _buildStaffPanel(),
                          if (role == 'donor') _buildDonorPanel(),
                          
                          const SizedBox(height: 35),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: TextButton.icon(
                              onPressed: _handleLogout, 
                              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                              label: const Text('Hesaptan Çıkış Yap', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.08),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
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

  // ===========================================================================
  // TASARIM WIDGET'LARI 
  // ===========================================================================

  Widget _buildProfileHeader(String role, String name, String email) {
    Gradient bgGradient = role == 'staff' 
      ? const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF1565C0)])
      : const LinearGradient(colors: [Color(0xFFEF5350), Color(0xFFD32F2F)]);
    
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: bgGradient,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
          ),
        ),
        Positioned(
          bottom: -50,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: role == 'staff' ? Colors.blue.shade50 : Colors.red.shade50,
                  child: Icon(
                    role == 'staff' ? Icons.medical_services_rounded : (role == 'admin' ? Icons.admin_panel_settings : Icons.favorite_rounded),
                    size: 45,
                    color: role == 'staff' ? const Color(0xFF1565C0) : const Color(0xFFE53935),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Text(email, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDonorPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 60), 
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text("Sağlık & Bağış Bilgileri", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        ),
        _buildDataCard(icon: Icons.bloodtype, iconColor: Colors.redAccent, title: "Kan Grubu", value: _getBloodType(), subtitle: "Sisteme Kayıtlı"),
        _buildDataCard(icon: Icons.star_rounded, iconColor: Colors.amber.shade600, title: "Bağış Puanı", value: "0 Puan", subtitle: "Gönüllü Bağışçı"),
        _buildDataCard(icon: Icons.history_rounded, iconColor: Colors.blueGrey, title: "Son Bağış", value: "Henüz Yapılmadı"),
      ],
    );
  }

  Widget _buildStaffPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text("Kurumsal Görev Bilgileri", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        ),
        _buildDataCard(icon: Icons.badge_rounded, iconColor: Colors.blueAccent, title: "Görev Unvanı", value: _getStaffTitle()),
        _buildDataCard(icon: Icons.local_hospital_rounded, iconColor: Colors.teal, title: "Bağlı Kurum", value: _getStaffInstitution()),
        _buildDataCard(icon: Icons.pin_rounded, iconColor: Colors.indigo, title: "Sicil Numarası", value: _getStaffNo()),
      ],
    );
  }

  Widget _buildAdminPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text("Sistem Yetkileri", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        ),
        _buildDataCard(icon: Icons.security_rounded, iconColor: Colors.deepPurple, title: "Yetki Seviyesi", value: "Super Admin", subtitle: "Tüm sistem erişimi açık"),
        _buildDataCard(icon: Icons.data_usage_rounded, iconColor: Colors.orange, title: "Sunucu Durumu", value: "Bağlantı Aktif"),
      ],
    );
  }

  Widget _buildDataCard({required IconData icon, required Color iconColor, required String title, required String value, String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}