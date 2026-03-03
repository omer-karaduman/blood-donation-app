import json
import os
from sqlalchemy.orm import Session
from database import SessionLocal
import models
from geoalchemy2.elements import WKTElement

def get_root_name(full_name):
    # İsimdeki ilk iki kelimeyi kök kabul et (Örn: Ege Üniversitesi)
    words = full_name.split()
    return " ".join(words[:2]) if len(words) >= 2 else full_name

def import_with_hierarchy():
    db: Session = SessionLocal()
    json_path = os.path.join(os.path.dirname(__file__), "data", "izmir_hospitals.json")
    
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        hospitals = data.get("onemliyer", [])
        parents_map = {} # Kök İsim -> Parent UUID eşleşmesi

        print(f"🔄 {len(hospitals)} kayıt hiyerarşik olarak işleniyor...")

        for h in hospitals:
            raw_name = h["ADI"]
            root_name = get_root_name(raw_name)
            
            # 1. Parent (Ana Kurum) Kontrolü/Oluşturma
            if root_name not in parents_map:
                # Ana kurumu veritabanına ekle (Konum olarak ilk bulduğunun konumunu veriyoruz)
                point = WKTElement(f'POINT({h["BOYLAM"]} {h["ENLEM"]})', srid=4326)
                parent_inst = models.Institution(
                    kurum_adi=f"{root_name} (Merkez)",
                    konum=point,
                    yetkili_kisi="Başhekimlik",
                    iletisim=f"{h['ILCE']} - Ana Kampüs",
                    parent_id=None # Ana kurumun parent'ı olmaz
                )
                db.add(parent_inst)
                db.flush() # ID alabilmek için flush
                parents_map[root_name] = parent_inst.kurum_id
            
            # 2. Child (Birim/Poliklinik) Oluşturma
            point = WKTElement(f'POINT({h["BOYLAM"]} {h["ENLEM"]})', srid=4326)
            child_inst = models.Institution(
                kurum_adi=raw_name,
                konum=point,
                yetkili_kisi="Birim Sorumlusu",
                iletisim=f"{h['ILCE']} / {h['YOL']} No:{h['KAPINO']}",
                parent_id=parents_map[root_name] # Ana kuruma bağladık
            )
            db.add(child_inst)

        db.commit()
        print("🚀 Hiyerarşik yapı başarıyla kuruldu!")
        
    except Exception as e:
        print(f"❌ Hata: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    import_with_hierarchy()