import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants/api_constants.dart';

class DonorProfileTab extends StatefulWidget {
  final dynamic currentUser;
  const DonorProfileTab({super.key, required this.currentUser});

  @override
  State<DonorProfileTab> createState() => _DonorProfileTabState();
}

class _DonorProfileTabState extends State<DonorProfileTab> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _profileData;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfileFromServer();
  }

  // 📡 VERİYİ ÇEK: Boş gelirse email'i yedek olarak kullanır
  Future<void> _fetchProfileFromServer() async {
    try {
      final url = ApiConstants.donorProfileEndpoint(widget.currentUser.userId);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _profileData = data;
          // 💡 AKILLI DOLDURMA: Eğer DB boşsa email'in başını yazar
          _nameController.text = (data['ad_soyad'] != null && data['ad_soyad'] != "") 
              ? data['ad_soyad'] 
              : widget.currentUser.email.split('@')[0].toUpperCase();
          _phoneController.text = data['telefon'] ?? "";
          _weightController.text = (data['kilo'] ?? 0).toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Profil hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  // 💾 VERİYİ KAYDET: Artık veriler hardcoded kalmayacak!
  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    try {
      final url = ApiConstants.donorProfileUpdateEndpoint(widget.currentUser.userId);
      final response = await http.put(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "ad_soyad": _nameController.text,
          "telefon": _phoneController.text,
          "kilo": int.tryParse(_weightController.text) ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil başarıyla veritabanına kaydedildi!"), backgroundColor: Colors.green),
        );
        _fetchProfileFromServer(); // Ekranı tazele
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kayıt sırasında hata oluştu."), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 🚀 KIRMIZI GRADYAN HEADER (image_e94509.png'deki gibi) ---
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE53935), Color(0xFFB71C1C)], 
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                  ),
                ),
                Positioned(
                  top: 50,
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 60, color: Color(0xFFE53935)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _nameController.text,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(widget.currentUser.email, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- FORM KARTLARI ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                ),
                child: Column(
                  children: [
                    _buildModernField(_nameController, "Ad Soyad", Icons.badge_outlined),
                    const Divider(height: 30),
                    _buildModernField(_phoneController, "Telefon", Icons.phone_android),
                    const Divider(height: 30),
                    _buildModernField(_weightController, "Kilo (kg)", Icons.monitor_weight_outlined, isNumeric: true),
                  ],
                ),
              ),
            ),

            // --- KAN GRUBU BİLGİSİ ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(15)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Kan Grubu", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
                    Text(_profileData?['kan_grubu'] ?? "Seçilmedi", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFE53935))),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // --- KAYDET BUTONU ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  minimumSize: const Size(double.infinity, 55),
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("BİLGİLERİ VERİTABANINA KAYDET", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, String label, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
        border: InputBorder.none,
      ),
    );
  }
}