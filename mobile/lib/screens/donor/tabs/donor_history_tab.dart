import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants/api_constants.dart';

class DonorHistoryTab extends StatefulWidget {
  final dynamic currentUser;
  const DonorHistoryTab({super.key, required this.currentUser});

  @override
  State<DonorHistoryTab> createState() => _DonorHistoryTabState();
}

class _DonorHistoryTabState extends State<DonorHistoryTab> {
  bool _isLoading = true;
  List<dynamic> _historyData = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // 📡 GEÇMİŞ BAĞIŞLARI ÇEK
  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final url = ApiConstants.donorHistoryEndpoint(widget.currentUser.userId);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          _historyData = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      } else {
        debugPrint("Hata: Backend ${response.statusCode} döndürdü.");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Bağış geçmişi çekilemedi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🎨 DURUMA GÖRE RENK VE İKON BELİRLEYİCİ
  Map<String, dynamic> _getStatusConfig(String? status) {
    // Backend 'Basarili' veya 'Reddedildi' gönderiyor
    String s = (status ?? '').toLowerCase();
    
    if (s == 'basarili' || s == 'success' || s == 'basarılı') {
      return {"color": Colors.green, "icon": Icons.check_circle_outline, "label": "Başarılı"};
    } else if (s == 'reddedildi' || s == 'red' || s == 'failed') {
      return {"color": Colors.red, "icon": Icons.cancel_outlined, "label": "Reddedildi"};
    } else {
      return {"color": Colors.orange, "icon": Icons.hourglass_empty, "label": "Beklemede"};
    }
  }

  // 🕒 TARİH FORMATLAYICI
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Tarih Belirtilmemiş";
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
    } catch (e) {
      return dateStr;
    }
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
                    onRefresh: _fetchHistory,
                    child: _historyData.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            itemCount: _historyData.length,
                            itemBuilder: (context, index) {
                              final item = _historyData[index];
                              return _buildHistoryCard(item);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

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
            "Bağış Geçmişim",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            "Geçmişte yaptığınız kan bağışları ve durumları",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // 🏥 BAĞIŞ KARTI TASARIMI (GÜNCELLENDİ)
  Widget _buildHistoryCard(Map<String, dynamic> item) {
    // 🚀 DÜZELTME: Backend'deki 'institution' objesi içinden 'kurum_adi' çekiliyor
    final hospitalName = item['institution']?['kurum_adi'] ?? "Bilinmeyen Hastane";
    
    // 🚀 DÜZELTME: Backend 'bagis_tarihi' anahtarını kullanıyor
    final rawDate = item['bagis_tarihi'];
    
    // 🚀 DÜZELTME: Backend 'islem_sonucu' anahtarını kullanıyor
    final rawStatus = item['islem_sonucu'];

    final statusConfig = _getStatusConfig(rawStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_hospital, color: Color(0xFFE53935), size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospitalName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(rawDate),
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusConfig['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusConfig['icon'], size: 16, color: statusConfig['color']),
                      const SizedBox(width: 6),
                      Text(
                        statusConfig['label'],
                        style: TextStyle(color: statusConfig['color'], fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Text("1 Ünite", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              "Henüz Bir Bağışınız Bulunmuyor",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Kan bağışı yaparak hayat kurtarabilir ve bağış geçmişinizi buradan takip edebilirsiniz.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}