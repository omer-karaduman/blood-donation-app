# backend/seed_data.py
import random
import uuid
from faker import Faker
from sqlalchemy.orm import Session
from database import engine, SessionLocal
import models
from datetime import datetime, timedelta
from geoalchemy2.elements import WKTElement

fake = Faker('tr_TR')

def create_mock_data(num_donors=100, num_staff=20, num_institutions=10, num_requests=50):
    models.Base.metadata.create_all(bind=engine)
    db: Session = SessionLocal()
    
    print("Veritabanı temizleniyor (Eski mimari verileri siliniyor)...")
    db.query(models.DonationHistory).delete()
    db.query(models.NotificationLog).delete()
    db.query(models.BloodRequest).delete()
    db.query(models.HealthStatus).delete()
    db.query(models.MLFeature).delete()
    db.query(models.GamificationData).delete()
    db.query(models.DonorProfile).delete()
    db.query(models.StaffProfile).delete()
    db.query(models.Institution).delete()
    db.query(models.User).delete()
    db.commit()

    print(f"{num_institutions} Hastane/Kurum oluşturuluyor...")
    institutions = []
    for _ in range(num_institutions):
        inst = models.Institution(
            kurum_adi=fake.company() + " Kan Merkezi",
            konum=WKTElement(f"POINT({fake.longitude()} {fake.latitude()})", srid=4326),
            yetkili_kisi=fake.name(),
            iletisim=fake.phone_number()
        )
        db.add(inst)
        institutions.append(inst)
    db.commit()

    print(f"{num_donors} Donör ve Profil oluşturuluyor...")
    donors = []
    blood_types = list(models.BloodTypeEnum)
    genders = list(models.GenderEnum)
    
    for _ in range(num_donors):
        # 1. Ana Kullanıcıyı Oluştur (Auth)
        user = models.User(
            email=fake.unique.email(),
            hashed_password="password123", # Basit bir şifre
            role=models.UserRoleEnum.DONOR
        )
        db.add(user)
        db.flush() # user_id'yi almak için

        # 2. Donör Profilini Oluştur (Kişisel Bilgiler)
        profile = models.DonorProfile(
            user_id=user.user_id,
            ad_soyad=fake.name(),
            telefon=fake.unique.phone_number(),
            cinsiyet=random.choice(genders),
            dogum_tarihi=fake.date_of_birth(minimum_age=18, maximum_age=65),
            kilo=random.uniform(55.0, 110.0),
            kan_grubu=random.choice(blood_types),
            konum=WKTElement(f"POINT({fake.longitude()} {fake.latitude()})", srid=4326)
        )
        db.add(profile)
        donors.append(profile)
    db.commit()

    print(f"{num_staff} Sağlık Çalışanı oluşturuluyor...")
    for _ in range(num_staff):
        user = models.User(
            email=fake.unique.email(),
            hashed_password="staffpassword",
            role=models.UserRoleEnum.HEALTHCARE
        )
        db.add(user)
        db.flush()

        staff = models.StaffProfile(
            user_id=user.user_id,
            kurum_id=random.choice(institutions).kurum_id,
            ad_soyad=fake.name(),
            unvan=random.choice(["Doktor", "Hemşire", "Lab Teknisyeni"]),
            personel_no=str(fake.unique.random_number(digits=6))
        )
        db.add(staff)
    db.commit()

    print(f"{num_requests} Kan Talebi ve Donör Reaksiyonları simüle ediliyor...")
    urgencies = list(models.UrgencyEnum)
    statuses = list(models.RequestStatusEnum)
    reactions = list(models.NotificationReactionEnum)
    results = list(models.DonationResultEnum)

    for _ in range(num_requests):
        req_time = fake.date_time_between(start_date='-6m', end_date='now')
        request = models.BloodRequest(
            kurum_id=random.choice(institutions).kurum_id,
            istenen_kan_grubu=random.choice(blood_types),
            unite_sayisi=random.randint(1, 5),
            aciliyet_durumu=random.choice(urgencies),
            durum=random.choice(statuses),
            olusturma_tarihi=req_time
        )
        db.add(request)
        db.commit()

        # Rastgele donörlere bildirim gönder (User tablosu üzerinden)
        notified_donors = random.sample(donors, random.randint(5, 15))
        for d in notified_donors:
            reaction = random.choice(reactions)
            reaction_time = req_time + timedelta(minutes=random.randint(1, 120)) if reaction != models.NotificationReactionEnum.GORMEZDEN_GELDI else None

            log = models.NotificationLog(
                user_id=d.user_id, # User tablosuna bakıyor
                talep_id=request.talep_id,
                gonderim_zamani=req_time + timedelta(seconds=random.randint(10, 60)),
                iletilme_durumu=models.NotificationDeliveryEnum.BASARILI,
                kullanici_reaksiyonu=reaction,
                reaksiyon_zamani=reaction_time
            )
            db.add(log)

            if reaction == models.NotificationReactionEnum.KABUL:
                donation = models.DonationHistory(
                    user_id=d.user_id, # DonorProfile tablosuna bakıyor
                    kurum_id=request.kurum_id,
                    talep_id=request.talep_id,
                    bagis_tarihi=reaction_time + timedelta(hours=random.randint(1, 5)),
                    islem_sonucu=random.choice(results)
                )
                db.add(donation)
    
    db.commit()
    print("✅ Yeni Mimariyle Veriler Başarıyla Hazırlandı!")
    db.close()

if __name__ == "__main__":
    create_mock_data()