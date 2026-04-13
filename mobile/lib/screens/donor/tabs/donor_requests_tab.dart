// mobile/lib/screens/donor/tabs/donor_requests_tab.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; 
import '../../../constants/api_constants.dart';

class DonorRequestsTab extends StatefulWidget {
  final dynamic currentUser;

  const DonorRequestsTab({super.key, required this.currentUser});

  @override
  State<DonorRequestsTab> createState() => _DonorRequestsTabState();
}

class _DonorRequestsTabState extends State<DonorRequestsTab> {
  // --- DURUM DEĞİŞKENLERİ ---
  bool _isLoading = true;
  List<dynamic> _requests = [];
  
  // Sayaç ve Otomatik Yenileme İçin Timer'lar
  Timer? _cooldownTimer;      // Kan verme bekleme süresi sayacı
  Timer? _autoRefreshTimer;   // Periyodik liste güncelleme sayacı
  Duration _timeLeft = Duration.zero;
  bool _isCooldown = false;

  // --- YAŞAM DÖNGÜSÜ (LIFECYCLE) ---

  @override
  void initState() {
    super.initState();
    // 1. Önce donörün kan verebilirliğini (90/120 gün) kontrol et
    _checkCooldown(); 
    
    // 2. 🚀 SİSTEM SENKRONİZASYONU:
    // Personel bir talebi iptal ederse veya süresi dolarsa donörün listesinden düşmesi için
    // her 30 saniyede bir listeyi "sessizce" (loading göstermeden) arka planda yeniler.
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isCooldown && !_isLoading) {
        _fetchRequests(isSilent: true); 
      }
    });
  }

  @override
  void dispose() {
    // Bellek sızıntısını önlemek için tüm sayaçları durdur
    _cooldownTimer?.cancel();
    _autoRefreshTimer?.cancel(); 
    super.dispose();
  }

  // --- MANTIKSAL FONKSİYONLAR ---

  // Kan verme süresini kontrol eder (Son bağış tarihine göre)
  void _checkCooldown() {
    if (widget.currentUser.sonBagisTarihi != null) {
      // Erkeklerde 90, Kadınlarda 120 gün kuralı
      int waitDays = widget.currentUser.cinsiyet == 'K' ? 120 : 90;
      final nextDate = widget.currentUser.sonBagisTarihi!.add(Duration(days: waitDays));
      final now = DateTime.now();

      if (now.isBefore(nextDate)) {
        setState(() {
          _isCooldown = true;
          _isLoading = false;
        });
        _startCooldownTimer(nextDate);
        return; 
      }
    }
    _fetchRequests();
  }

  // Geri sayım sayacını başlatır
  void _startCooldownTimer(DateTime target) {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = target.difference(DateTime.now());
      if (diff.isNegative) {
        if (mounted) {
          setState(() => _isCooldown = false);
          _cooldownTimer?.cancel();
          _fetchRequests(); 
        }
      } else {
        if (mounted) setState(() => _timeLeft = diff);
      }
    });
  }

  // Backend'den kan taleplerini (feed) çeker
  Future<void> _fetchRequests({bool isSilent = false}) async {
    if (!isSilent && mounted) setState(() => _isLoading = true);
    
    try {
      final url = ApiConstants.donorFeedEndpoint(widget.currentUser.id); 
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _requests = data is List ? data : (data['items'] ?? []);
            _isLoading = false;
          });
        }
      } else {
        debugPrint("Hata: Backend ${response.statusCode} döndürdü.");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Talepler çekilemedi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Talebe yanıt verir (Kabul/Red)
  Future<void> _respondToRequest(String logId, String reaction) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
      );

      final url = "${ApiConstants.donorsEndpoint}/${widget.currentUser.id}/respond/$logId?reaksiyon=$reaction";
      final response = await http.post(Uri.parse(url));

      if (mounted) Navigator.pop(context); // Dialogu kapat

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reaction == 'Kabul' ? "Talep kabul edildi! Hastaneye bekleniyorsunuz." : "Talep listeden kaldırıldı."),
              backgroundColor: reaction == 'Kabul' ? Colors.green : Colors.grey,
            ),
          );
          _fetchRequests(); 
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bir hata oluştu.")));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      debugPrint("❌ Yanıt verme hatası: $e");
    }
  }

  // Kabul onay penceresi
  void _confirmAccept(String logId, String hastaneAdi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.volunteer_activism, color: Color(0xFFE53935)),
            SizedBox(width: 12),
            Text("Talebi Kabul Et", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "$hastaneAdi kurumundaki kan talebini kabul etmek istediğinize emin misiniz? Kabul ettikten sonra kuruma gitmeniz hayati önem taşımaktadır.",
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _respondToRequest(logId, "Kabul");
            },
            child: const Text("Kabul Ediyorum", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- ARA YÜZ (UI) BİLEŞENLERİ ---

  @override
  Widget build(BuildContext context) {
    if (_isCooldown) return _buildTimerUI();

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
                    onRefresh: () => _fetchRequests(),
                    child: _requests.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // Üst Başlık Paneli
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 25, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Aktif Kan Talepleri",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            "Size özel atanmış acil veya normal kan ihtiyaçları.",
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // Boş Liste Durumu
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_outline_rounded, size: 70, color: Colors.green.shade400),
            ),
            const SizedBox(height: 24),
            const Text(
              "Harika! Her şey yolunda.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                "Şu an bölgenizde uygun bir kan talebi bulunmuyor. Yeni bir ihtiyaç oluştuğunda size bildirim göndereceğiz.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Talep Kartı Tasarımı
  Widget _buildRequestCard(Map<String, dynamic> item) {
    final String logId = item['log_id']?.toString() ?? "";
    final String kurumAdi = item['kurum_adi'] ?? "Bilinmeyen Kurum";
    final String kanGrubu = item['istenen_kan_grubu'] ?? "?";
    final String aciliyet = item['aciliyet_durumu'] ?? "NORMAL";
    
    bool isUrgent = aciliyet.toUpperCase() == "ACIL" || aciliyet.toUpperCase() == "AFET";
    Color themeColor = isUrgent ? const Color(0xFFE53935) : Colors.orange.shade800;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.local_hospital_rounded, color: themeColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(kurumAdi, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                          ),
                          _buildUrgencyBadge(aciliyet, themeColor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text("${item['ilce']}, ${item['mahalle']}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _buildInfoTag(kanGrubu, const Color(0xFFE53935)),
                          const SizedBox(width: 10),
                          _buildInfoTag("${item['unite_sayisi']} Ünite", Colors.blueGrey),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondToRequest(logId, "Red"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("Gizle", style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmAccept(logId, kurumAdi),
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

  // Yardımcı Küçük Tasarım Parçaları
  Widget _buildUrgencyBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildInfoTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  // --- SAYAÇ EKRANI (COOLDOWN UI) ---

  Widget _buildTimerUI() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF0277BD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_rounded, size: 80, color: Colors.white70),
            const SizedBox(height: 24),
            const Text("Harika Bir İş Çıkardın!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Vücudunun yeni kan üretmesi için zamana ihtiyacı var. Kendi sağlığın için beklemen gerekiyor.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 48),
            _timerDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _timerDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _timeBox("${_timeLeft.inDays}", "GÜN"),
        _timeBox("${_timeLeft.inHours.remainder(24)}".padLeft(2, '0'), "SAAT"),
        _timeBox("${_timeLeft.inMinutes.remainder(60)}".padLeft(2, '0'), "DAKİKA"),
        _timeBox("${_timeLeft.inSeconds.remainder(60)}".padLeft(2, '0'), "SANİYE"),
      ],
    );
  }

  Widget _timeBox(String value, String label) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}