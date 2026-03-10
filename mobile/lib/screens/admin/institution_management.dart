import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/institution.dart'; 
import 'institution_detail_screen.dart';

// 1. SABİTLER DOSYASINI İÇERİ AKTARDIK
import '../../constants/api_constants.dart';

class InstitutionManagementScreen extends StatefulWidget {
  const InstitutionManagementScreen({super.key});

  @override
  State<InstitutionManagementScreen> createState() => _InstitutionManagementScreenState();
}

class _InstitutionManagementScreenState extends State<InstitutionManagementScreen> {
  String selectedDistrict = "Tümü";
  String selectedType = "Tümü";

  // --- ARAMA ÇUBUĞU KONTROLCÜLERİ ---
  final TextEditingController _nameSearchController = TextEditingController();
  final TextEditingController _districtSearchController = TextEditingController();

  // --- API İSTEKLERİNİ KONTROL ETMEK İÇİN FUTURE DEĞİŞKENİ ---
  late Future<List<Institution>> _institutionsFuture;

  final List<String> districts = [
    "Tümü", "Aliağa", "Balçova", "Bayındır", "Bayraklı", "Bergama", "Beydağ", 
    "Bornova", "Buca", "Çeşme", "Çiğli", "Dikili", "Foça", "Gaziemir", 
    "Güzelbahçe", "Karabağlar", "Karaburun", "Karşıyaka", "Kemalpaşa", 
    "Kınık", "Kiraz", "Konak", "Menderes", "Menemen", "Narlıdere", 
    "Ödemiş", "Seferihisar", "Selçuk", "Tire", "Torbalı", "Urla"
  ];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    _districtSearchController.dispose();
    super.dispose();
  }

  // 2. ESKİ 'baseUrl' FONKSİYONUNU TAMAMEN SİLDİK

  void _refreshData() {
    setState(() {
      _institutionsFuture = fetchInstitutions();
    });
  }

  Future<List<Institution>> fetchInstitutions() async {
    var queryParams = <String>[];
    if (selectedDistrict != "Tümü") queryParams.add('ilce=$selectedDistrict');
    if (selectedType != "Tümü") queryParams.add('tipi=$selectedType');

    String queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    
    // 3. API CONSTANTS KULLANARAK İSTEĞİ GÜNCELLEDİK
    String url = '${ApiConstants.institutionsEndpoint}$queryString';

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

  // --- TÜRKÇE KARAKTER DUYARLI KÜÇÜLTME FONKSİYONU ---
  String _normalizeTr(String text) {
    return text
        .replaceAll('I', 'ı')
        .replaceAll('İ', 'i')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ç', 'ç')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(), 
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
                  _buildSearchBars(), 
                  const SizedBox(height: 10),
                ],
              ),
            ),
            FutureBuilder<List<Institution>>(
              future: _institutionsFuture, 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                } else if (snapshot.hasError) {
                  return SliverFillRemaining(child: Center(child: Text("Hata: ${snapshot.error}")));
                }

                final List<Institution> allData = snapshot.data ?? [];

                // --- TEXT ARAMA FİLTRESİ (TÜRKÇE DESTEKLİ) ---
                final String nameQuery = _normalizeTr(_nameSearchController.text);
                final String districtQuery = _normalizeTr(_districtSearchController.text);

                final List<Institution> processedData = allData.where((inst) {
                  final bool matchesName = _normalizeTr(inst.ad).contains(nameQuery);
                  final bool matchesDistrict = _normalizeTr(inst.ilce).contains(districtQuery);
                  return matchesName && matchesDistrict;
                }).toList();

                // 1. Önce 'Parent' olanları bul
                final List<Institution> rootInstitutions = processedData.where((inst) => 
                  inst.parentId == null
                ).toList();

                // 2. 'Child' olanları ayır
                final List<Institution> subInstitutions = processedData.where((inst) => 
                  inst.parentId != null
                ).toList();

                // --- YETİM ÇOCUKLAR (ORPHAN) MANTIĞI ---
                final List<Institution> orphanInstitutions = subInstitutions.where((child) => 
                  !rootInstitutions.any((parent) => parent.id == child.parentId)
                ).toList();

                rootInstitutions.addAll(orphanInstitutions);
                // ------------------------------------------------

                if (rootInstitutions.isEmpty && subInstitutions.isEmpty) {
                  return const SliverFillRemaining(child: Center(child: Text("Kayıt bulunamadı.")));
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final parent = rootInstitutions[index];
                        
                        final childrenOfThisParent = subInstitutions.where((child) => 
                          child.parentId == parent.id
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

  Widget _buildSearchBars() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)
                ],
              ),
              child: TextField(
                controller: _nameSearchController,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "Kurum Ara...",
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)
                ],
              ),
              child: TextField(
                controller: _districtSearchController,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "İlçe Ara...",
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.location_city, size: 18, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyGroup(BuildContext context, Institution parent, List<Institution> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInstitutionCard(context, parent, isChild: false),
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
          "${inst.ilce} - ${inst.tamAdres}", 
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.settings_outlined, size: 20, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InstitutionDetailScreen(institution: inst),
            ),
          );
        },
      ),
    );
  }

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
            onChanged: (val) {
              if (val != null) {
                selectedDistrict = val;
                _refreshData();
              }
            },
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
          onSelectionChanged: (newSelection) {
            selectedType = newSelection.first;
            _refreshData();
          },
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