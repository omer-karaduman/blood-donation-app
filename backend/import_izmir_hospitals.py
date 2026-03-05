import json
import os
from sqlalchemy.orm import Session
from database import SessionLocal, engine
import models
from geoalchemy2.elements import WKTElement

def import_saglik_envanteri():
    # 1. EĞER TABLOLAR YOKSA OLUŞTUR (Sıfırdan kurulum için kritik!)
    print("🛠️ Veritabanı tabloları kontrol ediliyor...")
    models.Base.metadata.create_all(bind=engine)

    db: Session = SessionLocal()
    
    # 2. ESKİ VERİLERİ TEMİZLE (Eğer tablo zaten varsa ve doluysa)
    print("🧹 Eski kurum verileri temizleniyor...")
    db.query(models.Institution).delete()
    db.commit()

    json_path = os.path.join(os.path.dirname(__file__), "data", "izmir_saglik_envanteri_transformed.json")
    
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        id_to_uuid_map = {}

        print(f"🔄 Toplam {len(data)} kurum işleniyor...")

        # --- 1. AŞAMA: ÖNCE PARENT (ANA KURUM / BAĞIMSIZ) KAYITLARI ---
        print("🏥 Ana kurumlar (Parent) veritabanına ekleniyor...")
        for h in data:
            if h.get("PARENT_ID") is None:
                point = WKTElement(f'POINT({h["BOYLAM"]} {h["ENLEM"]})', srid=4326)
                
                inst = models.Institution(
                    kurum_adi=h["ADI"],
                    tipi=h["TIPI"],
                    ilce=h["ILCE"],
                    tam_adres=h["TAM_ADRES"],
                    parent_id=None, 
                    konum=point
                )
                db.add(inst)
                db.flush() 
                
                id_to_uuid_map[h["ID"]] = inst.kurum_id

        # --- 2. AŞAMA: SONRA CHILD (ALT BİRİM) KAYITLARI ---
        print("🔗 Bağlı birimler (Child) ana kurumlara bağlanıyor...")
        for h in data:
            if h.get("PARENT_ID") is not None:
                point = WKTElement(f'POINT({h["BOYLAM"]} {h["ENLEM"]})', srid=4326)
                
                db_parent_uuid = id_to_uuid_map.get(h["PARENT_ID"])
                
                if not db_parent_uuid:
                    print(f"⚠️ Uyarı: {h['ADI']} için Parent ID ({h['PARENT_ID']}) bulunamadı.")
                
                inst = models.Institution(
                    kurum_adi=h["ADI"],
                    tipi=h["TIPI"],
                    ilce=h["ILCE"],
                    tam_adres=h["TAM_ADRES"],
                    parent_id=db_parent_uuid,
                    konum=point
                )
                db.add(inst)

        db.commit()
        print("🚀 Hiyerarşik veriler başarıyla aktarıldı!")
        
    except Exception as e:
        print(f"❌ Hata: {e}")
        db.rollback() 
    finally:
        db.close()

if __name__ == "__main__":
    import_saglik_envanteri()