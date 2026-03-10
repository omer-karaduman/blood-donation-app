from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session, joinedload
from geoalchemy2.elements import WKTElement
from sqlalchemy import or_
import models
import schemas
from database import engine, SessionLocal
import uuid

# --- YENİ EKLENEN ML KÜTÜPHANELERİ ---
import joblib
import pandas as pd
import os
from pydantic import BaseModel
from typing import List
# ------------------------------------

# Tabloları oluştur
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Blood Donation AI API - V2")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Tüm kaynaklara izin ver (Test aşaması için ferah bir çözüm)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- ML MODELİNİ UYGULAMA BAŞLARKEN YÜKLE ---
MODEL_PATH = "ml_models/donor_rf_model.pkl"
rf_model = None

if os.path.exists(MODEL_PATH):
    rf_model = joblib.load(MODEL_PATH)
    print("✅ ML Modeli başarıyla yüklendi!")
else:
    print("⚠️ ML Modeli bulunamadı. Lütfen önce train_model.py scriptini çalıştırın.")
# --------------------------------------------

@app.get("/")
def read_root():
    return {"status": "Online", "message": "Bileşim Mimarisi (User + Profile) aktif."}

# --- YENİ KAYIT MANTIĞI ---
@app.post("/register/donor/", response_model=schemas.UserResponse)
def register_donor(user_in: schemas.DonorCreate, db: Session = Depends(get_db)):
    # 1. Email kontrolü (Auth tablosu için)
    db_user = db.query(models.User).filter(models.User.email == user_in.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Bu email adresi zaten kullanımda.")

    # 2. Ana Kullanıcıyı (Auth) Oluştur
    new_user = models.User(
        email=user_in.email,
        hashed_password=user_in.password, # Gerçekte passlib ile hash'lenmeli
        role=models.UserRoleEnum.DONOR
    )
    db.add(new_user)
    db.flush() # user_id'yi almak için veritabanına gönder ama henüz commit etme

    # 3. Donör Profilini Oluştur
    donor_data = user_in.model_dump(exclude={"email", "password", "latitude", "longitude"})
    new_profile = models.DonorProfile(
        user_id=new_user.user_id,
        **donor_data
    )

    # Konum verisi varsa PostGIS formatına çevir
    if user_in.latitude is not None and user_in.longitude is not None:
        new_profile.konum = WKTElement(f"POINT({user_in.longitude} {user_in.latitude})", srid=4326)

    db.add(new_profile)
    db.commit()
    db.refresh(new_user)
    return new_user

# --- MOBİL UYGULAMA İÇİN DONÖR LİSTESİ ---
@app.get("/donors/", response_model=list[schemas.DonorProfileResponse])
def get_donor_list(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    # DonorProfile tablosunu User tablosuyla birleştirerek getiriyoruz (Joined Load)
    return db.query(models.DonorProfile).options(joinedload(models.DonorProfile.user)).offset(skip).limit(limit).all()

@app.get("/institutions/", response_model=list[schemas.InstitutionResponse])
def get_institutions(ilce: str = None, tipi: str = None, db: Session = Depends(get_db)):
    # 1. Flutter tarafı düz liste beklediği için joinedload ile iç içe gömmeye (nested) gerek yok.
    query = db.query(models.Institution)

    # 2. İlçe Filtresi
    if ilce and ilce != "Tümü":
        def upper_tr(text):
            return text.replace("i", "İ").replace("ı", "I").upper()
        # Veritabanındaki 'ilce' kolonu üzerinden filtrele
        query = query.filter(models.Institution.ilce.ilike(f"%{upper_tr(ilce)}%"))
    
    # 3. Akıllı Tip Filtresi (Kritik Nokta)
    if tipi and tipi != "Tümü":
        # Eğer filtre "Kan Merkezi" ise:
        # Kendisi Kan Merkezi olanları VEYA alt birimlerinden (sub_units) herhangi biri 
        # Kan Merkezi olan "Hastaneleri" de getir diyoruz. 
        # Böylece Flutter, Kan Merkezini ekrana çizerken ana Hastaneyi (parent) de bulabilir!
        query = query.filter(
            or_(
                models.Institution.tipi == tipi,
                models.Institution.sub_units.any(models.Institution.tipi == tipi)
            )
        )

    # 4. Sadece Parent olanları DEĞİL, filtreye uyan tüm kayıtları (Parent + Child) düz bir liste olarak dönüyoruz.
    # Flutter bu düz listeyi alıp ID'ler üzerinden hiyerarşik kartları başarıyla oluşturacak.
    results = query.all()
    
    return results


# --- 1. KURUMA AİT PERSONELLERİ GETİRME ---
@app.get("/institutions/{kurum_id}/staff")
def get_institution_staff(kurum_id: uuid.UUID, db: Session = Depends(get_db)):
    # Bu kuruma atanmış tüm sağlık personellerini getir
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.kurum_id == kurum_id).all()
    
    # Flutter tarafında kolay okumak için listeyi formatlıyoruz
    result = []
    for s in staff:
        result.append({
            "user_id": s.user_id,
            "ad_soyad": s.ad_soyad,
            "unvan": s.unvan,
            "personel_no": s.personel_no,
            "email": s.user.email, # User tablosundan e-postayı da çekiyoruz
            "is_active": s.user.is_active
        })
    return result

# --- 2. KURUMA YENİ SAĞLIK PERSONELİ EKLEME ---
@app.post("/staff/", response_model=schemas.UserResponse)
def create_staff(staff: schemas.StaffCreate, db: Session = Depends(get_db)):
    # 1. E-posta daha önce alınmış mı kontrol et
    existing_user = db.query(models.User).filter(models.User.email == staff.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Bu e-posta adresi zaten kullanımda.")

    # 2. Önce Auth(Kimlik) için ana User kaydını oluştur
    new_user = models.User(
        email=staff.email,
        hashed_password=staff.password,
        role=models.UserRoleEnum.HEALTHCARE # Not: İleride bunu veritabanı modelinden STAFF'a çevirebilirsin
    )
    db.add(new_user)
    db.flush()

    # 3. Sağlık Personeli Profilini (StaffProfile) oluştur ve ana kullanıcıya bağla
    new_staff_profile = models.StaffProfile(
        user_id=new_user.user_id,
        kurum_id=staff.kurum_id,
        ad_soyad=staff.ad_soyad,
        unvan=staff.unvan,
        personel_no=staff.personel_no
    )
    db.add(new_staff_profile)
    db.commit()
    db.refresh(new_user)

    return new_user

@app.get("/staff/")
def get_all_staff(db: Session = Depends(get_db)):
    # Veritabanındaki tüm sağlık personellerini çek
    staff_list = db.query(models.StaffProfile).all()
    
    result = []
    for s in staff_list:
        result.append({
            "user_id": str(s.user_id),
            "ad_soyad": s.ad_soyad,
            "unvan": s.unvan,
            "personel_no": s.personel_no,
            "email": s.user.email if s.user else "Bilinmiyor",
            "is_active": s.user.is_active if s.user else False,
            "kurum_id": str(s.kurum_id),
            "kurum_adi": s.institution.kurum_adi if s.institution else "Bilinmeyen Kurum",
            "kurum_tipi": s.institution.tipi if s.institution else ""
        })
    return result

# --- 4. PERSONEL BİLGİLERİNİ GÜNCELLEME ---
@app.put("/staff/{user_id}")
def update_staff(user_id: uuid.UUID, update_data: dict, db: Session = Depends(get_db)):
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == user_id).first()
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    
    if not staff or not user:
        raise HTTPException(status_code=404, detail="Personel bulunamadı")

    # Personel profili güncellemeleri
    if "ad_soyad" in update_data:
        staff.ad_soyad = update_data["ad_soyad"]
    if "unvan" in update_data:
        staff.unvan = update_data["unvan"]
    if "kurum_id" in update_data:
        staff.kurum_id = update_data["kurum_id"]
        
    # User (Auth) tablosu güncellemeleri
    if "is_active" in update_data:
        user.is_active = update_data["is_active"]
    if "email" in update_data and update_data["email"]:
        user.email = update_data["email"]
    if "password" in update_data and update_data["password"]:
        user.hashed_password = update_data["password"] 

    db.commit()
    return {"message": "Personel başarıyla güncellendi"}

# --- 5. PERSONEL SİLME ---
@app.delete("/staff/{user_id}")
def delete_staff(user_id: uuid.UUID, db: Session = Depends(get_db)):
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == user_id).first()
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    
    if not staff or not user:
        raise HTTPException(status_code=404, detail="Personel bulunamadı")

    db.delete(staff)
    db.delete(user)
    db.commit()
    return {"message": "Personel sistemden tamamen silindi"}

# ======================================================================
# --- 🤖 YENİ: MAKİNE ÖĞRENMESİ TABANLI AKILLI DONÖR EŞLEŞTİRME API ---
# ======================================================================

# Frontend'den gelecek donör listesi formatı
class DonorFeature(BaseModel):
    donor_id: str
    age: int
    past_donations: int
    days_since_last_donation: int
    response_rate: float
    sensitivity_level: int
    preferred_hour: int

class MatchRequest(BaseModel):
    donors: List[DonorFeature]

@app.post("/api/ml/match-donors")
def match_donors(request: MatchRequest):
    if rf_model is None:
        raise HTTPException(status_code=500, detail="Sistemde aktif bir ML modeli bulunamadı.")
    
    # 1. Gelen JSON verisini Pandas DataFrame'e çevir
    donors_data = [d.dict() for d in request.donors]
    if not donors_data:
        return {"matches": []}
        
    df = pd.DataFrame(donors_data)
    
    # 2. Modelin eğitildiği özellik sütunlarını (features) seç
    features = [
        'age', 
        'past_donations', 
        'days_since_last_donation', 
        'response_rate', 
        'sensitivity_level', 
        'preferred_hour'
    ]
    
    try:
        X = df[features]
    except KeyError as e:
        raise HTTPException(status_code=400, detail=f"Eksik veri sütunu: {str(e)}")
    
    # 3. Modelden 'Bağış Yapma İhtimali' skorlarını al
    # predict_proba bize [gelmeme_ihtimali, gelme_ihtimali] döner. 1. index lazim.
    probabilities = rf_model.predict_proba(X)[:, 1]
    
    # 4. Sonuçları ID'ler ve skorlar ile eşleştir
    results = []
    for i, donor in enumerate(donors_data):
        match_score = round(probabilities[i] * 100, 1) # Örn: %87.4
        results.append({
            "donor_id": donor["donor_id"],
            "match_score": match_score
        })
        
    # 5. Skoru EN YÜKSEK olandan en düşüğe doğru sırala (Smart Selection)
    results = sorted(results, key=lambda x: x["match_score"], reverse=True)
    
    return {"status": "success", "matches": results}