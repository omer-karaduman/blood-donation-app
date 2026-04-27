"""Redesign accepted banner to be cleaner and more professional."""
src = r'C:\Users\grapl\Desktop\tez\blood-donation-app\mobile\lib\screens\donor\tabs\donor_home_tab.dart'
with open(src, encoding='utf-8') as f:
    content = f.read()

# Find the banner widget start and end
start_marker = "  // \u2500\u2500 ONAYLANMI\u015e TALEP BANNER \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
end_marker = "  // Kabul iptal dialogu\n"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)
print(f"Banner starts at: {start_idx}, ends at: {end_idx}")

# New banner code
new_banner = """  // \u2500\u2500 ONAYLANMI\u015e TALEP BANNER \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
\n  Widget _buildAcceptedBanner(Map<String, dynamic> item) {
    final blood = item['istenen_kan_grubu']?.toString() ?? '?';
    final kurum = item['kurum_adi'] ?? 'Bilinmiyor';
    final ilce  = item['ilce']?.toString() ?? '';
    final logId = item['log_id']?.toString() ?? '';
    final unite = item['unite_sayisi']?.toString() ?? '1';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ust renkli serit
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Bagisa Gitmeyi Onayladim',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    blood,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Alt detay kismi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kurum,
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _infoPill(Icons.location_on_rounded, ilce.isNotEmpty ? ilce : 'Konum yok',
                        const Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    _infoPill(Icons.water_drop_rounded, '$unite Unite',
                        const Color(0xFF1565C0)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _confirmCancelAccept(logId),
                    icon: const Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFD32F2F)),
                    label: const Text(
                      'Bagis Onayimi Iptal Et',
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEBEE),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _greenPill(IconData icon, String text) => _infoPill(icon, text, const Color(0xFF2E7D32));

  """

content = content[:start_idx] + new_banner + content[end_idx:]

with open(src, 'w', encoding='utf-8') as f:
    f.write(content)
print("Banner redesigned!")

# Verify no broken braces
open_b = content.count('{')
close_b = content.count('}')
print(f"Braces: open={open_b}, close={close_b}, diff={open_b-close_b}")
