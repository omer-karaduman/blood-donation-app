import json
import os
from sqlalchemy.orm import Session
from database import SessionLocal, engine
import models
from geoalchemy2.elements import WKTElement

def import_saglik_envanteri():
    # 1. EĞER TABLOLAR YOKSA OLUŞTUR
    print("🛠️ Veritabanı tabloları kontrol ediliyor...")
    models.Base.metadata.create_all(bind=engine)

    db: Session = SessionLocal()
    
    # 2. ESKİ VERİLERİ TEMİZLE
    print("🧹 Eski kurum verileri temizleniyor...")
    db.query(models.Institution).delete()
    db.commit()

    # --- 3. YENİ: İLÇELERİ VERİTABANINDAN ÇEK VE EŞLEŞTİR ---
    print("🌍 İlçe referansları veritabanından alınıyor...")
    districts = db.query(models.District).all()
    
    # Türkçe karakter sorununu aşmak için yardımcı fonksiyon
    def normalize_name(name):
        if not name: return ""
        return name.replace("i", "İ").replace("ı", "I").upper().strip()

    # Örn: {"ALİAĞA": UUID('...'), "BORNOVA": UUID('...')}
    district_map = {normalize_name(d.name): d.district_id for d in districts}
    
    if not district_map:
        print("⚠️ Uyarı: Veritabanında hiç ilçe bulunamadı! Lütfen önce ilçe verilerini yükleyin.")
        db.close()
        return

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
                
                # JSON'daki string ilçe ismini veritabanındaki UUID ile eşleştir
                ilce_isim = normalize_name(h.get("ILCE", ""))
                db_district_id = district_map.get(ilce_isim)
                
                if not db_district_id:
                    print(f"⚠️ Uyarı: '{h.get('ILCE')}' adlı ilçe veritabanında bulunamadı. Kurum: {h['ADI']}")

                inst = models.Institution(
                    kurum_adi=h["ADI"],
                    tipi=h["TIPI"],
                    district_id=db_district_id, # String yerine UUID ataması
                    neighborhood_id=None,       # Sağlık envanterinde mahalle verisi varsa buraya eklenebilir
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
                
                ilce_isim = normalize_name(h.get("ILCE", ""))
                db_district_id = district_map.get(ilce_isim)

                inst = models.Institution(
                    kurum_adi=h["ADI"],
                    tipi=h["TIPI"],
                    district_id=db_district_id, # String yerine UUID ataması
                    neighborhood_id=None,
                    tam_adres=h["TAM_ADRES"],
                    parent_id=db_parent_uuid,
                    konum=point
                )
                db.add(inst)

        db.commit()
        print("🚀 Hiyerarşik ve ilişkisel konum verileri başarıyla aktarıldı!")
        
    except Exception as e:
        print(f"❌ Hata: {e}")
        db.rollback() 
    finally:
        db.close()

if __name__ == "__main__":
    import_saglik_envanteri()