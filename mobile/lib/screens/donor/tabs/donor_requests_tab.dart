// mobile/lib/screens/donor/tabs/donor_requests_tab.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants/api_constants.dart';

class DonorRequestsTab extends StatefulWidget {
  final dynamic currentUser;
  const DonorRequestsTab({super.key, required this.currentUser});

  @override
  State<DonorRequestsTab> createState() => _DonorRequestsTabState();
}

class _DonorRequestsTabState extends State<DonorRequestsTab> {
  bool _isLoading = true;
  List<dynamic> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  // 📡 KAN TALEPLERİNİ (FEED) ÇEK
  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final url = ApiConstants.donorFeedEndpoint(widget.currentUser.userId);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _requests = data is List ? data : (data['items'] ?? []);
        });
      } else {
        debugPrint("Hata: Backend ${response.statusCode} döndürdü.");
      }
    } catch (e) {
      debugPrint("❌ Talepler çekilemedi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🤝 TALEBE YANIT VER (Kabul veya Red)
  Future<void> _respondToRequest(String logId, String reaction) async {
    // Reaksiyonlar backend enum: 'Kabul', 'Red', 'Gormezden_Geldi' vs.
    try {
      // Yükleniyor dialogu göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
      );

      final url = "${ApiConstants.donorsEndpoint}/${widget.currentUser.userId}/respond/$logId?reaksiyon=$reaction";
      final response = await http.post(Uri.parse(url));

      Navigator.pop(context); // Dialogu kapat

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reaction == 'Kabul' ? "Talep kabul edildi! Hastaneye bekleniyorsunuz." : "Talep listeden kaldırıldı."),
            backgroundColor: reaction == 'Kabul' ? Colors.green : Colors.grey,
          ),
        );
        _fetchRequests(); // Listeyi yenile, kabul edilen gitsin
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bir hata oluştu. Tekrar deneyin.")));
      }
    } catch (e) {
      Navigator.pop(context); // Dialogu kapat
      debugPrint("❌ Yanıt verme hatası: $e");
    }
  }

  // ❓ KABUL ONAY PENCERESİ
  void _confirmAccept(String logId, String hastaneAdi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Talebi Kabul Et", style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
        content: Text("$hastaneAdi kurumundaki kan talebini kabul etmek istediğinize emin misiniz? Kabul ettikten sonra en kısa sürede kuruma gitmeniz beklenmektedir."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () {
              Navigator.pop(context);
              _respondToRequest(logId, "Kabul");
            },
            child: const Text("Kabul Ediyorum", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
                : RefreshIndicator(
                    color: const Color(0xFFE53935),
                    onRefresh: _fetchRequests,
                    child: _requests.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              return _buildRequestCard(_requests[index]);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // 🔴 ÜST BİLGİ ALANI
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 25, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFE53935), Color(0xFFB71C1C)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Aktif Kan Talepleri",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            "Sistem tarafından size özel atanmış, acil veya normal kan ihtiyaçları.",
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // 📭 BOŞ DURUM (Talep Yoksa)
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_outline, size: 70, color: Colors.green.shade400),
            ),
            const SizedBox(height: 25),
            const Text(
              "Harika! Her şey yolunda.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Şu an bulunduğunuz bölgede kan grubunuzla eşleşen acil bir talep bulunmuyor. İhtiyaç anında size bildirim göndereceğiz.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🏥 TEKİL KAN TALEBİ KARTI
  Widget _buildRequestCard(Map<String, dynamic> item) {
    // Güvenli veri çekimi
    final String logId = item['log_id']?.toString() ?? "";
    final String kurumAdi = item['kurum_adi'] ?? "Sağlık Kurumu";
    final String kanGrubu = item['istenen_kan_grubu'] ?? "?";
    final String ilce = item['ilce'] ?? "";
    final String mahalle = item['mahalle'] ?? "";
    final String aciliyet = item['aciliyet_durumu'] ?? "NORMAL";
    final String unite = item['unite_sayisi']?.toString() ?? "1";

    bool isUrgent = aciliyet.toUpperCase() == "ACIL" || aciliyet.toUpperCase() == "AFET";
    Color badgeColor = isUrgent ? const Color(0xFFE53935) : Colors.orange.shade700;
    IconData badgeIcon = isUrgent ? Icons.warning_amber_rounded : Icons.info_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // ÜST KISIM (Bilgiler)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hastane İkonu
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                  child: Icon(Icons.local_hospital, color: badgeColor, size: 28),
                ),
                const SizedBox(width: 15),
                // Hastane, Konum ve Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(kurumAdi, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, size: 12, color: badgeColor),
                                const SizedBox(width: 4),
                                Text(
                                  aciliyet.toUpperCase(),
                                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text("$ilce, $mahalle", style: const TextStyle(fontSize: 13, color: Colors.grey), overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text(kanGrubu, style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          const SizedBox(width: 10),
                          Text("İhtiyaç: $unite Ünite", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          
          // ALT KISIM (Aksiyon Butonları)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondToRequest(logId, "Red"), // Reddet aksiyonu
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Gizle / Uygun Değilim", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmAccept(logId, kurumAdi), // Kabul Et aksiyonu
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Kabul Et", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}