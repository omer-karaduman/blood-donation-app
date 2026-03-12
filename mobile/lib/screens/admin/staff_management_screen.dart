// mobile/lib/screens/admin/staff_management_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/institution.dart';
import 'staff_settings_screen.dart';
import '../../constants/api_constants.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<dynamic> allStaffList = [];
  List<Institution> allInstitutions = [];
  bool isLoading = true;

  final TextEditingController _nameSearchController = TextEditingController();
  Institution? _selectedFilterInstitution;
  
  // YENİ: String yerine District nesnesi tutuyoruz
  District? _selectedFilterDistrict; 
  List<District> _districtsList = [];

  @override
  void initState() {
    super.initState();
    _fetchDistricts(); // Sayfa açılırken ilçeleri çek
    _fetchData();
  }

  @override
  void dispose() {
    _nameSearchController.dispose();
    super.dispose();
  }

  // --- YENİ: İLÇELERİ BACKEND'DEN ÇEK ---
  Future<void> _fetchDistricts() async {
    try {
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

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final staffResponse = await http.get(Uri.parse(ApiConstants.staffEndpoint));
      final instResponse = await http.get(Uri.parse(ApiConstants.institutionsEndpoint));

      if (staffResponse.statusCode == 200 && instResponse.statusCode == 200) {
        if(mounted) {
          setState(() {
            allStaffList = json.decode(utf8.decode(staffResponse.bodyBytes));
            final List<dynamic> instJson = json.decode(utf8.decode(instResponse.bodyBytes));
            allInstitutions = instJson.map((data) => Institution.fromJson(data)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Veri Çekme Hatası: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _normalizeTr(String text) {
    return text.replaceAll('I', 'ı').replaceAll('İ', 'i').replaceAll('Ş', 'ş').replaceAll('Ç', 'ç').replaceAll('Ö', 'ö').replaceAll('Ğ', 'ğ').replaceAll('Ü', 'ü').toLowerCase();
  }

  void _showInstitutionSearchDialog(Institution? currentSelection, Function(Institution?) onSelected, {bool isFilter = false}) {
    TextEditingController searchCtrl = TextEditingController();
    List<Institution> filteredList = List.from(allInstitutions);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              contentPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: "Kurum veya ilçe ara...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          String query = _normalizeTr(val);
                          filteredList = allInstitutions.where((inst) {
                            // YENİ: inst.ilce yerine inst.ilceAdi kullanıldı
                            return _normalizeTr(inst.ad).contains(query) || _normalizeTr(inst.ilceAdi).contains(query);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (isFilter)
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        tileColor: Colors.red.shade50,
                        leading: const Icon(Icons.clear_all, color: Colors.red),
                        title: const Text("Tüm Kurumlar (Filtreyi Temizle)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                        onTap: () {
                          onSelected(null);
                          Navigator.pop(context);
                        },
                      ),
                    Expanded(
                      child: filteredList.isEmpty 
                      ? const Center(child: Text("Sonuç bulunamadı."))
                      : ListView.builder(
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final inst = filteredList[index];
                            bool isSelected = currentSelection?.id == inst.id;
                            return ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              tileColor: isSelected ? Colors.blue.shade50 : null,
                              leading: Icon(
                                inst.tipi == "Kan Merkezi" ? Icons.bloodtype : Icons.local_hospital,
                                color: inst.tipi == "Kan Merkezi" ? Colors.red : Colors.blue,
                              ),
                              title: Text(inst.ad, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              // YENİ: inst.ilce yerine inst.ilceAdi kullanıldı
                              subtitle: Text(inst.ilceAdi, style: const TextStyle(fontSize: 12)),
                              onTap: () {
                                onSelected(inst);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _showDistrictSearchDialog(District? currentSelection, Function(District?) onSelected) {
    TextEditingController searchCtrl = TextEditingController();
    List<District> filteredList = List.from(_districtsList);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              contentPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.5,
                child: Column(
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: "İlçe ara...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          String query = _normalizeTr(val);
                          filteredList = _districtsList.where((d) => _normalizeTr(d.name).contains(query)).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      tileColor: Colors.red.shade50,
                      leading: const Icon(Icons.clear_all, color: Colors.red),
                      title: const Text("Tüm İlçeler (Filtreyi Temizle)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                      onTap: () {
                        onSelected(null);
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: filteredList.isEmpty 
                      ? const Center(child: Text("Sonuç bulunamadı."))
                      : ListView.builder(
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final dist = filteredList[index];
                            bool isSelected = currentSelection?.id == dist.id;
                            return ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              tileColor: isSelected ? Colors.blue.shade50 : null,
                              leading: Icon(Icons.location_on_outlined, color: isSelected ? Colors.blue : Colors.grey),
                              title: Text(dist.name, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              onTap: () {
                                onSelected(dist);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _showAddStaffForm() {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController passwordCtrl = TextEditingController();
    final TextEditingController customTitleCtrl = TextEditingController();

    final List<String> unvanListesi = ["Kan Merkezi Sorumlusu", "Başhekim", "Doktor", "Hemşire", "Laborant", "Diğer"];
    String selectedTitle = unvanListesi.first;
    Institution? formSelectedInstitution;
    
    String? formErrorMessage;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88, 
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 24, right: 24, top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(Icons.manage_accounts, color: Color(0xFF2C3E50), size: 28),
                        SizedBox(width: 10),
                        Text("Sisteme Personel Ekle", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Personel bilgilerini girip görev yapacağı kurumu arayarak seçin.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 25),

                    GestureDetector(
                      onTap: () {
                        if(isSubmitting) return; 
                        _showInstitutionSearchDialog(formSelectedInstitution, (secilen) {
                          setModalState(() {
                            formSelectedInstitution = secilen;
                            formErrorMessage = null; 
                          });
                        }, isFilter: false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (formErrorMessage != null && formSelectedInstitution == null) 
                                   ? Colors.red.shade300 
                                   : (formSelectedInstitution != null ? Colors.blue.shade200 : Colors.transparent)
                          )
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.local_hospital_outlined, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                formSelectedInstitution != null 
                                    // YENİ: formSelectedInstitution!.ilceAdi kullanıldı
                                    ? "${formSelectedInstitution!.ad} (${formSelectedInstitution!.ilceAdi})" 
                                    : "Görev Yapacağı Kurumu Ara / Seç",
                                style: TextStyle(
                                  color: formSelectedInstitution != null ? Colors.blue.shade900 : Colors.grey.shade600,
                                  fontSize: 15,
                                  fontWeight: formSelectedInstitution != null ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.search, color: Colors.blue.shade700),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    _buildModernFormTextField(nameCtrl, "Ad Soyad", Icons.person_outline, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))], onChanged: (v) => setModalState(() => formErrorMessage = null), enabled: !isSubmitting),
                    const SizedBox(height: 15),
                    _buildModernFormTextField(emailCtrl, "E-posta Adresi", Icons.email_outlined, onChanged: (v) => setModalState(() => formErrorMessage = null), enabled: !isSubmitting),
                    const SizedBox(height: 15),
                    _buildModernFormTextField(passwordCtrl, "Geçici Şifre", Icons.lock_outline, isPassword: true, onChanged: (v) => setModalState(() => formErrorMessage = null), enabled: !isSubmitting),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: selectedTitle,
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined, color: Colors.grey.shade600),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: unvanListesi.map((unvan) => DropdownMenuItem(value: unvan, child: Text(unvan))).toList(),
                      onChanged: isSubmitting ? null : (yeniDeger) {
                        if (yeniDeger != null) {
                          setModalState(() {
                            selectedTitle = yeniDeger;
                            formErrorMessage = null;
                          });
                        }
                      },
                    ),

                    if (selectedTitle == "Diğer") ...[
                      const SizedBox(height: 15),
                      _buildModernFormTextField(customTitleCtrl, "Lütfen ünvanı yazınız", Icons.edit_outlined, onChanged: (v) => setModalState(() => formErrorMessage = null), enabled: !isSubmitting),
                    ],
                    
                    const SizedBox(height: 25),

                    if (formErrorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
                            const SizedBox(width: 10),
                            Expanded(child: Text(formErrorMessage!, style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C3E50),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isSubmitting ? null : () async {
                          setModalState(() => formErrorMessage = null);

                          if (formSelectedInstitution == null) {
                            setModalState(() => formErrorMessage = "Lütfen görev yapılacak kurumu seçiniz.");
                            return;
                          }
                          if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
                            setModalState(() => formErrorMessage = "Lütfen Ad Soyad, E-posta ve Şifre alanlarını boş bırakmayınız.");
                            return;
                          }
                          if (passwordCtrl.text.length < 6) {
                            setModalState(() => formErrorMessage = "Şifre en az 6 karakter uzunluğunda olmalıdır.");
                            return;
                          }
                          
                          String finalTitle = selectedTitle == "Diğer" ? customTitleCtrl.text.trim() : selectedTitle;
                          if (selectedTitle == "Diğer" && finalTitle.isEmpty) {
                            setModalState(() => formErrorMessage = "Lütfen özel ünvanı yazınız.");
                            return;
                          }

                          setModalState(() => isSubmitting = true);

                          try {
                            final body = {
                              "email": emailCtrl.text.trim(),
                              "password": passwordCtrl.text.trim(),
                              "ad_soyad": nameCtrl.text.trim(),
                              "kurum_id": formSelectedInstitution!.id.toString(), // UUID güvencesi
                              "unvan": finalTitle,
                              "personel_no": "P-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}"
                            };

                            final response = await http.post(
                                    Uri.parse(ApiConstants.staffEndpoint),
                                    headers: {"Content-Type": "application/json"},
                                    body: json.encode(body),
                                  );

                            if (response.statusCode == 200) {
                              Navigator.pop(context);
                              _fetchData(); 
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Personel başarıyla atandı!"), backgroundColor: Colors.green.shade600));
                            } else {
                              String errorDetail = "Bir hata oluştu (${response.statusCode})";
                              try {
                                final errJson = json.decode(utf8.decode(response.bodyBytes));
                                if (errJson['detail'] != null) {
                                  if (errJson['detail'] is List) {
                                    errorDetail = "Girdiğiniz bilgilerden bazıları geçersiz. Lütfen formatları kontrol edin.";
                                  } else {
                                    errorDetail = errJson['detail'];
                                  }
                                }
                              } catch(e) {}
                              setModalState(() => formErrorMessage = errorDetail);
                            }
                          } catch (e) {
                            setModalState(() => formErrorMessage = "Sunucuya bağlanılamadı. Lütfen bağlantınızı kontrol edin.");
                          } finally {
                            setModalState(() => isSubmitting = false);
                          }
                        },
                        child: isSubmitting 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Sisteme Kaydet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildModernFormTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false, List<TextInputFormatter>? formatters, Function(String)? onChanged, bool enabled = true}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      inputFormatters: formatters,
      onChanged: onChanged,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        filled: true,
        fillColor: enabled ? Colors.grey.shade100 : Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildFilterTextField(TextEditingController controller, String hint, IconData icon) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
      ),
      child: TextField(
        controller: controller,
        onChanged: (value) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String nameQuery = _normalizeTr(_nameSearchController.text);

    final List<dynamic> processedStaffList = allStaffList.where((staff) {
      final String staffName = _normalizeTr(staff['ad_soyad'] ?? "");
      final String? staffInstId = staff['kurum_id'];
      
      final inst = allInstitutions.where((i) => i.id == staffInstId).firstOrNull;
      
      // YENİ: inst.ilce yerine inst.ilceAdi üzerinden arama yapıyoruz
      final String staffDistrict = inst != null ? _normalizeTr(inst.ilceAdi) : "";

      final bool matchesName = staffName.contains(nameQuery);
      
      // YENİ: _selectedFilterDistrict artık District objesi olduğu için .name üzerinden kontrol ediyoruz
      final bool matchesDistrict = _selectedFilterDistrict == null || staffDistrict == _normalizeTr(_selectedFilterDistrict!.name);
      
      final bool matchesInstitution = _selectedFilterInstitution == null || _selectedFilterInstitution!.id == staffInstId;

      return matchesName && matchesDistrict && matchesInstitution;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffForm,
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text("Yeni Personel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2C3E50),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text("Genel Personel Yönetimi", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text("Sistemdeki tüm hastane ve kan merkezi çalışanlarını buradan yönetebilirsiniz.", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 5, child: _buildFilterTextField(_nameSearchController, "Personel İsmine Göre...", Icons.person_search)),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4, 
                        child: GestureDetector(
                          onTap: () {
                            _showDistrictSearchDialog(_selectedFilterDistrict, (secilen) {
                              setState(() => _selectedFilterDistrict = secilen);
                            });
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
                              border: Border.all(color: _selectedFilterDistrict != null ? Colors.blue.shade300 : Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_city, size: 18, color: _selectedFilterDistrict != null ? Colors.blue : Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    // YENİ: _selectedFilterDistrict artık obje
                                    _selectedFilterDistrict?.name ?? "İlçe Seç...",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedFilterDistrict != null ? Colors.blue.shade700 : Colors.grey.shade400,
                                      fontWeight: _selectedFilterDistrict != null ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_selectedFilterDistrict != null)
                                  GestureDetector(
                                    onTap: () => setState(() => _selectedFilterDistrict = null),
                                    child: const Icon(Icons.close, size: 16, color: Colors.blue),
                                  ),
                              ],
                            ),
                          ),
                        )
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  GestureDetector(
                    onTap: () {
                      _showInstitutionSearchDialog(_selectedFilterInstitution, (secilen) {
                        setState(() => _selectedFilterInstitution = secilen);
                      }, isFilter: true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
                        border: Border.all(color: _selectedFilterInstitution != null ? Colors.red.shade300 : Colors.transparent)
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.filter_alt_outlined, color: _selectedFilterInstitution != null ? Colors.red : Colors.grey.shade600, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedFilterInstitution != null 
                                  ? "Filtre: ${_selectedFilterInstitution!.ad}" 
                                  : "Özel Bir Kuruma Göre Filtrele",
                              style: TextStyle(
                                color: _selectedFilterInstitution != null ? Colors.red.shade700 : Colors.grey.shade500,
                                fontSize: 13,
                                fontWeight: _selectedFilterInstitution != null ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedFilterInstitution != null)
                            const Icon(Icons.close, color: Colors.red, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Personel Listesi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2C3E50))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      "${processedStaffList.length} Kayıt", 
                      style: const TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : processedStaffList.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text("Arama kriterlerine uygun personel bulunamadı.", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final staff = processedStaffList[index]; 
                            
                            final inst = allInstitutions.where((i) => i.id == staff['kurum_id']).firstOrNull;
                            bool isBloodBank = inst?.tipi == "Kan Merkezi";
                            Color themeColor = isBloodBank ? const Color(0xFFE53935) : const Color(0xFF1E88E5);
                            
                            String adSoyad = staff['ad_soyad'] ?? "Bilinmiyor";
                            String kurumAdi = staff['kurum_adi'] ?? "Kurum Atanmamış";
                            String unvan = staff['unvan'] ?? "Ünvan Yok";
                            String email = staff['email'] ?? "E-posta Yok";

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: themeColor.withOpacity(0.1),
                                  child: Icon(Icons.person, color: themeColor),
                                ),
                                title: Text(adSoyad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2C3E50))),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(isBloodBank ? Icons.bloodtype : Icons.local_hospital, size: 12, color: themeColor),
                                            const SizedBox(width: 4),
                                            Flexible(child: Text(kurumAdi, style: TextStyle(fontSize: 11, color: themeColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(unvan, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.grey), 
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => StaffSettingsScreen(
                                          staff: staff, 
                                          allInstitutions: allInstitutions, 
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      _fetchData();
                                    }
                                  }
                                ),
                              ),
                            );
                          },
                          childCount: processedStaffList.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }
}