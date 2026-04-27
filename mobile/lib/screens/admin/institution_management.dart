// mobile/lib/screens/admin/institution_management.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../models/institution.dart';
import 'institution_detail_screen.dart';
import '../../../core/constants/api_constants.dart';

// --------------------------------------------------------------------------
// İzmir ilçe merkez koordinatları (DB'de ilçe/mahalle coord yok, bu tablo
// kullanılarak kurum eklenirken otomatik koordinat atanır)
// --------------------------------------------------------------------------
const Map<String, List<double>> _districtCoords = {
  'aliağa':     [38.7870, 26.9750],
  'balçova':    [38.3941, 27.0331],
  'bayındır':   [38.2215, 27.6496],
  'bayraklı':   [38.4843, 27.1776],
  'bergama':    [39.1184, 27.1980],
  'beydağ':     [38.0800, 28.2100],
  'bornova':    [38.4590, 27.2504],
  'buca':       [38.3845, 27.1633],
  'çeşme':      [38.3169, 26.3256],
  'çiğli':      [38.4995, 27.0493],
  'dikili':     [39.0649, 26.8924],
  'foça':       [38.6582, 26.7610],
  'gaziemir':   [38.3110, 27.1331],
  'güzelbahçe': [38.3800, 26.9100],
  'karabağlar': [38.3977, 27.1038],
  'karaburun':  [38.6352, 26.5223],
  'karşıyaka':  [38.4718, 27.0862],
  'kemalpaşa':  [38.4363, 27.4098],
  'kınık':      [39.0896, 27.3630],
  'kiraz':      [38.2304, 28.2185],
  'konak':      [38.4296, 27.1572],
  'menderes':   [38.2385, 27.1362],
  'menemen':    [38.6070, 27.0880],
  'narlıdere':  [38.3880, 27.0100],
  'ödemiş':     [38.2305, 27.9881],
  'seferihisar':[38.1979, 26.8455],
  'selçuk':     [37.9478, 27.3673],
  'tire':       [38.1006, 27.7218],
  'torbalı':    [38.1756, 27.3581],
  'urla':       [38.3302, 26.7460],
};

List<double> _coordsForDistrict(String districtName) {
  final key = districtName.toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ş', 's')
      .replaceAll('ç', 'c')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u');
  // Önce tam eşleşme
  if (_districtCoords.containsKey(key)) return _districtCoords[key]!;
  // Kısmi eşleşme
  for (final entry in _districtCoords.entries) {
    if (key.contains(entry.key) || entry.key.contains(key)) return entry.value;
  }
  // Varsayılan: İzmir merkezi
  return [38.4189, 27.1287];
}

// ==========================================================================
// ANA EKRAN
// ==========================================================================

class InstitutionManagementScreen extends StatefulWidget {
  const InstitutionManagementScreen({super.key});

  @override
  State<InstitutionManagementScreen> createState() =>
      _InstitutionManagementScreenState();
}

class _InstitutionManagementScreenState
    extends State<InstitutionManagementScreen> with TickerProviderStateMixin {
  // ── Filtreler ────────────────────────────────────────────────────────────
  District? selectedFilterDistrict;
  String selectedType = 'Tümü';

  // ── Controller'lar ───────────────────────────────────────────────────────
  final TextEditingController _nameSearchController = TextEditingController();

  // ── Veri ─────────────────────────────────────────────────────────────────
  late Future<List<Institution>> _institutionsFuture;
  List<District> _districtsList = [];

  // ── Animasyon ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Renk teması ──────────────────────────────────────────────────────────
  static const Color _hospitalColor   = Color(0xFF1E88E5); // Mavi
  static const Color _bloodBankColor  = Color(0xFFE53935); // Kırmızı
  static const Color _accentGradStart = Color(0xFF1A237E);
  static const Color _accentGradEnd   = Color(0xFF283593);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _fetchDistricts();
    _refreshData();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _nameSearchController.dispose();
    super.dispose();
  }

  // ── İlçeleri çek ─────────────────────────────────────────────────────────
  Future<void> _fetchDistricts() async {
    try {
      final res = await http.get(
          Uri.parse('${ApiConstants.locationsEndpoint}/districts'));
      if (res.statusCode == 200 && mounted) {
        final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
        setState(() {
          _districtsList =
              data.map((d) => District.fromJson(d)).toList();
        });
      }
    } catch (e) {
      debugPrint('İlçe verisi çekilemedi: $e');
    }
  }

  void _refreshData() {
    setState(() {
      _institutionsFuture = _fetchInstitutions();
    });
  }

  Future<List<Institution>> _fetchInstitutions() async {
    final params = <String>[];
    if (selectedFilterDistrict != null) {
      params.add('district_id=${selectedFilterDistrict!.id}');
    }
    if (selectedType != 'Tümü') params.add('tipi=$selectedType');
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    final res = await http
        .get(Uri.parse('${ApiConstants.institutionsEndpoint}$qs'));
    if (res.statusCode == 200) {
      final List<dynamic> json2 = json.decode(utf8.decode(res.bodyBytes));
      return json2.map((d) => Institution.fromJson(d)).toList();
    }
    throw Exception('Kurumlar yüklenemedi');
  }

  String _normalize(String t) => t
      .replaceAll('I', 'ı')
      .replaceAll('İ', 'i')
      .replaceAll('Ş', 'ş')
      .replaceAll('Ç', 'ç')
      .replaceAll('Ö', 'ö')
      .replaceAll('Ğ', 'ğ')
      .replaceAll('Ü', 'ü')
      .toLowerCase();

  // ==========================================================================
  // KURUm EKLEME FORMU
  // ==========================================================================
  void _showAddInstitutionForm({Institution? parentInst}) {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    String type = parentInst?.tipi ?? 'Hastane';

    District? formDistrict;
    Neighborhood? formNeighborhood;
    List<Neighborhood> formNeighborhoods = [];
    bool loadingNbh = false;
    bool isSubmitting = false;
    String? errorMsg;

    // Eğer alt birim ekleniyorsa parent bilgisini ön-doldur
    Institution? selectedParent = parentInst;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.92,
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                // ── Başlık çubuğu ────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: selectedParent != null
                          ? [const Color(0xFF880E4F), const Color(0xFFC2185B)]
                          : [_accentGradStart, _accentGradEnd],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              selectedParent != null
                                  ? Icons.account_tree_rounded
                                  : Icons.add_business_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedParent != null
                                      ? 'Alt Birim Ekle'
                                      : 'Yeni Kurum Kaydı',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (selectedParent != null)
                                  Text(
                                    selectedParent!.ad,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Form ─────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom:
                          MediaQuery.of(ctx).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kurum Adı
                        _formLabel('Kurum Adı'),
                        const SizedBox(height: 8),
                        _modernField(nameCtrl, 'Örn: İzmir Devlet Hastanesi',
                            Icons.business_rounded),
                        const SizedBox(height: 20),

                        // Kurum Tipi
                        _formLabel('Kurum Tipi'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _typeChip('Hastane', Icons.local_hospital_rounded,
                                _hospitalColor, type, (v) {
                              setModal(() => type = v);
                            }),
                            const SizedBox(width: 12),
                            _typeChip('Kan Merkezi', Icons.bloodtype_rounded,
                                _bloodBankColor, type, (v) {
                              setModal(() => type = v);
                            }),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // İlçe Seçimi
                        _formLabel('İlçe'),
                        const SizedBox(height: 8),
                        _districtDropdown(
                          value: formDistrict,
                          items: _districtsList,
                          onChanged: (val) async {
                            if (val == null) return;
                            setModal(() {
                              formDistrict = val;
                              formNeighborhood = null;
                              formNeighborhoods = [];
                              loadingNbh = true;
                            });
                            try {
                              final r = await http.get(Uri.parse(
                                  '${ApiConstants.locationsEndpoint}/districts/${val.id}/neighborhoods'));
                              if (r.statusCode == 200) {
                                final List<dynamic> nd =
                                    json.decode(utf8.decode(r.bodyBytes));
                                setModal(() {
                                  formNeighborhoods = nd
                                      .map((n) => Neighborhood.fromJson(n))
                                      .toList();
                                });
                              }
                            } catch (e) {
                              debugPrint('Mahalle hatası: $e');
                            } finally {
                              setModal(() => loadingNbh = false);
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // Mahalle Seçimi
                        _formLabel('Mahalle'),
                        const SizedBox(height: 8),
                        loadingNbh
                            ? const Center(
                                child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF283593),
                                ),
                              ))
                            : _neighborhoodDropdown(
                                value: formNeighborhood,
                                items: formNeighborhoods,
                                onChanged: formNeighborhoods.isEmpty
                                    ? null
                                    : (val) =>
                                        setModal(() => formNeighborhood = val),
                              ),

                        // Koordinat göstergesi
                        if (formDistrict != null) ...[
                          const SizedBox(height: 12),
                          _coordBadge(
                              _coordsForDistrict(formDistrict!.name)),
                        ],
                        const SizedBox(height: 20),

                        // Tam Adres
                        _formLabel('Tam Adres'),
                        const SizedBox(height: 8),
                        _modernField(addrCtrl, 'Mahalle, Sokak, Kapı No...',
                            Icons.map_rounded,
                            maxLines: 3),
                        const SizedBox(height: 20),

                        // Üst Kurum (opsiyonel)
                        _formLabel('Üst Kurum (Opsiyonel)'),
                        const SizedBox(height: 8),
                        _parentSelector(
                          selectedParent: selectedParent,
                          onTap: () => _showParentSearchDialog(
                            currentSelection: selectedParent,
                            onSelected: (inst) =>
                                setModal(() => selectedParent = inst),
                          ),
                          onClear: () => setModal(() => selectedParent = null),
                        ),
                        const SizedBox(height: 28),

                        // Hata mesajı
                        if (errorMsg != null)
                          _errorBanner(errorMsg!),

                        // Kaydet butonu
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF283593),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setModal(() => errorMsg = null);
                                    if (nameCtrl.text.trim().isEmpty) {
                                      setModal(() =>
                                          errorMsg = 'Kurum adı boş olamaz.');
                                      return;
                                    }
                                    if (formDistrict == null) {
                                      setModal(() =>
                                          errorMsg = 'Lütfen ilçe seçiniz.');
                                      return;
                                    }
                                    if (formNeighborhood == null) {
                                      setModal(() =>
                                          errorMsg = 'Lütfen mahalle seçiniz.');
                                      return;
                                    }
                                    if (addrCtrl.text.trim().isEmpty) {
                                      setModal(() =>
                                          errorMsg = 'Tam adres boş olamaz.');
                                      return;
                                    }

                                    setModal(() => isSubmitting = true);

                                    // Koordinatları ilçe bazında ata
                                    final coords =
                                        _coordsForDistrict(formDistrict!.name);

                                    try {
                                      final body = {
                                        'kurum_adi': nameCtrl.text.trim(),
                                        'tam_adres': addrCtrl.text.trim(),
                                        'tipi': type,
                                        'district_id': formDistrict!.id,
                                        'neighborhood_id': formNeighborhood!.id,
                                        'latitude': coords[0],
                                        'longitude': coords[1],
                                        'parent_id': selectedParent?.id,
                                      };
                                      final res = await http.post(
                                        Uri.parse(
                                            ApiConstants.institutionsEndpoint),
                                        headers: {
                                          'Content-Type': 'application/json'
                                        },
                                        body: json.encode(body),
                                      );
                                      if (res.statusCode == 200) {
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        _refreshData();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: const Text(
                                                'Kurum başarıyla eklendi!'),
                                            backgroundColor:
                                                Colors.green.shade600,
                                            behavior:
                                                SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ));
                                        }
                                      } else {
                                        setModal(() => errorMsg =
                                            'Sunucu hatası: ${res.statusCode}');
                                      }
                                    } catch (e) {
                                      setModal(() => errorMsg =
                                          'Bağlantı hatası. Sunucuyu kontrol edin.');
                                    } finally {
                                      setModal(() => isSubmitting = false);
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Kaydet',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800),
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
        },
      ),
    );
  }

  // Üst kurum arama dialogu
  void _showParentSearchDialog({
    Institution? currentSelection,
    required Function(Institution?) onSelected,
  }) {
    final TextEditingController sc = TextEditingController();

    _institutionsFuture.then((all) {
      List<Institution> filtered = List.from(all);
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.all(16),
            title: const Text('Üst Kurum Seç',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(ctx).size.height * 0.5,
              child: Column(
                children: [
                  TextField(
                    controller: sc,
                    decoration: InputDecoration(
                      hintText: 'Kurum ara...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (v) {
                      final q = _normalize(v);
                      setD(() {
                        filtered = all.where((i) =>
                            _normalize(i.ad).contains(q) ||
                            _normalize(i.ilceAdi).contains(q)).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    tileColor: Colors.red.shade50,
                    leading: const Icon(Icons.clear_all, color: Colors.red),
                    title: const Text('Üst Kurum Yok',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () {
                      onSelected(null);
                      Navigator.pop(ctx);
                    },
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (c, i) {
                        final inst = filtered[i];
                        final isSel = currentSelection?.id == inst.id;
                        final isBlood = inst.tipi == 'Kan Merkezi';
                        return ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          tileColor: isSel ? Colors.blue.shade50 : null,
                          leading: Icon(
                            isBlood
                                ? Icons.bloodtype_rounded
                                : Icons.local_hospital_rounded,
                            color:
                                isBlood ? _bloodBankColor : _hospitalColor,
                          ),
                          title: Text(inst.ad,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(inst.ilceAdi),
                          onTap: () {
                            onSelected(inst);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    });
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddInstitutionForm(),
        backgroundColor: const Color(0xFF283593),
        elevation: 4,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text('Yeni Kurum',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        color: _hospitalColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero Header ────────────────────────────────────────────────
            _buildHeroHeader(),

            // ── Filtreler ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildTypeFilter(),
                  _buildDistrictFilter(),
                  _buildSearchBar(),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Liste ──────────────────────────────────────────────────────
            FutureBuilder<List<Institution>>(
              future: _institutionsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF283593))));
                }
                if (snap.hasError) {
                  return SliverFillRemaining(
                    child: _buildErrorState(snap.error.toString()),
                  );
                }

                final all = snap.data ?? [];
                final query = _normalize(_nameSearchController.text);
                final filtered = all
                    .where((i) =>
                        _normalize(i.ad).contains(query) ||
                        _normalize(i.ilceAdi).contains(query))
                    .toList();

                // Hiyerarşi: root (parentId==null) ve alt birimler
                final roots = filtered
                    .where((i) => i.parentId == null)
                    .toList();
                final children =
                    filtered.where((i) => i.parentId != null).toList();

                // Yetim alt birimler (filtre sonrası parent listede yoksa)
                final orphans = children
                    .where((c) => !roots.any((r) => r.id == c.parentId))
                    .toList();
                final allRoots = [...roots, ...orphans];

                if (allRoots.isEmpty) {
                  return SliverFillRemaining(child: _buildEmptyState());
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        final parent = allRoots[idx];
                        final subs = children
                            .where((c) => c.parentId == parent.id)
                            .toList();
                        return _buildHierarchyGroup(parent, subs);
                      },
                      childCount: allRoots.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HERO HEADER
  // ==========================================================================
  Widget _buildHeroHeader() {
    return SliverToBoxAdapter(
      child: Container(
        height: 200,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
          ),
        ),
        child: Stack(
          children: [
            // Dekoratif daireler
            Positioned(
              top: -30,
              right: -20,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              top: 28,
              right: 36,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Opacity(
                  opacity: _pulseAnim.value * 0.25,
                  child: const Icon(Icons.local_hospital_rounded,
                      size: 90, color: Colors.white),
                ),
              ),
            ),
            // İçerik
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Geri + yenile
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _refreshData,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.sync_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            'SİSTEM YÖNETİCİSİ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kurum Yönetimi',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hastane & kan merkezlerini yönetin',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // FİLTRELER
  // ==========================================================================
  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'Tümü',
                label: Text('Tümü'),
                icon: Icon(Icons.all_inclusive_rounded)),
            ButtonSegment(
                value: 'Hastane',
                label: Text('Hastane'),
                icon: Icon(Icons.local_hospital_rounded)),
            ButtonSegment(
                value: 'Kan Merkezi',
                label: Text('Kan Merkezi'),
                icon: Icon(Icons.bloodtype_rounded)),
          ],
          selected: {selectedType},
          onSelectionChanged: (s) {
            setState(() {
              selectedType = s.first;
              _refreshData();
            });
          },
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.white,
            selectedBackgroundColor: const Color(0xFF283593),
            selectedForegroundColor: Colors.white,
            foregroundColor: const Color(0xFF283593),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildDistrictFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<District?>(
            value: selectedFilterDistrict,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: selectedFilterDistrict != null
                    ? const Color(0xFF283593)
                    : Colors.grey),
            hint: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text('Tüm İlçeler',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ],
            ),
            items: [
              const DropdownMenuItem<District?>(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Tüm İlçeler'),
                  ],
                ),
              ),
              ..._districtsList.map((d) => DropdownMenuItem(
                    value: d,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF283593)),
                        const SizedBox(width: 8),
                        Text(d.name),
                      ],
                    ),
                  )),
            ],
            onChanged: (val) {
              setState(() {
                selectedFilterDistrict = val;
                _refreshData();
              });
            },
            selectedItemBuilder: (_) => [
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF283593)),
                const SizedBox(width: 8),
                const Text('Tüm İlçeler',
                    style: TextStyle(color: Color(0xFF283593), fontWeight: FontWeight.w500)),
              ]),
              ..._districtsList.map((d) => Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF283593)),
                      const SizedBox(width: 8),
                      Text(d.name,
                          style: const TextStyle(
                              color: Color(0xFF283593),
                              fontWeight: FontWeight.w600)),
                    ],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: TextField(
          controller: _nameSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Kurum veya ilçe ara...',
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon:
                const Icon(Icons.search_rounded, color: Color(0xFF283593)),
            suffixIcon: _nameSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                    onPressed: () {
                      _nameSearchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // HİYERARŞİ GRUPLARI
  // ==========================================================================
  Widget _buildHierarchyGroup(
      Institution parent, List<Institution> subs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Ana kurum kartı
        _buildInstitutionCard(parent, isChild: false, hasSubs: subs.isNotEmpty),
        // Alt birimler
        if (subs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dikey çizgi
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Column(
                    children: List.generate(
                      subs.length,
                      (i) => Column(
                        children: [
                          Container(
                            width: 2,
                            height: 40,
                            color: Colors.grey.shade200,
                          ),
                          if (i < subs.length - 1)
                            Container(
                                width: 2,
                                height: 20,
                                color: Colors.grey.shade200),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: subs
                        .map((c) => _buildInstitutionCard(c,
                            isChild: true, hasSubs: false))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInstitutionCard(Institution inst,
      {required bool isChild, required bool hasSubs}) {
    final isBlood = inst.tipi == 'Kan Merkezi';
    final themeColor = isBlood ? _bloodBankColor : _hospitalColor;
    final bgColor =
        isBlood ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD);

    return Container(
      margin: EdgeInsets.only(
        top: isChild ? 8 : 0,
        bottom: isChild ? 0 : 2,
        left: isChild ? 12 : 0,
      ),
      decoration: BoxDecoration(
        color: isChild ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(isChild ? 16 : 20),
        border: isChild
            ? Border.all(color: Colors.grey.shade200)
            : null,
        boxShadow: isChild
            ? []
            : [
                BoxShadow(
                    color: themeColor.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isChild ? 16 : 20),
        child: InkWell(
          borderRadius: BorderRadius.circular(isChild ? 16 : 20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => InstitutionDetailScreen(institution: inst)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // İkon
                Container(
                  width: isChild ? 36 : 46,
                  height: isChild ? 36 : 46,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(isChild ? 10 : 14),
                  ),
                  child: Icon(
                    isChild
                        ? Icons.subdirectory_arrow_right_rounded
                        : (isBlood
                            ? Icons.bloodtype_rounded
                            : Icons.local_hospital_rounded),
                    color: themeColor,
                    size: isChild ? 18 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Bilgi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              inst.ad,
                              style: TextStyle(
                                fontWeight: isChild
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                fontSize: isChild ? 13 : 15,
                                color: const Color(0xFF1A1A2E),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Tip badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isBlood ? 'Kan' : 'Hst',
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${inst.ilceAdi} · ${inst.mahalleAdi}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (!isChild && inst.tamAdres.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          inst.tamAdres,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // Alt birim sayısı
                      if (hasSubs) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.account_tree_outlined,
                                      size: 11,
                                      color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Alt birimler var',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Sağ ok
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_right_rounded,
                      color: themeColor, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // BOŞ / HATA DURUMU
  // ==========================================================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 40, color: Color(0xFF1E88E5)),
          ),
          const SizedBox(height: 16),
          const Text('Kayıt bulunamadı',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 6),
          Text('Filtreleri değiştirerek tekrar deneyin',
              style:
                  TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 60, color: Color(0xFFE53935)),
            const SizedBox(height: 16),
            const Text('Bağlantı Hatası',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Text(err,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF283593),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // FORM YARDIMCILARI
  // ==========================================================================
  Widget _formLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E)),
      );

  Widget _modernField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? 28.0 : 0.0),
            child: Icon(icon, size: 20, color: const Color(0xFF283593)),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _typeChip(
    String label,
    IconData icon,
    Color color,
    String current,
    ValueChanged<String> onTap,
  ) {
    final sel = current == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: sel ? color : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: sel ? color : Colors.grey.shade200, width: 1.5),
            boxShadow: sel
                ? [
                    BoxShadow(
                        color: color.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: sel ? Colors.white : color, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: sel ? Colors.white : color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _districtDropdown({
    required District? value,
    required List<District> items,
    required ValueChanged<District?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<District?>(
          value: value,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(Icons.location_city_rounded,
                  size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text('İlçe seçin...',
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 14)),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF283593)),
          items: items
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d.name,
                        style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _neighborhoodDropdown({
    required Neighborhood? value,
    required List<Neighborhood> items,
    required ValueChanged<Neighborhood?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: onChanged == null ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Neighborhood?>(
          value: value,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 18,
                  color: onChanged == null
                      ? Colors.grey.shade300
                      : Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(
                items.isEmpty ? 'Önce ilçe seçin...' : 'Mahalle seçin...',
                style: TextStyle(
                    color: onChanged == null
                        ? Colors.grey.shade300
                        : Colors.grey.shade400,
                    fontSize: 14),
              ),
            ],
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: onChanged == null
                  ? Colors.grey.shade300
                  : const Color(0xFF283593)),
          items: items
              .map((n) => DropdownMenuItem(
                    value: n,
                    child:
                        Text(n.name, style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _coordBadge(List<double> coords) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.my_location_rounded,
              size: 14, color: Color(0xFF3949AB)),
          const SizedBox(width: 6),
          Text(
            'Koordinat: ${coords[0].toStringAsFixed(4)}, ${coords[1].toStringAsFixed(4)}',
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF3949AB),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _parentSelector({
    required Institution? selectedParent,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selectedParent != null
              ? const Color(0xFFE8EAF6)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selectedParent != null
                ? const Color(0xFF3949AB)
                : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_tree_rounded,
              size: 20,
              color: selectedParent != null
                  ? const Color(0xFF3949AB)
                  : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedParent != null
                    ? '${selectedParent.ad} (${selectedParent.ilceAdi})'
                    : 'Seç (varsa)',
                style: TextStyle(
                  color: selectedParent != null
                      ? const Color(0xFF3949AB)
                      : Colors.grey.shade400,
                  fontWeight: selectedParent != null
                      ? FontWeight.w700
                      : FontWeight.normal,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selectedParent != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 18, color: Color(0xFF3949AB)),
              )
            else
              const Icon(Icons.search_rounded,
                  size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE53935), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: Color(0xFFC62828),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}