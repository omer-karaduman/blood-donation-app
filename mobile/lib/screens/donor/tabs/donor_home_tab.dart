// mobile/lib/screens/donor/tabs/donor_home_tab.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../constants/api_constants.dart';
import '../../../models/donor.dart';
import '../../login_screen.dart';

class DonorHomeTab extends StatefulWidget {
  final Donor currentUser; 
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
  bool _kanVerebilirMi = true;
  
  int _toplamPuan = 0;
  int _seviye = 1;
  int _aktifTalepSayisi = 0;

  Map<String, dynamic>? _activeAcceptedRequest;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) _fetchDashboardData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // 🚀 KESİN ÇÖZÜM: Sihirli Uyanma Metodu (didUpdateWidget)
  // Siz alt menüde (BottomNavigationBar) herhangi bir sekmeye tıkladığınızda bu metot tetiklenir.
  // Biz de bunu "Kullanıcı Ana Sayfaya Döndü" sinyali olarak algılayıp anında veriyi çekiyoruz!
  @override
  void didUpdateWidget(covariant DonorHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchDashboardData(isSilent: true); // 0.2 saniye içinde güncel görevi ekrana getirir
  }

  // --- API İŞLEMLERİ ---

  Future<void> _fetchDashboardData({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) setState(() => _isLoading = true);
    
    try {
      final String userId = widget.currentUser.userId;

      final profileRes = await http.get(Uri.parse(ApiConstants.donorProfileEndpoint(userId)));
      final gamificationRes = await http.get(Uri.parse(ApiConstants.donorGamificationEndpoint(userId)));
      
      if (profileRes.statusCode == 200) {
        final pData = json.decode(utf8.decode(profileRes.bodyBytes));
        _userName = pData['ad_soyad'] ?? "Bağışçı";
        _kanVerebilirMi = pData['kan_verebilir_mi'] ?? true;
      }

      if (gamificationRes.statusCode == 200) {
        final gData = json.decode(utf8.decode(gamificationRes.bodyBytes));
        _toplamPuan = gData['toplam_puan'] ?? 0;
        _seviye = gData['seviye'] ?? 1;
      }

      final feedRes = await http.get(Uri.parse(ApiConstants.donorFeedEndpoint(userId)));
      if (feedRes.statusCode == 200) {
        final dynamic rawData = json.decode(utf8.decode(feedRes.bodyBytes));
        List<dynamic> feedList = rawData is List ? rawData : (rawData['items'] ?? []);
        
        final accepted = feedList.where((req) => (req['reaksiyon'] ?? req['kullanici_reaksiyonu']) == 'Kabul').toList();

        if (mounted) {
          setState(() {
            _activeAcceptedRequest = accepted.isNotEmpty ? Map<String, dynamic>.from(accepted.first) : null;
            _aktifTalepSayisi = feedList.where((req) => (req['reaksiyon'] ?? req['kullanici_reaksiyonu']) == 'Bekliyor').length;
          });
        }
      }
    } catch (e) {
      debugPrint("Dashboard hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelRequest(String logId) async {
    final backupRequest = _activeAcceptedRequest;
    
    setState(() {
      _activeAcceptedRequest = null; // İyimser arayüz (anında sil)
    });

    try {
      // Backend Enum uyumluluğu için "Red" gönderiliyor
      final url = "${ApiConstants.donorsEndpoint}/${widget.currentUser.userId}/respond/$logId?reaksiyon=Red";
      final response = await http.post(Uri.parse(url));
      
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Görev iptal edildi, kuruma bildirildi."),
              backgroundColor: Colors.blueGrey.shade800,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )
          );
        }
        _fetchDashboardData(isSilent: true);
      } else {
        setState(() {
          _activeAcceptedRequest = backupRequest;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("İptal Başarısız! Sunucu Hatası: ${response.statusCode}"),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            )
          );
        }
      }
    } catch (e) { 
      setState(() {
        _activeAcceptedRequest = backupRequest; 
      });
    }
  }

  String _getRemainingTimeText(Map<String, dynamic> request) {
    try {
      DateTime createdAt = DateTime.parse("${request['olusturma_tarihi']}Z").toLocal();
      DateTime expiresAt = createdAt.add(Duration(hours: request['gecerlilik_suresi_saat'] ?? 24));
      Duration diff = expiresAt.difference(DateTime.now());
      if (diff.isNegative) return "Süresi Doldu";
      return "${diff.inHours}sa ${diff.inMinutes.remainder(60)}dk";
    } catch (e) { return "--"; }
  }

  // --- TASARIM ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : RefreshIndicator(
              onRefresh: () => _fetchDashboardData(),
              color: const Color(0xFFE53935),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildHeader(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_activeAcceptedRequest != null) ...[
                            _buildActiveTaskCard(),
                            const SizedBox(height: 24),
                          ],
                          _buildEligibilityStatus(),
                          const SizedBox(height: 24),
                          _buildSectionTitle("Sosyal Etkiniz"),
                          const SizedBox(height: 12),
                          _buildImpactStats(),
                          const SizedBox(height: 24),
                          _buildSectionTitle("Hızlı İşlemler"),
                          const SizedBox(height: 12),
                          _buildQuickActions(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 80,
      pinned: true,
      backgroundColor: const Color(0xFFF8F9FA),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        centerTitle: false,
        title: Text(
          "Merhaba, ${_userName.split(' ').first}",
          style: const TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
    );
  }

  Widget _buildActiveTaskCard() {
    final req = _activeAcceptedRequest!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFE53935), size: 18),
                const SizedBox(width: 8),
                const Text("AKTİF BAĞIŞ GÖREVİ", style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['kurum_adi'] ?? "Hastane", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(req['ilce'] ?? "İzmir", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14)),
                      child: Text(req['istenen_kan_grubu'] ?? "AB+", style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("KALAN SÜRE", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFE53935)),
                            const SizedBox(width: 6),
                            Text(_getRemainingTimeText(req), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF263238))),
                          ],
                        ),
                      ],
                    ),
                    Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _showCancelConfirmDialog(req['log_id'].toString()),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Text("İptal Et", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmDialog(String logId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 40),
            ),
            const SizedBox(height: 20),
            const Text("Görevi İptal Et?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
            const SizedBox(height: 12),
            const Text(
              "Bu talebi iptal ettiğinizde hastane yeni bir donör aramak zorunda kalacak. Vazgeçmek istediğinize emin misiniz?",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Hayır, Geri Dön", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelRequest(logId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Evet, İptal Et", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEligibilityStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _kanVerebilirMi ? [const Color(0xFFE53935), const Color(0xFFC62828)] : [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: (_kanVerebilirMi ? const Color(0xFFE53935) : Colors.blueGrey).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(_kanVerebilirMi ? Icons.favorite : Icons.timer, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_kanVerebilirMi ? "Bağışa Uygunsunuz" : "Dinlenme Süreci", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  _kanVerebilirMi ? "Bugün bir hayat kurtarabilirsiniz." : "Vücudunuzun toparlanması gerekiyor.",
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          if (_aktifTalepSayisi > 0 && _activeAcceptedRequest == null)
            ElevatedButton(
              onPressed: () => widget.onTabChange(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE53935),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text("$_aktifTalepSayisi Talep", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildImpactStats() {
    return Row(
      children: [
        Expanded(child: _statCard("Toplam Puan", "$_toplamPuan", Icons.bolt_rounded, Colors.orange)),
        const SizedBox(width: 16),
        Expanded(child: _statCard("Bağışçı Seviyesi", "$_seviye", Icons.military_tech_rounded, Colors.blue)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _actionTile("Kan Talepleri", Icons.bloodtype_outlined, const Color(0xFFE53935), () => widget.onTabChange(1)),
        _actionTile("Geçmişim", Icons.history_rounded, Colors.teal, () => widget.onTabChange(2)),
        _actionTile("Ödüller", Icons.emoji_events_outlined, Colors.amber.shade700, () => widget.onTabChange(3)),
        _actionTile("Profil Ayarları", Icons.settings_outlined, Colors.blueGrey, () => widget.onTabChange(4)),
      ],
    );
  }

  Widget _actionTile(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.02)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF263238))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF263238)));
  }
}