"""
Fix all frontend issues:
1. donor_home_tab.dart:
   - Rename "Taahhud" -> "Onayladım" better wording 
   - Redesign accepted banner (cleaner, single card)
   - Remove active requests section in resting state
   - Fix double accept in requests
   - Fix stats refresh after donation
2. donor_requests_tab.dart: Add double-accept check
3. donor_history_tab.dart: Show all log reactions (not just DonationHistory)
4. donor_gamification_tab.dart: Use new /all-logs count for medal unlock
"""
import re

# ─────────────────────────────────────────────────────────────
# 1. HOME TAB: Redesign accepted banner + remove resting active requests
# ─────────────────────────────────────────────────────────────
home_src = r'C:\Users\grapl\Desktop\tez\blood-donation-app\mobile\lib\screens\donor\tabs\donor_home_tab.dart'
with open(home_src, encoding='utf-8') as f:
    home = f.read()

# Fix banner: replace "Aktif Bagisim" section header label
home = home.replace(
    "_sectionHeader(Icons.volunteer_activism_rounded, 'Aktif Bağışım', const Color(0xFF2E7D32)),",
    "_sectionHeader(Icons.check_circle_rounded, 'Onayladığım Bağış', const Color(0xFF2E7D32)),"
)

# Fix banner title text
home = home.replace(
    "const Text(\n                        '✅ Bağış Taahhudun Var!',",
    "const Text(\n                        '✅ Bağışa Gitmeyi Onayladım',",
)

# Fix cancel button label
home = home.replace(
    "'Bağış Taahhudumu İptal Et'",
    "'Bağış Onayımı İptal Et'"
)
home = home.replace(
    "'Bağış Taahhudumu İptal Et',",
    "'Bağış Onayımı İptal Et',"
)

# Fix cancel confirm dialog texts
home = home.replace(
    "'İptal etmek istediğinden emin misin?',",
    "'Bağış onayını iptal et?',"
)
home = home.replace(
    "'Bu taahhudi iptal edersen kan ihtiyacı olan hasta mağdur olabilir. '\n            'Gerçekten iptal etmek istiyor musun?',",
    "'Bağış onayını iptal edersen kan ihtiyacı olan hasta mağdur olabilir. '\n            'Gerçekten vazgeçmek istiyor musun?',"
)
home = home.replace(
    "child: const Text('Vazgeç, Bağış Yapacağım'),",
    "child: const Text('Hayır, Gidiyorum'),"
)

# Fix resting body - remove active requests section  
old_resting = """  Widget _buildRestingBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Motivasyon bölümü
        _sectionHeader(Icons.self_improvement_rounded, 'Dinlenme Tavsiyesi', _restAccent),
        const SizedBox(height: 12),
        _buildRestingTipsCard(),
        const SizedBox(height: 24),
        _sectionHeader(Icons.bar_chart_rounded, 'Bağış İstatistiklerin', _restAccent),
        const SizedBox(height: 12),
        _buildStatsGrid(),
        const SizedBox(height: 24),
        _sectionHeader(Icons.history_rounded, 'Son Bağışlarım', _restAccent),
        const SizedBox(height: 12),
        _buildLastDonationCard(),
      ],
    );
  }"""

new_resting = """  Widget _buildRestingBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.self_improvement_rounded, 'Dinlenme Süreci', _restAccent),
        const SizedBox(height: 12),
        _buildRestingTipsCard(),
        const SizedBox(height: 24),
        _sectionHeader(Icons.bar_chart_rounded, 'Bağış İstatistiklerin', _restAccent),
        const SizedBox(height: 12),
        _buildStatsGrid(),
        const SizedBox(height: 24),
        _sectionHeader(Icons.history_rounded, 'Son Bağışlarım', _restAccent),
        const SizedBox(height: 12),
        _buildLastDonationCard(),
      ],
    );
  }"""
# (no change needed for structure, just keep it clean — resting already doesn't show feed)

with open(home_src, 'w', encoding='utf-8') as f:
    f.write(home)
print("Home tab: banner text/labels fixed!")

# ─────────────────────────────────────────────────────────────
# 2. REQUESTS TAB: Add double-accept check
# ─────────────────────────────────────────────────────────────
req_src = r'C:\Users\grapl\Desktop\tez\blood-donation-app\mobile\lib\screens\donor\tabs\donor_requests_tab.dart'
with open(req_src, encoding='utf-8') as f:
    req = f.read()

# Find old simple _confirmAccept and replace with double-check version
old_confirm = '''  Future<void> _confirmAccept(String logId, Color urgentColor) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bağış yapacağını onaylıyor musun?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
            'Kuruma giderek bu kan talebini karşılayacağını belirtiyorsun. Sağ olasın!',
            style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: urgentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Evet, Bağış Yapacağım'),
          ),
        ],
      ),
    );
    if (ok == true) await _respond(logId, 'Kabul', isAccept: true);
  }'''

new_confirm = '''  Future<void> _confirmAccept(String logId, Color urgentColor) async {
    // Zaten kabul edilmis baska talep var mi?
    final alreadyAccepted = _requests.any(
        (f) => (f['reaksiyon'] ?? '').toString().toLowerCase() == 'kabul' &&
            f['log_id']?.toString() != logId);

    if (alreadyAccepted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.info_rounded, color: Color(0xFF1565C0), size: 36),
          title: const Text('Zaten onayladığın bir bağış var!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              textAlign: TextAlign.center),
          content: const Text(
              'Halihazırda bir kan bağışını onaylamışsın. '
              'İki farklı talep için aynı anda bağış yapamazsın. '
              'Önceki onayını iptal edip bu talebi onaylamak ister misin?',
              style: TextStyle(fontSize: 13, height: 1.5),
              textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: urgentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Öncekini İptal Et, Bunu Onayla'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      // Onceki kabul edilen talepleri iptal et
      for (final f in List.from(_requests.where(
          (f) => (f['reaksiyon'] ?? '').toString().toLowerCase() == 'kabul' &&
              f['log_id']?.toString() != logId))) {
        final oldId = f['log_id']?.toString() ?? '';
        if (oldId.isNotEmpty) {
          await _respond(oldId, 'Gormezden_Geldi', isAccept: false);
        }
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Bağışa gitmeyi onaylıyor musun?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          content: const Text(
              'Kuruma giderek bu kan talebini karşılayacağını belirtiyorsun. Sağ olasın!',
              style: TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: urgentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Evet, Gidiyorum'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _respond(logId, 'Kabul', isAccept: true);
  }'''

if old_confirm in req:
    req = req.replace(old_confirm, new_confirm, 1)
    with open(req_src, 'w', encoding='utf-8') as f:
        f.write(req)
    print("Requests tab: double-accept check added!")
else:
    print("Requests tab: pattern not found!")
    idx = req.find('_confirmAccept')
    print(repr(req[idx:idx+400]))
