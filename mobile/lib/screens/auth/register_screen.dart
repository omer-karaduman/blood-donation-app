// mobile/lib/screens/auth/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../../core/constants/api_constants.dart';
import '../../models/institution.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  bool _isLoading = false;
  bool _obscurePass = true;

  // Form keys
  final _key1 = GlobalKey<FormState>();
  final _key2 = GlobalKey<FormState>();
  final _key3 = GlobalKey<FormState>();

  // Adım 1 – Kimlik
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _birthCtrl     = TextEditingController();

  // Adım 2 – Konum
  final _phoneCtrl     = TextEditingController();
  District?     _district;
  Neighborhood? _neighborhood;
  List<District>     _districts     = [];
  List<Neighborhood> _neighborhoods = [];
  bool _loadingNbh = false;

  // Adım 3 – Sağlık
  String? _bloodType;
  String? _gender;
  final _weightCtrl = TextEditingController();

  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  // Animasyon
  late AnimationController _bgCtrl;
  late AnimationController _slideCtrl;
  late Animation<double>   _bgAnim;
  late Animation<double>   _slideAnim;

  static const Color _red      = Color(0xFFD32F2F);
  static const Color _redDark  = Color(0xFFB71C1C);
  static const Color _redLight = Color(0xFFEF5350);

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _bgAnim    = CurvedAnimation(parent: _bgCtrl,   curve: Curves.easeInOut);
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic);
    _slideCtrl.forward();
    _fetchDistricts();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _slideCtrl.dispose();
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    _birthCtrl.dispose(); _phoneCtrl.dispose(); _weightCtrl.dispose();
    super.dispose();
  }

  // ==========================================================================
  // VERİ
  // ==========================================================================
  Future<void> _fetchDistricts() async {
    try {
      final res = await http.get(Uri.parse('${ApiConstants.locationsEndpoint}/districts'));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as List;
        if (mounted) setState(() => _districts = data.map((d) => District.fromJson(d)).toList());
      }
    } catch (_) {}
  }

  Future<void> _fetchNeighborhoods(String districtId) async {
    if (!mounted) return;
    setState(() { _loadingNbh = true; _neighborhood = null; _neighborhoods = []; });
    try {
      final res = await http.get(
          Uri.parse('${ApiConstants.locationsEndpoint}/districts/$districtId/neighborhoods'));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as List;
        if (mounted) setState(() => _neighborhoods = data.map((n) => Neighborhood.fromJson(n)).toList());
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingNbh = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 6570)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _red, onPrimary: Colors.white, onSurface: Colors.black87),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _birthCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  // ==========================================================================
  // NAVİGASYON
  // ==========================================================================
  void _next() {
    if (_step == 0 && _key1.currentState!.validate()) {
      setState(() => _step++);
      _slideCtrl.forward(from: 0);
    } else if (_step == 1 && _key2.currentState!.validate()) {
      setState(() => _step++);
      _slideCtrl.forward(from: 0);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _slideCtrl.forward(from: 0);
    } else {
      Navigator.pop(context);
    }
  }

  // ==========================================================================
  // KAYIT (orijinal iş mantığı korundu)
  // ==========================================================================
  Future<void> _submit() async {
    if (!_key3.currentState!.validate()) return;
    if (_bloodType == null || _gender == null) {
      _showErr('Lütfen kan grubu ve cinsiyeti seçin.');
      return;
    }
    setState(() => _isLoading = true);

    double? lat, lon;
    try {
      final dName  = _district?.name ?? '';
      final rawN   = _neighborhood?.name ?? '';
      final cleanN = rawN.replaceAll(RegExp(r'\s+Mah\.?$|\s+Mahallesi$', caseSensitive: false), '').trim();
      final headers = {'User-Agent': 'IzmirBloodDonationApp/1.0 (StudentProject)'};

      for (final q in [
        '$cleanN Mahallesi, $dName, İzmir, Türkiye',
        '$cleanN, $dName, İzmir, Türkiye',
        '$dName, İzmir, Türkiye',
      ]) {
        final res = await http.get(
          Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=1'),
          headers: headers,
        );
        final data = json.decode(res.body);
        if (data.isNotEmpty) {
          lat = double.parse(data[0]['lat']);
          lon = double.parse(data[0]['lon']);
          break;
        }
      }
    } catch (_) {
      lat = 38.4237; lon = 27.1428;
    }

    try {
      final res = await http.post(
        Uri.parse(ApiConstants.donorRegisterEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ad_soyad': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text.trim(),
          'dogum_tarihi': _birthCtrl.text.trim(),
          'telefon': _phoneCtrl.text.trim(),
          'kan_grubu': _bloodType,
          'cinsiyet': _gender,
          'kilo': double.tryParse(_weightCtrl.text.trim()) ?? 0.0,
          'neighborhood_id': _neighborhood?.id,
          'latitude': lat,
          'longitude': lon,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Kayıt başarılı! Giriş yapabilirsiniz.'),
          ]),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context);
      } else {
        String msg = 'Kayıt başarısız (${res.statusCode}).';
        try {
          final e = json.decode(utf8.decode(res.bodyBytes));
          if (e['detail'] is List) {
            msg = 'Bazı alanlar hatalı:\n' +
                (e['detail'] as List)
                    .map((x) => '• ${x['loc']?.last}: ${x['msg']}')
                    .join('\n');
          } else if (e['detail'] is String) {
            msg = e['detail'];
          }
        } catch (_) {}
        _showErr(msg);
      }
    } catch (_) {
      _showErr('Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(children: [
        // Arkaplan blob
        AnimatedBuilder(
          animation: _bgAnim,
          builder: (_, __) => CustomPaint(
            size: Size(size.width, size.height),
            painter: _BlobPainter(_bgAnim.value),
          ),
        ),

        SafeArea(
          child: Column(children: [
            // ── Üst başlık ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                // Geri butonu
                GestureDetector(
                  onTap: _back,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70, size: 16),
                  ),
                ),
                const Spacer(),
                const Text('Donör Kaydı',
                    style: TextStyle(color: Colors.white70,
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                const SizedBox(width: 40),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Adım göstergesi ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: _buildStepper(),
            ),

            const SizedBox(height: 28),

            // ── Adım içeriği ────────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _slideAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(_slideAnim),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStepContent(),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ==========================================================================
  // ADIM GÖSTERGESİ
  // ==========================================================================
  Widget _buildStepper() {
    final steps = [
      _StepDef(Icons.person_outline_rounded, 'Kimlik'),
      _StepDef(Icons.location_on_outlined, 'Bölge'),
      _StepDef(Icons.favorite_border_rounded, 'Sağlık'),
    ];
    return Row(
      children: steps.asMap().entries.expand((e) {
        final i    = e.key;
        final s    = e.value;
        final done = _step > i;
        final active = _step == i;
        final widgets = <Widget>[
          Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: active || done
                    ? const LinearGradient(
                        colors: [_redDark, _red, _redLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : null,
                color: active || done ? null : Colors.white12,
                shape: BoxShape.circle,
                boxShadow: active
                    ? [BoxShadow(
                        color: _red.withValues(alpha: 0.35),
                        blurRadius: 12, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Icon(
                done ? Icons.check_rounded : s.icon,
                color: active || done ? Colors.white : Colors.white30,
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(s.label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w800 : FontWeight.normal,
                    color: active
                        ? _redLight
                        : done
                            ? Colors.white54
                            : Colors.white24)),
          ]),
        ];
        if (i < steps.length - 1) {
          widgets.add(Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              height: 2,
              decoration: BoxDecoration(
                gradient: done
                    ? const LinearGradient(colors: [_redDark, _red])
                    : null,
                color: done ? null : Colors.white12,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ));
        }
        return widgets;
      }).toList(),
    );
  }

  // ==========================================================================
  // ADIM İÇERİĞİ SEÇİCİ
  // ==========================================================================
  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      default: return const SizedBox();
    }
  }

  // ==========================================================================
  // ADIM 1: KİMLİK
  // ==========================================================================
  Widget _buildStep1() {
    return SingleChildScrollView(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Form(
        key: _key1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _stepHeader('Hesap Bilgileri',
              'Sisteme giriş için gerekli kişisel bilgilerinizi girin.'),
          const SizedBox(height: 24),

          _gfld(ctrl: _nameCtrl, label: 'Ad Soyad', icon: Icons.badge_outlined,
              formatters: [FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'))],
              validator: (v) => v!.trim().length < 3 ? 'Geçerli bir ad girin' : null),
          const SizedBox(height: 14),

          _gfld(ctrl: _birthCtrl, label: 'Doğum Tarihi (YYYY-AA-GG)',
              icon: Icons.calendar_month_outlined, readOnly: true,
              onTap: _pickBirthDate,
              validator: (v) => v!.isEmpty ? 'Doğum tarihi zorunlu' : null),
          const SizedBox(height: 14),

          _gfld(ctrl: _emailCtrl, label: 'E-posta Adresi', icon: Icons.email_outlined,
              validator: (v) {
                if (v!.isEmpty) return 'E-posta boş bırakılamaz';
                if (!RegExp(r'^[\w.]+@\w+\.\w+').hasMatch(v)) return 'Geçerli e-posta girin';
                return null;
              }),
          const SizedBox(height: 14),

          _gfld(ctrl: _passCtrl, label: 'Şifre Belirleyin',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              suffix: IconButton(
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
                icon: Icon(
                  _obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: Colors.white38, size: 20),
              ),
              validator: (v) => v!.length < 6 ? 'Şifre en az 6 karakter' : null),

          const SizedBox(height: 32),
          _nextBtn('Devam Et →', _next),
        ]),
      ),
    );
  }

  // ==========================================================================
  // ADIM 2: BÖLGE
  // ==========================================================================
  Widget _buildStep2() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Form(
        key: _key2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _stepHeader('İletişim & Bölge',
              'Size en yakın çağrıları iletebilmemiz için yaşadığınız bölgeyi girin.'),
          const SizedBox(height: 24),

          _gfld(ctrl: _phoneCtrl, label: 'Cep Telefonu', icon: Icons.phone_outlined,
              formatters: [FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11)],
              validator: (v) => v!.length < 10 ? 'Geçerli telefon girin (05...)' : null),
          const SizedBox(height: 14),

          // İlçe
          _glassDrop<District>(
            label: 'İzmir İlçe',
            icon: Icons.location_city_outlined,
            value: _district,
            items: _districts,
            itemLabel: (d) => d.name,
            validator: (v) => v == null ? 'İlçe seçimi zorunlu' : null,
            onChanged: (v) {
              setState(() => _district = v);
              if (v != null) _fetchNeighborhoods(v.id);
            },
          ),
          const SizedBox(height: 14),

          // Mahalle
          if (_loadingNbh)
            const Center(child: CircularProgressIndicator(color: _red))
          else
            _glassDrop<Neighborhood>(
              label: 'Mahalle',
              icon: Icons.location_on_outlined,
              value: _neighborhood,
              items: _neighborhoods,
              itemLabel: (n) => n.name,
              validator: (v) => v == null ? 'Mahalle seçimi zorunlu' : null,
              onChanged: (v) => setState(() => _neighborhood = v),
            ),

          const SizedBox(height: 32),
          Row(children: [
            _backBtn(),
            const SizedBox(width: 12),
            Expanded(child: _nextBtn('Devam Et →', _next)),
          ]),
        ]),
      ),
    );
  }

  // ==========================================================================
  // ADIM 3: SAĞLIK
  // ==========================================================================
  Widget _buildStep3() {
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Form(
        key: _key3,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _stepHeader('Sağlık Bilgileri',
              'Doğru eşleşmeler için temel sağlık verilerinizi girin.'),
          const SizedBox(height: 24),

          // Kan grubu
          _glassDrop<String>(
            label: 'Kan Grubunuz',
            icon: Icons.bloodtype_outlined,
            value: _bloodType,
            items: _bloodTypes,
            itemLabel: (t) => t,
            validator: (v) => v == null ? 'Kan grubu zorunlu' : null,
            onChanged: (v) => setState(() => _bloodType = v),
            accentColor: _red,
          ),
          const SizedBox(height: 14),

          // Cinsiyet
          _glassDrop<String>(
            label: 'Cinsiyetiniz',
            icon: Icons.transgender_outlined,
            value: _gender,
            items: const ['E', 'K'],
            itemLabel: (g) => g == 'E' ? 'Erkek' : 'Kadın',
            validator: (v) => v == null ? 'Cinsiyet seçimi zorunlu' : null,
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 14),

          _gfld(ctrl: _weightCtrl, label: 'Kilonuz (kg)',
              icon: Icons.monitor_weight_outlined,
              formatters: [FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3)],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Kilo zorunlu';
                final w = int.tryParse(v);
                if (w == null || w < 50) return 'En az 50 kg olmalısınız';
                return null;
              }),

          const SizedBox(height: 32),
          Row(children: [
            _backBtn(),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volunteer_activism_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Donör Ol!',
                                style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ==========================================================================
  // ORTAK WİDGET'LAR
  // ==========================================================================
  Widget _stepHeader(String title, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: Colors.white,
          fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
      const SizedBox(height: 6),
      Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
          fontSize: 13, height: 1.4)),
    ],
  );

  Widget _gfld({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool readOnly   = false,
    VoidCallback? onTap,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: isPassword && _obscurePass,
      readOnly: readOnly,
      onTap: onTap,
      inputFormatters: formatters,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: _red,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
        prefixIcon: Icon(icon, color: _redLight, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _redLight, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _glassDrop<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required String? Function(T?)? validator,
    required ValueChanged<T?> onChanged,
    Color accentColor = _redLight,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      validator: validator,
      isExpanded: true,
      dropdownColor: const Color(0xFF1A2030),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
        prefixIcon: Icon(icon, color: _redLight, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _redLight, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent)),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      items: items.map((item) => DropdownMenuItem<T>(
        value: item,
        child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: items.isEmpty ? null : onChanged,
    );
  }

  Widget _nextBtn(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _red,
        foregroundColor: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    ),
  );

  Widget _backBtn() => SizedBox(
    height: 52, width: 52,
    child: OutlinedButton(
      onPressed: _back,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Icon(Icons.arrow_back_ios_new_rounded,
          color: Colors.white54, size: 16),
    ),
  );
}

// ─── Arkaplan Blob Painter ────────────────────────────────────────────────────

class _BlobPainter extends CustomPainter {
  final double t;
  const _BlobPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const red = Color(0xFFD32F2F);

    paint.color = red.withValues(alpha: 0.10);
    final cx1 = size.width * 0.15 + math.sin(t * math.pi) * 25;
    final cy1 = size.height * 0.15 + math.cos(t * math.pi * 0.7) * 20;
    canvas.drawCircle(Offset(cx1, cy1), 190, paint);

    paint.color = red.withValues(alpha: 0.06);
    final cx2 = size.width * 0.9 + math.cos(t * math.pi * 0.8) * 20;
    final cy2 = size.height * 0.7 + math.sin(t * math.pi) * 25;
    canvas.drawCircle(Offset(cx2, cy2), 200, paint);

    paint.color = red.withValues(alpha: 0.08);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.3), 80, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
}

class _StepDef {
  final IconData icon;
  final String label;
  const _StepDef(this.icon, this.label);
}