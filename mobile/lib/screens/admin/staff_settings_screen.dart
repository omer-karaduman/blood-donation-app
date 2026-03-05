import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../../models/institution.dart';

class StaffSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> staff;
  final List<Institution> allInstitutions;

  const StaffSettingsScreen({super.key, required this.staff, required this.allInstitutions});

  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _customTitleCtrl;
  
  late bool _isActive;
  late Institution _selectedInstitution;
  
  // YENİ: Yüklenme ve Hata Durumları
  bool _isSubmitting = false;
  bool _isDeleting = false;
  String? _formErrorMessage;

  final List<String> unvanListesi = ["Kan Merkezi Sorumlusu", "Başhekim", "Doktor", "Hemşire", "Laborant", "Diğer"];
  late String _selectedTitle;

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (e) {
      return 'http://localhost:8000';
    }
    return 'http://localhost:8000';
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.staff['ad_soyad']);
    _emailCtrl = TextEditingController(text: widget.staff['email']);
    _passwordCtrl = TextEditingController(); 
    _customTitleCtrl = TextEditingController();

    _isActive = widget.staff['is_active'] ?? true;
    
    // Kurumu eşleştir
    _selectedInstitution = widget.allInstitutions.firstWhere(
      (inst) => inst.id.toString() == widget.staff['kurum_id'].toString(),
      orElse: () => widget.allInstitutions.first,
    );

    // Ünvanı eşleştir
    String currentTitle = widget.staff['unvan'] ?? "";
    if (unvanListesi.contains(currentTitle)) {
      _selectedTitle = currentTitle;
    } else {
      _selectedTitle = "Diğer";
      _customTitleCtrl.text = currentTitle;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _customTitleCtrl.dispose();
    super.dispose();
  }

  String _normalizeTr(String text) {
    return text.replaceAll('I', 'ı').replaceAll('İ', 'i').replaceAll('Ş', 'ş').replaceAll('Ç', 'ç').replaceAll('Ö', 'ö').replaceAll('Ğ', 'ğ').replaceAll('Ü', 'ü').toLowerCase();
  }

  // --- AKILLI KURUM ARAMA PENCERESİ ---
  void _showInstitutionSearchDialog() {
    TextEditingController searchCtrl = TextEditingController();
    List<Institution> filteredList = List.from(widget.allInstitutions);

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
                          filteredList = widget.allInstitutions.where((inst) {
                            return _normalizeTr(inst.ad).contains(query) || _normalizeTr(inst.ilce).contains(query);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredList.isEmpty 
                      ? const Center(child: Text("Sonuç bulunamadı."))
                      : ListView.builder(
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final inst = filteredList[index];
                            bool isSelected = _selectedInstitution.id == inst.id;
                            return ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              tileColor: isSelected ? Colors.blue.shade50 : null,
                              leading: Icon(
                                inst.tipi == "Kan Merkezi" ? Icons.bloodtype : Icons.local_hospital,
                                color: inst.tipi == "Kan Merkezi" ? Colors.red : Colors.blue,
                              ),
                              title: Text(inst.ad, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              subtitle: Text(inst.ilce, style: const TextStyle(fontSize: 12)),
                              onTap: () {
                                setState(() {
                                  _selectedInstitution = inst;
                                  _formErrorMessage = null; // Seçim yapınca hatayı sil
                                });
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

  // --- GÜNCELLEME İŞLEMİ (INLINE HATA YÖNETİMİ İLE) ---
  Future<void> _updateStaff() async {
    setState(() => _formErrorMessage = null);

    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      setState(() => _formErrorMessage = "Ad Soyad ve E-posta boş bırakılamaz.");
      return;
    }

    String finalTitle = _selectedTitle == "Diğer" ? _customTitleCtrl.text.trim() : _selectedTitle;
    if (finalTitle.isEmpty) {
      setState(() => _formErrorMessage = "Lütfen geçerli bir ünvan girin.");
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final body = {
        "ad_soyad": _nameCtrl.text.trim(),
        "email": _emailCtrl.text.trim(),
        "password": _passwordCtrl.text.trim(), 
        "unvan": finalTitle,
        "kurum_id": _selectedInstitution.id,
        "is_active": _isActive,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/staff/${widget.staff['user_id']}'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Değişiklikler başarıyla kaydedildi!"), backgroundColor: Colors.green.shade600));
          Navigator.pop(context, true); 
        }
      } else {
        String errorDetail = "Güncelleme başarısız (${response.statusCode})";
        try {
          final errJson = json.decode(utf8.decode(response.bodyBytes));
          if (errJson['detail'] != null) errorDetail = errJson['detail'];
        } catch(e) {}
        setState(() => _formErrorMessage = errorDetail);
      }
    } catch (e) {
      setState(() => _formErrorMessage = "Sunucuya bağlanılamadı. Lütfen bağlantınızı kontrol edin.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- SİLME İŞLEMİ ---
  Future<void> _deleteStaff() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text("Kalıcı Silme İşlemi", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Bu personelin hesabı ve sistem erişimi tamamen kalıcı olarak silinecektir. Bu işlem geri alınamaz. Onaylıyor musunuz?", style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal Et", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Evet, Tamamen Sil")
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
      _formErrorMessage = null;
    });

    try {
      final response = await http.delete(Uri.parse('$baseUrl/staff/${widget.staff['user_id']}'));
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personel başarıyla sistemden silindi."), backgroundColor: Colors.red));
          Navigator.pop(context, true); 
        }
      } else {
        setState(() => _formErrorMessage = "Silme işlemi başarısız oldu (${response.statusCode}).");
      }
    } catch (e) {
      setState(() => _formErrorMessage = "Sunucu bağlantı hatası oluştu.");
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // --- MODERN TEXTFIELD MİMARİSİ (Hata temizleme ve kilitlenme destekli) ---
  Widget _buildModernTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false, List<TextInputFormatter>? formatters}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      inputFormatters: formatters,
      enabled: !_isSubmitting && !_isDeleting, // İşlem sırasında kutuları kilitle
      onChanged: (v) => setState(() => _formErrorMessage = null), // Yazı yazılınca hatayı sil
      decoration: InputDecoration(
        labelText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        filled: true,
        fillColor: (_isSubmitting || _isDeleting) ? Colors.grey.shade200 : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text("Personel Ayarları", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. HESAP ERİŞİMİ ---
            const Text("Hesap Erişimi (Yetkilendirme)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
              child: SwitchListTile(
                title: Text(_isActive ? "Hesap Aktif (Sisteme Girebilir)" : "Hesap Dondurulmuş (Giriş Engelli)", 
                  style: TextStyle(fontWeight: FontWeight.bold, color: _isActive ? Colors.green.shade700 : Colors.red.shade700)
                ),
                subtitle: const Text("İşten ayrılan personelin hesabını buradan askıya alabilirsiniz.", style: TextStyle(fontSize: 12)),
                value: _isActive,
                activeColor: Colors.green,
                onChanged: (_isSubmitting || _isDeleting) ? null : (val) => setState(() {
                  _isActive = val;
                  _formErrorMessage = null;
                }),
              ),
            ),
            const SizedBox(height: 25),

            // --- 2. GÖREV YAPTIĞI KURUM ---
            const Text("Görev Yaptığı Kurum", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: (_isSubmitting || _isDeleting) ? null : _showInstitutionSearchDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200)
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_hospital_outlined, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "${_selectedInstitution.ad} (${_selectedInstitution.ilce})",
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // --- 3. KİMLİK VE GÜVENLİK BİLGİLERİ ---
            const Text("Kimlik ve Güvenlik Bilgileri", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
              child: Column(
                children: [
                  _buildModernTextField(_nameCtrl, "Ad Soyad", Icons.person_outline, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))]),
                  const SizedBox(height: 15),
                  
                  _buildModernTextField(_emailCtrl, "E-posta Adresi", Icons.email_outlined),
                  const SizedBox(height: 15),
                  
                  _buildModernTextField(_passwordCtrl, "Yeni Şifre (Değiştirmek istemiyorsanız boş bırakın)", Icons.lock_outline, isPassword: true),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: _selectedTitle,
                    icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.badge_outlined, color: Colors.grey.shade600),
                      filled: true,
                      fillColor: (_isSubmitting || _isDeleting) ? Colors.grey.shade200 : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    items: unvanListesi.map((unvan) => DropdownMenuItem(value: unvan, child: Text(unvan))).toList(),
                    onChanged: (_isSubmitting || _isDeleting) ? null : (val) {
                      if (val != null) setState(() {
                        _selectedTitle = val;
                        _formErrorMessage = null;
                      });
                    },
                  ),

                  if (_selectedTitle == "Diğer") ...[
                    const SizedBox(height: 15),
                    _buildModernTextField(_customTitleCtrl, "Lütfen özel ünvanı yazınız", Icons.edit_outlined),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- INLINE HATA GÖSTERGE ALANI ---
            if (_formErrorMessage != null)
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
                        _formErrorMessage!,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // --- 4. TEHLİKELİ ALAN (SİLME) ---
            const Text("Tehlikeli İşlemler", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50, 
                borderRadius: BorderRadius.circular(16), 
                border: Border.all(color: Colors.red.shade200)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hesabı Tamamen Sil", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("Bu işlem geri alınamaz. Personelin tüm yetkileri iptal edilecek ve veri tabanından kalıcı olarak silinecektir.", style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, 
                        foregroundColor: Colors.white, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: (_isSubmitting || _isDeleting) ? null : _deleteStaff,
                      icon: _isDeleting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.delete_forever),
                      label: Text(_isDeleting ? "Siliniyor..." : "Personeli Sistemden Sil", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C3E50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: (_isSubmitting || _isDeleting) ? null : _updateStaff,
            child: _isSubmitting
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Değişiklikleri Kaydet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}