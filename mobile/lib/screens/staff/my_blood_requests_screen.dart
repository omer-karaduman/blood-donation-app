// mobile/lib/screens/staff/my_blood_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../constants/api_constants.dart';
import 'blood_request_detail_screen.dart'; // 🚀 Detay ekranı importu

class MyBloodRequestsScreen extends StatefulWidget {
  final String staffUserId; 

  const MyBloodRequestsScreen({super.key, required this.staffUserId});

  @override
  State<MyBloodRequestsScreen> createState() => _MyBloodRequestsScreenState();
}

class _MyBloodRequestsScreenState extends State<MyBloodRequestsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMyRequests();
  }

  Future<void> _fetchMyRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/staff/my-requests?personel_id=${widget.staffUserId}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _requests = jsonDecode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Talepler yüklenemedi. (Hata: ${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Sunucuya bağlanılamadı. Lütfen bağlantınızı kontrol edin.";
        _isLoading = false;
      });
    }
  }

  String _formatDate(String isoDate) {
    try {
      DateTime date = DateTime.parse("${isoDate}Z").toLocal();
      return DateFormat('dd.MM.yyyy - HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  // 🚀 KALAN SÜRE HESAPLAYICI
  Widget _buildRemainingTime(Map<String, dynamic> request) {
    if (request['durum'] == 'IPTAL' || request['durum'] == 'SURESI_DOLDU') {
      return _buildTimeBadge("Süresi Doldu", Colors.red.shade700, Icons.timer_off_outlined);
    }

    try {
      DateTime createdAt = DateTime.parse("${request['olusturma_tarihi']}Z").toLocal();
      // Backend'den süre gelmezse varsayılan 24 saat alıyoruz
      int durationHours = request['gecerlilik_suresi_saat'] ?? 24; 
      DateTime expiresAt = createdAt.add(Duration(hours: durationHours));
      
      Duration remaining = expiresAt.difference(DateTime.now());

      if (remaining.isNegative) {
        return _buildTimeBadge("Süresi Doldu", Colors.red.shade700, Icons.timer_off_outlined);
      }

      int hours = remaining.inHours;
      int minutes = remaining.inMinutes.remainder(60);

      return _buildTimeBadge("Kalan Süre: ${hours}s ${minutes}dk", Colors.orange.shade800, Icons.timer_outlined);
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildTimeBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text(
          "Açtığım Talepler",
          style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF263238)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMyRequests,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchMyRequests,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
                child: const Text("Tekrar Dene", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "Henüz bir kan talebi oluşturmadınız.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyRequests,
      color: const Color(0xFF1565C0),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];
          final List dynamicResponses = request['donor_yanitlari'] ?? [];
          final int notifiedCount = dynamicResponses.length; // 🚀 ML'in bulduğu kişi sayısı
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: Material( // 🚀 InkWell efekti için Material eklendi
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  // 🚀 Detay sayfasına git, geri dönünce listeyi yenile (İptal etmiş olabilir)
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BloodRequestDetailScreen(
                        requestData: request, 
                        staffUserId: widget.staffUserId
                      ),
                    ),
                  );
                  _fetchMyRequests(); // Döndüğünde listeyi güncelle
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. SATIR: Kan Grubu ve Kalan Süre Rozeti
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: Text(
                              "${request['istenen_kan_grubu']} Kan Aranıyor", 
                              style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 12)
                            ),
                          ),
                          _buildRemainingTime(request), // 🚀 KALAN SÜRE BURADA GÖSTERİLİYOR
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // 2. SATIR: Temel Bilgiler (Miktar ve Oluşturma Tarihi)
                      Row(
                        children: [
                          _buildInfoColumn("Miktar", "${request['unite_sayisi']} Ünite"),
                          const SizedBox(width: 30),
                          _buildInfoColumn("Oluşturulma", _formatDate(request['olusturma_tarihi'])),
                        ],
                      ),
                      
                      // 3. SATIR: ML ÖZET BİLGİSİ (Yapay Zeka hissi veren ikon değiştirildi)
                      if (notifiedCount > 0) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD), // Çok hafif, profesyonel bir mavi arka plan
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBDEFB)) // Kenarlık
                          ),
                          child: Row(
                            children: [
                              // 🚀 Tarama/Eşleştirme İkonu
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.person_search_rounded, color: Colors.blue.shade800, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(color: Colors.blue.shade900, fontSize: 13, height: 1.4),
                                    children: [
                                      const TextSpan(text: "Akıllı eşleştirme algoritması "),
                                      TextSpan(text: "$notifiedCount donör", style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const TextSpan(text: " tespit etti ve acil bildirim gönderdi."),
                                    ]
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (request['durum'] == 'Aktif' || request['durum'] == 'AKTIF') ...[
                        // Eğer aktif ama hiç donör bulunamadıysa uyarı göster
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1),
                        ),
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 18),
                            const SizedBox(width: 8),
                            const Text("Bölgede uygun donör bulunamadı.", style: TextStyle(color: Colors.orange, fontSize: 12)),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
      ],
    );
  }
}