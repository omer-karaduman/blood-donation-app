// mobile/lib/screens/donor/tabs/donor_requests_tab.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; 
import '../../../constants/api_constants.dart';
import '../../../models/donor.dart';

class DonorRequestsTab extends StatefulWidget {
  final Donor currentUser; 
  
  const DonorRequestsTab({
    super.key, 
    required this.currentUser, 
  });

  @override
  State<DonorRequestsTab> createState() => _DonorRequestsTabState();
}

class _DonorRequestsTabState extends State<DonorRequestsTab> {
  bool _isLoading = true;
  bool _isBackgroundFetching = false; 
  List<dynamic> _requests = [];
  
  // 🚀 KESİN ÇÖZÜM: Kullanıcının aktif görevi olup olmadığını kendi içimizde takip ediyoruz
  bool _hasActiveAcceptedRequest = false; 
  
  Timer? _cooldownTimer;      
  Timer? _autoRefreshTimer;   
  Duration _timeLeft = Duration.zero;
  bool _isCooldown = false;

  @override
  void initState() {
    super.initState();
    _checkCooldown(); 
    
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isCooldown && !_isLoading && !_isBackgroundFetching) {
        _fetchRequests(isSilent: true); 
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _autoRefreshTimer?.cancel(); 
    super.dispose();
  }

  // --- MANTIK ---

  // 📡 SUNUCUDAN EN GÜNCEL TARİHİ ÇEKEREK SAYAÇ KONTROLÜ YAP (KESİN ÇÖZÜM)
  // 📡 SUNUCUDAN EN GÜNCEL TARİHİ ÇEKEREK SAYAÇ KONTROLÜ YAP
  Future<void> _checkCooldown() async {
    try {
      final url = ApiConstants.donorProfileEndpoint(widget.currentUser.userId);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final String? sonBagisTarihiStr = data['son_bagis_tarihi'];

        if (sonBagisTarihiStr != null && sonBagisTarihiStr.isNotEmpty) {
          
          // 🚀 SAAT DİLİMİ (TIMEZONE) DÜZELTMESİ
          // Backend'den gelen tarihe 'Z' ekleyip UTC olduğunu belirtiyoruz, 
          // ardından toLocal() ile Türkiye (UTC+3) saatine %100 isabetli çeviriyoruz.
          String safeDateStr = sonBagisTarihiStr;
          if (!safeDateStr.endsWith('Z')) safeDateStr += 'Z';
          
          DateTime sonBagis = DateTime.parse(safeDateStr).toLocal();

          int waitDays = widget.currentUser.cinsiyet == 'K' ? 120 : 90;
          final nextDate = sonBagis.add(Duration(days: waitDays));
          final now = DateTime.now();

          if (now.isBefore(nextDate)) {
            if (mounted) {
              setState(() {
                _isCooldown = true;
                _isLoading = false;
              });
              _startCooldownTimer(nextDate);
              return; 
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Sayaç için güncel profil çekilemedi: $e");
    }

    if (mounted) {
      setState(() => _isCooldown = false);
      _fetchRequests();
    }
  }

  void _startCooldownTimer(DateTime target) {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = target.difference(DateTime.now());
      if (diff.isNegative) {
        if (mounted) {
          setState(() => _isCooldown = false);
          _cooldownTimer?.cancel();
          _fetchRequests(); 
        }
      } else {
        if (mounted) setState(() => _timeLeft = diff);
      }
    });
  }

  Future<void> _fetchRequests({bool isSilent = false}) async {
    if (!isSilent && mounted) setState(() => _isLoading = true);
    else _isBackgroundFetching = true;
    
    try {
      final url = ApiConstants.donorFeedEndpoint(widget.currentUser.userId); 
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            final List<dynamic> rawList = data is List ? data : (data['items'] ?? []);
            
            // 🚀 KONTROL: Veriler arasında durumu 'Kabul' olan var mı? Varsa kilitleyeceğiz.
            _hasActiveAcceptedRequest = rawList.any((req) {
              final reaksiyon = req['reaksiyon'] ?? req['kullanici_reaksiyonu'];
              return reaksiyon == 'Kabul';
            });

            // Listede sadece 'Bekliyor' olanları göster
            _requests = rawList.where((req) {
               final reaksiyon = req['reaksiyon'] ?? req['kullanici_reaksiyonu'];
               return reaksiyon == 'Bekliyor' || reaksiyon == null;
            }).toList();
            
            _isLoading = false;
            _isBackgroundFetching = false;
          });
        }
      } else {
        if (mounted) setState(() { _isLoading = false; _isBackgroundFetching = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _isBackgroundFetching = false; });
    }
  }

  Future<void> _respondToRequest(String logId, String reaction) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
      );

      final url = "${ApiConstants.donorsEndpoint}/${widget.currentUser.userId}/respond/$logId?reaksiyon=$reaction";
      final response = await http.post(Uri.parse(url));

      if (mounted) Navigator.pop(context); 

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reaction == 'Kabul' ? "Harika! Hastaneye bekleniyorsunuz." : "Talep listenizden gizlendi."),
              behavior: SnackBarBehavior.floating,
              backgroundColor: reaction == 'Kabul' ? Colors.green.shade600 : Colors.blueGrey.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          _fetchRequests(); 
        }
      } else {
        // Hata durumunda ekrana bilgi ver
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("İşlem gerçekleştirilemedi. Lütfen tekrar deneyin."),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
    }
  }

  Future<void> _confirmAccept(String logId, String hastaneAdi) async {
    // Eğer yerel hafızamız aktif bir görevimiz olduğunu sanıyorsa (belki veri eskimiştir)
    if (_hasActiveAcceptedRequest) {
      
      // Kullanıcıyı hemen engellemek yerine arka planda sunucudan "Hızlı Teyit" alalım
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE53935))),
      );

      // Verileri sessizce ve anında güncelle
      await _fetchRequests(isSilent: true);
      
      if (mounted) Navigator.pop(context); // Yükleniyor'u kapat

      // Güncel veriyi çektikten sonra HALA aktif görevimiz varsa, şimdi güvenle engelleyebiliriz
      if (_hasActiveAcceptedRequest) {
         _showAlreadyHasRequestWarning();
         return;
      }
    }
    
    // Eğer teyit sonucunda görevimiz olmadığı anlaşıldıysa veya zaten yoksa, onay penceresini aç
    _showConfirmSheet(logId, hastaneAdi);
  }

  void _showAlreadyHasRequestWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            const Text("Aktif Göreviniz Var", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Şu anda zaten kabul ettiğiniz bir kan talebi bulunuyor. "
          "Yeni bir talebi kabul etmek için önce mevcut görevinizi tamamlamalı "
          "veya ana sayfa üzerinden iptal etmelisiniz.",
          style: TextStyle(color: Colors.blueGrey, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context), 
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Anladım", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    if (_isCooldown) return _buildTimerUI(key: const ValueKey('timer_view'));

    return Scaffold(
      key: const ValueKey('requests_view'),
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  const Text("Size Uygun Kan Talepleri", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                ],
              ),
            ),
          ),
          _isLoading && _requests.isEmpty
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFFE53935))))
              : _requests.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState())
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildRequestCard(_requests[index]),
                          childCount: _requests.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        centerTitle: false,
        title: Text("Kan Talepleri", style: TextStyle(color: Colors.blueGrey.shade900, fontWeight: FontWeight.w800, fontSize: 22)),
        background: Container(color: Colors.white),
      ),
    );
  }

  // 🏥 TALEP KARTI OLUŞTURUCU
  Widget _buildRequestCard(Map<String, dynamic> item) {
    final String logId = item['log_id']?.toString() ?? "";
    final String kurumAdi = item['kurum_adi']?.toString() ?? "Bilinmeyen Hastane";
    final String aciliyet = item['aciliyet_durumu']?.toString() ?? "NORMAL";
    final bool isUrgent = aciliyet.toUpperCase() == "ACIL" || aciliyet.toUpperCase() == "AFET";
    
    String remainingText = "Hesaplanıyor...";
    try {
      if (item['olusturma_tarihi'] != null) {
        // 🚀 SAAT DİLİMİ DÜZELTMESİ (Talep Kartları İçin)
        String dateStr = item['olusturma_tarihi'].toString();
        if (!dateStr.endsWith('Z')) dateStr += 'Z';
        
        DateTime createdAt = DateTime.parse(dateStr).toLocal();
        int durationHours = item['gecerlilik_suresi_saat'] ?? 24; 
        DateTime expiresAt = createdAt.add(Duration(hours: durationHours));
        Duration remaining = expiresAt.difference(DateTime.now());
        
        if (!remaining.isNegative) {
          remainingText = "${remaining.inHours}s ${remaining.inMinutes.remainder(60)}dk kaldı";
        } else {
          remainingText = "Süresi Doldu";
        }
      }
    } catch (e) { remainingText = "Süre Bilgisi Yok"; }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: isUrgent ? const Color(0xFFE53935) : Colors.orange.shade300),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBadge(aciliyet.toUpperCase(), isUrgent),
                          Row(
                            children: [
                              Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.blueGrey.shade300),
                              const SizedBox(width: 4),
                              Text(remainingText, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(kurumAdi, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(item['ilce'] ?? "Bölge Bilinmiyor", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => _showIgnoreSheet(logId),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  alignment: Alignment.center,
                                  child: Text("İlgilenmiyorum", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade600)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Material(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => _confirmAccept(logId, kurumAdi),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  alignment: Alignment.center,
                                  child: const Text("Kabul Et", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, bool isUrgent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: isUrgent ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: isUrgent ? const Color(0xFFC62828) : Colors.orange.shade900, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  void _showIgnoreSheet(String logId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 25),
            Icon(Icons.visibility_off_rounded, color: Colors.blueGrey.shade300, size: 50),
            const SizedBox(height: 20),
            const Text("Talebi Gizle", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              "Bu talebi listenizden kaldırmak istediğinize emin misiniz? Gizlenen talepler tekrar gösterilmez.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300), 
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    child: const Text("Vazgeç", style: TextStyle(color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () { 
                      Navigator.pop(context); 
                      // 🚀 DÜZELTME: Enum uyumluluğu için "Red" olarak güncellendi.
                      _respondToRequest(logId, "Red"); 
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade800, 
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    child: const Text("Gizle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmSheet(String logId, String hastane) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 25),
            const Icon(Icons.favorite_rounded, color: Color(0xFFE53935), size: 50),
            const SizedBox(height: 20),
            const Text("Harika Bir Adım!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              "$hastane kurumuna bağış yapmayı kabul ederek bir can kurtaracaksınız. Onaylıyor musunuz?", 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 15, height: 1.5)
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300), 
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    child: const Text("Vazgeç", style: TextStyle(color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () { 
                      Navigator.pop(context); 
                      _respondToRequest(logId, "Kabul"); 
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935), 
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    child: const Text("Onaylıyorum", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: Icon(Icons.verified_user_rounded, size: 60, color: Colors.green.shade400)),
          const SizedBox(height: 24),
          const Text("Şu An Her Şey Yolunda", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("Size uygun aktif bir kan talebi bulunmuyor.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ⏳ SANIYE EKLENMİŞ YENİ VE MODERN SAYAÇ EKRANI
  Widget _buildTimerUI({Key? key}) {
    return Scaffold(
      key: key,
      backgroundColor: const Color(0xFFF4F6F8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20), // Ekran kenarı boşluğunu biraz kıstık
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🟠 İkon Kutusu
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.timer_rounded, size: 70, color: Colors.orange.shade600),
              ),
              const SizedBox(height: 30),
              
              // 📝 Başlık
              const Text(
                "Dinlenme Sürecindesiniz",
                style: TextStyle(color: Color(0xFF2D3142), fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              
              // 📝 Açıklama
              const Text(
                "Vücudunuzun toparlanması için gereken süreyi bekliyorsunuz. Bir sonraki kan bağışınızı yapabilmenize kalan süre:",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9098B1), fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 40),
              
              // ⏳ 4'LÜ SAYAÇ KARTLARI (Saniye Eklendi)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _timeBox("${_timeLeft.inDays}", "GÜN"),
                  const SizedBox(width: 8),
                  _timeBox("${_timeLeft.inHours.remainder(24)}", "SAAT"),
                  const SizedBox(width: 8),
                  _timeBox("${_timeLeft.inMinutes.remainder(60)}", "DAKİKA"),
                  const SizedBox(width: 8),
                  // 🚀 YENİ EKLENEN SANİYE KUTUSU
                  _timeBox("${_timeLeft.inSeconds.remainder(60)}", "SANİYE"), 
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🕒 4 KUTUYA GÖRE OPTİMİZE EDİLMİŞ SAYAÇ KUTULARI
  Widget _timeBox(String value, String label) {
    return Container(
      width: 75, // 4 kutu sığsın diye genişlik 90'dan 75'e düşürüldü
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9098B1).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            // Eğer saniye veya dakika tek haneliyse başına '0' koyarak daha şık gösterir (Örn: 9 yerine 09)
            value.padLeft(2, '0'), 
            style: const TextStyle(color: Color(0xFFE53935), fontSize: 26, fontWeight: FontWeight.w900)
          ),
          const SizedBox(height: 6),
          Text(
            label, 
            style: const TextStyle(color: Color(0xFF9098B1), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)
          ),
        ],
      ),
    );
  }
}