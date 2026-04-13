// mobile/lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../models/user.dart'; // 🚀 KRİTİK: UserRole enum'ı için bu import şart!
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; 
  int _selectedRoleIndex = 0; 

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleLogin() async {
    setState(() => _isLoading = true);

    // AuthService artık Donör ise Donor nesnesi, değilse User nesnesi döndürüyor
    final user = await AuthService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (mounted) setState(() => _isLoading = false);

    if (user != null) {
      // --- ROL VE SEKME DOĞRULAMASI ---
      bool isDonorTab = _selectedRoleIndex == 0;
      
      // 🚀 DÜZELTME: .name kullanmak yerine doğrudan enum karşılaştırması yapıyoruz
      // Bu yöntem NoSuchMethodError hatasını tamamen ortadan kaldırır.
      bool isUserDonor = user.role == UserRole.donor;

      if (isDonorTab && !isUserDonor) {
        _showErrorSnackBar("Yetkisiz Giriş: Kurumsal hesaplar 'Personel Girişi' sekmesini kullanmalıdır.");
        return;
      } 
      else if (!isDonorTab && isUserDonor) {
        _showErrorSnackBar("Yetkisiz Giriş: Bireysel donör hesapları 'Donör Girişi' sekmesini kullanmalıdır.");
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigationScreen(currentUser: user),
          ),
        );
      }
    } else {
      _showErrorSnackBar("Giriş başarısız! E-posta veya şifreniz hatalı.");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.bloodtype_rounded, size: 80, color: Color(0xFFE53935)),
              const SizedBox(height: 15),
              const Text(
                "Kan Bağışı AI",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF263238), letterSpacing: -0.5),
              ),
              const SizedBox(height: 5),
              Text(
                _selectedRoleIndex == 0 ? "Hayat kurtarmak için sisteme giriş yapın" : "Kurumsal sisteme erişim sağlayın",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 40),
              
              // --- ROL SEÇİM SEKME (TAB) ALANI ---
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildRoleTab(0, "Donör Girişi", Icons.volunteer_activism)),
                    Expanded(child: _buildRoleTab(1, "Personel Girişi", Icons.local_hospital_rounded)),
                  ],
                ),
              ),
              const SizedBox(height: 35),
              
              // --- GİRİŞ FORMU ---
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: _selectedRoleIndex == 0 ? "E-posta Adresi" : "Kurumsal E-posta",
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Şifre",
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 40),
              
              // --- GİRİŞ YAP BUTONU ---
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedRoleIndex == 0 ? const Color(0xFFE53935) : const Color(0xFF1565C0),
                      ),
                      child: Text(
                        _selectedRoleIndex == 0 ? "Donör Olarak Giriş Yap" : "Sisteme Giriş Yap",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
              
              const SizedBox(height: 25),
              
              // --- KAYIT OL YÖNLENDİRMESİ (Sadece Donör İçin Görünür) ---
              if (_selectedRoleIndex == 0)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Hesabın yok mu? ", style: TextStyle(color: Colors.grey)),
                      Text("Hemen Donör Ol", style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else 
                // Personel sekmesindeysek sadece bir bilgi notu çıkarıyoruz
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    "Personel hesapları yalnızca sistem yöneticileri\ntarafından oluşturulabilir.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SEKME (TAB) TASARIMI YARDIMCI WIDGET ---
  Widget _buildRoleTab(int index, String title, IconData icon) {
    bool isSelected = _selectedRoleIndex == index;
    // Donör için kırmızı, personel için hastane mavisi tonu
    Color activeColor = index == 0 ? const Color(0xFFE53935) : const Color(0xFF1565C0);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRoleIndex = index;
          // Sekme değişince eski yazıları temizle
          _emailController.clear();
          _passwordController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected 
            ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] 
            : [],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}