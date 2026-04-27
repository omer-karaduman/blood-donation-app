src = r'C:\Users\grapl\Desktop\tez\blood-donation-app\mobile\lib\screens\staff\blood_request_detail_screen.dart'
with open(src, encoding='utf-8') as f:
    content = f.read()

old = '      reactionLabel = "Kabul Etti";\n    } else if (reaction == \'Red\')'
new = '      reactionLabel = "Kabul Etti";\n    } else if (reaction == \'Gormezden_Geldi\') {\n      reactionColor = _textSecond;\n      reactionBg = const Color(0xFFF3F4F6);\n      reactionLight = const Color(0xFFE5E7EB);\n      reactionIcon = Icons.do_not_disturb_rounded;\n      reactionLabel = "\u0130lgilenmedi";\n    } else if (reaction == \'Red\')'

if old in content:
    content = content.replace(old, new, 1)
    with open(src, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Staff screen patched OK')
else:
    print('Pattern not found, trying alternative...')
    idx = content.find('reactionLabel = "Kabul Etti"')
    if idx >= 0:
        print(repr(content[idx:idx+200]))
    else:
        print('Kabul Etti not found either!')
