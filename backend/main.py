from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session, joinedload
from geoalchemy2.elements import WKTElement
from sqlalchemy import or_
import models
import schemas
from database import engine, SessionLocal
import uuid
from datetime import datetime
import traceback
import joblib
import pandas as pd
import os
from typing import List

# Tabloları oluştur
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Blood Donation AI API - V2 (Optimized)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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

# --- ML MODELİNİ YÜKLE ---
MODEL_PATH = "ml_models/donor_rf_model.pkl"
rf_model = None

if os.path.exists(MODEL_PATH):
    rf_model = joblib.load(MODEL_PATH)
    print("✅ ML Modeli başarıyla yüklendi!")
else:
    print("⚠️ ML Modeli bulunamadı. Lütfen önce train_model.py scriptini çalıştırın.")

@app.get("/")
def read_root():
    return {"status": "Online", "message": "Akıllı Kan Bağışı Sistemi Aktif."}

# ======================================================================
# --- 1. PERSONEL (STAFF) İŞ AKIŞI: KAN TALEBİ VE OTOMATİK ML ---
# ======================================================================

@app.post("/requests/", response_model=schemas.BloodRequestDetailResponse)
def create_smart_blood_request(
    request_in: schemas.BloodRequestCreate, 
    personel_id: uuid.UUID, 
    db: Session = Depends(get_db)
):
    """
    Staff sadece kan grubu ve ünite bilgisini girer. 
    Sistem arka planda ML modelini çalıştırır ve donör bildirimlerini (log) oluşturur.
    """
    # 1. Personelin kurumunu doğrula
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == personel_id).first()
    if not staff:
        raise HTTPException(status_code=404, detail="Personel yetkisi bulunamadı.")

    # 2. Kan Talebi Kaydını Oluştur
    new_request = models.BloodRequest(
        kurum_id=staff.kurum_id,
        olusturan_personel_id=personel_id,
        istenen_kan_grubu=request_in.istenen_kan_grubu,
        unite_sayisi=request_in.unite_sayisi,
        aciliyet_durumu=request_in.aciliyet_durumu,
        durum=models.RequestStatusEnum.AKTIF
    )
    db.add(new_request)
    db.flush()

    # 3. ARKA PLAN ML SÜRECİ (Görünmez Zeka)
    if rf_model is not None:
        donors = db.query(models.DonorProfile)\
                   .options(joinedload(models.DonorProfile.ml_features))\
                   .filter(models.DonorProfile.kan_grubu == request_in.istenen_kan_grubu)\
                   .filter(models.DonorProfile.kan_verebilir_mi == True)\
                   .all()

        if donors:
            ml_input_data = []
            valid_donors = []
            for d in donors:
                age = (datetime.utcnow().date() - d.dogum_tarihi.date()).days // 365
                days_since = (datetime.utcnow() - d.son_bagis_tarihi).days if d.son_bagis_tarihi else 999
                
                feat = d.ml_features
                response_rate = (feat.olumlu_yanit_sayisi / feat.toplam_bildirim_sayisi) if feat and feat.toplam_bildirim_sayisi > 0 else 0.5
                
                ml_input_data.append({
                    "age": age,
                    "past_donations": feat.basarili_bagis_sayisi if feat else 0,
                    "days_since_last_donation": days_since,
                    "response_rate": response_rate,
                    "sensitivity_level": 3,
                    "preferred_hour": feat.tercih_edilen_saatler[0] if feat and feat.tercih_edilen_saatler else 12
                })
                valid_donors.append(d)

            df = pd.DataFrame(ml_input_data)
            probabilities = rf_model.predict_proba(df)[:, 1]

            # 4. Akıllı Bildirim Loglama (Admin'in göreceği kısımlar)
            for i, donor in enumerate(valid_donors):
                score = float(probabilities[i] * 100)
                
                if score >= 40.0: # Belirli bir başarı eşiği
                    new_log = models.NotificationLog(
                        user_id=donor.user_id,
                        talep_id=new_request.talep_id,
                        ml_skoru_o_an=score,
                        iletilme_durumu=models.NotificationDeliveryEnum.BASARILI,
                        kullanici_reaksiyonu=models.NotificationReactionEnum.GORMEZDEN_GELDI
                    )
                    db.add(new_log)
                    if donor.ml_features:
                        donor.ml_features.toplam_bildirim_sayisi += 1

    db.commit()
    db.refresh(new_request)
    return new_request

@app.get("/staff/my-requests", response_model=List[schemas.BloodRequestDetailResponse])
def get_staff_requests(personel_id: uuid.UUID, db: Session = Depends(get_db)):
    """Staff'ın kendi taleplerini ve donör reaksiyonlarını (geliyorum/red) görmesi için."""
    requests = db.query(models.BloodRequest)\
                 .options(joinedload(models.BloodRequest.bildirimler).joinedload(models.NotificationLog.user))\
                 .filter(models.BloodRequest.olusturan_personel_id == personel_id)\
                 .order_by(models.BloodRequest.olusturma_tarihi.desc())\
                 .all()
    
    output = []
    for r in requests:
        donor_yanitlari = []
        for b in r.bildirimler:
            donor_yanitlari.append({
                "donor_ad_soyad": b.user.donor_profile.ad_soyad,
                "reaksiyon": b.kullanici_reaksiyonu,
                "reaksiyon_zamani": b.reaksiyon_zamani
            })
        
        output.append({
            "talep_id": r.talep_id,
            "istenen_kan_grubu": r.istenen_kan_grubu,
            "unite_sayisi": r.unite_sayisi,
            "durum": r.durum,
            "olusturma_tarihi": r.olusturma_tarihi,
            "donor_yanitlari": donor_yanitlari
        })
    return output

# ======================================================================
# --- 2. ADMİN İŞ AKIŞI: SİSTEM DENETİMİ ---
# ======================================================================

@app.get("/admin/system-logs", response_model=List[schemas.AdminRequestLogResponse])
def get_admin_logs(db: Session = Depends(get_db)):
    """Admin'in tüm talepleri ve ML öneri sayılarını izlemesi için."""
    logs = db.query(models.BloodRequest).order_by(models.BloodRequest.olusturma_tarihi.desc()).all()
    
    result = []
    for log in logs:
        result.append({
            "talep_id": log.talep_id,
            "kurum_adi": log.institution.kurum_adi if log.institution else "Bilinmiyor",
            "staff_ad_soyad": log.personel.staff_profile.ad_soyad if log.personel else "Sistem",
            "olusturma_tarihi": log.olusturma_tarihi,
            "istenen_kan_grubu": log.istenen_kan_grubu,
            "onerilen_donor_sayisi": len(log.bildirimler)
        })
    return result

# ======================================================================
# --- 3. GENEL YÖNETİM (Kayıt, Kurum, Personel) ---
# ======================================================================

@app.post("/register/donor/", response_model=schemas.UserResponse)
def register_donor(user_in: schemas.DonorCreate, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.email == user_in.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email kullanımda.")

    new_user = models.User(email=user_in.email, hashed_password=user_in.password, role=models.UserRoleEnum.DONOR)
    db.add(new_user)
    db.flush()

    donor_data = user_in.model_dump(exclude={"email", "password", "latitude", "longitude"})
    new_profile = models.DonorProfile(user_id=new_user.user_id, **donor_data)

    if user_in.latitude is not None and user_in.longitude is not None:
        new_profile.konum = WKTElement(f"POINT({user_in.longitude} {user_in.latitude})", srid=4326)

    db.add(new_profile)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.get("/institutions/", response_model=list[schemas.InstitutionResponse])
def get_institutions(ilce: str = None, tipi: str = None, db: Session = Depends(get_db)):
    query = db.query(models.Institution)
    if ilce and ilce != "Tümü":
        def upper_tr(text): return text.replace("i", "İ").replace("ı", "I").upper()
        query = query.filter(models.Institution.ilce.ilike(f"%{upper_tr(ilce)}%"))
    
    if tipi and tipi != "Tümü":
        query = query.filter(or_(models.Institution.tipi == tipi, models.Institution.sub_units.any(models.Institution.tipi == tipi)))
    return query.all()

@app.get("/staff/")
def get_all_staff(db: Session = Depends(get_db)):
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
            "kurum_adi": s.institution.kurum_adi if s.institution else "Bilinmiyor"
        })
    return result

@app.post("/staff/", response_model=schemas.UserResponse)
def create_staff(staff: schemas.StaffCreate, db: Session = Depends(get_db)):
    existing_user = db.query(models.User).filter(models.User.email == staff.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email kullanımda.")

    new_user = models.User(email=staff.email, hashed_password=staff.password, role=models.UserRoleEnum.HEALTHCARE)
    db.add(new_user)
    db.flush()

    new_staff_profile = models.StaffProfile(user_id=new_user.user_id, kurum_id=staff.kurum_id, ad_soyad=staff.ad_soyad, unvan=staff.unvan, personel_no=staff.personel_no)
    db.add(new_staff_profile)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.put("/staff/{user_id}")
def update_staff(user_id: uuid.UUID, update_data: dict, db: Session = Depends(get_db)):
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == user_id).first()
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not staff or not user:
        raise HTTPException(status_code=404, detail="Bulunamadı")
    
    if "ad_soyad" in update_data: staff.ad_soyad = update_data["ad_soyad"]
    if "email" in update_data: user.email = update_data["email"]
    db.commit()
    return {"message": "Güncellendi"}

@app.delete("/staff/{user_id}")
def delete_staff(user_id: uuid.UUID, db: Session = Depends(get_db)):
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == user_id).first()
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if staff: db.delete(staff)
    if user: db.delete(user)
    db.commit()
    return {"message": "Silindi"}