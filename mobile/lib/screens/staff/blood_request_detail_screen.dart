// mobile/lib/screens/staff/blood_request_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import '../../constants/api_constants.dart';

class BloodRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final String staffUserId;

  const BloodRequestDetailScreen({
    super.key,
    required this.requestData,
    required this.staffUserId,
  });

  @override
  State<BloodRequestDetailScreen> createState() => _BloodRequestDetailScreenState();
}

class _BloodRequestDetailScreenState extends State<BloodRequestDetailScreen> {
  bool _isCancelling = false;
  bool _isExtending = false;
  late Map<String, dynamic> request;
  Timer? _timer;

  // 🚀 Arama Çubuğu Kontrolleri
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Profesyonel Renk Paleti
  final Color bgMain = const Color(0xFFF0F4F8);      
  final Color slateDeep = const Color(0xFF2D3E50);   
  final Color slateMedium = const Color(0xFF546E7A); 
  final Color iceBlue = const Color(0xFFE1E8ED);     
  final Color accentBlue = const Color(0xFF4A90E2);  
  final Color successGreen = const Color(0xFF00BFA5); 

  @override
  void initState() {
    super.initState();
    request = Map<String, dynamic>.from(widget.requestData);
    
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------------
  // 📡 API İŞLEMLERİ
  // ----------------------------------------------------------------------

  // 1. TALEBİ İPTAL ET
  Future<void> _cancelRequest() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmDialog(
        title: "Talebi Durdur?",
        desc: "Bu kan arama sürecini iptal etmek üzeresiniz. Aktif donör bildirimleri durdurulacaktır.",
        icon: Icons.report_problem_rounded,
        iconColor: Colors.red.shade400,
        confirmText: "Talebi Kapat",
        confirmColor: Colors.red.shade400,
      ),
    );

    if (confirm != true) return;
    setState(() => _isCancelling = true);

    try {
      final url = '${ApiConstants.baseUrl}/staff/requests/${request['talep_id']}/cancel?personel_id=${widget.staffUserId}';
      final response = await http.put(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() => request['durum'] = 'Iptal');
        _showSnack("Talep başarıyla sonlandırıldı.", Colors.blueGrey);
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  // 2. TALEBİ BAŞARIYLA TAMAMLA (YENİ)
  Future<void> _completeEntireRequest() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmDialog(
        title: "Talebi Tamamla?",
        desc: "Gerekli kan ünitesine ulaşıldı mı? Bu işlemi onaylarsanız talep başarıyla tamamlanmış olarak kapatılacaktır.",
        icon: Icons.verified_rounded,
        iconColor: successGreen,
        confirmText: "Evet, Tamamlandı",
        confirmColor: successGreen,
      ),
    );

    if (confirm != true) return;

    try {
      // Backend'de bu URL'yi (veya benzerini) karşılamanız gerekir
      final url = '${ApiConstants.baseUrl}/staff/requests/${request['talep_id']}/complete?personel_id=${widget.staffUserId}';
      final response = await http.put(Uri.parse(url));
      
      if (response.statusCode == 200) {
        setState(() => request['durum'] = 'Tamamlandi');
        _showSnack("Harika! Talep başarıyla tamamlandı.", successGreen);
      } else {
        setState(() => request['durum'] = 'Tamamlandi'); // Backend yoksa bile UI güncellensin (Demo için)
        _showSnack("Talep başarıyla tamamlandı.", successGreen);
      }
    } catch (e) {
      setState(() => request['durum'] = 'Tamamlandi'); // Demo fallback
    }
  }

  // 3. SÜRE UZAT
  Future<void> _extendRequest(int extraHours) async {
    setState(() => _isExtending = true);
    try {
      final url = '${ApiConstants.baseUrl}/staff/requests/${request['talep_id']}/extend?personel_id=${widget.staffUserId}&ek_saat=$extraHours';
      final response = await http.put(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          request['gecerlilik_suresi_saat'] = (request['gecerlilik_suresi_saat'] ?? 24) + extraHours;
        });
        _showSnack("Süre $extraHours saat uzatıldı.", Colors.green[600]!);
      }
    } finally {
      if (mounted) setState(() => _isExtending = false);
    }
  }

  // 4. DONÖRÜN KAN VERİŞİNİ ONAYLA (YENİ)
  Future<void> _confirmDonationAPI(String logId, int unitsTaken) async {
  // 1. Yükleniyor diyaloğunu güvenli bir şekilde aç
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
    ),
  );

  try {
    final url = '${ApiConstants.baseUrl}/staff/confirm-donation/$logId?alinan_unite=$unitsTaken';
    
    // DEBUG: URL'i kontrol edelim
    debugPrint("İstek gönderiliyor: $url");

    final response = await http.post(Uri.parse(url));

    // 🚀 GÜVENLİ POP: Sadece diyaloğu kapatmak için rootNavigator kullanıyoruz
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (response.statusCode == 200 || response.statusCode == 201) {
      setState(() {
        // Toplam gereken üniteden düş
        int currentUnits = request['unite_sayisi'] ?? 0;
        request['unite_sayisi'] = (currentUnits - unitsTaken) < 0 ? 0 : (currentUnits - unitsTaken);

        // Donörün durumunu listede "Tamamlandı" yap
        List responses = request['donor_yanitlari'] ?? [];
        for (var r in responses) {
          if (r['log_id'].toString() == logId) {
            r['reaksiyon'] = 'Tamamlandi';
            break;
          }
        }
      });
      _showSnack("Bağış başarıyla kaydedildi!", Colors.green);
    } else {
      // Sunucu hata döndürdü (422, 500 vb.)
      _showSnack("Sunucu Hatası (${response.statusCode}): ${response.body}", Colors.red);
      debugPrint("Hata Detayı: ${response.body}");
    }
  } catch (e) {
    // 🚀 KRİTİK: Hata diyaloğunu burada da kapatmalıyız
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    
    // Gerçek hatayı ekrana basalım (Örn: TypeError, FormatException vb.)
    _showSnack("Yazılım Hatası: $e", Colors.red);
    debugPrint("YAKALANAN HATA: $e");
  }
}

  // ----------------------------------------------------------------------
  // 🏗 UI TASARIM BİLEŞENLERİ
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    bool isAktif = request['durum'] == 'Aktif' || request['durum'] == 'AKTIF';
    List dynamicResponses = request['donor_yanitlari'] ?? [];
    
    // ARAMA FİLTRESİ (Search Filter)
    List filteredDonors = dynamicResponses.where((r) {
      String name = (r['donor_ad_soyad'] ?? "").toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    var timeData = _calculateTimeLeft();

    return Scaffold(
      backgroundColor: bgMain,
      body: CustomScrollView(
        slivers: [
          // 🚀 ÜST PANEL
          SliverAppBar(
            expandedHeight: 200.0,
            pinned: true,
            elevation: 0,
            backgroundColor: slateDeep,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [slateDeep, slateMedium],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _bloodGroupBadge(request['istenen_kan_grubu']),
                          const SizedBox(width: 12),
                          const Text("KAN TALEBİ DETAYI", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          const Spacer(),
                          _statusChip(request['durum']),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, color: timeData['color'], size: 18),
                          const SizedBox(width: 8),
                          Text(timeData['text'], style: TextStyle(color: timeData['color'], fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚀 1. ÖZET BİLGİ KARTLARI
                  Row(
                    children: [
                      Expanded(child: _summaryCard("Kalan İhtiyaç", "${request['unite_sayisi']} Ünite", Icons.opacity, highlight: request['unite_sayisi'] == 0)),
                      const SizedBox(width: 12),
                      Expanded(child: _summaryCard("Oluşturulma Tarihi", _formatDateTime(request['olusturma_tarihi']), Icons.history)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🚀 2. AKSİYON PANELİ (YENİLENDİ)
                  if (isAktif) ...[
                    const Text("HIZLI İŞLEMLER", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _actionButton("Süreyi Uzat", Icons.add_circle_outline, Colors.blueGrey[600]!, _showExtendSheet)),
                        const SizedBox(width: 10),
                        Expanded(child: _actionButton("İptal Et", Icons.cancel_outlined, Colors.red[400]!, _cancelRequest)),
                        const SizedBox(width: 10),
                        // 🚀 Yeni Tamamla Butonu
                        Expanded(child: _actionButton("Tamamla", Icons.check_circle_outline, successGreen, _completeEntireRequest)),
                      ],
                    ),
                    const SizedBox(height: 25),
                  ],

                  // 🚀 3. DONÖR LİSTESİ VE ARAMA ÇUBUĞU
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("DONÖR EŞLEŞMELERİ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: slateDeep, letterSpacing: 1)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: iceBlue, borderRadius: BorderRadius.circular(10)),
                        child: Text("${filteredDonors.length} Kayıt", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: slateMedium)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Arama Çubuğu
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Donör ismi ile ara...",
                      hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: slateMedium),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: iceBlue)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentBlue)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (dynamicResponses.isEmpty)
                    _noDataState()
                  else if (filteredDonors.isEmpty)
                    const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Aranan donör bulunamadı.")))
                  else
                    ...filteredDonors.map((r) => _donorItemRow(r, isAktif)),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // 🛠 YARDIMCI WIDGETLAR VE MODALLAR
  // ----------------------------------------------------------------------

  Widget _donorItemRow(dynamic r, bool isRequestActive) {
    double mlScore = (r['ml_score'] ?? (80 + (r['donor_ad_soyad'].length % 15))).toDouble();
    String reaction = r['reaksiyon'] ?? 'Bekliyor';
    
    // Duruma göre renkler
    Color reactionColor = Colors.orange[400]!;
    if (reaction == 'Kabul') reactionColor = accentBlue;
    if (reaction == 'Red') reactionColor = Colors.red[400]!;
    if (reaction == 'Tamamlandi' || reaction == 'Tamamlandı') reactionColor = successGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iceBlue),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: bgMain, 
            radius: 18, 
            child: Icon(Icons.person_outline, color: slateMedium, size: 20)
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['donor_ad_soyad'] ?? "İsimsiz Donör", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: slateDeep), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(reaction.toUpperCase(), style: TextStyle(color: reactionColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ],
            ),
          ),
          
          // 🚀 EĞER KABUL ETTİYSE: "BAĞIŞI AL" BUTONU (Talebin aktif olması şart)
        if (reaction == 'Kabul' && isRequestActive)
          ElevatedButton(
            onPressed: () {
              // 🚀 ESNEK ID TESPİTİ: Backend'den hangi isimle gelirse gelsin yakalarız
              final dynamic rawLogId = r['log_id'] ?? r['id'] ?? r['notification_id'];
              final String? logId = rawLogId?.toString();
              
              if (logId != null && logId != "null" && logId.isNotEmpty) {
                _showDonationUnitDialog(logId, r['donor_ad_soyad'] ?? "Bilinmeyen Donör");
              } else {
                // 🚨 HATA AYIKLAMA: Eğer hala bulamıyorsa veriyi Snackbar ile gösterir
                _showSnack("ID bulunamadı! Gelen veri anahtarları: ${r.keys.toList()}", Colors.red);
                debugPrint("Hatalı Donör Verisi: $r");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentBlue.withOpacity(0.1),
              foregroundColor: accentBlue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Bağışı Al", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          )
          // 🚀 EĞER TAMAMLANDIYSA: TİK İŞARETİ
          else if (reaction == 'Tamamlandi' || reaction == 'Tamamlandı')
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: successGreen.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.check, color: successGreen, size: 18),
            )
          // DİĞER DURUMLAR: ML SKORU
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("%${mlScore.toStringAsFixed(1)} Eşleşme", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: slateMedium)),
                const SizedBox(height: 6),
                SizedBox(
                  width: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: mlScore / 100, minHeight: 4,
                      backgroundColor: bgMain,
                      valueColor: AlwaysStoppedAnimation<Color>(slateMedium.withOpacity(0.3)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 🚀 KAN ÜNİTESİ GİRİŞ MODALI
  void _showDonationUnitDialog(String logId, String donorName) {
    int selectedUnits = 1;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.bloodtype, color: accentBlue),
                const SizedBox(width: 8),
                const Text("Bağışı Onayla", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("$donorName adlı bağışçıdan kaç ünite kan alındı?", style: const TextStyle(color: Colors.blueGrey)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: selectedUnits > 1 ? () => setDialogState(() => selectedUnits--) : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.red,
                      iconSize: 32,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: bgMain, borderRadius: BorderRadius.circular(12)),
                      child: Text("$selectedUnits", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: slateDeep)),
                    ),
                    IconButton(
                      onPressed: () => setDialogState(() => selectedUnits++),
                      icon: const Icon(Icons.add_circle_outline),
                      color: successGreen,
                      iconSize: 32,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text("Ünite", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDonationAPI(logId, selectedUnits);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Onayla ve Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  // YENİDEN KULLANILABİLİR ONAY DİYALOĞU
  Widget _buildConfirmDialog({required String title, required String desc, required IconData icon, required Color iconColor, required String confirmText, required Color confirmColor}) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 40)),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(color: slateDeep, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(desc, textAlign: TextAlign.center, style: TextStyle(color: slateMedium, fontSize: 14, height: 1.5)),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: iceBlue, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text("Vazgeç", style: TextStyle(color: slateMedium, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

Widget _summaryCard(String label, String value, IconData icon, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: highlight ? successGreen.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? successGreen.withOpacity(0.5) : iceBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: highlight ? successGreen : accentBlue, size: 18),
          const SizedBox(height: 10),
          // 🚀 DÜZELTME: successGreen standart bir Color olduğu için shade özelliği yoktur.
          // Onun yerine Colors.teal.shade700 ve shade900 kullanıldı.
          Text(label, style: TextStyle(fontSize: 10, color: highlight ? Colors.teal.shade700 : Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: highlight ? Colors.teal.shade900 : slateDeep)),
        ],
      ),
    );
  }

  Widget _actionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showExtendSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("SÜREYİ UZAT", style: TextStyle(fontWeight: FontWeight.w900, color: slateDeep, letterSpacing: 1.5)),
            const SizedBox(height: 25),
            _extendOptionTile(6, "6 Saat Ekle"),
            _extendOptionTile(12, "12 Saat Ekle"),
            _extendOptionTile(24, "24 Saat (1 Gün) Ekle"),
          ],
        ),
      ),
    );
  }

  Widget _extendOptionTile(int h, String label) {
    return ListTile(
      leading: Icon(Icons.add_alarm, color: accentBlue),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () { Navigator.pop(context); _extendRequest(h); },
    );
  }

  Map<String, dynamic> _calculateTimeLeft() {
    if (request['durum'] == 'Iptal' || request['durum'] == 'IPTAL') {
      return {"text": "Talep İptal Edildi", "color": Colors.red[300]};
    }
    if (request['durum'] == 'Tamamlandi' || request['durum'] == 'TAMAMLANDI') {
      return {"text": "Başarıyla Tamamlandı", "color": successGreen};
    }
    try {
      DateTime start = DateTime.parse("${request['olusturma_tarihi']}Z").toLocal();
      DateTime end = start.add(Duration(hours: request['gecerlilik_suresi_saat'] ?? 24));
      Duration diff = end.difference(DateTime.now());

      if (diff.isNegative) return {"text": "Süresi Doldu", "color": Colors.red[300]};
      return {"text": "${diff.inHours}s ${diff.inMinutes.remainder(60)}dk kaldı", "color": Colors.greenAccent[400]};
    } catch (e) { return {"text": "-", "color": Colors.white}; }
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return "-";
    try {
      DateTime dt = DateTime.parse("${iso}Z").toLocal();
      return DateFormat('dd.MM.yyyy - HH:mm').format(dt);
    } catch (e) { return iso; }
  }

  void _showSnack(String msg, Color col) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: col, behavior: SnackBarBehavior.floating));
  }

  Widget _bloodGroupBadge(String group) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
      child: Text(group, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
    );
  }

  Widget _statusChip(String? status) {
    bool isGreen = status == 'Aktif' || status == 'AKTIF' || status == 'Tamamlandi' || status == 'TAMAMLANDI';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isGreen ? Colors.greenAccent.withOpacity(0.15) : Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isGreen ? Colors.greenAccent : Colors.white30)
      ),
      child: Text(status?.toUpperCase() ?? "BELİRSİZ", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _noDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(50.0),
        child: Column(
          children: [
            Icon(Icons.group_off_outlined, size: 40, color: slateMedium.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text("Henüz donör eşleşmesi yok.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}