src = r'C:\Users\grapl\Desktop\tez\blood-donation-app\mobile\lib\screens\donor\tabs\donor_home_tab.dart'

with open(src, encoding='utf-8') as f:
    lines = f.readlines()

# Lines 1018-1096 (0-indexed: 1017-1095) are the broken _confirmAccept block
# Replace them with correct Dart code
correct_block = (
    "  // Bagis yapacagim - cift kabul kontrolu ile\n"
    "  Future<void> _confirmAccept(String logId) async {\n"
    "    final alreadyAccepted = _feed.any(\n"
    "        (f) => (f['reaksiyon'] ?? '').toString().toLowerCase() == 'kabul' &&\n"
    "            f['log_id']?.toString() != logId);\n"
    "\n"
    "    if (alreadyAccepted) {\n"
    "      final ok = await showDialog<bool>(\n"
    "        context: context,\n"
    "        builder: (ctx) => AlertDialog(\n"
    "          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),\n"
    "          icon: const Icon(Icons.info_rounded, color: Color(0xFF1565C0), size: 36),\n"
    "          title: const Text('Zaten aktif bir taahhudun var!',\n"
    "              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),\n"
    "              textAlign: TextAlign.center),\n"
    "          content: const Text(\n"
    "              'Halihazirda bir kan bagisi taahhudun bulunuyor. '\n"
    "              'Iki farkli talep icin ayni anda bagis yapamazsin. '\n"
    "              'Bu yeni talebi kabul edersen oncekini iptal edip bu talebi onaylamak ister misin?',\n"
    "              style: TextStyle(fontSize: 13, height: 1.5),\n"
    "              textAlign: TextAlign.center),\n"
    "          actionsAlignment: MainAxisAlignment.center,\n"
    "          actions: [\n"
    "            TextButton(\n"
    "              onPressed: () => Navigator.pop(ctx, false),\n"
    "              child: const Text('Vazgec'),\n"
    "            ),\n"
    "            ElevatedButton(\n"
    "              onPressed: () => Navigator.pop(ctx, true),\n"
    "              style: ElevatedButton.styleFrom(\n"
    "                backgroundColor: _activePrimary,\n"
    "                foregroundColor: Colors.white,\n"
    "                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n"
    "              ),\n"
    "              child: const Text('Oncekini Iptal Et, Bunu Onayla'),\n"
    "            ),\n"
    "          ],\n"
    "        ),\n"
    "      );\n"
    "      if (ok != true) return;\n"
    "      for (final f in List.from(_feed.where(\n"
    "          (f) => (f['reaksiyon'] ?? '').toString().toLowerCase() == 'kabul' &&\n"
    "              f['log_id']?.toString() != logId))) {\n"
    "        final oldId = f['log_id']?.toString() ?? '';\n"
    "        if (oldId.isNotEmpty) {\n"
    "          await _respond(oldId, 'Gormezden_Geldi', isAccept: false, silent: true);\n"
    "        }\n"
    "      }\n"
    "    } else {\n"
    "      final ok = await showDialog<bool>(\n"
    "        context: context,\n"
    "        builder: (ctx) => AlertDialog(\n"
    "          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),\n"
    "          title: const Text('Bagis yapacagini onayliyor musun?',\n"
    "              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),\n"
    "          content: const Text(\n"
    "              'Kuruma giderek bu kan talebini karsilayacagini belirtiyorsun. Teşekkürler!',\n"
    "              style: TextStyle(fontSize: 14)),\n"
    "          actions: [\n"
    "            TextButton(\n"
    "              onPressed: () => Navigator.pop(ctx, false),\n"
    "              child: const Text('Vazgec'),\n"
    "            ),\n"
    "            ElevatedButton(\n"
    "              onPressed: () => Navigator.pop(ctx, true),\n"
    "              style: ElevatedButton.styleFrom(\n"
    "                backgroundColor: _activePrimary,\n"
    "                foregroundColor: Colors.white,\n"
    "                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n"
    "              ),\n"
    "              child: const Text('Evet, Bagis Yapacagim'),\n"
    "            ),\n"
    "          ],\n"
    "        ),\n"
    "      );\n"
    "      if (ok != true) return;\n"
    "    }\n"
    "    await _respond(logId, 'Kabul', isAccept: true);\n"
    "  }\n"
)

# Replace lines 1018-1096 (0-indexed 1017-1095)
new_lines = lines[:1017] + [correct_block] + lines[1096:]

with open(src, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f'Done! Total lines: {len(new_lines)}')

# Verify no backslash-quote in the replaced section
with open(src, encoding='utf-8') as f:
    content = f.read()

idx = content.find("_confirmAccept")
section = content[idx:idx+2000]
if "\\'" in section:
    print("WARNING: Still has backslash-quote!")
else:
    print("OK: No backslash-quote found in _confirmAccept")
