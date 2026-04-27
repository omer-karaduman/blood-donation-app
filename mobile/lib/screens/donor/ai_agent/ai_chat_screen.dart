// mobile/lib/screens/donor/ai_agent/ai_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import '../../../../../core/constants/api_constants.dart';
import '../../../models/donor.dart';

class AiChatScreen extends StatefulWidget {
  final Donor currentUser;
  const AiChatScreen({super.key, required this.currentUser});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────

  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;

  // ── Animasyonlar ───────────────────────────────────────────────────────────

  late AnimationController _dotCtrl;
  late AnimationController _headerCtrl;
  late Animation<double> _headerAnim;

  // ── Tema ───────────────────────────────────────────────────────────────────

  static const _gradTop    = Color(0xFF0D1B2A);
  static const _gradMid    = Color(0xFF1B2838);
  static const _accent     = Color(0xFFC0182A);
  static const _accentGlow = Color(0xFF8B0019);
  static const _surface    = Color(0xFF1E2D3D);
  static const _surfaceL   = Color(0xFF243447);
  static const _textW      = Colors.white;
  static const Color _textD = Color(0xFFB0BEC5);
  static const _inputBg    = Color(0xFF162030);

  static const _suggestions = [
    'Kan bağışı hakkında bilgi ver',
    'A+ kan grubu kimlere verir?',
    'Bağış öncesi nelere dikkat etmeliyim?',
    'Kan bağışının faydaları neler?',
    'Kaç günde bir bağış yapılabilir?',
  ];

  @override
  void initState() {
    super.initState();

    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _headerAnim =
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutBack);
    _headerCtrl.forward();

    // Hoş geldiniz mesajı
    _messages.add(_ChatMessage(
      text: 'Merhaba ${widget.currentUser.adSoyad.split(" ").first}! 👋\n\n'
          'Ben KanAI asistanınım. Kan bağışı, sağlık ve randevu konularında sorularınızı yanıtlayabilirim.\n\n'
          'Size nasıl yardımcı olabilirim?',
      isAi: true,
      time: _formatTime(DateTime.now()),
      showSuggestions: true,
    ));
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _headerCtrl.dispose();
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = preset ?? _controller.text.trim();
    if (text.isEmpty || _isTyping) return;

    if (preset == null) _controller.clear();

    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isAi: false,
        time: _formatTime(DateTime.now()),
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final res = await http.post(
        Uri.parse(ApiConstants.aiChatEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': text,
          'user_id': widget.currentUser.userId,
          'kan_grubu': widget.currentUser.kanGrubu,
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      String reply = 'Bir hata oluştu. Lütfen tekrar deneyin.';
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        reply = data['reply'] ?? data['response'] ?? data['message'] ?? reply;
      }

      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          text: reply,
          isAi: true,
          time: _formatTime(DateTime.now()),
        ));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          text: 'Sunucuya ulaşılamadı. Lütfen bağlantınızı kontrol edin.',
          isAi: true,
          time: _formatTime(DateTime.now()),
        ));
      });
    }
    _scrollToBottom();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gradTop,
      body: Stack(
        children: [
          // Arka plan gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_gradTop, _gradMid],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Dekoratif partiküller
          const _StarField(),
          Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildMessageList()),
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return ScaleTransition(
      scale: _headerAnim,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            border: Border(
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.07), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Geri
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _textD, size: 16),
                ),
              ),
              const SizedBox(width: 14),
              // AI avatar + animasyonlu pulse
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _dotCtrl,
                    builder: (_, __) => Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _accent.withValues(
                              alpha: 0.3 + 0.3 * math.sin(_dotCtrl.value * 2 * math.pi)),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accent, _accentGlow],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('KanAI Asistan',
                        style: TextStyle(
                            color: _textW,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text('Aktif · Yapay Zeka Destekli',
                            style: TextStyle(color: _textD, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MESAJ LİSTESİ ──────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return _buildTypingIndicator();
        return _buildMessageBubble(_messages[i]);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            msg.isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (msg.isAi) ...[
            _AiAvatar(accent: _accent),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBubble(msg.text, true),
                  const SizedBox(height: 4),
                  Text(msg.time,
                      style: const TextStyle(
                          color: _textD, fontSize: 10)),
                  if (msg.showSuggestions) ...[
                    const SizedBox(height: 12),
                    _buildSuggestions(),
                  ],
                ],
              ),
            ),
          ] else ...[
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBubble(msg.text, false),
                  const SizedBox(height: 4),
                  Text(msg.time,
                      style: const TextStyle(color: _textD, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _UserAvatar(accent: _accent),
          ],
        ],
      ),
    );
  }

  Widget _buildBubble(String text, bool isAi) {
    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isAi ? _surfaceL : _accent,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isAi ? 4 : 20),
          bottomRight: Radius.circular(isAi ? 20 : 4),
        ),
        border: isAi
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.07), width: 0.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: (isAi ? Colors.black : _accent).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isAi ? _textW : Colors.white,
          fontSize: 14,
          height: 1.55,
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _suggestions.map((s) => GestureDetector(
        onTap: () => _sendMessage(s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward_ios_rounded,
                  color: _accent, size: 10),
              const SizedBox(width: 5),
              Text(s,
                  style: const TextStyle(
                      color: _textW,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _AiAvatar(accent: _accent),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _surfaceL,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07), width: 0.5),
            ),
            child: AnimatedBuilder(
              animation: _dotCtrl,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i * 0.33;
                    final val = math.sin(
                        (_dotCtrl.value - delay) * 2 * math.pi);
                    final opacity = (val.clamp(-1.0, 1.0) + 1) / 2;
                    return Container(
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 5),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.3 + opacity * 0.7),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── INPUT ──────────────────────────────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 14, right: 14, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: _inputBg,
        border: Border(
            top: BorderSide(
                color: Colors.white.withValues(alpha: 0.07), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(
                    color: _textW,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: _accent,
                  cursorWidth: 2,
                  decoration: InputDecoration(
                    hintText: 'Bir soru sor...',
                    hintStyle: TextStyle(
                        color: _textD.withValues(alpha: 0.6), fontSize: 14),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_accent, _accentGlow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Alt widget'lar ────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isAi;
  final String time;
  final bool showSuggestions;
  const _ChatMessage({
    required this.text,
    required this.isAi,
    required this.time,
    this.showSuggestions = false,
  });
}

class _AiAvatar extends StatelessWidget {
  final Color accent;
  const _AiAvatar({required this.accent});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [accent, accent.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.auto_awesome_rounded,
          color: Colors.white, size: 16),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final Color accent;
  const _UserAvatar({required this.accent});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Icon(Icons.person_rounded, color: accent, size: 16),
    );
  }
}

// ── Star field dekorasyon ──────────────────────────────────────────────────────

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rng = math.Random(42);
    return CustomPaint(
      size: Size(size.width, size.height),
      painter: _StarPainter(rng),
    );
  }
}

class _StarPainter extends CustomPainter {
  final math.Random rng;
  _StarPainter(this.rng);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final rng2 = math.Random(42);
    for (int i = 0; i < 60; i++) {
      final x = rng2.nextDouble() * size.width;
      final y = rng2.nextDouble() * size.height;
      final r = rng2.nextDouble() * 1.5 + 0.5;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter _) => false;
}