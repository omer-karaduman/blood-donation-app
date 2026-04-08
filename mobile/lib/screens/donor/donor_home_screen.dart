// mobile/lib/screens/donor/donor_home_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants/api_constants.dart'; 

class DonorHomeScreen extends StatefulWidget {
  final dynamic currentUser;

  const DonorHomeScreen({super.key, required this.currentUser});

  @override
  State<DonorHomeScreen> createState() => _DonorHomeScreenState();
}

class _DonorHomeScreenState extends State<DonorHomeScreen> {
  bool _isLoading = true;
  List<dynamic> _feedRequests = [];
  String _realFirstName = ""; // Sadece gerçek ismi tutacak

  @override
  void initState() {
    super.initState();
    _loadDataById();
  }

  // --- KESİN ÇÖZÜM: HER ŞEYİ ID ÜZERİNDEN YÜKLE ---
  Future<void> _loadDataById() async {
    if (widget.currentUser == null) return;
    
    // Kullanıcı ID'sini alıyoruz
    String userId = widget.currentUser.userId.toString();

    try {
      // 1. ADIM: ID ile Backend'e gidip ismi çekiyoruz
      final nameResponse = await http.get(Uri.parse('${ApiConstants.baseUrl}/users/$userId/profile'));
      
      if (nameResponse.statusCode == 200) {
        final userData = json.decode(utf8.decode(nameResponse.bodyBytes));
        String fullName = userData['ad_soyad'] ?? "";
        
        if (fullName.isNotEmpty) {
          // İsmin sadece ilk parçasını al (İsmail Erkan -> İsmail)
          String first = fullName.trim().split(' ').first;
          _realFirstName = first[0].toUpperCase() + first.substring(1).toLowerCase();
        }
      }

      // 2. ADIM: Donör akışını (talepleri) çekiyoruz
      final feedResponse = await http.get(Uri.parse('${ApiConstants.baseUrl}/donors/$userId/feed'));
      
      if (feedResponse.statusCode == 200) {
        _feedRequests = json.decode(utf8.decode(feedResponse.bodyBytes));
      }

    } catch (e) {
      debugPrint("ID ile veri çekilirken hata: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _respondToRequest(String talepId, bool isGoing) {
    setState(() {
      _feedRequests.removeWhere((req) => req['talep_id'] == talepId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isGoing ? "Hastaneye yönlendiriliyorsunuz." : "Bilgi verildi."), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 90,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _realFirstName.isEmpty ? "Merhaba," : "Merhaba, $_realFirstName 👋", 
              style: const TextStyle(color: Colors.blueGrey, fontSize: 16, fontWeight: FontWeight.w600)
            ),
            const SizedBox(height: 4),
            const Text("Bugün Bir Hayat Kurtar!", style: TextStyle(color: Color(0xFF263238), fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFE53935), size: 32),
              onPressed: () {},
            ),
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
        : RefreshIndicator(
            onRefresh: _loadDataById,
            child: _feedRequests.isEmpty 
              ? _buildEmptyState() 
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _feedRequests.length,
                  itemBuilder: (context, index) => _buildRequestCard(_feedRequests[index]),
                ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Icon(Icons.favorite_border_rounded, size: 80, color: Colors.grey),
        const SizedBox(height: 20),
        const Center(child: Text("Şu an acil bir kan ihtiyacı yok.", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    bool isUrgent = req['aciliyet_durumu'] == 'Acil';
    
    // YENİ: İlçe ve Mahalle verisini dinamik olarak birleştiriyoruz
    String ilce = req['ilce'] ?? "İzmir";
    String mahalle = req['mahalle'] ?? "";
    String locationText = mahalle.isNotEmpty ? "$ilce / $mahalle" : ilce;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  height: 60, width: 60,
                  decoration: BoxDecoration(color: isUrgent ? Colors.red.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(16)),
                  child: Center(child: Text(req['istenen_kan_grubu'] ?? "?", style: TextStyle(color: isUrgent ? Colors.red : Colors.orange.shade900, fontSize: 20, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(req['kurum_adi'] ?? "Hastane", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238))),
                  // YENİ: Artık locationText kullanıyoruz (İlçe / Mahalle)
                  Text("$locationText • ${req['unite_sayisi']} Ünite İhtiyaç", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ])),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _respondToRequest(req['talep_id'], false), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Uygun Değilim"))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => _respondToRequest(req['talep_id'], true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Gidebilirim", style: TextStyle(color: Colors.white)))),
              ],
            ),
          )
        ],
      ),
    );
  }
}