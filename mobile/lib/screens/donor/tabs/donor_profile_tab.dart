// lib/screens/donor/tabs/donor_profile_tab.dart
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
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _weightController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Mevcut verileri controller'lara dolduruyoruz
    _nameController = TextEditingController(text: widget.currentUser.email.split('@')[0]); // Örnek
    _phoneController = TextEditingController(text: "05XX XXX XX XX"); 
    _weightController = TextEditingController(text: "75");
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    // TODO: Backend'deki PUT /donors/{user_id} endpoint'ine istek atılacak
    await Future.delayed(const Duration(seconds: 1)); 
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil başarıyla güncellendi!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profil Ayarları", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profil Fotoğrafı Alanı
              Stack(
                children: [
                  const CircleAvatar(radius: 60, backgroundColor: Color(0xFFFDECEA), child: Icon(Icons.person, size: 60, color: Color(0xFFE53935))),
                  Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: const Color(0xFFE53935), radius: 18, child: IconButton(icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white), onPressed: () {}))),
                ],
              ),
              const SizedBox(height: 30),
              
              // Form Alanları
              _buildTextField(_nameController, "Ad Soyad", Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(_phoneController, "Telefon", Icons.phone_android_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildTextField(_weightController, "Kilo (kg)", Icons.monitor_weight_outlined, keyboardType: TextInputType.number),
              
              const SizedBox(height: 30),
              
              // Kan Grubu Bilgisi (Değiştirilemez, Bilgi Amaçlı)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Kan Grubunuz", style: TextStyle(color: Colors.black54)),
                    Text("A+", style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Güncelle Butonu
              ElevatedButton(
                onPressed: _isSaving ? null : _updateProfile,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Bilgileri Güncelle"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
        filled: true,
        fillColor: Colors.grey[50].withOpacity(0.5),
      ),
    );
  }
}