// lib/screens/donor/tabs/donor_gamification_tab.dart
import 'package:flutter/material.dart';

class DonorGamificationTab extends StatelessWidget {
  final dynamic currentUser;
  const DonorGamificationTab({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDECEA).withOpacity(0.3),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFE53935),
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  const Text("Toplam Puan", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const Text("1250 XP", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: const Text("Seviye 4: Kahraman Bağışçı", style: TextStyle(color: Colors.white))),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1),
              delegate: SliverChildListDelegate([
                _badgeCard("İlk Bağış", Icons.favorite, Colors.pink),
                _badgeCard("Düzenli Bağışçı", Icons.calendar_month, Colors.orange),
                _badgeCard("Hızlı Yanıt", Icons.bolt, Colors.blue),
                _badgeCard("Hayat Kurtarıcı", Icons.verified_user, Colors.green),
              ]),
            ),
          )
        ],
      ),
    );
  }

  Widget _badgeCard(String title, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 30, child: Icon(icon, color: color, size: 30)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}