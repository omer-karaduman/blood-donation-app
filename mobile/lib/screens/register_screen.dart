// mobile/lib/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';
import '../models/institution.dart'; 

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // --- FORM KEY'LERİ ---
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // --- ADIM 1: KİMLİK BİLGİLERİ ---
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _birthDateController = TextEditingController();

  // --- ADIM 2: İLETİŞİM VE KONUM ---
  final _phoneController = TextEditingController();
  
  District? _selectedDistrict;
  Neighborhood? _selectedNeighborhood;
  List<District> _districtsList = [];
  List<Neighborhood> _neighborhoodsList = [];
  bool _isLoadingNeighborhoods = false;

  // --- ADIM 3: SAĞLIK BİLGİLERİ ---
  String? _selectedBloodType;
  String? _selectedGender; 
  final _weightController = TextEditingController();

  final List<String> bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _fetchDistricts(); 
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    super.dispose();
  }

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

  Future<void> _fetchNeighborhoods(String districtId) async {
    if (!mounted) return;
    setState(() {
      _isLoadingNeighborhoods = true;
      _selectedNeighborhood = null;
      _neighborhoodsList = [];
    });

    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/locations/districts/$districtId/neighborhoods'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _neighborhoodsList = data.map((n) => Neighborhood.fromJson(n)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Mahalle verisi çekilemedi: $e");
    } finally {
      if (mounted) setState(() => _isLoadingNeighborhoods = false);
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000), 
      firstDate: DateTime(1950), 
      lastDate: DateTime.now().subtract(const Duration(days: 6570)), 
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE53935), 
              onPrimary: Colors.white, 
              onSurface: Color(0xFF263238), 
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_formKey1.currentState!.validate()) setState(() => _currentStep++);
    } 
    else if (_currentStep == 1) {
      if (_formKey2.currentState!.validate()) setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // ==========================================================
  // AKILLI KAYIT (GEOCODING) İŞLEMİ (OSM + 3 Kademeli Arama)
  // ==========================================================
  Future<void> _submitRegistration() async {
    if (!_formKey3.currentState!.validate()) return;
    if (_selectedBloodType == null || _selectedGender == null) {
      _showError("Lütfen kan grubu ve cinsiyet seçiniz.");
      return;
    }

    setState(() => _isLoading = true);

    double? targetLat;
    double? targetLon;

    // 1. ADRESİ KOORDİNATA ÇEVİR (Akıllı Türkçe Metin Filtresi ile)
    try {
      String dName = _selectedDistrict?.name ?? "";
      String rawNName = _selectedNeighborhood?.name ?? "";
      
      // HARİKA HİLE: Dart diline uygun Case-Insensitive (Büyük/Küçük harf duyarsız) regex
      String cleanNName = rawNName.replaceAll(RegExp(r'\s+Mah\.?$|\s+Mahallesi$', caseSensitive: false), '').trim();

      // Nominatim için özel User-Agent (Bloklanmamak için önemli)
      final headers = {'User-Agent': 'IzmirBloodDonationApp/1.0 (StudentProject)'};

      // AŞAMA 1: Tam "Mahallesi" ekiyle ara (OSM bunu çok sever)
      String query1 = "$cleanNName Mahallesi, $dName, İzmir, Türkiye";
      debugPrint("Koordinat aranıyor (Aşama 1): $query1");
      
      var response = await http.get(Uri.parse("https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query1)}&format=json&limit=1"), headers: headers);
      var data = json.decode(response.body);

      if (data.isNotEmpty) {
        targetLat = double.parse(data[0]['lat']);
        targetLon = double.parse(data[0]['lon']);
        debugPrint("✅ Aşama 1 Başarılı! Mahalle bulundu: $targetLat, $targetLon");
      } else {
        
        // AŞAMA 2: Sadece yalın isimle ara (Örn: "Aşağıılgındere, Bergama" - Köyden mahalleye dönenler için)
        String query2 = "$cleanNName, $dName, İzmir, Türkiye";
        debugPrint("Mahalle ekiyle bulunamadı. Koordinat aranıyor (Aşama 2): $query2");
        
        response = await http.get(Uri.parse("https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query2)}&format=json&limit=1"), headers: headers);
        data = json.decode(response.body);

        if (data.isNotEmpty) {
          targetLat = double.parse(data[0]['lat']);
          targetLon = double.parse(data[0]['lon']);
          debugPrint("✅ Aşama 2 Başarılı! Belde/Köy bulundu: $targetLat, $targetLon");
        } else {
          
          // AŞAMA 3: Hiçbiri bulunmazsa SADECE İLÇE merkezini ara
          String query3 = "$dName, İzmir, Türkiye";
          debugPrint("Yalın isim de bulunamadı. Sadece İlçe aranıyor (Aşama 3): $query3");
          
          response = await http.get(Uri.parse("https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query3)}&format=json&limit=1"), headers: headers);
          data = json.decode(response.body);

          if (data.isNotEmpty) {
            targetLat = double.parse(data[0]['lat']);
            targetLon = double.parse(data[0]['lon']);
            debugPrint("⚠️ Aşama 3 Başarılı! Mahalle bulunamadı, İlçe merkezi atandı: $targetLat, $targetLon");
          }
        }
      }
    } catch (e) {
      debugPrint("❌ OpenStreetMap servisine ulaşılamadı. Hata: $e");
      targetLat = 38.4237; 
      targetLon = 27.1428; // Konak Meydan
    }

    // 2. BACKEND'E VERİYİ GÖNDER
    try {
      final body = {
        "ad_soyad": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
        "dogum_tarihi": _birthDateController.text.trim(), 
        "telefon": _phoneController.text.trim(),
        "kan_grubu": _selectedBloodType,
        "cinsiyet": _selectedGender, 
        "kilo": double.tryParse(_weightController.text.trim()) ?? 0.0,
        "neighborhood_id": _selectedNeighborhood?.id,
        "latitude": targetLat, 
        "longitude": targetLon, 
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/register/donor/'), 
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kayıt başarılı! Giriş yapabilirsiniz."), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      } else {
        String errorMsg = "Kayıt başarısız oldu (${response.statusCode}).";
        try {
          final errData = json.decode(utf8.decode(response.bodyBytes));
          if (errData['detail'] != null) {
            if (errData['detail'] is List) {
              List<String> errorDetails = [];
              for (var err in errData['detail']) {
                String fieldName = (err['loc'] != null && err['loc'].length > 1) 
                    ? err['loc'].last.toString() 
                    : "Alan";
                String msg = err['msg'] ?? "Hatalı format";
                errorDetails.add("• $fieldName: $msg");
              }
              errorMsg = "Lütfen şu alanları düzeltin:\n" + errorDetails.join("\n");
            } else {
              errorMsg = errData['detail'].toString(); 
            }
          }
        } catch(e) {}
        
        _showError(errorMsg);
      }
    } catch (e) {
      _showError("Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700, 
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF263238)),
          onPressed: () {
            if (_currentStep == 0) {
              Navigator.pop(context);
            } else {
              _previousStep();
            }
          },
        ),
        title: const Text("Donör Kaydı", style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildCustomStepper(),
            const SizedBox(height: 30),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomStepper() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          _buildStepCircle(0, Icons.person_outline, "Kimlik"),
          _buildStepLine(0),
          _buildStepCircle(1, Icons.location_on_outlined, "Bölge"), 
          _buildStepLine(1),
          _buildStepCircle(2, Icons.favorite_border, "Sağlık"),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int index, IconData icon, String label) {
    bool isActive = _currentStep >= index;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE53935) : Colors.grey.shade200,
            shape: BoxShape.circle,
            boxShadow: isActive ? [BoxShadow(color: const Color(0xFFE53935).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Icon(icon, color: isActive ? Colors.white : Colors.grey.shade500, size: 22),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? const Color(0xFFE53935) : Colors.grey)),
      ],
    );
  }

  Widget _buildStepLine(int index) {
    bool isActive = _currentStep > index;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 3,
        color: isActive ? const Color(0xFFE53935) : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      default: return const SizedBox();
    }
  }

  // --- ADIM 1: KİMLİK BİLGİLERİ FORM ---
  Widget _buildStep1() {
    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Hesap Bilgileri", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
            const SizedBox(height: 5),
            const Text("Sisteme giriş yapmak için gerekli bilgileriniz.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            TextFormField(
              controller: _nameController,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))],
              validator: (value) => value!.trim().length < 3 ? "Lütfen geçerli bir Ad Soyad girin" : null,
              decoration: const InputDecoration(labelText: "Ad Soyad", prefixIcon: Icon(Icons.badge_outlined)),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _birthDateController,
              readOnly: true, 
              onTap: () => _selectBirthDate(context),
              validator: (value) => value!.isEmpty ? "Doğum tarihi zorunludur" : null,
              decoration: const InputDecoration(
                labelText: "Doğum Tarihi", 
                prefixIcon: Icon(Icons.calendar_month_outlined),
                hintText: "YYYY-AA-GG",
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value!.isEmpty) return "E-posta boş bırakılamaz";
                if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                  return "Lütfen geçerli bir e-posta adresi girin";
                }
                return null;
              },
              decoration: const InputDecoration(labelText: "E-posta Adresi", prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _passwordController,
              obscureText: true,
              validator: (value) => value!.length < 6 ? "Şifre en az 6 karakter olmalıdır" : null,
              decoration: const InputDecoration(labelText: "Şifre Belirleyin", prefixIcon: Icon(Icons.lock_outline)),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(onPressed: _nextStep, child: const Text("Devam Et (İletişim)"))
            ),
          ],
        ),
      ),
    );
  }

  // --- ADIM 2: BÖLGE VE İLETİŞİM BİLGİLERİ FORM ---
  Widget _buildStep2() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("İletişim & Bölge", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
            const SizedBox(height: 5),
            const Text("Size en yakın yardım çağrılarını iletebilmemiz için yaşadığınız bölgeyi seçiniz.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
              validator: (value) => value!.length < 10 ? "Geçerli bir telefon numarası girin (Örn: 05...)" : null,
              decoration: const InputDecoration(labelText: "Cep Telefonu", prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<District>(
              value: _selectedDistrict,
              validator: (value) => value == null ? "Lütfen yaşadığınız ilçeyi seçin" : null,
              decoration: const InputDecoration(
                labelText: "İzmir İlçe", 
                prefixIcon: Icon(Icons.location_city_outlined)
              ),
              items: _districtsList.map((district) {
                return DropdownMenuItem(value: district, child: Text(district.name));
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedDistrict = val;
                });
                if(val != null) {
                  _fetchNeighborhoods(val.id);
                }
              },
            ),
            const SizedBox(height: 20),

            _isLoadingNeighborhoods 
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<Neighborhood>(
                  value: _selectedNeighborhood,
                  validator: (value) => value == null ? "Lütfen mahalle seçin" : null,
                  decoration: const InputDecoration(
                    labelText: "Mahalle", 
                    prefixIcon: Icon(Icons.location_on_outlined)
                  ),
                  items: _neighborhoodsList.map((n) {
                    return DropdownMenuItem(value: n, child: Text(n.name, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: _neighborhoodsList.isEmpty ? null : (val) {
                    setState(() {
                      _selectedNeighborhood = val;
                    });
                  },
                ),

            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _previousStep, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Geri", style: TextStyle(color: Colors.grey)))),
                const SizedBox(width: 15),
                Expanded(flex: 2, child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)), onPressed: _nextStep, child: const Text("Devam Et (Sağlık)"))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- ADIM 3: SAĞLIK BİLGİLERİ FORM ---
  Widget _buildStep3() {
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Form(
        key: _formKey3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Sağlık Bilgileri", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
            const SizedBox(height: 5),
            const Text("Doğru eşleşmeler için temel sağlık verileriniz.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            DropdownButtonFormField<String>(
              value: _selectedBloodType,
              validator: (value) => value == null ? "Kan grubu zorunludur" : null,
              decoration: const InputDecoration(labelText: "Kan Grubunuz", prefixIcon: Icon(Icons.bloodtype_outlined, color: Color(0xFFE53935))),
              items: bloodTypes.map((type) => DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
              onChanged: (val) => setState(() => _selectedBloodType = val),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedGender,
              validator: (value) => value == null ? "Cinsiyet seçimi zorunludur" : null,
              decoration: const InputDecoration(labelText: "Cinsiyetiniz", prefixIcon: Icon(Icons.transgender_outlined)),
              items: const [
                DropdownMenuItem(value: 'E', child: Text('Erkek')),
                DropdownMenuItem(value: 'K', child: Text('Kadın')),
              ],
              onChanged: (val) => setState(() => _selectedGender = val),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              validator: (value) {
                if (value == null || value.isEmpty) return "Kilo zorunludur";
                int? weight = int.tryParse(value);
                if (weight == null || weight < 50) return "Kan bağışı için en az 50 kg olmalısınız";
                return null;
              },
              decoration: const InputDecoration(labelText: "Kilonuz (kg)", prefixIcon: Icon(Icons.monitor_weight_outlined)),
            ),
            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _previousStep, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Geri", style: TextStyle(color: Colors.grey)))),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2, 
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
                    onPressed: _isLoading ? null : _submitRegistration, 
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Kayıt Ol")
                  )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}