// mobile/lib/screens/donor/tabs/donor_home_tab.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants/api_constants.dart';
import '../../login_screen.dart';

class DonorHomeTab extends StatefulWidget {
  final dynamic currentUser;
  // 🚀 Yeni: Sekmeler arası geçiş için callback eklendi
  final Function(int) onTabChange;

  const DonorHomeTab({
    super.key, 
    required this.currentUser, 
    required this.onTabChange
  });

  @override
  State<DonorHomeTab> createState() => _DonorHomeTabState();
}

class _DonorHomeTabState extends State<DonorHomeTab> {
  bool _isLoading = true;
  String _userName = "Bağışçı";
  bool _kanVerebilirMi = true; // Profil verisinden gelecek
  
  int _toplamPuan = 0;
  int _seviye = 1;
  int _aktifTalepSayisi = 0; // Feed'den sadece sayısını alacağız

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // 📡 ANA SAYFA (DASHBOARD) VERİLERİNİ ÇEK
  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final String userId = widget.currentUser.userId;

      // 1. Profil Verisi (İsim ve Kan Verebilme Durumu)
      final profileRes = await http.get(Uri.parse(ApiConstants.donorProfileEndpoint(userId)));
      if (profileRes.statusCode == 200) {
        final pData = json.decode(utf8.decode(profileRes.bodyBytes));
        if (pData['ad_soyad'] != null) _userName = pData['ad_soyad'];
        if (pData['kan_verebilir_mi'] != null) _kanVerebilirMi = pData['kan_verebilir_mi'];
      }

      // 2. Oyunlaştırma (Puan ve Seviye)
      final gamificationRes = await http.get(Uri.parse(ApiConstants.donorGamificationEndpoint(userId)));
      if (gamificationRes.statusCode == 200) {
        final gData = json.decode(utf8.decode(gamificationRes.bodyBytes));
        _toplamPuan = gData['toplam_puan'] ?? 0;
        _seviye = gData['seviye'] ?? 1;
      }

      // 3. Akıllı Özet için Talep Sayısı
      final feedRes = await http.get(Uri.parse(ApiConstants.donorFeedEndpoint(userId)));
      if (feedRes.statusCode == 200) {
        final fData = json.decode(utf8.decode(feedRes.bodyBytes));
        final feedList = fData is List ? fData : (fData['items'] ?? []);
        _aktifTalepSayisi = feedList.length;
      }

    } catch (e) {
      debugPrint("❌ Dashboard verisi çekilemedi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🚪 ÇIKIŞ YAPMA İŞLEMİ (Yenilenmiş Modern Tasarım)
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔴 Üst İkon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Color(0xFFE53935), size: 36),
              ),
              const SizedBox(height: 20),
              
              // 📝 Başlık
              const Text(
                "Çıkış Yap",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              
              // 📄 Açıklama
              const Text(
                "Hesabınızdan çıkış yapmak istediğinize emin misiniz? Oturumunuz kapatılacaktır.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 30),
              
              // 🔘 Butonlar
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("İptal", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (Route<dynamic> route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFE53935),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text("Çıkış Yap", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📖 NASIL BAĞIŞ YAPARIM MODALI
  void _showHowToDonateModal() {
    final List<Map<String, dynamic>> steps = [
      {
        "title": "Profilini Tamamla",
        "desc": "Kan grubun, konumun ve sağlık bilgilerinle profilini güncel tut. Akıllı sistemimiz bu verilere göre sana ulaşır.",
        "icon": Icons.app_registration,
        "color": Colors.blue
      },
      {
        "title": "Akıllı Eşleşme (ML)",
        "desc": "Sistem, Makine Öğrenmesi kullanarak acil durumlarda sana en yakın ve en uygun donörü (seni!) belirler.",
        "icon": Icons.psychology,
        "color": Colors.purple
      },
      {
        "title": "Anlık Bildirim",
        "desc": "Sana uygun bir talep düştüğünde uygulama üzerinden anında bilgilendirilirsin.",
        "icon": Icons.bolt,
        "color": Colors.amber
      },
      {
        "title": "Hastanede Bağış",
        "desc": "Talebi kabul ettikten sonra ilgili hastaneye giderek bağışını yaparsın. Görevli işlemi onayladığında sürecin tamamlanır.",
        "icon": Icons.local_hospital,
        "color": const Color(0xFFE53935)
      },
      {
        "title": "Puan ve Rozet",
        "desc": "Her başarılı bağış sana puan ve seviye kazandırır. Topluluğun kahramanlarından biri ol!",
        "icon": Icons.emoji_events,
        "color": Colors.green
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text("Sistem Nasıl Çalışır?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: steps.length,
                itemBuilder: (context, index) {
                  final step = steps[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 25.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: step['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                          child: Icon(step['icon'], color: step['color'], size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${index + 1}. ${step['title']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(step['desc'], style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("ANLADIM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : RefreshIndicator(
              color: const Color(0xFFE53935),
              onRefresh: _fetchDashboardData,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEligibilityCard(),
                          const SizedBox(height: 20),
                          // 🚀 Akıllı Özet Banner'ına basınca Taleplere (1) git
                          InkWell(
                            onTap: () => widget.onTabChange(1),
                            borderRadius: BorderRadius.circular(16),
                            child: _buildSmartAlertBanner(),
                          ),
                          const SizedBox(height: 25),
                          const Text("Sosyal Etkiniz", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 12),
                          // 🚀 Etki kartına basınca Puanlara (3) git
                          InkWell(
                            onTap: () => widget.onTabChange(3),
                            borderRadius: BorderRadius.circular(20),
                            child: _buildImpactCard(),
                          ),
                          const SizedBox(height: 25),
                          const Text("Hızlı Erişim", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 12),
                          _buildActionGrid(),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // 🔴 ÜST BAR VE SELAMLAMA
  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 80.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFFF8F9FA),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          "Merhaba, ${_userName.split(' ').first} 👋",
          style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
            ]),
            child: const Icon(Icons.logout, color: Color(0xFFE53935), size: 20),
          ),
          onPressed: _handleLogout,
        ),
        const SizedBox(width: 15),
      ],
    );
  }

  // 🩸 BAĞIŞ UYGUNLUK KARTI
  Widget _buildEligibilityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _kanVerebilirMi 
            ? [const Color(0xFFE53935), const Color(0xFFB71C1C)] 
            : [Colors.blueGrey.shade600, Colors.blueGrey.shade800], 
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (_kanVerebilirMi ? const Color(0xFFE53935) : Colors.blueGrey).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_kanVerebilirMi ? Icons.favorite : Icons.timer, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Text(
                _kanVerebilirMi ? "Bağışa Uygunsunuz" : "Dinlenme Sürecindesiniz",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _kanVerebilirMi 
              ? "Şu an kan bağışı yaparak sisteme düşen taleplere yanıt verebilir ve hayat kurtarabilirsiniz."
              : "Son bağışınızdan dolayı bekleme süresindesiniz. Vücudunuzun toparlanması için zaman tanıyın.",
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // 🔔 AKILLI ÖZET BİLDİRİMİ
  Widget _buildSmartAlertBanner() {
    if (_aktifTalepSayisi == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.notifications_active, color: Color(0xFFE53935), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Yeni Bildirimler", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE53935))),
                const SizedBox(height: 2),
                Text("Bölgenizde size uygun $_aktifTalepSayisi acil kan talebi var.", style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  // 🏆 OYUNLAŞTIRMA & ETKİ KARTI
  Widget _buildImpactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildImpactStat(Icons.military_tech, "Seviye", "$_seviye", Colors.orange),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _buildImpactStat(Icons.stars, "Toplam Puan", "$_toplamPuan", Colors.blue),
        ],
      ),
    );
  }

  Widget _buildImpactStat(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // 📱 HIZLI ERİŞİM MENÜSÜ (Grid)
  Widget _buildActionGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: [
        // 🚀 Bağış Geçmişim -> Index 2
        _buildActionTile(Icons.history, "Bağış\nGeçmişim", Colors.teal, onTap: () => widget.onTabChange(2)),
        // Modal açılışı
        _buildActionTile(Icons.info_outline, "Nasıl Bağış\nYaparım?", Colors.indigo, onTap: _showHowToDonateModal),
        // 🚀 Kan Talepleri -> Index 1
        _buildActionTile(Icons.bloodtype, "Kan\nTalepleri", const Color(0xFFE53935), onTap: () => widget.onTabChange(1)),
        // 🚀 Rozetlerim -> Index 3
        _buildActionTile(Icons.emoji_events, "Rozetlerim", Colors.amber.shade700, onTap: () => widget.onTabChange(3)),
      ],
    );
  }

  Widget _buildActionTile(IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.2)),
          ],
        ),
      ),
    );
  }
}