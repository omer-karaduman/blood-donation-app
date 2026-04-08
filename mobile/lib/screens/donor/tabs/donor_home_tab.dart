// lib/screens/donor/tabs/donor_home_tab.dart
import 'package:flutter/material.dart';

class DonorHomeTab extends StatelessWidget {
  final dynamic currentUser;
  const DonorHomeTab({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // --- ÜST PANEL (Görseldeki Tonlama) ---
          Container(
            padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 30),
            decoration: const BoxDecoration(
              color: Color(0xFFE53935), // Referans kırmızı
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Hoş geldin,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                        Text(currentUser.email.split('@')[0].toUpperCase(), // Profil adı
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 25),
                // Özet Kartı (Kan Grubu ve Durum)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statusInfo("Kan Grubu", "A+"), // Backend'den gelecek
                      const VerticalDivider(),
                      _statusInfo("Son Bağış", "2 Ay Önce"),
                      const VerticalDivider(),
                      _statusInfo("Puan", "1250"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // --- ALT KISIM: AKTİF TALEPLER ---
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, color: Color(0xFFE53935)),
                SizedBox(width: 10),
                Text("Acil Kan Çağrıları", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Buraya senin o şık kartların olduğu ListView.builder gelecek
        ],
      ),
    );
  }

  Widget _statusInfo(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(value, style: const TextStyle(color: Color(0xFFE53935), fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}