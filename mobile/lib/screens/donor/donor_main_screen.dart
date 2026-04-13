import 'package:flutter/material.dart';
import 'tabs/donor_home_tab.dart';
import 'tabs/donor_requests_tab.dart'; // YENİ EKLENDİ
import 'tabs/donor_history_tab.dart';
import 'tabs/donor_gamification_tab.dart';
import 'tabs/donor_profile_tab.dart';
import '../../models/donor.dart';

class DonorMainScreen extends StatefulWidget {
  final Donor currentUser;
  const DonorMainScreen({super.key, required this.currentUser});

  @override
  State<DonorMainScreen> createState() => _DonorMainScreenState();
}

class _DonorMainScreenState extends State<DonorMainScreen> {
  int _currentIndex = 0;

  // 🚀 EKLENDİ: Ana sayfadan (DonorHomeTab) tıklamalarla diğer sekmelere geçiş yapabilmek için
  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sekmelerin (Tab'lerin) listesi
    final List<Widget> tabs = [
      DonorHomeTab(
        currentUser: widget.currentUser,
        onTabChange: _changeTab, // 🚀 EKLENDİ: Zorunlu olan yönlendirme parametresi
      ),
      DonorRequestsTab(currentUser: widget.currentUser), // YENİ EKLENDİ
      DonorHistoryTab(currentUser: widget.currentUser),
      DonorGamificationTab(currentUser: widget.currentUser),
      DonorProfileTab(currentUser: widget.currentUser),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _changeTab, // 🚀 GÜNCELLENDİ: Alt barda tıklanınca da aynı fonksiyon çalışacak
        selectedItemColor: const Color(0xFFE53935), // Referans aldığın o güzel kırmızı
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // 4'ten fazla sekme olduğu için 'fixed' olması kritik
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.bloodtype), label: 'Talepler'), // YENİ EKLENDİ
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Bağışlarım'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Puanlar'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}