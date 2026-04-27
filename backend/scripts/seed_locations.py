import json
import os
from sqlalchemy.orm import Session
from database import SessionLocal, engine
import models

def seed_izmir_locations():
    # Tabloların var olduğundan emin ol
    print("🛠️ Veritabanı tabloları kontrol ediliyor...")
    models.Base.metadata.create_all(bind=engine)

    db: Session = SessionLocal()

    # Eğer daha önce eklenmişse çift kayıt (duplicate) olmaması için kontrol et
    existing_districts_count = db.query(models.District).count()
    if existing_districts_count > 0:
        print(f"✅ Veritabanında zaten {existing_districts_count} ilçe bulunuyor. İşlem atlanıyor.")
        print("Eğer sıfırdan yüklemek isterseniz önce veritabanındaki kayıtları silin.")
        db.close()
        return

    # JSON dosyasının yolu (Kendi klasör yapına göre gerekirse güncelleyebilirsin)
    # JSON dosyasının 'data' klasörü içinde olduğunu varsayıyoruz.
    json_path = os.path.join(os.path.dirname(__file__), "data", "izmir_data.json")

    if not os.path.exists(json_path):
        # Eğer data klasöründe değilse doğrudan ana dizine bak
        json_path = os.path.join(os.path.dirname(__file__), "izmir_data.json")
        if not os.path.exists(json_path):
            print(f"❌ HATA: {json_path} dosyası bulunamadı!")
            db.close()
            return

    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        # İzmir'in plaka kodu olan "35" anahtarını alıyoruz
        izmir_data = data.get("35", {})
        
        if not izmir_data:
            print("❌ HATA: JSON formatı geçersiz veya '35' (İzmir) anahtarı bulunamadı.")
            return

        toplam_mahalle = 0

        print(f"🌍 İzmir'in {len(izmir_data)} ilçesi veritabanına aktarılıyor...")

        # Sözlük (Dictionary) üzerinde döngüye gir: Anahtar=İlçe, Değer=Mahalle Listesi
        for district_name, neighborhoods in izmir_data.items():
            
            # 1. İlçeyi Oluştur ve Veritabanına Ekle
            new_district = models.District(name=district_name, city_code=35)
            db.add(new_district)
            db.flush() # UUID'nin oluşması için flush yapıyoruz (commit etmeden önce DB'ye gönderir)

            # 2. Bu ilçeye ait mahalleleri oluştur
            for neighborhood_name in neighborhoods:
                new_neighborhood = models.Neighborhood(
                    district_id=new_district.district_id, # İlişkiyi UUID üzerinden kuruyoruz
                    name=neighborhood_name
                )
                db.add(new_neighborhood)
                toplam_mahalle += 1

        # Tüm işlemleri tek seferde kaydet (Performans için döngü dışında commit atılır)
        db.commit()
        print(f"🚀 BAŞARILI! {len(izmir_data)} ilçe ve {toplam_mahalle} mahalle sisteme başarıyla eklendi.")

    except Exception as e:
        db.rollback()
        print(f"❌ Veritabanına yazılırken bir hata oluştu: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed_izmir_locations()