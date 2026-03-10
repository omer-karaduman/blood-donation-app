import 'package:flutter/material.dart';
import 'create_blood_request_screen.dart'; // Yeni oluşturduğumuz ekran
import 'my_blood_requests_screen.dart';     // Yeni oluşturduğumuz ekran

class StaffDashboard extends StatelessWidget {
  // Bu veriler normalde giriş yapan kullanıcının profilinden (Auth/Provider) gelir.
  final String staffName = "Ömer Karaduman";
  final String institutionName = "Ege Üniversitesi Hastanesi";

  const StaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB), // Temiz beyaz tonu
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
                        Text(
                          institutionName,
                          style: const TextStyle(
                            fontSize: 15, 
                            fontWeight: FontWeight.bold, 
                            color: Color(0xFF263238)
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sağ Köşe: Personel İsmi
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "SAĞLIK PERSONELİ",
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.grey.shade500, 
                          letterSpacing: 1.2
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        staffName,
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

            // --- 2. OPERASYONEL KARTLAR (BAĞLANTILAR YAPILDI) ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // YENİ KAN TALEBİ OLUŞTUR
                  _buildStaffActionCard(
                    title: "Yeni Kan Talebi Oluştur",
                    subTitle: "Kan grubu ve ünite miktarı belirleyerek sistem üzerinden talep açın.",
                    icon: Icons.add_moderator_rounded, 
                    color: const Color(0xFFD32F2F), // Kan kırmızısı
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const CreateBloodRequestScreen())
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // TALEPLERİMİ İNCELE
                  _buildStaffActionCard(
                    title: "Açtığım Talepleri İncele",
                    subTitle: "Geçmiş taleplerinizi ve donörlerden gelen yanıtları kontrol edin.",
                    icon: Icons.fact_check_rounded, 
                    color: const Color(0xFF1565C0), // Güven veren mavi
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const MyBloodRequestsScreen())
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

  // Personel İşlem Kartı Tasarımı
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