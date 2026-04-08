// lib/screens/donor/tabs/donor_history_tab.dart
import 'package:flutter/material.dart';

class DonorHistoryTab extends StatelessWidget {
  final dynamic currentUser;
  const DonorHistoryTab({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    // Örnek veri (Backend'deki DonationHistory tablosundan gelecek)
    final List<Map<String, dynamic>> mockHistory = [
      {"date": "12.02.2026", "hospital": "Ege Üniversitesi Hastanesi", "result": "Başarılı", "status": true},
      {"date": "05.11.2025", "hospital": "İzmir Şehir Hastanesi", "result": "Reddedildi (Düşük Hemoglobin)", "status": false},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Bağış Geçmişim"), centerTitle: true, elevation: 0),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: mockHistory.length,
        itemBuilder: (context, index) {
          final item = mockHistory[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Icon(item['status'] ? Icons.check_circle : Icons.cancel, color: item['status'] ? Colors.green : Colors.red),
              title: Text(item['hospital'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item['date']),
              trailing: Text(item['result'], style: TextStyle(color: item['status'] ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }
}