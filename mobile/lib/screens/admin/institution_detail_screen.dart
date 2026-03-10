import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/institution.dart';
import 'staff_settings_screen.dart'; 
// 1. SABİTLER DOSYASINI İÇERİ AKTARDIK
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

  // 2. ESKİ 'baseUrl' FONKSİYONUNU TAMAMEN SİLDİK

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // --- ARKA PLANDAN VERİLERİ ÇEKME ---
  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      // 3. API CONSTANTS KULLANARAK İSTEKLERİ GÜNCELLEDİK
      // Not: kurum id'si url'in arasına girdiği için birleştirme yapıyoruz.
      final staffResponse = await http.get(Uri.parse('${ApiConstants.institutionsEndpoint}${widget.institution.id}/staff'));
      final instResponse = await http.get(Uri.parse(ApiConstants.institutionsEndpoint));

      if (staffResponse.statusCode == 200 && instResponse.statusCode == 200) {
        setState(() {
          staffList = json.decode(utf8.decode(staffResponse.bodyBytes));
          
          final List<dynamic> instJson = json.decode(utf8.decode(instResponse.bodyBytes));
          allInstitutions = instJson.map((data) => Institution.fromJson(data)).toList();
        });
      }
    } catch (e) {
      debugPrint("Hata: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --- YENİLENMİŞ VE ŞIK PERSONEL EKLEME FORMU (INLINE HATA İLE) ---
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
                    Center(
                      child: Container(
                        width: 50, height: 5,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Icon(Icons.person_add_alt_1, color: themeColor, size: 28),
                        const SizedBox(width: 10),
                        const Text("Yeni Personel Ata", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Bu kuruma yetkili bir sağlık personeli hesabı oluşturun.", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 25),

                    // İSİM
                    _buildModernTextField(
                      nameCtrl, "Ad Soyad", Icons.person_outline, 
                      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))],
                      onChanged: (v) => setModalState(() => formErrorMessage = null),
                      enabled: !isSubmitting
                    ),
                    const SizedBox(height: 15),

                    // E-POSTA
                    _buildModernTextField(
                      emailCtrl, "E-posta Adresi", Icons.email_outlined,
                      onChanged: (v) => setModalState(() => formErrorMessage = null),
                      enabled: !isSubmitting
                    ),
                    const SizedBox(height: 15),

                    // ŞİFRE
                    _buildModernTextField(
                      passwordCtrl, "Geçici Şifre", Icons.lock_outline, isPassword: true,
                      onChanged: (v) => setModalState(() => formErrorMessage = null),
                      enabled: !isSubmitting
                    ),
                    const SizedBox(height: 15),

                    // ÜNVAN SEÇİCİ
                    DropdownButtonFormField<String>(
                      value: selectedTitle,
                      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined, color: Colors.grey.shade600),
                        filled: true,
                        fillColor: isSubmitting ? Colors.grey.shade200 : Colors.grey.shade100,
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
                      _buildModernTextField(
                        customTitleCtrl, "Lütfen ünvanı yazınız", Icons.edit_outlined,
                        onChanged: (v) => setModalState(() => formErrorMessage = null),
                        enabled: !isSubmitting
                      ),
                    ],
                    
                    const SizedBox(height: 25),

                    // --- INLINE HATA GÖSTERGE ALANI ---
                    if (formErrorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200)
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                formErrorMessage!,
                                style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // --- KAYDET BUTONU ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isSubmitting ? null : () async {
                          setModalState(() => formErrorMessage = null);

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
                              "kurum_id": widget.institution.id, 
                              "unvan": finalTitle,
                              "personel_no": "P-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}"
                            };

                            // 4. PERSONEL KAYDETME İSTEĞİNİ GÜNCELLEDİK
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
                          : const Text("Hesabı Oluştur ve Ata", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // --- MODERN TEXT FIELD MİMARİSİ ---
  Widget _buildModernTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false, List<TextInputFormatter>? formatters, Function(String)? onChanged, bool enabled = true}) {
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

  @override
  Widget build(BuildContext context) {
    bool isBloodBank = widget.institution.tipi == "Kan Merkezi";
    Color themeColor = isBloodBank ? const Color(0xFFE53935) : const Color(0xFF1E88E5);
    Color lightThemeColor = isBloodBank ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStaffForm(themeColor),
        backgroundColor: themeColor,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text("Personel Ata", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240.0,
            floating: false,
            pinned: true,
            backgroundColor: themeColor,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [themeColor, themeColor.withOpacity(0.6)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: Text(widget.institution.tipi, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        Text(widget.institution.ad, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.2)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "${widget.institution.ilce} - ${widget.institution.tamAdres}",
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Kayıtlı Personeller", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2C3E50))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: lightThemeColor, borderRadius: BorderRadius.circular(12)),
                    child: Text("${staffList.length} Kişi", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
          isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : staffList.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text("Henüz personel atanmamış.", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final staff = staffList[index];
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
                                  backgroundColor: lightThemeColor,
                                  child: Text(
                                    staff['ad_soyad'].toString().substring(0, 1).toUpperCase(),
                                    style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                                title: Text(staff['ad_soyad'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2C3E50))),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                                        child: Text(staff['unvan'], style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(staff['email'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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