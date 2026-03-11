// mobile/lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants/api_constants.dart';
import '../../models/admin_summary.dart'; // AdminSummary modelini import ettiğinizden emin olun
import 'institution_management.dart';
import 'staff_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminSummary? _summary;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAdminSummary();
  }

  // Backend'den gerçek verileri çeken merkezi fonksiyon
  Future<void> _fetchAdminSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/summary'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _summary = AdminSummary.fromJson(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Sunucu hatası: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Özet verisi çekilemedi: $e");
      setState(() {
        _errorMessage = "Bağlantı hatası. Lütfen internetinizi kontrol edin.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _fetchAdminSummary,
        color: const Color(0xFFE53935),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Liste boş olsa bile kaydırmayı sağlar
          slivers: [
            // Havalı Genişleyen Üst Bar
            SliverAppBar.large(
              title: const Text(
                "Yönetim Paneli", 
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF263238))
              ),
              surfaceTintColor: Colors.transparent,
              backgroundColor: const Color(0xFFF8F9FA),
              actions: [
                IconButton(
                  onPressed: _fetchAdminSummary,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF263238)),
                ),
              ],
            ),
            
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const Text(
                    "Sistem Özeti", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238))
                  ),
                  const SizedBox(height: 15),
                  
                  // Dinamik İstatistik Kartları
                  if (_errorMessage != null)
                    _buildErrorWidget()
                  else
                    Row(
                      children: [
                        _buildModernStatCard(
                          "Toplam Donör", 
                          _isLoading ? "..." : (_summary?.totalDonors.toString() ?? "0"), 
                          Icons.favorite_rounded, 
                          Colors.red.shade400
                        ),
                        const SizedBox(width: 15),
                        _buildModernStatCard(
                          "Aktif Talepler", 
                          _isLoading ? "..." : (_summary?.activeRequests.toString() ?? "0"), 
                          Icons.campaign_rounded, 
                          Colors.orange.shade400
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 35),
                  const Text(
                    "Operasyonel Yönetim", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238))
                  ),
                  const SizedBox(height: 15),
                  
                  // Menü Kartları
                  _buildActionCard(
                    context,
                    title: "Hastane & Kurumlar", 
                    sub: "Kurum ekle, PostGIS koordinatlarını yönet.", 
                    icon: Icons.local_hospital_rounded, 
                    color: Colors.green.shade400,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const InstitutionManagementScreen()),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: "Personel Yönetimi", 
                    sub: "Doktor ve sağlık personeli yetkilerini düzenle.", 
                    icon: Icons.badge_rounded, 
                    color: Colors.blue.shade400,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StaffManagementScreen()),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    title: "ML Performans Raporu", 
                    sub: "Model doğruluğu ve F1 Skor analizi.", 
                    icon: Icons.psychology_rounded, 
                    color: Colors.purple.shade400,
                    onTap: () {
                      // İleride detaylı ML ekranına bağlanabilir
                      debugPrint("ML Raporu tıklandı");
                    },
                  ),
                  const SizedBox(height: 50),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODERN İSTATİSTİK KARTI BİLEŞENİ ---
  Widget _buildModernStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03), 
              blurRadius: 20, 
              offset: const Offset(0, 10)
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 15),
            Text(
              value, 
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF263238))
            ),
            Text(
              title, 
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)
            ),
          ],
        ),
      ),
    );
  }

  // --- MODERN AKSİYON KARTI BİLEŞENİ ---
  Widget _buildActionCard(
    BuildContext context, {
    required String title, 
    required String sub, 
    required IconData icon, 
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238))
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub, 
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, height: 1.3)
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HATA DURUMU WIDGET'I ---
  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? "Bilinmeyen bir hata oluştu",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
          TextButton(
            onPressed: _fetchAdminSummary,
            child: const Text("Tekrar Dene", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}