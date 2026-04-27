// mobile/lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ── Core ─────────────────────────────────────────────────────────────────────
import 'core/constants/api_constants.dart';
import 'core/theme/app_theme.dart';

// ── Models ───────────────────────────────────────────────────────────────────
import 'models/user.dart';

// ── Ekranlar: Auth ────────────────────────────────────────────────────────────
import 'screens/auth/login_screen.dart';

// ── Ekranlar: Shared ──────────────────────────────────────────────────────────
import 'screens/shared/profile_screen.dart';

// ── Ekranlar: Admin ───────────────────────────────────────────────────────────
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_logs_screen.dart';

// ── Ekranlar: Staff ───────────────────────────────────────────────────────────
import 'screens/staff/staff_dashboard.dart';

// ── Ekranlar: Donör Tabları ───────────────────────────────────────────────────
import 'screens/donor/tabs/donor_home_tab.dart';
import 'screens/donor/tabs/donor_history_tab.dart';
import 'screens/donor/tabs/donor_gamification_tab.dart';
import 'screens/donor/tabs/donor_profile_tab.dart';
import 'screens/donor/tabs/donor_requests_tab.dart';

// ── Firebase ──────────────────────────────────────────────────────────────────
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initialize();

  final messaging = FirebaseMessaging.instance;
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
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ana Navigasyon Ekranı
// ─────────────────────────────────────────────────────────────────────────────

class MainNavigationScreen extends StatefulWidget {
  final dynamic currentUser;
  const MainNavigationScreen({super.key, required this.currentUser});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex       = 0;
  bool _isLoadingStaffData = false;
  String _staffName        = 'Görevli Personel';
  String _staffInstitution = 'Kayıtlı Sağlık Kurumu';

  String _getSafeRoleStr() {
    try {
      if (widget.currentUser == null || widget.currentUser.role == null) return 'donor';
      return widget.currentUser.role.toString().split('.').last.toLowerCase();
    } catch (_) {
      return 'donor';
    }
  }

  @override
  void initState() {
    super.initState();
    if (_getSafeRoleStr() == 'staff') _fetchStaffData();
  }

  Future<void> _fetchStaffData() async {
    setState(() => _isLoadingStaffData = true);
    try {
      final res = await http.get(Uri.parse(ApiConstants.staffEndpoint));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
        final myProfile = data.firstWhere(
          (s) => s['user_id'] == widget.currentUser.userId,
          orElse: () => null,
        );
        if (myProfile != null && mounted) {
          setState(() {
            _staffName        = myProfile['ad_soyad'] ?? widget.currentUser.email.split('@')[0].toUpperCase();
            _staffInstitution = myProfile['kurum_adi'] ?? 'Kurum Bilgisi Yok';
            _isLoadingStaffData = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStaffData = false);
    }
  }

  List<Widget> _getPages() {
    switch (_getSafeRoleStr()) {
      case 'admin':
        return [
          const AdminDashboard(),
          const AdminLogsScreen(),
          ProfileScreen(currentUser: widget.currentUser),
        ];
      case 'staff':
        return [
          StaffDashboard(
            staffUserId:     widget.currentUser.userId,
            staffName:       _staffName,
            institutionName: _staffInstitution,
          ),
          ProfileScreen(currentUser: widget.currentUser),
        ];
      case 'donor':
      default:
        return [
          DonorHomeTab(
            currentUser: widget.currentUser,
            onTabChange: (i) => setState(() => _selectedIndex = i),
          ),
          DonorRequestsTab(currentUser: widget.currentUser),
          DonorHistoryTab(currentUser: widget.currentUser),
          DonorGamificationTab(currentUser: widget.currentUser),
          DonorProfileTab(currentUser: widget.currentUser),
        ];
    }
  }

  List<BottomNavigationBarItem> _getNavItems() {
    switch (_getSafeRoleStr()) {
      case 'admin':
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded),      label: 'Sistem'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded),   label: 'Loglar'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded),         label: 'Profil'),
        ];
      case 'staff':
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.local_hospital_rounded), label: 'Kurum'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded),         label: 'Profil'),
        ];
      case 'donor':
      default:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded),           label: 'Ana Sayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.bloodtype),              label: 'Talepler'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded),        label: 'Bağışlarım'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded),   label: 'Puanlar'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded),         label: 'Profil'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _getPages()),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          currentIndex:        _selectedIndex,
          onTap:               (i) => setState(() => _selectedIndex = i),
          selectedItemColor:   const Color(0xFFE53935),
          unselectedItemColor: Colors.grey,
          backgroundColor:     Colors.white,
          type:                BottomNavigationBarType.fixed,
          selectedFontSize:    12,
          unselectedFontSize:  11,
          elevation:           0,
          items:               _getNavItems(),
        ),
      ),
    );
  }
}