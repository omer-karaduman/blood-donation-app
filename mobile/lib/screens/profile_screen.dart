import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim'), backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 20),
            const Text('Ömer Karaduman', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('A+ Pozitif Donör'),
            const Divider(height: 40),
            const ListTile(leading: Icon(Icons.star, color: Colors.amber), title: Text('Puan: 1250'), subtitle: Text('Seviye: Kahraman Donör')),
            const ListTile(leading: Icon(Icons.history), title: Text('Son Bağış: 24.12.2025')),
            const Spacer(),
            OutlinedButton(onPressed: () {}, child: const Text('Çıkış Yap', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}