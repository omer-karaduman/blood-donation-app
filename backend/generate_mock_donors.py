import pandas as pd
import numpy as np
from faker import Faker
import random
import uuid
import os

# Veritabanı bağlantıları
from database import SessionLocal
import models

# Türkçe sahte veriler üretmek için Faker'ı TR lokaliyle başlatıyoruz
fake = Faker('tr_TR')

def generate_mock_data(num_records=5000):
    print(f"⚙️ {num_records} adet sahte donör verisi üretiliyor...")
    
    # 1. VERİTABANINDAN GERÇEK KONUM UUID'LERİNİ ÇEK
    db = SessionLocal()
    try:
        neighborhoods = db.query(models.Neighborhood).all()
        if not neighborhoods:
            print("⚠️ HATA: Veritabanında mahalle verisi bulunamadı!")
            print("Lütfen sahte veri üretmeden önce 'izmir_data.json' verilerini veritabanına yükleyin.")
            return
    finally:
        db.close()

    # Türkiye'deki yaklaşık kan grubu dağılım oranları
    blood_groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'] # 0 yerine O harfi standarttır
    bg_weights = [0.37, 0.06, 0.14, 0.02, 0.08, 0.01, 0.28, 0.04]

    # İzmir için yaklaşık koordinat sınırları (Enlem ve Boylam)
    izmir_lat_min, izmir_lat_max = 38.1000, 38.7000
    izmir_lon_min, izmir_lon_max = 26.8000, 27.4000

    data = []

    for _ in range(num_records):
        donor_id = str(uuid.uuid4())
        age = random.randint(18, 65) 
        blood_group = random.choices(blood_groups, weights=bg_weights, k=1)[0]
        
        # --- YENİ: İLÇE VE MAHALLE ATAMASI ---
        # Veritabanından çekilen gerçek mahallelerden birini rastgele seç
        random_neighborhood = random.choice(neighborhoods)
        district_id = str(random_neighborhood.district_id)
        neighborhood_id = str(random_neighborhood.neighborhood_id)

        # İzmir sınırları içinde rastgele lokasyon
        latitude = round(random.uniform(izmir_lat_min, izmir_lat_max), 6)
        longitude = round(random.uniform(izmir_lon_min, izmir_lon_max), 6)

        past_donations = random.randint(0, 20)
        days_since_last_donation = random.randint(10, 800)
        response_rate = round(random.uniform(0.0, 1.0), 2) 
        sensitivity_level = random.randint(1, 5) 
        preferred_hour = random.randint(8, 20) 

        # --- ML MODELİ İÇİN HEDEF DEĞİŞKEN (TARGET) ÜRETİMİ ---
        probability = 0.1 
        
        # Kan verme kuralı: Son bağışın üzerinden en az 90 gün geçmiş olmalı
        if days_since_last_donation > 90:
            probability += 0.3
            
            if sensitivity_level >= 4:
                probability += 0.2
            if response_rate > 0.6:
                probability += 0.2
            if past_donations > 5:
                probability += 0.15
        else:
            probability = 0.01 

        # Gürültü ekleme
        probability += random.uniform(-0.1, 0.1)
        probability = max(0.0, min(1.0, probability))

        # Sonuç: 1 (Gelir/Bağış Yapar), 0 (Gelmez)
        will_donate = 1 if random.random() < probability else 0

        data.append({
            "donor_id": donor_id,
            "age": age,
            "blood_group": blood_group,
            "district_id": district_id,         # Eklendi
            "neighborhood_id": neighborhood_id, # Eklendi
            "latitude": latitude,
            "longitude": longitude,
            "past_donations": past_donations,
            "days_since_last_donation": days_since_last_donation,
            "response_rate": response_rate,
            "sensitivity_level": sensitivity_level,
            "preferred_hour": preferred_hour,
            "will_donate": will_donate
        })

    # Veriyi Pandas DataFrame'e çevir
    df = pd.DataFrame(data)
    
    os.makedirs('data', exist_ok=True)
    file_path = 'data/mock_donors.csv'
    df.to_csv(file_path, index=False)
    
    print(f"✅ Başarılı! Veri seti '{file_path}' konumuna kaydedildi.")
    print("\n📊 Veri Seti Özeti:")
    print(df['will_donate'].value_counts(normalize=True).map('{:.2%}'.format))

if __name__ == "__main__":
    generate_mock_data(5000)