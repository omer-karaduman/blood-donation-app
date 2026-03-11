// mobile/lib/screens/admin/institution_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/institution.dart';
import 'staff_settings_screen.dart';
import '../../constants/api_constants.dart';

class InstitutionDetailScreen extends StatefulWidget {
  final Institution institution;

  const InstitutionDetailScreen({super.key, required this.institution});

  @override
  State<InstitutionDetailScreen> createState() => _InstitutionDetailScreenState();
}

class _InstitutionDetailScreenState extends State<InstitutionDetailScreen> {
  List<dynamic> staffList = [];
  List<Institution> allInstitutions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // --- VERİ ÇEKME SÜRECİ ---
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      // Backend'den bu kuruma özel personelleri ve tüm kurum listesini çeker
      final staffResponse = await http.get(Uri.parse('${ApiConstants.institutionsEndpoint}${widget.institution.id}/staff'));
      final instResponse = await http.get(Uri.parse(ApiConstants.institutionsEndpoint));

      if (staffResponse.statusCode == 200 && instResponse.statusCode == 200) {
        if (mounted) {
          setState(() {
            staffList = json.decode(utf8.decode(staffResponse.bodyBytes));
            final List<dynamic> instJson = json.decode(utf8.decode(instResponse.bodyBytes));
            allInstitutions = instJson.map((data) => Institution.fromJson(data)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Veri çekme hatası: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- PERSONEL EKLEME FORMU ---
  void _showAddStaffForm(Color themeColor) {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController passwordCtrl = TextEditingController();
    final TextEditingController customTitleCtrl = TextEditingController();

    final List<String> unvanListesi = ["Kan Merkezi Sorumlusu", "Başhekim", "Doktor", "Hemşire", "Laborant", "Diğer"];
    String selectedTitle = unvanListesi.first;

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
                    Row(
                      children: [
                        Icon(Icons.person_add_alt_1, color: themeColor, size: 28),
                        const SizedBox(width: 10),
                        const Text("Yeni Personel Ata", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("${widget.institution.ad} birimi için yeni personel hesabı oluşturun.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 25),

                    _buildModernTextField(nameCtrl, "Ad Soyad", Icons.person_outline, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))], enabled: !isSubmitting),
                    const SizedBox(height: 15),
                    _buildModernTextField(emailCtrl, "E-posta Adresi", Icons.email_outlined, enabled: !isSubmitting),
                    const SizedBox(height: 15),
                    _buildModernTextField(passwordCtrl, "Geçici Şifre", Icons.lock_outline, isPassword: true, enabled: !isSubmitting),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: selectedTitle,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      items: unvanListesi.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: isSubmitting ? null : (v) => setModalState(() => selectedTitle = v!),
                    ),

                    if (selectedTitle == "Diğer") ...[
                      const SizedBox(height: 15),
                      _buildModernTextField(customTitleCtrl, "Ünvan Yazınız", Icons.edit_outlined, enabled: !isSubmitting),
                    ],
                    
                    if (formErrorMessage != null) ...[
                      const SizedBox(height: 15),
                      Text(formErrorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: isSubmitting ? null : () async {
                          setModalState(() => isSubmitting = true);
                          try {
                            final body = {
                              "email": emailCtrl.text.trim(),
                              "password": passwordCtrl.text.trim(),
                              "ad_soyad": nameCtrl.text.trim(),
                              "kurum_id": widget.institution.id, 
                              "unvan": selectedTitle == "Diğer" ? customTitleCtrl.text : selectedTitle,
                              "personel_no": "P-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}"
                            };

                            final res = await http.post(Uri.parse(ApiConstants.staffEndpoint), headers: {"Content-Type": "application/json"}, body: json.encode(body));

                            if (res.statusCode == 200) {
                              Navigator.pop(context);
                              _fetchData();
                            } else {
                              setModalState(() => formErrorMessage = "Hata: ${res.statusCode}");
                            }
                          } catch (e) {
                            setModalState(() => formErrorMessage = "Bağlantı hatası");
                          } finally {
                            setModalState(() => isSubmitting = false);
                          }
                        },
                        child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Kaydet ve Ata", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildModernTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false, List<TextInputFormatter>? formatters, bool enabled = true}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      inputFormatters: formatters,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isBloodBank = widget.institution.tipi == "Kan Merkezi";
    Color themeColor = isBloodBank ? const Color(0xFFE53935) : const Color(0xFF1E88E5);
    Color lightColor = isBloodBank ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStaffForm(themeColor),
        backgroundColor: themeColor,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Personel Ata", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: themeColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.institution.ad, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [themeColor, themeColor.withOpacity(0.6)])),
                child: Center(child: Icon(isBloodBank ? Icons.bloodtype : Icons.local_hospital, size: 80, color: Colors.white24)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Görevli Personeller", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("${staffList.length} Personel", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          isLoading
            ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            : staffList.isEmpty
              ? const SliverFillRemaining(child: Center(child: Text("Kayıtlı personel bulunamadı.")))
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final staff = staffList[index];
                        String ad = staff['ad_soyad'] ?? "İsimsiz";
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: lightColor, child: Text(ad[0].toUpperCase(), style: TextStyle(color: themeColor))),
                            title: Text(ad, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${staff['unvan']}\n${staff['email']}"),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: () async {
                                final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => StaffSettingsScreen(staff: staff, allInstitutions: allInstitutions)));
                                if (res == true) _fetchData();
                              },
                            ),
                          ),
                        );
                      },
                      childCount: staffList.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}