import 'package:flutter/material.dart';
import 'tabs/donor_home_tab.dart';
import 'tabs/donor_history_tab.dart';
import 'tabs/donor_gamification_tab.dart';
import 'tabs/donor_profile_tab.dart';

class DonorMainScreen extends StatefulWidget {
  final dynamic currentUser;
  const DonorMainScreen({super.key, required this.currentUser});

  @override
  State<DonorMainScreen> createState() => _DonorMainScreenState();
}

class _DonorMainScreenState extends State<DonorMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      DonorHomeTab(currentUser: widget.currentUser),
      DonorHistoryTab(currentUser: widget.currentUser),
      DonorGamificationTab(currentUser: widget.currentUser),
      DonorProfileTab(currentUser: widget.currentUser),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFFE53935), // Referans aldığın o güzel kırmızı
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Bağışlarım'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Puanlar'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}