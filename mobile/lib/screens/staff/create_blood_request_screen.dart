import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/api_constants.dart';

class CreateBloodRequestScreen extends StatefulWidget {
  // Login sonrası backend'den gelen gerçek veriler buraya parametre olarak geçilecek
  final String staffUserId;
  final String staffName;
  final String institutionName;

  const CreateBloodRequestScreen({
    super.key,
    required this.staffUserId,
    this.staffName = "Yetkili Personel", // Veri gelmezse varsayılan
    this.institutionName = "Kayıtlı Sağlık Kurumu", // Veri gelmezse varsayılan
  });

  @override
  State<CreateBloodRequestScreen> createState() => _CreateBloodRequestScreenState();
}

class _CreateBloodRequestScreenState extends State<CreateBloodRequestScreen> {
  // Form Değişkenleri
  String? selectedBloodType;
  int unitCount = 1;
  String urgency = "Normal";
  
  bool _isLoading = false; // Çift tıklamayı önlemek için loading state

  final List<String> bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  Future<void> submitRequest() async {
    if (selectedBloodType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen ihtiyaç duyulan kan grubunu seçiniz.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Artık hardcoded ID yerine login olan personelin gerçek ID'si gidiyor
      final response = await http.post(
        Uri.parse('${ApiConstants.requestsEndpoint}?personel_id=${widget.staffUserId}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "istenen_kan_grubu": selectedBloodType,
          "unite_sayisi": unitCount,
          "aciliyet_durumu": urgency,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true); // Geri dönerken true gönder, listeyi yenilesin
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green, 
            content: Text("Kan talebi başarıyla oluşturuldu. Akıllı eşleştirmeler başlatıldı.")
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade600, 
            content: Text("Sunucu Hatası (${response.statusCode}): Talebiniz oluşturulamadı.")
          ),
        );
      }
    } catch (e) {
      debugPrint("Bağlantı Hatası: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sunucuya bağlanılamadı. Lütfen internetinizi kontrol edin.")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text(
          "Yeni Kan Talebi", 
          style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 18)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF263238)),
      ),
      body: Column(
        children: [
          // Dinamik verilerle çalışan bilgi çubuğu
          _buildInfoBar(),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("İhtiyaç Duyulan Kan Grubu"),
                  const SizedBox(height: 12),
                  _buildBloodTypeSelector(),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle("Talep Edilen Miktar (Ünite)"),
                  const SizedBox(height: 12),
                  _buildUnitCounter(),

                  const SizedBox(height: 32),
                  _buildSectionTitle("Aciliyet Durumu"),
                  const SizedBox(height: 12),
                  _buildUrgencySelector(),
                  
                  const SizedBox(height: 50),
                  
                  // Talebi Yayınla Butonu (Yükleniyor Animasyonlu)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(
                            width: 24, height: 24, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Text(
                            "TALEBİ YAYINLA",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _buildInfoItem("KURUM", widget.institutionName, CrossAxisAlignment.start)),
          Expanded(child: _buildInfoItem("GÖREVLİ", widget.staffName, CrossAxisAlignment.end)),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, CrossAxisAlignment alignment) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.1)),
        const SizedBox(height: 2),
        Text(
          value, 
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF455A64), letterSpacing: 0.5),
    );
  }

  Widget _buildBloodTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedBloodType,
          hint: const Text("Grup Seçin", style: TextStyle(fontSize: 14)),
          isExpanded: true,
          items: bloodTypes.map((String type) {
            return DropdownMenuItem<String>(
              value: type, 
              child: Text(type, style: const TextStyle(fontWeight: FontWeight.bold))
            );
          }).toList(),
          onChanged: (val) => setState(() => selectedBloodType = val),
        ),
      ),
    );
  }

  Widget _buildUnitCounter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCounterButton(Icons.remove, () {
          if (unitCount > 1) setState(() => unitCount--);
        }),
        Container(
          width: 100,
          alignment: Alignment.center,
          child: Text("$unitCount", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
        ),
        _buildCounterButton(Icons.add, () => setState(() => unitCount++)),
      ],
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF263238), size: 28),
      ),
    );
  }

  Widget _buildUrgencySelector() {
    return Row(
      children: ["Normal", "Acil", "Afet"].map((type) {
        bool isSelected = urgency == type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Container(width: double.infinity, alignment: Alignment.center, child: Text(type)),
              selected: isSelected,
              onSelected: (val) => setState(() => urgency = type),
              selectedColor: const Color(0xFFD32F2F).withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFD32F2F) : Colors.grey.shade600, 
                fontWeight: FontWeight.bold,
                fontSize: 13
              ),
              side: BorderSide(color: isSelected ? const Color(0xFFD32F2F) : Colors.grey.shade300),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      }).toList(),
    );
  }
}