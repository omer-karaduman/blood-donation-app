import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import '../../models/institution.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb;

class InstitutionManagementScreen extends StatefulWidget {
  const InstitutionManagementScreen({super.key});

  @override
  State<InstitutionManagementScreen> createState() => _InstitutionManagementScreenState();
}

class _InstitutionManagementScreenState extends State<InstitutionManagementScreen> {
  String selectedDistrict = "Tümü";
  String selectedType = "Tümü";

  final List<String> districts = [
    "Tümü", "Aliağa", "Balçova", "Bayındır", "Bayraklı", "Bergama", "Beydağ", 
    "Bornova", "Buca", "Çeşme", "Çiğli", "Dikili", "Foça", "Gaziemir", 
    "Güzelbahçe", "Karabağlar", "Karaburun", "Karşıyaka", "Kemalpaşa", 
    "Kınık", "Kiraz", "Konak", "Menderes", "Menemen", "Narlıdere", 
    "Ödemiş", "Seferihisar", "Selçuk", "Tire", "Torbalı", "Urla"
  ];

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000'; 
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (e) {
      return 'http://localhost:8000';
    }
    return 'http://localhost:8000';
  }

  Future<List<Institution>> fetchInstitutions() async {
    var queryParams = <String>[];
    if (selectedDistrict != "Tümü") queryParams.add('ilce=$selectedDistrict');
    if (selectedType != "Tümü") queryParams.add('tipi=$selectedType');

    String queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    String url = '$baseUrl/institutions/$queryString';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
        return jsonData.map((data) => Institution.fromJson(data)).toList();
      }
      throw Exception('Sunucu Hatası');
    } catch (e) {
      throw Exception('Bağlantı Hatası: $e');
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
              title: const Text("Hiyerarşik Kurum Yönetimi", style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildDistrictFilter(),
                  _buildTypeFilter(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            FutureBuilder<List<Institution>>(
              future: fetchInstitutions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                } else if (snapshot.hasError) {
                  return SliverFillRemaining(child: Center(child: Text("Hata: ${snapshot.error}")));
                }

                final List<Institution> allData = snapshot.data ?? [];
                
                // --- GELİŞMİŞ HİYERARŞİ MANTIĞI ---
                // 1. Önce 'Parent' olanları veya 'Bağımsız Kurum' olarak işaretlenmiş ana yapıları bul
                final List<Institution> rootInstitutions = allData.where((inst) => 
                  inst.hiyerarsiTipi == "Parent" || inst.parentAdi == "Bağımsız Kurum"
                ).toList();

                // 2. 'Child' olanları ayır
                final List<Institution> subInstitutions = allData.where((inst) => 
                  inst.hiyerarsiTipi == "Child"
                ).toList();

                if (rootInstitutions.isEmpty && subInstitutions.isEmpty) {
                  return const SliverFillRemaining(child: Center(child: Text("Kayıt bulunamadı.")));
                }

                // Ekranda sadece ana kurumları döneceğiz, çocuklar onların altında render edilecek
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final parent = rootInstitutions[index];
                        
                        // Bu ebeveyne (parent) bağlı olan çocukları (child) isminden bul
                        final childrenOfThisParent = subInstitutions.where((child) => 
                          child.parentAdi == parent.ad
                        ).toList();

                        return _buildHierarchyGroup(context, parent, childrenOfThisParent);
                      },
                      childCount: rootInstitutions.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- HİYERARŞİK GRUP OLUŞTURUCU ---
  Widget _buildHierarchyGroup(BuildContext context, Institution parent, List<Institution> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Ana Kurum Kartı
        _buildInstitutionCard(context, parent, isChild: false),
        
        // 2. Eğer varsa Alt Birim Kartları (Sağa yaslı ve bağlı ikonlu)
        if (children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 45, right: 20),
            child: Column(
              children: children.map<Widget>((child) => 
                _buildInstitutionCard(context, child, isChild: true)
              ).toList(),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  // --- ORTAK KART TASARIMI ---
  Widget _buildInstitutionCard(BuildContext context, Institution inst, {required bool isChild}) {
    bool isBloodBank = inst.tipi == "Kan Merkezi";
    Color themeColor = isBloodBank ? Colors.red : Colors.blue;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isChild ? 0 : 20, vertical: 4),
      decoration: BoxDecoration(
        color: isChild ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(isChild ? 16 : 24),
        border: isChild ? Border.all(color: Colors.grey.shade200) : null,
        boxShadow: isChild ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: isChild ? 18 : 22,
          backgroundColor: themeColor.withOpacity(0.1),
          child: Icon(
            isChild ? Icons.subdirectory_arrow_right_rounded : (isBloodBank ? Icons.bloodtype : Icons.local_hospital),
            color: themeColor,
            size: isChild ? 18 : 24,
          ),
        ),
        title: Text(
          inst.ad,
          style: TextStyle(
            fontWeight: isChild ? FontWeight.w500 : FontWeight.bold,
            fontSize: isChild ? 13 : 15,
          ),
        ),
        subtitle: Text(
          "${inst.ilce} - ${inst.tipi}",
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.settings_outlined, size: 20, color: Colors.grey),
        onTap: () {
          // Yönetim veya detay sayfasına yönlendirme
        },
      ),
    );
  }

  // --- FİLTRELEME WIDGETLARI ---
  Widget _buildDistrictFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedDistrict,
            isExpanded: true,
            icon: const Icon(Icons.location_on_outlined, color: Colors.red),
            items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (val) => val != null ? setState(() => selectedDistrict = val) : null,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: "Tümü", label: Text("Tümü"), icon: Icon(Icons.all_inclusive)),
            ButtonSegment(value: "Hastane", label: Text("Hastane"), icon: Icon(Icons.local_hospital)),
            ButtonSegment(value: "Kan Merkezi", label: Text("Kan Merkezi"), icon: Icon(Icons.bloodtype)),
          ],
          selected: {selectedType},
          onSelectionChanged: (newSelection) => setState(() => selectedType = newSelection.first),
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.white,
            selectedBackgroundColor: Colors.red.shade100,
            selectedForegroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}