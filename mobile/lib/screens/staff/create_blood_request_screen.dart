// mobile/lib/screens/staff/create_blood_request_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import '../../constants/api_constants.dart';

class CreateBloodRequestScreen extends StatefulWidget {
  final String staffUserId;
  final String staffName;
  final String institutionName;

  const CreateBloodRequestScreen({
    super.key,
    required this.staffUserId,
    this.staffName = "Yetkili Personel",
    this.institutionName = "Kayıtlı Sağlık Kurumu",
  });

  @override
  State<CreateBloodRequestScreen> createState() =>
      _CreateBloodRequestScreenState();
}

class _CreateBloodRequestScreenState extends State<CreateBloodRequestScreen>
    with TickerProviderStateMixin {
  String? selectedBloodType;
  int unitCount = 1;
  String urgency = "Normal";
  int _selectedDurationHours = 24;
  bool _isLoading = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  final List<Map<String, dynamic>> _durationOptions = [
    {"label": "6 Saat", "value": 6, "icon": Icons.schedule_rounded},
    {"label": "12 Saat", "value": 12, "icon": Icons.schedule_rounded},
    {"label": "1 Gün", "value": 24, "icon": Icons.today_rounded},
    {"label": "2 Gün", "value": 48, "icon": Icons.today_rounded},
    {"label": "3 Gün", "value": 72, "icon": Icons.date_range_rounded},
    {"label": "1 Hafta", "value": 168, "icon": Icons.calendar_month_rounded},
    {"label": "2 Hafta", "value": 336, "icon": Icons.calendar_month_rounded},
  ];

  final Map<String, Map<String, dynamic>> urgencyConfig = {
    "Normal": {
      "color": const Color(0xFF1565C0),
      "bg": const Color(0xFFE3F2FD),
      "icon": Icons.check_circle_outline_rounded,
      "label": "Normal",
    },
    "Acil": {
      "color": const Color(0xFFE65100),
      "bg": const Color(0xFFFFF3E0),
      "icon": Icons.warning_amber_rounded,
      "label": "Acil",
    },
    "Afet": {
      "color": const Color(0xFFB71C1C),
      "bg": const Color(0xFFFFEBEE),
      "icon": Icons.crisis_alert_rounded,
      "label": "Afet",
    },
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> submitRequest() async {
    if (selectedBloodType == null) {
      _showSnackBar("Lütfen ihtiyaç duyulan kan grubunu seçiniz.", isError: true);
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConstants.requestsEndpoint}?personel_id=${widget.staffUserId}'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "istenen_kan_grubu": selectedBloodType,
          "unite_sayisi": unitCount,
          "aciliyet_durumu": urgency,
          "gecerlilik_suresi_saat": _selectedDurationHours,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        "Kan talebi başarıyla oluşturuldu. Akıllı eşleştirmeler başlatıldı.",
                        style: TextStyle(color: Colors.white))),
              ],
            ),
          ),
        );
      } else {
        _showSnackBar("Sunucu Hatası (${response.statusCode}): Talebiniz oluşturulamadı.",
            isError: true);
      }
    } catch (e) {
      debugPrint("Bağlantı Hatası: $e");
      if (!mounted) return;
      _showSnackBar("Sunucuya bağlanılamadı. Lütfen internetinizi kontrol edin.",
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            isError ? const Color(0xFFB71C1C) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          // Gradient Header Arka Plan
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFB71C1C),
                    Color(0xFFD32F2F),
                    Color(0xFFEF5350),
                  ],
                ),
              ),
            ),
          ),

          // Dekoratif daireler
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 40,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // İçerik
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "YENİ KAN TALEBİ",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Talep Oluştur",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Kurum & Personel Cam Kartı
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      widget.staffName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      widget.institutionName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white.withOpacity(0.75),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- ANA FORM ALANI ---
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF4F6F9),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. KAN GRUBU
                              _buildSectionHeader(
                                "İhtiyaç Duyulan Kan Grubu",
                                Icons.bloodtype_rounded,
                                const Color(0xFFD32F2F),
                              ),
                              const SizedBox(height: 14),
                              _buildBloodTypeGrid(),

                              const SizedBox(height: 28),

                              // 2. ÜNİTE
                              _buildSectionHeader(
                                "Talep Edilen Miktar",
                                Icons.water_drop_rounded,
                                const Color(0xFF1565C0),
                              ),
                              const SizedBox(height: 14),
                              _buildUnitCounter(),

                              const SizedBox(height: 28),

                              // 3. ACİLİYET
                              _buildSectionHeader(
                                "Aciliyet Durumu",
                                Icons.local_fire_department_rounded,
                                const Color(0xFFE65100),
                              ),
                              const SizedBox(height: 14),
                              _buildUrgencySelector(),

                              const SizedBox(height: 28),

                              // 4. GEÇERLİLİK SÜRESİ
                              _buildSectionHeader(
                                "Talebin Geçerlilik Süresi",
                                Icons.timer_outlined,
                                const Color(0xFF00695C),
                              ),
                              const SizedBox(height: 14),
                              _buildDurationSelector(),

                              const SizedBox(height: 32),

                              // ÖZET KART
                              if (selectedBloodType != null) _buildSummaryCard(),
                              if (selectedBloodType != null)
                                const SizedBox(height: 24),

                              // GÖNDER BUTONU
                              _buildSubmitButton(),

                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildBloodTypeGrid() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: bloodTypes.map((type) {
        final bool isSelected = selectedBloodType == type;
        return GestureDetector(
          onTap: () => setState(() => selectedBloodType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFD32F2F) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFD32F2F)
                    : Colors.grey.shade200,
                width: isSelected ? 0 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFD32F2F).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Center(
              child: Text(
                type,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF37474F),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUnitCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Azalt butonu
          GestureDetector(
            onTap: () {
              if (unitCount > 1) setState(() => unitCount--);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: unitCount > 1
                    ? const Color(0xFFD32F2F).withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.remove_rounded,
                color: unitCount > 1
                    ? const Color(0xFFD32F2F)
                    : Colors.grey.shade400,
                size: 22,
              ),
            ),
          ),

          // Ünite sayısı ve etiketi
          Column(
            children: [
              Text(
                "$unitCount",
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E),
                  height: 1,
                ),
              ),
              Text(
                "ÜNİTE",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          // Artır butonu
          GestureDetector(
            onTap: () => setState(() => unitCount++),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD32F2F).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencySelector() {
    return Row(
      children: urgencyConfig.keys.map((type) {
        final config = urgencyConfig[type]!;
        final bool isSelected = urgency == type;
        final Color color = config["color"] as Color;
        final Color bg = config["bg"] as Color;
        final IconData icon = config["icon"] as IconData;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => urgency = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade200,
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: isSelected ? Colors.white : color,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _durationOptions.asMap().entries.map((entry) {
          final i = entry.key;
          final option = entry.value;
          final bool isSelected = _selectedDurationHours == option["value"];
          final bool isLast = i == _durationOptions.length - 1;

          return GestureDetector(
            onTap: () =>
                setState(() => _selectedDurationHours = option["value"] as int),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00695C).withOpacity(0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(18) : Radius.zero,
                  bottom: isLast ? const Radius.circular(18) : Radius.zero,
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 13),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? const Color(0xFF00695C)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00695C)
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded,
                                  size: 11, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          option["label"] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF00695C)
                                : Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00695C).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "SEÇİLDİ",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF00695C),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 18,
                      endIndent: 18,
                      color: Colors.grey.shade100,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final urgConf = urgencyConfig[urgency]!;
    final Color urgColor = urgConf["color"] as Color;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF263238),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_rounded,
                  color: Colors.white54, size: 14),
              const SizedBox(width: 6),
              Text(
                "TALEP ÖZETİ",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Kan grubu
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD32F2F).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  selectedBloodType ?? "",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$unitCount Ünite",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: urgColor.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            urgency.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: urgColor == const Color(0xFFB71C1C)
                                  ? Colors.redAccent.shade100
                                  : urgColor == const Color(0xFFE65100)
                                      ? Colors.orange.shade300
                                      : Colors.blue.shade300,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.timer_outlined,
                            size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text(
                          _durationOptions.firstWhere((d) =>
                              d["value"] == _selectedDurationHours)["label"],
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD32F2F),
          disabledBackgroundColor: const Color(0xFFD32F2F).withOpacity(0.6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: const Color(0xFFD32F2F).withOpacity(0.4),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Text(
                    "TALEBİ YAYINLA",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}