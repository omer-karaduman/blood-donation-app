import random
from faker import Faker
from datetime import datetime, timedelta
from geoalchemy2.elements import WKTElement
import sys
import os

# Projedeki diğer dosyaları görebilmesi için yolu ekliyoruz
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import SessionLocal
import models

# Türkçe veriler üretmesi için Faker'ı ayarlıyoruz
fake = Faker('tr_TR')

def seed_donors(num_donors=100):
    db = SessionLocal()
    
    blood_types = list(models.BloodTypeEnum)
    genders = list(models.GenderEnum)

    print(f"🚀 {num_donors} adet gerçekçi İzmirli donör veritabanına ekleniyor...")
    
    # --- YENİ: VERİTABANINDAN GERÇEK MAHALLELERİ ÇEK ---
    neighborhoods = db.query(models.Neighborhood).all()
    if not neighborhoods:
        print("⚠️ HATA: Veritabanında mahalle verisi bulunamadı!")
        print("Lütfen sahte donör eklemeden önce İzmir ilçe/mahalle verilerini (izmir_data.json) yükleyin.")
        db.close()
        return

    try:
        for i in range(num_donors):
            # 1. Ana Kullanıcıyı (Auth) Oluştur
            new_user = models.User(
                email=fake.unique.email(),
                hashed_password="hashed_password_123", # Test için sabit şifre
                role=models.UserRoleEnum.DONOR
            )
            db.add(new_user)
            db.flush() # Veritabanından user_id'yi al
            
            # Veritabanından rastgele geçerli bir mahalle seç
            random_neighborhood = random.choice(neighborhoods)
            
            # 2. Donör Profilini Oluştur (İzmir Koordinatları İçerir)
            # İzmir: Lat(38.3 - 38.6), Lon(26.9 - 27.3)
            lon = random.uniform(26.9, 27.3)
            lat = random.uniform(38.3, 38.6)
            point = WKTElement(f"POINT({lon} {lat})", srid=4326)
            
            # Rastgele bağış tarihi (Son 1-2 yıl içinde)
            days_since_last = random.randint(15, 400)
            last_donation = datetime.utcnow() - timedelta(days=days_since_last)
            
            # Kurallara göre kan verebilir mi? (Basit kural: 90 günden eskiyse evet)
            can_donate = days_since_last > 90
            
            # Cinsiyete uygun isim seçimi
            gender = random.choice(genders)
            name = fake.name_male() if gender == models.GenderEnum.E else fake.name_female()

            new_profile = models.DonorProfile(
                user_id=new_user.user_id,
                ad_soyad=name,
                telefon=fake.unique.phone_number(),
                cinsiyet=gender,
                dogum_tarihi=fake.date_of_birth(minimum_age=18, maximum_age=65),
                kilo=random.uniform(55.0, 110.0),
                kan_grubu=random.choice(blood_types),
                son_bagis_tarihi=last_donation,
                kan_verebilir_mi=can_donate,
                konum=point,
                neighborhood_id=random_neighborhood.neighborhood_id # YENİ: İlişkisel mahalle ataması
            )
            db.add(new_profile)

            # 3. ML Özelliklerini (MLFeature) Oluştur
            total_notif = random.randint(1, 20)
            positive_responses = random.randint(0, total_notif)
            success_donations = random.randint(0, positive_responses)
            
            new_ml_feature = models.MLFeature(
                user_id=new_user.user_id,
                toplam_bildirim_sayisi=total_notif,
                olumlu_yanit_sayisi=positive_responses,
                basarili_bagis_sayisi=success_donations,
                tercih_edilen_saatler=[random.randint(9, 13), random.randint(14, 19)], # Sabah ve Öğleden sonra saatleri
                maks_kabul_mesafesi=random.uniform(5.0, 50.0),
                ml_tahmin_skoru=0.0 # Bu değer ML modeli çalıştığında güncellenecek
            )
            db.add(new_ml_feature)

            # 4. YENİ: Oyunlaştırma (Gamification) Verisini İlklendir
            new_gamification = models.GamificationData(
                user_id=new_user.user_id,
                toplam_puan=random.randint(0, 1500), # Sahte puanlar
                seviye=random.randint(1, 10)         # Sahte seviyeler
            )
            db.add(new_gamification)

        db.commit()
        print(f"✅ Başarılı! {num_donors} gerçekçi donör sisteme eklendi.")
    except Exception as e:
        db.rollback()
        print(f"❌ Bir hata oluştu: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_donors(100)