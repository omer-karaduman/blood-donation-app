src = r'C:\Users\grapl\Desktop\tez\blood-donation-app\backend\app\routers\blood_requests.py'
with open(src, encoding='utf-8') as f:
    content = f.read()

# Fix donor_yanitlari: convert enums to string values
old = '''        donor_yanitlari = [
            {
                "log_id":         b.log_id,
                "donor_ad_soyad": (
                    b.user.donor_profile.ad_soyad
                    if b.user and b.user.donor_profile
                    else "Bilinmeyen Don\u00f6r"
                ),
                "reaksiyon":      b.kullanici_reaksiyonu,
                "reaksiyon_zamani": b.reaksiyon_zamani,
                "ml_score":       b.ml_skoru_o_an or 0.0,
            }
            for b in r.bildirimler
        ]
        output.append({
            "talep_id":             r.talep_id,
            "istenen_kan_grubu":    r.istenen_kan_grubu,
            "unite_sayisi":         r.unite_sayisi,
            "durum":                r.durum,
            "aciliyet_durumu":      r.aciliyet_durumu,
            "olusturma_tarihi":     r.olusturma_tarihi,
            "donor_yanitlari":      donor_yanitlari,
            "gecerlilik_suresi_saat": r.gecerlilik_suresi_saat,
        })'''

new = '''        donor_yanitlari = [
            {
                "log_id":         str(b.log_id),
                "donor_ad_soyad": (
                    b.user.donor_profile.ad_soyad
                    if b.user and b.user.donor_profile
                    else "Bilinmeyen Don\u00f6r"
                ),
                "reaksiyon":      b.kullanici_reaksiyonu.value if hasattr(b.kullanici_reaksiyonu, 'value') else str(b.kullanici_reaksiyonu),
                "reaksiyon_zamani": b.reaksiyon_zamani.isoformat() if b.reaksiyon_zamani else None,
                "ml_score":       b.ml_skoru_o_an or 0.0,
            }
            for b in r.bildirimler
        ]
        output.append({
            "talep_id":             str(r.talep_id),
            "istenen_kan_grubu":    r.istenen_kan_grubu.value if hasattr(r.istenen_kan_grubu, 'value') else str(r.istenen_kan_grubu),
            "unite_sayisi":         r.unite_sayisi,
            "durum":                r.durum.value if hasattr(r.durum, 'value') else str(r.durum),
            "aciliyet_durumu":      r.aciliyet_durumu.value if hasattr(r.aciliyet_durumu, 'value') else str(r.aciliyet_durumu),
            "olusturma_tarihi":     r.olusturma_tarihi.isoformat() if r.olusturma_tarihi else None,
            "donor_yanitlari":      donor_yanitlari,
            "gecerlilik_suresi_saat": r.gecerlilik_suresi_saat,
        })'''

if old in content:
    content = content.replace(old, new, 1)
    with open(src, 'w', encoding='utf-8') as f:
        f.write(content)
    print('blood_requests.py patched OK')
else:
    print('NOT FOUND')
    idx = content.find('"reaksiyon":      b.kullanici_reaksiyonu,')
    print('Line found at char:', idx)
    print(repr(content[idx-200:idx+200]))
