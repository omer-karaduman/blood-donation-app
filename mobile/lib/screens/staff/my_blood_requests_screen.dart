// mobile/lib/screens/staff/my_blood_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../constants/api_constants.dart';
import 'blood_request_detail_screen.dart';

class MyBloodRequestsScreen extends StatefulWidget {
  final String staffUserId;

  const MyBloodRequestsScreen({super.key, required this.staffUserId});

  @override
  State<MyBloodRequestsScreen> createState() => _MyBloodRequestsScreenState();
}

class _MyBloodRequestsScreenState extends State<MyBloodRequestsScreen> with TickerProviderStateMixin {
  List<dynamic> _allRequests = [];
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;
  
  // Filtreleme için durum yönetimi
  String _selectedUrgencyFilter = "Hepsi"; 
  final List<String> _urgencyLevels = ["Hepsi", "Normal", "Acil", "Afet"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchMyRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/staff/my-requests?personel_id=${widget.staffUserId}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _allRequests = jsonDecode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Talepler yüklenemedi. (Hata: ${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Sunucuya bağlanılamadı.";
        _isLoading = false;
      });
    }
  }

  // 🚀 DÜZELTİLMİŞ FİLTRELEME MANTIĞI
  List<dynamic> _filterRequests(String targetTab) {
    return _allRequests.where((req) {
      // 1. Durum Kontrolü (Case-insensitive)
      final String status = (req['durum'] ?? "").toString().toUpperCase();
      bool statusMatch = false;
      
      if (targetTab == 'AKTIF') {
        statusMatch = status == 'AKTIF';
      } else if (targetTab == 'TAMAMLANDI') {
        statusMatch = status == 'TAMAMLANDI';
      } else if (targetTab == 'IPTAL') {
        statusMatch = (status == 'IPTAL' || status == 'SURESI_DOLDU');
      }

      // 2. Aciliyet Kontrolü (Case-insensitive ve Null Güvenli)
      final String urgency = (req['aciliyet_durumu'] ?? "Normal").toString();
      bool urgencyMatch = _selectedUrgencyFilter == "Hepsi" || 
                         urgency.toLowerCase() == _selectedUrgencyFilter.toLowerCase();

      return statusMatch && urgencyMatch;
    }).toList();
  }

  Color _getStatusColor(String? status) {
    final s = status?.toUpperCase();
    if (s == 'AKTIF') return const Color(0xFFD32F2F);
    if (s == 'TAMAMLANDI') return Colors.green.shade700;
    return Colors.grey.shade600;
  }

  Color _getUrgencyColor(String? urgency) {
    final u = urgency?.toLowerCase();
    if (u == 'afet') return Colors.purple.shade700;
    if (u == 'acil') return Colors.orange.shade900;
    return Colors.blueGrey.shade600;
  }

  String _formatDate(String isoDate) {
    try {
      DateTime date = DateTime.parse("${isoDate}Z").toLocal();
      return DateFormat('dd.MM.yyyy - HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text("Açtığım Talepler", style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF263238)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchMyRequests)],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1565C0),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1565C0),
          tabs: const [Tab(text: "Aktif"), Tab(text: "Tamamlanan"), Tab(text: "İptal")],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
        : Column(
            children: [
              // 🚀 ACİLİYET FİLTRELEME ÇUBUĞU
              Container(
                height: 50,
                color: Colors.white,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _urgencyLevels.length,
                  itemBuilder: (context, i) {
                    final level = _urgencyLevels[i];
                    bool isSelected = _selectedUrgencyFilter == level;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(level, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1565C0),
                        backgroundColor: Colors.grey.shade100,
                        onSelected: (val) { if(val) setState(() { _selectedUrgencyFilter = level; }); },
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestList(_filterRequests('AKTIF')),
                    _buildRequestList(_filterRequests('TAMAMLANDI')),
                    _buildRequestList(_filterRequests('IPTAL')),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildRequestList(List<dynamic> requests) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off_rounded, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text("Sonuca uygun talep bulunamadı.", style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) => _buildRequestCard(requests[index]),
    );
  }

  Widget _buildRequestCard(dynamic request) {
    final String status = (request['durum'] ?? "").toString().toUpperCase();
    final String urgency = (request['aciliyet_durumu'] ?? "Normal").toString();
    final Color mainColor = _getStatusColor(status);
    final int notifiedCount = (request['donor_yanitlari'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mainColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => BloodRequestDetailScreen(requestData: request, staffUserId: widget.staffUserId)));
          _fetchMyRequests();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Durum ve Kan Grubu Etiketi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: mainColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      status == 'AKTIF' ? "${request['istenen_kan_grubu']} Aranıyor" : "${request['istenen_kan_grubu']} Talebi",
                      style: TextStyle(color: mainColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  // Aciliyet Rozeti
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _getUrgencyColor(urgency).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(urgency, style: TextStyle(color: _getUrgencyColor(urgency), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // 🚀 İPTAL EDİLENLERDE ÜNİTE YERİNE KAN GRUBU GÖSTERİMİ
                  if (status == 'IPTAL' || status == 'SURESI_DOLDU') 
                    _buildInfoColumn("Kan Grubu", "${request['istenen_kan_grubu']}")
                  else
                    _buildInfoColumn("Miktar", "${request['unite_sayisi']} Ünite"),
                  
                  const SizedBox(width: 32),
                  _buildInfoColumn("Oluşturulma Tarihi", _formatDate(request['olusturma_tarihi'])),
                ],
              ),
              if (status == 'AKTIF') ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFEEEEEE))),
                if (notifiedCount > 0) 
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.blue, size: 16),
                      const SizedBox(width: 6),
                      Text("$notifiedCount donöre bildirim iletildi.", style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  )
                else 
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text("Bölgede uygun donör bulunamadı.", style: TextStyle(color: Colors.orange.shade900, fontSize: 12, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _buildRemainingTime(request),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemainingTime(Map<String, dynamic> request) {
    try {
      DateTime createdAt = DateTime.parse("${request['olusturma_tarihi']}Z").toLocal();
      int durationHours = request['gecerlilik_suresi_saat'] ?? 24; 
      DateTime expiresAt = createdAt.add(Duration(hours: durationHours));
      Duration remaining = expiresAt.difference(DateTime.now());
      if (remaining.isNegative) return const SizedBox.shrink();
      return Row(
        children: [
          Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text("Talep Süresi: ${remaining.inHours}s ${remaining.inMinutes.remainder(60)}dk", style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      );
    } catch (e) { return const SizedBox.shrink(); }
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
      ],
    );
  }
}