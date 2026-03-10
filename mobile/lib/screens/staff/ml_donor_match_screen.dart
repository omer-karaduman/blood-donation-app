import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/api_constants.dart';

class MlDonorMatchScreen extends StatefulWidget {
  const MlDonorMatchScreen({super.key});

  @override
  State<MlDonorMatchScreen> createState() => _MlDonorMatchScreenState();
}

class _MlDonorMatchScreenState extends State<MlDonorMatchScreen> {
  bool isLoading = false;
  List<dynamic> matchedDonors = [];
  String selectedBloodType = 'A+'; // Varsayılan kan grubu
  
  final List<String> bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  // Gerçek Veritabanından ML Eşleştirmesi Çeken Fonksiyon
  Future<void> fetchRealMatches() async {
    setState(() {
      isLoading = true;
      matchedDonors = [];
    });

    try {
      // Backend'e sadece istenilen kan grubunu gönderiyoruz
      final url = Uri.parse('${ApiConstants.smartMatchEndpoint}?kan_grubu=${Uri.encodeComponent(selectedBloodType)}');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          matchedDonors = data['matches'] ?? [];
        });
      } else {
        debugPrint("API Hatası: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Bağlantı Hatası: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Acil Kan Talebi (ML)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filtreleme ve Arama Kartı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("İhtiyaç Duyulan Kan Grubu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedBloodType,
                    icon: const Icon(Icons.bloodtype, color: Colors.red),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.red.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: bloodTypes.map((type) => DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))).toList(),
                    onChanged: (val) => setState(() => selectedBloodType = val!),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : fetchRealMatches,
                      icon: isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.psychology_alt),
                      label: Text(isLoading ? "Yapay Zekâ Analiz Ediyor..." : "Uygun Donörleri Eşleştir"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Sonuç Listesi Başlığı
            if (matchedDonors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Yapay Zekâ Tarafından Sıralandı (${matchedDonors.length} Kişi)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                ),
              ),

            // Sonuç Listesi
            Expanded(
              child: matchedDonors.isEmpty && !isLoading
                  ? Center(child: Text("Tarama başlatmak için yukarıdan seçim yapın.", style: TextStyle(color: Colors.grey.shade600)))
                  : ListView.builder(
                      itemCount: matchedDonors.length,
                      itemBuilder: (context, index) {
                        final donor = matchedDonors[index];
                        final score = donor['match_score'];
                        
                        // Skora göre renk ve etiket belirleme
                        Color scoreColor = Colors.red;
                        String label = "Düşük İhtimal";
                        if (score > 70) { scoreColor = Colors.green; label = "Yüksek İhtimal"; }
                        else if (score > 40) { scoreColor = Colors.orange; label = "Orta İhtimal"; }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.shade100,
                              child: Text(donor['kan_grubu'], style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(donor['ad_soyad'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(donor['telefon']),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "%${score.toStringAsFixed(1)}", 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: scoreColor)
                                ),
                                Text(label, style: TextStyle(fontSize: 10, color: scoreColor, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}