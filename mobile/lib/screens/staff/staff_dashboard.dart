import 'package:flutter/material.dart';
// İleride eklenecek ekranların importları (örnek):
// import 'blood_request_screen.dart';
// import 'ml_donor_match_screen.dart';
// import 'emergency_broadcast_screen.dart';

class StaffDashboard extends StatelessWidget {
  const StaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Admin paneli ile uyumlu ferah arka plan
      body: CustomScrollView(
        slivers: [
          // Havalı ve genişleyen üst bar
          SliverAppBar.large(
            title: const Text(
              "Sağlık Personeli Paneli", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF263238))
            ),
            surfaceTintColor: Colors.transparent,
            backgroundColor: const Color(0xFFF8F9FA),
            actions: [
              IconButton(
                onPressed: () {
                  // Bildirimler veya profile git
                }, 
                icon: const Icon(Icons.notifications_active_rounded, color: Color(0xFF263238))
              ),
              IconButton(
                onPressed: () {
                  // Profil ayarlarına git
                }, 
                icon: const Icon(Icons.account_circle_rounded, color: Color(0xFF263238))
              ),
            ],
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text(
                  "Kurum Özeti", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238))
                ),
                const SizedBox(height: 15),
                
                // İstatistik Kartları
                Row(
                  children: [
                    _buildModernStatCard("Aktif Talepler", "12", Icons.bloodtype_rounded, Colors.red.shade400),
                    const SizedBox(width: 15),
                    _buildModernStatCard("Gelen Bağış", "34", Icons.volunteer_activism_rounded, Colors.green.shade400),
                  ],
                ),
                
                const SizedBox(height: 35),
                const Text(
                  "Operasyonel İşlemler", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238))
                ),
                const SizedBox(height: 15),
                
                // Menü Kartları
                _buildActionCard(
                  context,
                  title: "Kan Talebi Oluştur", 
                  sub: "Kurumun ihtiyaç duyduğu kan grubu ve ünite miktarını sisteme gir.", 
                  icon: Icons.add_circle_outline_rounded, 
                  color: Colors.red.shade400,
                  onTap: () {
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const BloodRequestScreen()));
                    debugPrint("Kan Talebi Oluştur tıklandı");
                  },
                ),
                _buildActionCard(
                  context,
                  title: "Akıllı Donör Eşleştirme (ML)", 
                  sub: "Makine öğrenmesi ile en uygun donörleri listele ve önceliklendir.", 
                  icon: Icons.psychology_rounded, 
                  color: Colors.indigo.shade400,
                  onTap: () {
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const MlDonorMatchScreen()));
                    debugPrint("ML Eşleştirme tıklandı");
                  },
                ),
                _buildActionCard(
                  context,
                  title: "Acil Durum Modu", 
                  sub: "Acil kan ihtiyacı için yakın çevredeki donörlere anlık bildirim (FCM/SMS) gönder.", 
                  icon: Icons.campaign_rounded, 
                  color: Colors.orange.shade600,
                  onTap: () {
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyBroadcastScreen()));
                    debugPrint("Acil Durum Modu tıklandı");
                  },
                ),
                _buildActionCard(
                  context,
                  title: "Bağışçı Randevuları", 
                  sub: "Bugün kurumunuza gelecek olan bağışçıları ve durumlarını görüntüle.", 
                  icon: Icons.calendar_month_rounded, 
                  color: Colors.blue.shade400,
                  onTap: () {
                    debugPrint("Randevular tıklandı");
                  },
                ),
                const SizedBox(height: 50),
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

  // --- MODERN AKSİYON KARTI ---
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
        border: Border.all(color: Colors.white),
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