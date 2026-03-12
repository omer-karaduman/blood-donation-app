// mobile/lib/screens/staff/my_blood_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../constants/api_constants.dart';

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
      DateTime date = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd.MM.yyyy - HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      Text(
                        request['durum'] ?? "Bilinmiyor", 
                        style: TextStyle(
                          color: request['durum'] == 'Aktif' ? Colors.green.shade700 : Colors.grey.shade600, 
                          fontWeight: FontWeight.bold, fontSize: 12
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  Row(
                    children: [
                      _buildInfoColumn("Miktar", "${request['unite_sayisi']} Ünite"),
                      const SizedBox(width: 20),
                      _buildInfoColumn("Tarih", _formatDate(request['olusturma_tarihi'])),
                    ],
                  ),
                  
                  if (dynamicResponses.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    const Text("Donör Yanıtları (ML Önerileri)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    ...dynamicResponses.map((r) {
                      // YENİ: Backend Enum değerlerine göre eşleştirme düzeltildi
                      bool isKabul = r['reaksiyon'] == 'Kabul';
                      bool isRed = r['reaksiyon'] == 'Red';
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              isKabul ? Icons.check_circle : (isRed ? Icons.cancel : Icons.access_time_filled),
                              size: 16, 
                              color: isKabul ? Colors.green : (isRed ? Colors.red : Colors.orange)
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(r['donor_ad_soyad'] ?? "Bilinmeyen Donör", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                            Text(
                              isKabul ? "Geliyor" : (isRed ? "Gelemiyor" : "Bekliyor"), 
                              style: const TextStyle(fontSize: 12, color: Colors.grey)
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
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
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
      ],
    );
  }
}