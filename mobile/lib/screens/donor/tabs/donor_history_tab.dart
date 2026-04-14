// mobile/lib/screens/donor/tabs/donor_history_tab.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants/api_constants.dart';

class DonorHistoryTab extends StatefulWidget {
  final dynamic currentUser;
  const DonorHistoryTab({super.key, required this.currentUser});

  @override
  State<DonorHistoryTab> createState() => _DonorHistoryTabState();
}

class _DonorHistoryTabState extends State<DonorHistoryTab> {
  bool _isLoading = true;
  List<dynamic> _historyData = [];
  List<dynamic> _filteredData = []; // Filtrelenmiş liste için
  
  String _selectedFilter = 'Tümü';
  final List<String> _filters = ['Tümü', 'Son 3 Ay', 'Son 6 Ay', 'Bu Yıl'];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  // 📡 GEÇMİŞ BAĞIŞLARI ÇEK
  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final url = ApiConstants.donorHistoryEndpoint(widget.currentUser.userId);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          _historyData = json.decode(utf8.decode(response.bodyBytes));
          _applyFilter(_selectedFilter); // Veri gelince seçili filtreyi uygula
          _isLoading = false;
        });
      } else {
        debugPrint("Hata: Backend ${response.statusCode} döndürdü.");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Bağış geçmişi çekilemedi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔍 TARİH FİLTRESİ UYGULAMA METODU
  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      
      if (filter == 'Tümü') {
        _filteredData = List.from(_historyData);
      } else {
        final now = DateTime.now();
        _filteredData = _historyData.where((item) {
          final dateStr = item['bagis_tarihi'];
          if (dateStr == null) return false;
          
          final date = DateTime.tryParse(dateStr);
          if (date == null) return false;

          if (filter == 'Son 3 Ay') {
            return now.difference(date).inDays <= 90;
          } else if (filter == 'Son 6 Ay') {
            return now.difference(date).inDays <= 180;
          } else if (filter == 'Bu Yıl') {
            return date.year == now.year;
          }
          return true;
        }).toList();
      }
    });
  }

  // 🎨 DURUMA GÖRE RENK VE İKON BELİRLEYİCİ
  Map<String, dynamic> _getStatusConfig(String? status) {
    String s = (status ?? '').toLowerCase();
    if (s == 'basarili' || s == 'success' || s == 'basarılı') {
      return {"color": const Color(0xFF43A047), "bgColor": const Color(0xFFE8F5E9), "icon": Icons.check_circle_rounded, "label": "Başarılı"};
    } else if (s == 'reddedildi' || s == 'red' || s == 'failed') {
      return {"color": const Color(0xFFE53935), "bgColor": const Color(0xFFFFEBEE), "icon": Icons.cancel_rounded, "label": "Reddedildi"};
    } else {
      return {"color": const Color(0xFFFFB300), "bgColor": const Color(0xFFFFF8E1), "icon": Icons.hourglass_empty_rounded, "label": "Beklemede"};
    }
  }

  // 🕒 TARİH FORMATLAYICI
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Tarih Belirtilmemiş";
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        color: const Color(0xFFD32F2F),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildFilterChips()),
            _isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F))),
                  )
                : _filteredData.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState())
                    : SliverPadding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildHistoryCard(_filteredData[index]),
                            childCount: _filteredData.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  // 🌟 SADE VE ŞIK BAŞLIK (APP BAR)
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 70, bottom: 30, left: 24, right: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)], // Daha tok ve zarif kırmızılar
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Bağış Geçmişi",
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            _isLoading 
              ? "Kayıtlar yükleniyor..." 
              : "Toplam ${_historyData.length} işlem kaydınız bulunuyor.",
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // 🔘 FİLTRELEME BUTONLARI (CHIPS)
  // 🔘 FİLTRELEME BUTONLARI (CHIPS)
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Hatalı satır (showsHorizontalScrollIndicator: false) buradan silindi.
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: ChoiceChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) _applyFilter(filter);
                },
                selectedColor: const Color(0xFFD32F2F),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF4A4A4A),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : Colors.grey.shade300,
                  ),
                ),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // 🏥 TEMİZ VE MİNİMAL KART TASARIMI
// 🏥 TEMİZ VE MİNİMAL KART TASARIMI
  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final hospitalName = item['institution']?['kurum_adi'] ?? "Bilinmeyen Hastane";
    final rawDate = item['bagis_tarihi'];
    final rawStatus = item['islem_sonucu'];
    final statusConfig = _getStatusConfig(rawStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🩸 Sol İkon (Hastane yerine Kan Damlası)
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0), // Çok açık ve şık bir kırmızı arka plan
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.water_drop_rounded, // 🩸 Burada damla kullandık
              color: Color(0xFFD32F2F), 
              size: 26
            ),
          ),
          const SizedBox(width: 16),
          
          // Orta Metinler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hospitalName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2D3142)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF9098B1)),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(rawDate),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF9098B1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          
          // Sağ Durum Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusConfig['bgColor'],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusConfig['icon'], size: 14, color: statusConfig['color']),
                const SizedBox(width: 4),
                Text(
                  statusConfig['label'],
                  style: TextStyle(color: statusConfig['color'], fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📭 BOŞ DURUM TASARIMI
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            _selectedFilter == 'Tümü' 
              ? "Henüz İşlem Kaydınız Yok" 
              : "$_selectedFilter İçin Kayıt Bulunamadı",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
          ),
          const SizedBox(height: 10),
          const Text(
            "Geçmiş kan bağışı ve red kayıtlarınız burada listelenir.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF9098B1)),
          ),
        ],
      ),
    );
  }
}