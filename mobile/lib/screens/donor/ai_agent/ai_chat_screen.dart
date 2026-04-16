// mobile/lib/screens/donor/ai_agent/ai_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../constants/api_constants.dart';
import '../../../models/donor.dart';

class AiChatScreen extends StatefulWidget {
  final Donor currentUser;

  const AiChatScreen({super.key, required this.currentUser});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  // ── Tema renkleri ────────────────────────────────
  static const _crimson = Color(0xFFC0182A);
  static const _crimsonDark = Color(0xFF8B0000);
  static const _bg = Color(0xFFF5F5F7);
  static const _surface = Colors.white;
  static const _textPrimary = Color(0xFF1C1C1E);
  static const _textSecondary = Color(0xFF8E8E93);

  // ── Öneri chip'leri ────────────────────────────────────────────────────────
  final List<String> _suggestions = [
    "Bağışa uygun muyum?",
    "Süreç nasıl işler?",
    "Bağış öncesi beslenme",
    "Yakın merkez bul",
  ];

  final List<Map<String, dynamic>> _messages = [
    {
      "isAi": true,
      "text":
          "Merhaba! Ben Kan Bağışı Asistanınım. 🩸\n\nBağış süreci, uygunluk koşulları veya yakın merkezler hakkında sorularını yanıtlayabilirim. Sana nasıl yardımcı olabilirim?",
      "time": "Şimdi",
      "showSuggestions": true,
    }
  ];

  // ── API / Mesaj Gönderme ───────────────────────────────────────────────────

  void _sendMessage([String? quickText]) async {
    final text = quickText ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"isAi": false, "text": text, "time": _nowTime()});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    String aiResponse = "";

    try {
      // 🚀 Backend'e POST isteği atıyoruz
      // Not: ApiConstants.baseUrl Android emülatör için genelde "http://10.0.2.2:8000" olmalıdır
      final url = Uri.parse(ApiConstants.aiChatEndpoint);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'message': text,
          'user_id': widget.currentUser.userId,
        }),
      );

      if (response.statusCode == 200) {
        // Türkçe karakter sorunu yaşamamak için utf8.decode kullanıyoruz
        final data = json.decode(utf8.decode(response.bodyBytes));
        aiResponse = data['reply'] ?? "Yanıt alınamadı.";
      } else {
        aiResponse = "Üzgünüm, şu an sunucuya bağlanamıyorum. (Hata: ${response.statusCode})";
      }
    } catch (e) {
      aiResponse = "Bir bağlantı hatası oluştu. Sunucu çalışıyor mu?";
      debugPrint("AI Chat Hatası: $e");
    }

    if (mounted) {
      setState(() {
        _messages.add({
          "isAi": true,
          "text": aiResponse,
          "time": _nowTime(),
          "showSuggestions": false,
        });
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  String _nowTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingBubble();
                }
                final msg = _messages[index];
                return _buildMessageRow(msg);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ── APP BAR ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_crimson, _crimsonDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 15),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Bağış Asistanı",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Çevrimiçi",
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.75)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.more_horiz_rounded,
                  color: Colors.white.withOpacity(0.8)),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  // ── MESAJ SATIRI ───────────────────────────────────────────────────────────

  Widget _buildMessageRow(Map<String, dynamic> msg) {
    final bool isAi = msg["isAi"] as bool;
    final bool showSuggestions = msg["showSuggestions"] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isAi) ...[
            _aiAvatarIcon(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                _buildBubble(msg["text"] as String, isAi),
                const SizedBox(height: 4),
                Text(
                  msg["time"] as String? ?? "",
                  style: const TextStyle(
                      fontSize: 10, color: _textSecondary),
                ),
                if (showSuggestions) ...[
                  const SizedBox(height: 10),
                  _buildSuggestionChips(),
                ],
              ],
            ),
          ),
          if (!isAi) ...[
            const SizedBox(width: 8),
            _userAvatarIcon(),
          ],
        ],
      ),
    );
  }

  Widget _aiAvatarIcon() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _surface,
        border: Border.all(color: _crimson.withOpacity(0.2)),
      ),
      child: const Icon(Icons.auto_awesome, color: _crimson, size: 14),
    );
  }

  Widget _userAvatarIcon() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _crimson.withOpacity(0.1),
        border: Border.all(color: _crimson.withOpacity(0.2)),
      ),
      child: const Icon(Icons.person_outline_rounded,
          color: _crimson, size: 16),
    );
  }

  Widget _buildBubble(String text, bool isAi) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isAi ? _surface : _crimson,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isAi ? 4 : 18),
          bottomRight: Radius.circular(isAi ? 18 : 4),
        ),
        border: isAi
            ? Border.all(color: Colors.black.withOpacity(0.07), width: 0.5)
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isAi ? _textPrimary : Colors.white,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  // ── ÖNERI CHİP'LERİ ───────────────────────────────────────────────────────

  Widget _buildSuggestionChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _suggestions
          .map((s) => GestureDetector(
                onTap: () => _sendMessage(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _crimson.withOpacity(0.25), width: 0.8),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _crimson),
                  ),
                ),
              ))
          .toList(),
    );
  }

  // ── YAZMA GÖSTERGESI ──────────────────────────────────────────────────────

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _aiAvatarIcon(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border:
                  Border.all(color: Colors.black.withOpacity(0.07), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => AnimatedContainer(
                  duration: Duration(milliseconds: 400 + i * 150),
                  margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _crimson.withOpacity(0.4 + i * 0.25),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── INPUT ALANI ───────────────────────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
            top: BorderSide(color: Colors.black.withOpacity(0.08), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.black.withOpacity(0.08), width: 0.5),
              ),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(fontSize: 14, color: _textPrimary),
                decoration: const InputDecoration(
                  hintText: "Asistana bir soru sor...",
                  hintStyle: TextStyle(
                      color: _textSecondary, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  suffixIcon: Icon(Icons.mic_none_rounded,
                      color: _textSecondary, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_crimson, _crimsonDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}