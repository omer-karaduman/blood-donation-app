import random
from faker import Faker
from datetime import datetime, timedelta
from geoalchemy2.elements import WKTElement
import sys
import os
from sqlalchemy.orm import joinedload

# Projedeki diğer dosyaları görebilmesi için yolu ekliyoruz
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
import models

# Türkçe veriler üretmesi için Faker'ı ayarlıyoruz
fake = Faker('tr_TR')

# --- OFFLINE LOKASYON TABLOSU (API LİMİTLERİNDEN KAÇIŞ) ---
# API'nin bizi bloklamasını engellemek için İzmir'in merkez koordinatlarını sabitliyoruz.
DISTRICT_COORDS = {
    "Konak": (38.4189, 27.1287), "Bornova": (38.4651, 27.2168), "Buca": (38.3844, 27.1641),
    "Karşıyaka": (38.4541, 27.1105), "Bayraklı": (38.4623, 27.1659), "Çiğli": (38.4922, 27.0634),
    "Gaziemir": (38.3283, 27.1344), "Balçova": (38.3892, 27.0475), "Narlıdere": (38.3844, 26.9922),
    "Güzelbahçe": (38.3721, 26.8844), "Menemen": (38.6072, 27.0603), "Torbalı": (38.1553, 27.3621),
    "Menderes": (38.2503, 27.1351), "Aliağa": (38.7997, 26.9705), "Bergama": (39.1203, 27.1775),
    "Ödemiş": (38.2306, 27.9714), "Tire": (38.0878, 27.7356), "Karaburun": (38.6361, 26.5103),
    "Urla": (38.3253, 26.7644), "Çeşme": (38.3225, 26.3031), "Kınık": (39.0853, 27.3844),
    "Kiraz": (38.2308, 28.2044), "Beydağ": (38.0928, 28.2144), "Bayındır": (38.2142, 27.6475),
    "Selçuk": (37.9483, 27.3678), "Foça": (38.6694, 26.7567), "Dikili": (39.0733, 26.8903),
    "Seferihisar": (38.1972, 26.8392), "Kemalpaşa": (38.4239, 27.4172),
}

def get_offline_coordinates(district_name):
    """API'ye gitmeden çevrimdışı koordinat üretir (Jitter ekleyerek)."""
    base_lat, base_lon = DISTRICT_COORDS.get(district_name, (38.4189, 27.1287))
    
    # Mahalle içindeki farklı sokakları simüle etmek için +/- 1-2 km (0.015 derece) sapma ekle
    # Bu sayede Konak'taki herkes aynı binada üst üste binmez, dağılır.
    final_lat = base_lat + random.uniform(-0.015, 0.015)
    final_lon = base_lon + random.uniform(-0.015, 0.015)
    
    return final_lat, final_lon

def seed_donors(num_donors=100):
    db = SessionLocal()
    
    blood_types = list(models.BloodTypeEnum)
    genders = list(models.GenderEnum)

    print(f"🚀 {num_donors} adet donör Offline Tablo ile saniyeler içinde ekleniyor...")
    
    neighborhoods = db.query(models.Neighborhood).options(joinedload(models.Neighborhood.district)).all()
    
    if not neighborhoods:
        print("⚠️ HATA: Veritabanında mahalle verisi bulunamadı!")
        db.close()
        return

    try:
        for i in range(num_donors):
            # 1. Ana Kullanıcı
            new_user = models.User(
                email=fake.unique.email(),
                hashed_password="hashed_password_123",
                role=models.UserRoleEnum.DONOR
            )
            db.add(new_user)
            db.flush() 
            
            # 2. Rastgele Mahalle Seç
            random_neighborhood = random.choice(neighborhoods)
            dist_name = random_neighborhood.district.name
            
            # --- OFFLINE KOORDİNAT ATAMASI ---
            lat, lon = get_offline_coordinates(dist_name)
            point = WKTElement(f"POINT({lon} {lat})", srid=4326)
            
            # 3. Profil Detayları
            gender = random.choice(genders)
            name = fake.name_male() if gender == models.GenderEnum.E else fake.name_female()
            days_since_last = random.randint(15, 400)
            
            # Tıbbi kural (Erkek 90 gün, Kadın 120 gün)
            can_donate = days_since_last > (90 if gender == models.GenderEnum.E else 120)

            new_profile = models.DonorProfile(
                user_id=new_user.user_id,
                ad_soyad=name,
                telefon=fake.unique.phone_number(),
                cinsiyet=gender,
                dogum_tarihi=fake.date_of_birth(minimum_age=18, maximum_age=65),
                kilo=random.uniform(55.0, 110.0),
                kan_grubu=random.choice(blood_types),
                son_bagis_tarihi=datetime.utcnow() - timedelta(days=days_since_last),
                kan_verebilir_mi=can_donate,
                konum=point, 
                neighborhood_id=random_neighborhood.neighborhood_id 
            )
            db.add(new_profile)

            # 4. ML ve Oyunlaştırma
            total_notif = random.randint(1, 20)
            pos_resp = random.randint(0, total_notif)
            
            db.add(models.MLFeature(
                user_id=new_user.user_id,
                toplam_bildirim_sayisi=total_notif,
                olumlu_yanit_sayisi=pos_resp,
                basarili_bagis_sayisi=random.randint(0, pos_resp),
                tercih_edilen_saatler=[random.randint(9, 18)],
                maks_kabul_mesafesi=random.uniform(5.0, 50.0),
                ml_tahmin_skoru=0.0,
                duyarlilik_seviyesi=random.randint(1, 5) 
            ))

            db.add(models.GamificationData(
                user_id=new_user.user_id, toplam_puan=random.randint(0, 1500), seviye=random.randint(1, 10)         
            ))

            # 10'arlı paketler halinde kaydet
            if (i + 1) % 10 == 0:
                db.commit()

        db.commit()
        print(f"✅ MÜKEMMEL! API limitlerine takılmadan {num_donors} adet test donörü başarıyla eklendi.")
    except Exception as e:
        db.rollback()
        print(f"❌ Bir hata oluştu: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_donors(100)