// mobile/lib/screens/admin/institution_management.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/institution.dart'; 
import 'institution_detail_screen.dart';
import '../../constants/api_constants.dart';

class InstitutionManagementScreen extends StatefulWidget {
  const InstitutionManagementScreen({super.key});

  @override
  State<InstitutionManagementScreen> createState() => _InstitutionManagementScreenState();
}

class _InstitutionManagementScreenState extends State<InstitutionManagementScreen> {
  // YENİ: Dinamik filtreleme değişkenleri
  District? selectedFilterDistrict; // Null olması "Tümü" anlamına gelir
  String selectedType = "Tümü";

  // --- KONTROLCÜLER ---
  final TextEditingController _nameSearchController = TextEditingController();
  final TextEditingController _districtSearchController = TextEditingController();
  
  late Future<List<Institution>> _institutionsFuture;
  List<District> _districtsList = []; // Backend'den çekilecek

  @override
  void initState() {
    super.initState();
    _fetchDistricts(); // Önce ilçeleri çek
    _refreshData();
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    _districtSearchController.dispose();
    super.dispose();
  }

  // --- YENİ: İLÇELERİ BACKEND'DEN ÇEK ---
  Future<void> _fetchDistricts() async {
    try {
      // ApiConstants.baseUrl varsayımıyla (kendi proje yapılandırmana göre ayarlayabilirsin)
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/locations/districts'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _districtsList = data.map((d) => District.fromJson(d)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("İlçe verisi çekilemedi: $e");
    }
  }

  void _refreshData() {
    setState(() {
      _institutionsFuture = fetchInstitutions();
    });
  }

  Future<List<Institution>> fetchInstitutions() async {
    var queryParams = <String>[];
    // YENİ: String isim yerine UUID gönderiyoruz
    if (selectedFilterDistrict != null) queryParams.add('district_id=${selectedFilterDistrict!.id}');
    if (selectedType != "Tümü") queryParams.add('tipi=$selectedType');

    String queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    String url = '${ApiConstants.institutionsEndpoint}$queryString';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
        return jsonData.map((data) => Institution.fromJson(data)).toList();
      }
      throw Exception('Veriler yüklenemedi');
    } catch (e) {
      throw Exception('Bağlantı Hatası: $e');
    }
  }

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

  // --- YENİ KURUM EKLEME MODAL FORMU ---
  void _showAddInstitutionForm() {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    String type = "Hastane";
    
    // Form içi dinamik lokasyon değişkenleri
    District? formSelectedDistrict;
    Neighborhood? formSelectedNeighborhood;
    List<Neighborhood> formNeighborhoods = [];
    bool isLoadingNeighborhoods = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24, right: 24, top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),
                    const Text("Yeni Kurum Kaydı", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 25),
                    
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Kurum Adı", prefixIcon: Icon(Icons.business))),
                    const SizedBox(height: 15),
                    
                    DropdownButtonFormField<String>(
                      value: type,
                      items: ["Hastane", "Kan Merkezi"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setModalState(() => type = v!),
                      decoration: const InputDecoration(labelText: "Kurum Tipi", prefixIcon: Icon(Icons.local_hospital)),
                    ),
                    const SizedBox(height: 15),

                    // YENİ: Dinamik İlçe Seçici
                    DropdownButtonFormField<District>(
                      value: formSelectedDistrict,
                      hint: const Text("İlçe Seçin"),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.location_city)),
                      items: _districtsList.map((d) => DropdownMenuItem(value: d, child: Text(d.name))).toList(),
                      onChanged: (val) async {
                        if (val == null) return;
                        setModalState(() {
                          formSelectedDistrict = val;
                          formSelectedNeighborhood = null;
                          formNeighborhoods = [];
                          isLoadingNeighborhoods = true;
                        });

                        // Seçilen ilçenin mahallelerini çek
                        try {
                          final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/locations/districts/${val.id}/neighborhoods'));
                          if (res.statusCode == 200) {
                            final List<dynamic> nData = json.decode(utf8.decode(res.bodyBytes));
                            setModalState(() {
                              formNeighborhoods = nData.map((n) => Neighborhood.fromJson(n)).toList();
                            });
                          }
                        } catch (e) {
                          debugPrint("Mahalle hatası: $e");
                        } finally {
                          setModalState(() => isLoadingNeighborhoods = false);
                        }
                      },
                    ),
                    const SizedBox(height: 15),

                    // YENİ: Dinamik Mahalle Seçici
                    isLoadingNeighborhoods 
                      ? const CircularProgressIndicator()
                      : DropdownButtonFormField<Neighborhood>(
                          value: formSelectedNeighborhood,
                          hint: const Text("Mahalle Seçin"),
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on)),
                          items: formNeighborhoods.map((n) => DropdownMenuItem(value: n, child: Text(n.name))).toList(),
                          onChanged: formNeighborhoods.isEmpty ? null : (val) {
                            setModalState(() => formSelectedNeighborhood = val);
                          },
                        ),
                    const SizedBox(height: 15),

                    TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: "Tam Adres", prefixIcon: Icon(Icons.map))),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF263238), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () async {
                          if (formSelectedDistrict == null || formSelectedNeighborhood == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen ilçe ve mahalle seçiniz.")));
                            return;
                          }

                          // YENİ: Backend'e gönderilecek JSON (UUID formatında)
                          final body = {
                            "kurum_adi": nameCtrl.text.trim(),
                            "tam_adres": addrCtrl.text.trim(),
                            "tipi": type,
                            "district_id": formSelectedDistrict!.id,
                            "neighborhood_id": formSelectedNeighborhood!.id,
                            "latitude": 38.42, // Geliştirmede İzmir merkez varsayılan
                            "longitude": 27.14,
                            "parent_id": null
                          };

                          try {
                            final res = await http.post(
                              Uri.parse(ApiConstants.institutionsEndpoint),
                              headers: {"Content-Type": "application/json"},
                              body: json.encode(body)
                            );
                            if (res.statusCode == 200) {
                              Navigator.pop(context);
                              _refreshData();
                            } else {
                              debugPrint("Hata: ${res.statusCode}");
                            }
                          } catch (e) {
                            debugPrint("Post hatası: $e");
                          }
                        },
                        child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddInstitutionForm,
        backgroundColor: const Color(0xFF263238),
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text("Yeni Kurum", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(), 
        child: CustomScrollView(
          slivers: [
            SliverAppBar.medium(
              title: const Text("Kurum Yönetimi", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF263238))),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              actions: [
                IconButton(onPressed: _refreshData, icon: const Icon(Icons.sync_rounded, color: Colors.grey)),
              ],
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
                final String nameQuery = _normalizeTr(_nameSearchController.text);
                final String districtQuery = _normalizeTr(_districtSearchController.text);

                final List<Institution> processedData = allData.where((inst) {
                  final bool matchesName = _normalizeTr(inst.ad).contains(nameQuery);
                  // YENİ: Arama çubuğunda inst.ilce yerine inst.ilceAdi kullanıyoruz
                  final bool matchesDistrict = _normalizeTr(inst.ilceAdi).contains(districtQuery);
                  return matchesName && matchesDistrict;
                }).toList();

                // Hiyerarşi Mantığı
                final List<Institution> rootInstitutions = processedData.where((inst) => inst.parentId == null).toList();
                final List<Institution> subInstitutions = processedData.where((inst) => inst.parentId != null).toList();
                
                final List<Institution> orphanInstitutions = subInstitutions.where((child) => 
                  !rootInstitutions.any((parent) => parent.id == child.parentId)
                ).toList();
                rootInstitutions.addAll(orphanInstitutions);

                if (rootInstitutions.isEmpty) {
                  return const SliverFillRemaining(child: Center(child: Text("Kayıt bulunamadı.")));
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final parent = rootInstitutions[index];
                        final children = subInstitutions.where((child) => child.parentId == parent.id).toList();
                        return _buildHierarchyGroup(context, parent, children);
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
            child: _buildSingleSearchField(_nameSearchController, "Kurum Ara...", Icons.search),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _buildSingleSearchField(_districtSearchController, "İlçe Ara...", Icons.location_city),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSearchField(TextEditingController controller, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)]),
      child: TextField(
        controller: controller,
        onChanged: (value) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
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
    Color themeColor = isBloodBank ? const Color(0xFFE53935) : const Color(0xFF1E88E5);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isChild ? 0 : 20, vertical: 4),
      decoration: BoxDecoration(
        color: isChild ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(isChild ? 16 : 24),
        border: isChild ? Border.all(color: Colors.grey.shade200) : null,
        boxShadow: isChild ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: isChild ? 18 : 22,
          backgroundColor: themeColor.withOpacity(0.1),
          child: Icon(
            isChild ? Icons.subdirectory_arrow_right_rounded : (isBloodBank ? Icons.bloodtype : Icons.local_hospital),
            color: themeColor, size: isChild ? 18 : 24,
          ),
        ),
        title: Text(inst.ad, style: TextStyle(fontWeight: isChild ? FontWeight.w500 : FontWeight.bold, fontSize: isChild ? 13 : 15)),
        // YENİ: inst.ilceAdi kullanıldı
        subtitle: Text("${inst.ilceAdi} - ${inst.tamAdres}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: const Icon(Icons.settings_outlined, size: 20, color: Colors.grey),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => InstitutionDetailScreen(institution: inst))),
      ),
    );
  }

  Widget _buildDistrictFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: DropdownButtonHideUnderline(
          // YENİ: String yerine District nesnesi kullanılıyor
          child: DropdownButton<District?>(
            value: selectedFilterDistrict,
            isExpanded: true,
            hint: const Text("Tüm İlçeler"),
            icon: const Icon(Icons.location_on_outlined, color: Colors.red),
            items: [
              const DropdownMenuItem<District?>(value: null, child: Text("Tüm İlçeler")),
              ..._districtsList.map((d) => DropdownMenuItem(value: d, child: Text(d.name))),
            ],
            onChanged: (val) {
              setState(() { selectedFilterDistrict = val; _refreshData(); });
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
            ButtonSegment(value: "Kan Merkezi", label: Text("Merkez"), icon: Icon(Icons.bloodtype)),
          ],
          selected: {selectedType},
          onSelectionChanged: (newSelection) { setState(() { selectedType = newSelection.first; _refreshData(); }); },
          style: SegmentedButton.styleFrom(backgroundColor: Colors.white, selectedBackgroundColor: Colors.red.shade50, selectedForegroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    );
  }
}