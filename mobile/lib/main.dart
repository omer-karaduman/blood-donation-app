// mobile/lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'constants/api_constants.dart';
import 'models/user.dart';

// --- EKRAN İMPORTLARI ---
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/staff/staff_dashboard.dart';

// --- 🚀 YENİ MODÜLER DONÖR TABLARI İMPORTLARI ---
import 'screens/donor/tabs/donor_home_tab.dart';
import 'screens/donor/tabs/donor_history_tab.dart';
import 'screens/donor/tabs/donor_gamification_tab.dart';
import 'screens/donor/tabs/donor_profile_tab.dart';
import 'screens/donor/tabs/donor_requests_tab.dart'; // İsim uyumuna dikkat (çoğul/tekil)

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize(); 

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  runApp(const BloodDonationApp()); 
}

class BloodDonationApp extends StatelessWidget {
  const BloodDonationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kan Bağışı AI',
      debugShowCheckedModeBanner: false,
      // 🚀 SENİN ÇOK GÜZEL DEDİĞİN TEMA AYARLARI
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          primary: const Color(0xFFE53935),
          secondary: const Color(0xFF263238),
          surface: const Color(0xFFF8F9FA),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
      home: const LoginScreen(), 
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final dynamic currentUser; 
  const MainNavigationScreen({super.key, required this.currentUser});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _isLoadingStaffData = false;
  String _staffName = "Görevli Personel";
  String _staffInstitution = "Kayıtlı Sağlık Kurumu";

  String _getSafeRoleStr() {
    try {
      if (widget.currentUser == null || widget.currentUser.role == null) return 'donor';
      return widget.currentUser.role.toString().split('.').last.toLowerCase();
    } catch (e) {
      return 'donor'; 
    }
  }

  @override
  void initState() {
    super.initState();
    if (_getSafeRoleStr() == 'staff') {
      _fetchStaffData();
    }
  }

  Future<void> _fetchStaffData() async {
    setState(() => _isLoadingStaffData = true);
    try {
      final response = await http.get(Uri.parse(ApiConstants.staffEndpoint));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final myProfile = data.firstWhere(
          (s) => s['user_id'] == widget.currentUser.userId, 
          orElse: () => null
        );
        if (myProfile != null && mounted) {
          setState(() {
            _staffName = myProfile['ad_soyad'] ?? widget.currentUser.email.split('@')[0].toUpperCase();
            _staffInstitution = myProfile['kurum_adi'] ?? "Kurum Bilgisi Yok";
            _isLoadingStaffData = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStaffData = false);
    }
  }

  // --- 🚀 GÜNCEL 5'Lİ DONÖR SAYFA LİSTESİ ---
// --- 🚀 GÜNCEL 5'Lİ DONÖR SAYFA LİSTESİ ---
  List<Widget> _getPages() {
    String roleStr = _getSafeRoleStr(); 

    switch (roleStr) {
      case 'admin':
        return [const AdminDashboard(), ProfileScreen(currentUser: widget.currentUser)];
      case 'staff':
        return [
          StaffDashboard(
            staffUserId: widget.currentUser.userId,
            staffName: _staffName,
            institutionName: _staffInstitution,
          ), 
          ProfileScreen(currentUser: widget.currentUser)
        ];
      case 'donor':
      default:
        return [
          // 🚀 HATA BURADAYDI: onTabChange parametresi eklendi!
          DonorHomeTab(
            currentUser: widget.currentUser,
            onTabChange: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          DonorRequestsTab(currentUser: widget.currentUser), 
          DonorHistoryTab(currentUser: widget.currentUser),
          DonorGamificationTab(currentUser: widget.currentUser),
          DonorProfileTab(currentUser: widget.currentUser),
        ];
    }
  }

  // --- 🚀 GÜNCEL 5'Lİ DONÖR İKON YAPISI ---
  List<BottomNavigationBarItem> _getNavItems() {
    String roleStr = _getSafeRoleStr(); 

    switch (roleStr) {
      case 'admin':
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Sistem'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ];
      case 'staff':
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.local_hospital_rounded), label: 'Kurum'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ];
      case 'donor':
      default:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.bloodtype), label: 'Talepler'), // YENİ EKLENDİ
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Bağışlarım'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Puanlar'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _getPages(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: const Color(0xFFE53935),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed, // 5 öğe için bu tip zorunludur
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 0,
          items: _getNavItems(),
        ),
      ),
    );
  }
}