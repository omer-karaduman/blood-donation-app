import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Form kontrolleri
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedBloodType = 'A+';

  Future<void> _register() async {
    const String apiUrl = 'http://localhost:8000/register/donor/';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': _emailController.text,
        'password': _passwordController.text,
        'ad_soyad': _nameController.text,
        'telefon': _phoneController.text,
        'cinsiyet': 'E', // Şimdilik sabit, Melih buraya seçim ekleyebilir
        'dogum_tarihi': '1998-05-15', // Sabit test verisi
        'kilo': 75.0,
        'kan_grubu': _selectedBloodType,
        'latitude': 38.42,
        'longitude': 27.14,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt Başarılı! Artık bir kahramansın.')),
      );
      Navigator.pop(context); // Kayıttan sonra geri dön
    } else {
      print(response.body);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Donör Ol')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Ad Soyad')),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-posta')),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Şifre'), obscureText: true),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Telefon')),
              DropdownButtonFormField<String>(
                value: _selectedBloodType,
                items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((String type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) => setState(() => _selectedBloodType = val!),
                decoration: const InputDecoration(labelText: 'Kan Grubu'),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('Kayıt Ol'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}