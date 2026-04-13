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
  String _userName = "Bagisci";
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
      if (mounted) {
        _fetchDashboardData(isSilent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // --- VERİ ÇEKME ---

  Future<void> _fetchDashboardData({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) setState(() => _isLoading = true);
    
    try {
      final String userId = widget.currentUser.userId;

      final profileRes = await http.get(Uri.parse(ApiConstants.donorProfileEndpoint(userId)));
      if (profileRes.statusCode == 200) {
        final pData = json.decode(utf8.decode(profileRes.bodyBytes));
        _userName = pData['ad_soyad'] ?? "Bagisci";
        _kanVerebilirMi = pData['kan_verebilir_mi'] ?? true;
      }

      final gamificationRes = await http.get(Uri.parse(ApiConstants.donorGamificationEndpoint(userId)));
      if (gamificationRes.statusCode == 200) {
        final gData = json.decode(utf8.decode(gamificationRes.bodyBytes));
        _toplamPuan = gData['toplam_puan'] ?? 0;
        _seviye = gData['seviye'] ?? 1;
      }

      final feedRes = await http.get(Uri.parse(ApiConstants.donorFeedEndpoint(userId)));
      if (feedRes.statusCode == 200) {
        final dynamic rawData = json.decode(utf8.decode(feedRes.bodyBytes));
        
        List<dynamic> feedList = [];
        if (rawData is List) {
          feedList = rawData;
        } else if (rawData is Map && rawData['items'] != null) {
          feedList = rawData['items'];
        }
        
        final accepted = feedList.where((req) {
          final reaksiyon = req['reaksiyon'] ?? req['kullanici_reaksiyonu'];
          return reaksiyon == 'Kabul';
        }).toList();

        if (mounted) {
          setState(() {
            if (accepted.isNotEmpty) {
              _activeAcceptedRequest = Map<String, dynamic>.from(accepted.first);
            } else {
              _activeAcceptedRequest = null;
            }
            _aktifTalepSayisi = feedList.where((req) {
              final reaksiyon = req['reaksiyon'] ?? req['kullanici_reaksiyonu'];
              return reaksiyon == 'Bekliyor' || reaksiyon == null;
            }).length;
          });
        }
      }
    } catch (e) {
      debugPrint("Dashboard hatasi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelRequest(String logId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
      );

      final url = "${ApiConstants.donorsEndpoint}/${widget.currentUser.userId}/respond/$logId?reaksiyon=Red";
      final response = await http.post(Uri.parse(url));

      if (mounted) Navigator.pop(context); 

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gorev iptal edildi."), backgroundColor: Colors.black87),
        );
        _fetchDashboardData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  String _getRemainingTimeText(Map<String, dynamic> request) {
    try {
      if (request['olusturma_tarihi'] == null) return "Sure Bilgisi Yok";
      DateTime createdAt = DateTime.parse("${request['olusturma_tarihi']}Z").toLocal();
      int durationHours = request['gecerlilik_suresi_saat'] ?? 24; 
      DateTime expiresAt = createdAt.add(Duration(hours: durationHours));
      Duration remaining = expiresAt.difference(DateTime.now());
      if (remaining.isNegative) return "Suresi Doldu";
      return "${remaining.inHours}sa ${remaining.inMinutes.remainder(60)}dk kaldi";
    } catch (e) { return "Hesaplaniyor..."; }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('donor_home_main_view'), // Mouse Tracker hatasını önlemek için Key
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : RefreshIndicator(
              color: const Color(0xFFE53935),
              onRefresh: () => _fetchDashboardData(),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_activeAcceptedRequest != null) ...[
                            _buildActiveTaskCard(),
                            const SizedBox(height: 25),
                          ],
                          _buildEligibilityCard(),
                          const SizedBox(height: 20),
                          if (_aktifTalepSayisi > 0) ...[
                            InkWell(
                              onTap: () => widget.onTabChange(1),
                              borderRadius: BorderRadius.circular(16),
                              child: _buildSmartAlertBanner(),
                            ),
                            const SizedBox(height: 25),
                          ],
                          const Text("Sosyal Etkiniz", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => widget.onTabChange(3),
                            borderRadius: BorderRadius.circular(20),
                            child: _buildImpactCard(),
                          ),
                          const SizedBox(height: 25),
                          const Text("Hizli Erisim", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
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

  Widget _buildActiveTaskCard() {
    final req = _activeAcceptedRequest!;
    final String kurumAdi = req['kurum_adi']?.toString() ?? "Hastane";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFFE53935).withOpacity(0.1), blurRadius: 25, offset: const Offset(0, 10))],
        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.15), width: 2),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFE53935).withOpacity(0.08), shape: BoxShape.circle),
                  child: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFE53935), size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("MEVCUT GOREVINIZ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFE53935), letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text(kurumAdi, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded( // Layout taşmasını önlemek için Expanded eklendi
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_rounded, size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Text(_getRemainingTimeText(req), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blueGrey)),
                        ],
                      ),
                      const Text("Lutfen kuruma ulasin.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showCancelConfirmDialog(req['log_id'].toString()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueGrey.shade400,
                    elevation: 0,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Iptal", style: TextStyle(fontWeight: FontWeight.bold)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Gorevden Vazgec?"),
        content: const Text("Bu gorevi iptal ettiginizde hastane yeni donor aramaya baslayacaktir."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Geri Don", style: TextStyle(color: Colors.blueGrey))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _cancelRequest(logId); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Evet, Iptal Et", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 90.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFFF8F9FA),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          "Merhaba, ${_userName.split(' ').first}",
          style: const TextStyle(color: Color(0xFF263238), fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: const Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 18),
          ),
          onPressed: _handleLogout,
        ),
        const SizedBox(width: 15),
      ],
    );
  }

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
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: (_kanVerebilirMi ? const Color(0xFFE53935) : Colors.blueGrey).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_kanVerebilirMi ? Icons.favorite_rounded : Icons.timer_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(_kanVerebilirMi ? "Bagisa Uygunsunuz" : "Dinlenme Surecindesiniz", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _kanVerebilirMi 
              ? "Harika! Su an kan bagisi yaparak hayat kurtarabilirsiniz."
              : "Son bagisinizdan dolayi vucudunuzun toparlanmasi gerekiyor.",
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartAlertBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFE53935), size: 22)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Yeni Talepler", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFC62828))),
                Text("Size uygun $_aktifTalepSayisi talep var.", style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFC62828)),
        ],
      ),
    );
  }

  Widget _buildImpactCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildImpactStat(Icons.military_tech_rounded, "Seviye", "$_seviye", Colors.orange.shade700),
          Container(width: 1.5, height: 45, color: Colors.grey.shade100),
          _buildImpactStat(Icons.stars_rounded, "Puan", "$_toplamPuan", const Color(0xFF1565C0)),
        ],
      ),
    );
  }

  Widget _buildImpactStat(IconData icon, String label, String value, Color color) {
    return Column(children: [Icon(icon, color: color, size: 34), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF263238))), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600))]);
  }

  Widget _buildActionGrid() {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.4,
      children: [
        _buildActionTile(Icons.history_rounded, "Bagis Gecmisim", Colors.teal, onTap: () => widget.onTabChange(2)),
        _buildActionTile(Icons.psychology_alt_rounded, "Nasil Bagis Yaparim?", Colors.indigo, onTap: _showHowToDonateModal),
        _buildActionTile(Icons.bloodtype_rounded, "Kan Talepleri", const Color(0xFFE53935), onTap: () => widget.onTabChange(1)),
        _buildActionTile(Icons.emoji_events_rounded, "Rozetlerim", Colors.amber.shade800, onTap: () => widget.onTabChange(3)),
      ],
    );
  }

  Widget _buildActionTile(IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 30), const Spacer(), Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF263238), height: 1.2))]),
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Cikis Yapilsin mi?"),
        content: const Text("Oturumunuz kapatilacaktir."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgec", style: TextStyle(color: Colors.blueGrey))),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (r) => false),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Cikis Yap", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showHowToDonateModal() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
          const Padding(padding: EdgeInsets.all(25), child: Text("Surec Nasil Isler?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 25), children: [
            _stepItem(1, "Profilini Tamamla", "Saglik ve konum bilgilerini girin.", Icons.person_search_rounded),
            _stepItem(2, "Bildirimleri Takip Et", "Sana uygun bir talep oldugunda bildirilirsin.", Icons.add_alert_rounded),
            _stepItem(3, "Talebi Kabul Et", "Hastaneye giderek bagisini yap.", Icons.check_circle_rounded),
          ])),
          Padding(padding: const EdgeInsets.all(25), child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("ANLADIM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
        ]),
      ),
    );
  }

  Widget _stepItem(int no, String title, String desc, IconData icon) {
    return Padding(padding: const EdgeInsets.only(bottom: 25), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE53935).withOpacity(0.08), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: const Color(0xFFE53935), size: 26)),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("$no. $title", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text(desc, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4))]))
    ]));
  }
}