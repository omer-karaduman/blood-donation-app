import 'package:flutter/material.dart';

class HealthcareScreen extends StatelessWidget {
  const HealthcareScreen({super.key}); // const hatasını bu satır çözecek

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sağlık Personeli Paneli'), backgroundColor: Colors.blue),
      body: const Center(child: Text('Doktor Ekranı - Yakında Hazır!')),
    );
  }
}