import json
import os
from sqlalchemy.orm import Session
from database import SessionLocal, engine
import models
from geoalchemy2.elements import WKTElement

def import_saglik_envanteri():
    # 1. VERİTABANI TABLOLARINI YENİLE (Şema değişikliği ihtimaline karşı temizlik)
    print("🧹 Veritabanı tabloları güncelleniyor...")
    models.Base.metadata.drop_all(bind=engine)
    models.Base.metadata.create_all(bind=engine)
    print("✨ Tablolar yeni şemaya göre başarıyla oluşturuldu!")

    db: Session = SessionLocal()
    # Dosya adını yeni transformed JSON dosyana göre güncelledik
    json_path = os.path.join(os.path.dirname(__file__), "data", "izmir_saglik_envanteri_transformed.json")
    
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # JSON'daki integer ID'yi DB'deki UUID ile eşleştirmek için bir harita
        # Key: JSON ID (int), Value: DB kurum_id (UUID)
        id_to_uuid_map = {}

        print(f"🔄 Toplam {len(data)} kurum işleniyor...")

        # --- 1. AŞAMA: ÖNCE PARENT (ANA KURUM / BAĞIMSIZ) KAYITLARI ---
        # PARENT_ID'si null olanlar hiyerarşinin tepesindedir.
        print("🏥 Ana kurumlar (Parent) veritabanına ekleniyor...")
        for h in data:
            if h["PARENT_ID"] is None:
                point = WKTElement(f'POINT({h["BOYLAM"]} {h["ENLEM"]})', srid=4326)
                
                inst = models.Institution(
                    kurum_adi=h["ADI"],
                    tipi=h["TIPI"],
                    ilce=h["ILCE"],
                    iletisim=h["TAM_ADRES"],
                    yetkili_kisi="Başhekimlik",
                    hiyerarsi_tipi="Parent", # PARENT_ID null ise 'Parent' kabul ediyoruz
                    parent_id=None, 
                    konum=point
                )
                db.add(inst)
                db.flush() # Veritabanına anlık gönderip kurum_id (UUID) bilgisini alıyoruz
                
                # Eşleşmeyi haritaya kaydet
                id_to_uuid_map[h["ID"]] = inst.kurum_id

        # --- 2. AŞAMA: SONRA CHILD (ALT BİRİM) KAYITLARI ---
        # PARENT_ID'si dolu olanları, haritamızdaki UUID'ler ile bağlıyoruz.
        print("🔗 Bağlı birimler (Child) ana kurumlara bağlanıyor...")
        for h in data:
            if h["PARENT_ID"] is not None:
                point = WKTElement(f'POINT({h["BOYLAM"]} {h["ENLEM"]})', srid=4326)
                
                # JSON'daki PARENT_ID'ye karşılık gelen DB UUID'sini haritadan çek
                db_parent_uuid = id_to_uuid_map.get(h["PARENT_ID"])
                
                inst = models.Institution(
                    kurum_adi=h["ADI"],
                    tipi=h["TIPI"],
                    ilce=h["ILCE"],
                    iletisim=h["TAM_ADRES"],
                    yetkili_kisi="Birim Sorumlusu",
                    hiyerarsi_tipi="Child",
                    parent_id=db_parent_uuid,
                    konum=point
                )
                db.add(inst)

        db.commit()
        print("🚀 Hiyerarşik veriler (ID bazlı) başarıyla aktarıldı!")
        
    except Exception as e:
        print(f"❌ Hata: {e}")
        db.rollback() 
    finally:
        db.close()

if __name__ == "__main__":
    import_saglik_envanteri()