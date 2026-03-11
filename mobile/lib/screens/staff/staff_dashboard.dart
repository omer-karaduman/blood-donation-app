// mobile/lib/screens/staff/staff_dashboard.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants/api_constants.dart';
import 'create_blood_request_screen.dart';
import 'my_blood_requests_screen.dart';

class StaffDashboard extends StatefulWidget {
  final String staffUserId;
  final String staffName;
  final String institutionName;

  const StaffDashboard({
    super.key, 
    this.staffUserId = "00000000-0000-0000-0000-000000000000",
    this.staffName = "Görevli Personel",
    this.institutionName = "Sağlık Kurumu",
  });

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  // Dinamik verileri tutacağımız değişkenler
  String _realName = "";
  String _realTitle = "SAĞLIK PERSONELİ";
  String _realInstitution = "Yükleniyor...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Varsayılan değerleri atayalım, internet yavaşsa boş durmasın
    _realName = widget.staffName;
    _realInstitution = widget.institutionName;
    
    // Gerçek verileri backend'den çek
    _fetchMyProfile();
  }

  Future<void> _fetchMyProfile() async {
    try {
      // Tüm personelleri çekip içinden giriş yapan kişiyi buluyoruz
      final response = await http.get(Uri.parse(ApiConstants.staffEndpoint));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        // Kendi user_id'miz ile eşleşen profili bul
        final myProfile = data.firstWhere(
          (s) => s['user_id'] == widget.staffUserId, 
          orElse: () => null
        );

        if (myProfile != null && mounted) {
          setState(() {
            _realName = myProfile['ad_soyad'] ?? widget.staffName;
            _realInstitution = myProfile['kurum_adi'] ?? widget.institutionName;
            
            // Ünvan verisi boş değilse al ve büyük harfe çevir
            if (myProfile['unvan'] != null && myProfile['unvan'].toString().isNotEmpty) {
              _realTitle = myProfile['unvan'].toString().toUpperCase();
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Profil verisi çekilemedi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. ÜST BİLGİ ALANI (SOLDA KURUM, SAĞDA PERSONEL) ---
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sol Köşe: Hastane/Kurum Bilgisi
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "GÖREVLİ KURUM",
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.grey.shade500, 
                            letterSpacing: 1.2
                          ),
                        ),
                        const SizedBox(height: 4),
                        _isLoading 
                          ? SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey.shade300))
                          : Text(
                              _realInstitution,
                              style: const TextStyle(
                                fontSize: 15, 
                                fontWeight: FontWeight.bold, 
                                color: Color(0xFF263238)
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      ],
                    ),
                  ),
                  // Sağ Köşe: Personel İsmi ve Dinamik Ünvanı
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _realTitle, // ARTIK ÜNVAN DİNAMİK GELİYOR (Örn: BAŞHEKİM, HEMŞİRE)
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          color: const Color(0xFFD32F2F), // Ünvanı hafif kırmızıyla vurguladık
                          letterSpacing: 1.2
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _realName, // ARTIK GERÇEK İSİM GELİYOR
                        style: const TextStyle(
                          fontSize: 15, 
                          fontWeight: FontWeight.w600, 
                          color: Color(0xFF263238)
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(indent: 20, endIndent: 20, thickness: 0.5),
            const SizedBox(height: 20),

            // --- 2. OPERASYONEL KARTLAR ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildStaffActionCard(
                    title: "Yeni Kan Talebi Oluştur",
                    subTitle: "Kan grubu ve ünite miktarı belirleyerek sistem üzerinden talep açın.",
                    icon: Icons.add_moderator_rounded, 
                    color: const Color(0xFFD32F2F),
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => CreateBloodRequestScreen(
                            staffUserId: widget.staffUserId,
                            // Talep oluşturma ekranına da gerçek verileri yolluyoruz!
                            staffName: _realName,
                            institutionName: _realInstitution,
                          )
                        )
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildStaffActionCard(
                    title: "Açtığım Talepleri İncele",
                    subTitle: "Geçmiş taleplerinizi ve donörlerden gelen yanıtları kontrol edin.",
                    icon: Icons.fact_check_rounded, 
                    color: const Color(0xFF1565C0),
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => MyBloodRequestsScreen(
                            staffUserId: widget.staffUserId,
                          )
                        )
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffActionCard({
    required String title,
    required String subTitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17, 
                      fontWeight: FontWeight.bold, 
                      color: Color(0xFF263238)
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subTitle,
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.grey.shade600, 
                      height: 1.4
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}