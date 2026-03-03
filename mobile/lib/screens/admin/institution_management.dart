import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import '../../models/institution.dart'; 

class InstitutionManagementScreen extends StatefulWidget {
  const InstitutionManagementScreen({super.key});

  @override
  State<InstitutionManagementScreen> createState() => _InstitutionManagementScreenState();
}

class _InstitutionManagementScreenState extends State<InstitutionManagementScreen> {
  String selectedDistrict = "Tümü";
  final List<String> districts = [
    "Tümü", "Aliağa", "Balçova", "Bayındır", "Bayraklı", "Bergama", "Beydağ", 
    "Bornova", "Buca", "Çeşme", "Çiğli", "Dikili", "Foça", "Gaziemir", 
    "Güzelbahçe", "Karabağlar", "Karaburun", "Karşıyaka", "Kemalpaşa", 
    "Kınık", "Kiraz", "Konak", "Menderes", "Menemen", "Narlıdere", 
    "Ödemiş", "Seferihisar", "Selçuk", "Tire", "Torbalı", "Urla"
  ];

  String get baseUrl {
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (e) {
      return 'http://localhost:8000';
    }
    return 'http://localhost:8000';
  }

  Future<List<Institution>> fetchInstitutions() async {
    String url = '$baseUrl/institutions/';
    if (selectedDistrict != "Tümü") {
      url += '?ilce=$selectedDistrict';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
        return jsonData.map((data) => Institution.fromJson(data)).toList();
      } else {
        throw Exception('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: CustomScrollView(
          slivers: [
            SliverAppBar.medium(
              title: const Text("Hastane & Kurumlar", style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            
            SliverToBoxAdapter(
              child: _buildDistrictFilter(),
            ),

            FutureBuilder<List<Institution>>(
              future: fetchInstitutions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                } else if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(child: Text("Hata: ${snapshot.error}")),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SliverFillRemaining(child: Center(child: Text("Kayıt bulunamadı.")));
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final inst = snapshot.data![index];
                        return _buildInstitutionCard(context, inst, index % 5 == 0);
                      },
                      childCount: snapshot.data!.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: const Color(0xFFE53935),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text("Yeni Kurum", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildDistrictFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedDistrict,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                  borderRadius: BorderRadius.circular(15),
                  items: districts.map((String district) {
                    return DropdownMenuItem<String>(
                      value: district,
                      child: Text(district),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => selectedDistrict = newValue);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionCard(BuildContext context, Institution inst, bool isUrgent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: isUrgent ? Colors.red.shade50 : Colors.blue.shade50,
              child: Icon(Icons.local_hospital_rounded, color: isUrgent ? Colors.red : Colors.blue),
            ),
            title: Text(inst.ad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 14, color: Colors.red.shade300),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        // BURADA loc YERİNE inst.iletisim KULLANDIK
                        inst.iletisim.replaceFirst("/", " ilçesi,"), 
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 30, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(inst.yetkili, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Yönet"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}