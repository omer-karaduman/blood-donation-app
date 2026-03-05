import 'package:flutter/material.dart';
import 'institution_management.dart';
import 'staff_management_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Ferah arka plan
      body: CustomScrollView(
        slivers: [
          // Havalı ve genişleyen üst bar
          SliverAppBar.large(
            title: const Text(
              "Yönetim Paneli", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF263238))
            ),
            surfaceTintColor: Colors.transparent,
            backgroundColor: const Color(0xFFF8F9FA),
            actions: [
              IconButton(
                onPressed: () {}, 
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF263238))
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
                
                // İstatistik Kartları (Ferah Tasarım)
                Row(
                  children: [
                    _buildModernStatCard("Donör", "1.250", Icons.favorite_rounded, Colors.red.shade400),
                    const SizedBox(width: 15),
                    _buildModernStatCard("Analiz", "%92", Icons.auto_graph_rounded, Colors.indigo.shade400),
                  ],
                ),
                
                const SizedBox(height: 35),
                const Text(
                  "Operasyonel Yönetim", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238))
                ),
                const SizedBox(height: 15),
                
                // Menü Kartları (Navigasyon Bağlanmış Hali)
                _buildActionCard(
                  context,
                  title: "Hastane & Kurumlar", 
                  sub: "Yeni hastane ekle, PostGIS koordinatlarını yönet.", 
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
                    // YENİ YÖNLENDİRME KODU BURADA
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
                    // İleride ML Analiz ekranına bağlanacak
                    debugPrint("ML Performans tıklandı");
                  },
                ),
                const SizedBox(height: 50), // Alt kısım ferah kalsın
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // --- MODERN İSTATİSTİK KARTI ---
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

  // --- MODERN AKSİYON KARTI (Dinamik onTap parametreli) ---
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
        border: Border.all(color: Colors.white), // Hafif kontur
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
}