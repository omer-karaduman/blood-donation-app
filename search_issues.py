import re, os

# Search ALL dart files for hardcoded saat patterns  
base = r'C:\Users\grapl\Desktop\tez\blood-donation-app\mobile\lib\screens\admin'
for root, dirs, files in os.walk(base):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        path = os.path.join(root, fn)
        with open(path, encoding='utf-8') as fp:
            lines = fp.readlines()
        for i, line in enumerate(lines, 1):
            if 'gecerlilik' in line.lower() or '3 saat' in line or "'3'" in line or '"3"' in line:
                print(f'{fn}:{i}: {line.rstrip()}')

print('\n--- STAFF COUNT ISSUE ---')
# Also search institution screens for personel_sayisi
for root, dirs, files in os.walk(base):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        path = os.path.join(root, fn)
        with open(path, encoding='utf-8') as fp:
            lines = fp.readlines()
        for i, line in enumerate(lines, 1):
            if 'personel_sayisi' in line or 'staff_count' in line or 'personelSayisi' in line:
                print(f'{fn}:{i}: {line.rstrip()}')
