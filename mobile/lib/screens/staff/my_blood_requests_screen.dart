import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants/api_constants.dart';

class MyBloodRequestsScreen extends StatefulWidget {
  const MyBloodRequestsScreen({super.key});

  @override
  State<MyBloodRequestsScreen> createState() => _MyBloodRequestsScreenState();
}

class _MyBloodRequestsScreenState extends State<MyBloodRequestsScreen> {
  final String staffUserId = "550e8400-e29b-41d4-a716-446655440000"; // Örnek
  List<dynamic> myRequests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMyRequests();
  }

  Future<void> fetchMyRequests() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.myRequestsEndpoint}?personel_id=$staffUserId')
      );
      
      if (response.statusCode == 200) {
        setState(() {
          myRequests = json.decode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() { isLoading = false; });
      debugPrint("Hata: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text("Açtığım Talepler", style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myRequests.length,
            itemBuilder: (context, index) {
              final req = myRequests[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFD32F2F).withOpacity(0.1),
                    child: Text(req['istenen_kan_grubu'], style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                  ),
                  title: Text("${req['unite_sayisi']} Ünite Talep Edildi"),
                  subtitle: Text("Durum: ${req['durum']}"),
                  children: [
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text("Donör Reaksiyonları", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    ...(req['donor_yanitlari'] as List).map((yanit) => ListTile(
                      dense: true,
                      title: Text(yanit['donor_ad_soyad']),
                      trailing: _buildReactionBadge(yanit['reaksiyon']),
                    )).toList(),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildReactionBadge(String reaction) {
    Color color = Colors.grey;
    String text = "Bekleniyor";

    if (reaction == "Kabul") { color = Colors.green; text = "Geliyor"; }
    else if (reaction == "Red") { color = Colors.red; text = "Reddetti"; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}