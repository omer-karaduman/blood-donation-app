import 'package:flutter/material.dart';

// Ekranlar
import 'screens/home_screen.dart';
import 'screens/donor_list_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/healthcare_screen.dart'; 
import 'screens/admin/admin_dashboard.dart';

void main() {
  runApp(const BloodDonationApp());
}

class BloodDonationApp extends StatelessWidget {
  const BloodDonationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kan Bağışı AI',
      debugShowCheckedModeBanner: false,
      // --- İŞTE O FERAH TEMA AYARLARI BURADA BAŞLIYOR ---
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935), // Modern ve yumuşak bir kırmızı
          primary: const Color(0xFFE53935),
          secondary: const Color(0xFF263238), // Profesyonel koyu ton
          surface: const Color(0xFFF8F9FA),   // Gözü yormayan açık gri fon
        ),
        // Kartların köşelerini yumuşatıyoruz
        cardTheme: const CardThemeData( // CardTheme yerine CardThemeData yazdık
          elevation: 0,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)), // Daha yumuşak köşeler
          ),
          color: Colors.white,
        ),
        // Appbar'ı şeffaf ve modern yapıyoruz
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Color(0xFF263238), 
            fontSize: 20, 
            fontWeight: FontWeight.bold
          ),
        ),
      ),
      // ------------------------------------------------
      home: const RoleSelectionScreen(), 
    );
  }
}

// --- TEST SÜRECİ İÇİN GEÇİCİ ROL SEÇME EKRANI ---
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.red.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bloodtype_rounded, size: 100, color: Color(0xFFE53935)),
              const SizedBox(height: 20),
              const Text(
                "Hoş geldin Ömer,", 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Lütfen devam etmek için bir rol seç:",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              _roleButton(context, "Donör (Bağışçı)", "donor", Icons.favorite),
              _roleButton(context, "Sağlık Çalışanı (Doktor)", "healthcare", Icons.medication),
              _roleButton(context, "Admin (Yönetici)", "admin", Icons.admin_panel_settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleButton(BuildContext context, String label, String role, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 40),
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 55),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF263238),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainNavigationScreen(userRole: role)),
          );
        },
      ),
    );
  }
}

// --- DİNAMİK NAVİGASYON MERKEZİ ---
class MainNavigationScreen extends StatefulWidget {
  final String userRole;

  const MainNavigationScreen({super.key, required this.userRole});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  List<Widget> _getPages() {
    switch (widget.userRole) {
      case 'admin':
        return [const AdminDashboard(), const ProfileScreen()];
      case 'healthcare':
        return [const HealthcareScreen(), const ProfileScreen()];
      case 'donor':
      default:
        return [const HomeScreen(), const DonorListScreen(), const ProfileScreen()];
    }
  }

  List<BottomNavigationBarItem> _getNavItems() {
    switch (widget.userRole) {
      case 'admin':
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Panel'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ];
      case 'healthcare':
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.add_alert_rounded), label: 'Talep Aç'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ];
      case 'donor':
      default:
        return const [
          BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Keşfet'),
          BottomNavigationBarItem(icon: Icon(Icons.water_drop_rounded), label: 'Donörler'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages();
    final items = _getNavItems();

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: const Color(0xFFE53935),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: items,
        ),
      ),
    );
  }
}