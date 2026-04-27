src = r'C:\Users\grapl\Desktop\tez\blood-donation-app\mobile\lib\screens\donor\tabs\donor_requests_tab.dart'
with open(src, encoding='utf-8') as f:
    content = f.read()

# Fix LinkedMap: replace spread with Map.from()
old = "          if (idx != -1) _requests[idx] = {..._requests[idx], 'reaksiyon': 'Kabul'};"
new = """          if (idx != -1) {
            final updated = Map<String, dynamic>.from(_requests[idx]);
            updated['reaksiyon'] = 'Kabul';
            _requests[idx] = updated;
          }"""

if old in content:
    content = content.replace(old, new, 1)
    with open(src, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Requests tab patched OK')
else:
    print('Pattern not found')
    idx = content.find('_requests[idx] = {')
    if idx >= 0:
        print(repr(content[idx:idx+100]))
