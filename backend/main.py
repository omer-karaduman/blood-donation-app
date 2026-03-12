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

# Veritabanı tablolarını otomatik oluştur
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Blood Donation AI API - V3 (Relational Location Optimized)")

# CORS Ayarları: Mobil ve Web erişimi için tüm kaynaklara izin veriliyor
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Veritabanı oturum yönetimi
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

# --- ANA DİZİN ---
@app.get("/")
def read_root():
    return {"status": "Online", "message": "Akıllı Kan Bağışı Sistemi Aktif."}

# ======================================================================
# --- KONUM SERVİSLERİ (YENİ) ---
# ======================================================================

@app.get("/locations/districts", response_model=List[schemas.DistrictResponse])
def get_districts(db: Session = Depends(get_db)):
    """İzmir'in tüm ilçelerini listeler."""
    return db.query(models.District).order_by(models.District.name).all()

@app.get("/locations/districts/{district_id}/neighborhoods", response_model=List[schemas.NeighborhoodResponse])
def get_neighborhoods(district_id: uuid.UUID, db: Session = Depends(get_db)):
    """Seçilen ilçeye ait mahalleleri listeler."""
    return db.query(models.Neighborhood).filter(
        models.Neighborhood.district_id == district_id
    ).order_by(models.Neighborhood.name).all()

# --- KİMLİK DOĞRULAMA (LOGIN) ---
@app.post("/login", response_model=schemas.UserResponse)
def login(login_data: schemas.LoginRequest, db: Session = Depends(get_db)):
    """Kullanıcı e-posta ve şifresini doğrular, rol bilgisini döner."""
    user = db.query(models.User)\
             .options(joinedload(models.User.donor_profile), joinedload(models.User.staff_profile))\
             .filter(models.User.email == login_data.email).first()
    
    # Not: Gerçek projede şifreler passlib gibi bir kütüphane ile doğrulanmalıdır
    if not user or user.hashed_password != login_data.password:
        raise HTTPException(status_code=401, detail="E-posta veya şifre hatalı.")
    
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Hesabınız askıya alınmıştır.")
        
    return user 

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
    Personel kan talebi oluşturur. Sistem arka planda ML modelini çalıştırarak 
    uygun donörlere bildirim loglarını otomatik yazar.
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

            # 4. Akıllı Bildirim Loglama
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
    """Personelin kendi taleplerini ve donör yanıtlarını izlemesini sağlar."""
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
                "donor_ad_soyad": b.user.donor_profile.ad_soyad if b.user and b.user.donor_profile else "Bilinmeyen Donör",
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
# --- 2. ADMİN İŞ AKIŞI: SİSTEM DENETİMİ VE ÖZET ---
# ======================================================================

@app.get("/api/admin/summary")
def get_admin_summary(db: Session = Depends(get_db)):
    """Admin paneli için toplam donör ve aktif talep sayılarını döner."""
    donor_count = db.query(models.DonorProfile).count()
    active_requests = db.query(models.BloodRequest).filter(models.BloodRequest.durum == models.RequestStatusEnum.AKTIF).count()
    return {"total_donors": donor_count, "active_requests": active_requests}

@app.get("/admin/system-logs", response_model=List[schemas.AdminRequestLogResponse])
def get_admin_logs(db: Session = Depends(get_db)):
    """Tüm talepleri ve her talep için yapılan ML öneri sayılarını listeler."""
    logs = db.query(models.BloodRequest).order_by(models.BloodRequest.olusturma_tarihi.desc()).all()
    
    result = []
    for log in logs:
        result.append({
            "talep_id": log.talep_id,
            "kurum_adi": log.institution.kurum_adi if log.institution else "Bilinmiyor",
            "staff_ad_soyad": log.personel.staff_profile.ad_soyad if (log.personel and log.personel.staff_profile) else "Sistem",
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
    """Yeni donör kaydı oluşturur (İlişkisel Konum Destekli)."""
    db_user = db.query(models.User).filter(models.User.email == user_in.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email kullanımda.")

    new_user = models.User(email=user_in.email, hashed_password=user_in.password, role=models.UserRoleEnum.DONOR)
    db.add(new_user)
    db.flush()

    # DonorProfile verisi - latitude ve longitude hariç (WKTElement kullanılacak)
    donor_data = user_in.model_dump(exclude={"email", "password", "latitude", "longitude"})
    new_profile = models.DonorProfile(user_id=new_user.user_id, **donor_data)

    if user_in.latitude is not None and user_in.longitude is not None:
        new_profile.konum = WKTElement(f"POINT({user_in.longitude} {user_in.latitude})", srid=4326)

    db.add(new_profile)
    
    # ML Özelliklerini ilklendir
    new_features = models.MLFeature(user_id=new_user.user_id)
    db.add(new_features)

    # Oyunlaştırma Verisini İlklendir
    new_gamification = models.GamificationData(user_id=new_user.user_id)
    db.add(new_gamification)

    db.commit()
    db.refresh(new_user)
    return new_user

@app.get("/institutions/", response_model=list[schemas.InstitutionResponse])
def get_institutions(district_id: uuid.UUID = None, tipi: models.InstitutionTypeEnum = None, db: Session = Depends(get_db)):
    """Kurumları ilçe ID'si veya tipine göre filtreler."""
    query = db.query(models.Institution).options(
        joinedload(models.Institution.district),
        joinedload(models.Institution.neighborhood)
    )
    if district_id:
        query = query.filter(models.Institution.district_id == district_id)
    if tipi:
        query = query.filter(models.Institution.tipi == tipi)
    return query.all()

@app.get("/staff/")
def get_all_staff(db: Session = Depends(get_db)):
    """Tüm personeli listeler; boş veriler için varsayılan değerler döner (Null Safety)."""
    staff_list = db.query(models.StaffProfile).all()
    result = []
    for s in staff_list:
        result.append({
            "user_id": str(s.user_id),
            "ad_soyad": s.ad_soyad or "İsimsiz Personel",
            "unvan": s.unvan or "Belirtilmemiş",
            "personel_no": s.personel_no,
            "email": s.user.email if s.user else "Bilinmiyor",
            "is_active": s.user.is_active if s.user else False,
            "kurum_id": str(s.kurum_id) if s.kurum_id else None,
            "kurum_adi": s.institution.kurum_adi if s.institution else "Bilinmiyor"
        })
    return result

@app.post("/staff/", response_model=schemas.UserResponse)
def create_staff(staff: schemas.StaffCreate, db: Session = Depends(get_db)):
    """Yeni sağlık personeli kaydı oluşturur."""
    existing_user = db.query(models.User).filter(models.User.email == staff.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email kullanımda.")

    new_user = models.User(email=staff.email, hashed_password=staff.password, role=models.UserRoleEnum.HEALTHCARE)
    db.add(new_user)
    db.flush()

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

@app.put("/staff/{user_id}")
def update_staff(user_id: uuid.UUID, update_data: dict, db: Session = Depends(get_db)):
    """Personel bilgilerini günceller."""
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
    """Personeli sistemden tamamen siler."""
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == user_id).first()
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if staff: db.delete(staff)
    if user: db.delete(user)
    db.commit()
    return {"message": "Silindi"}

@app.get("/institutions/{institution_id}/staff")
def get_institution_staff(institution_id: uuid.UUID, db: Session = Depends(get_db)):
    """Sadece belirli bir kuruma kayıtlı personelleri listeler."""
    staff_list = db.query(models.StaffProfile).filter(models.StaffProfile.kurum_id == institution_id).all()
    result = []
    for s in staff_list:
        result.append({
            "user_id": str(s.user_id),
            "ad_soyad": s.ad_soyad or "İsimsiz Personel",
            "unvan": s.unvan or "Belirtilmemiş",
            "personel_no": s.personel_no,
            "email": s.user.email if s.user else "Bilinmiyor",
            "is_active": s.user.is_active if s.user else False,
            "kurum_adi": s.institution.kurum_adi if s.institution else "Bilinmiyor"
        })
    return result

@app.post("/institutions/", response_model=schemas.InstitutionResponse)
def create_institution(inst_in: schemas.InstitutionCreate, db: Session = Depends(get_db)):
    """Adminin yeni bir hastane veya kan merkezi eklemesini sağlar (İlişkisel konumla)."""
    new_inst = models.Institution(
        kurum_adi=inst_in.kurum_adi,
        tipi=inst_in.tipi,
        district_id=inst_in.district_id,
        neighborhood_id=inst_in.neighborhood_id,
        tam_adres=inst_in.tam_adres,
        parent_id=inst_in.parent_id
    )
    if inst_in.latitude is not None and inst_in.longitude is not None:
        new_inst.konum = WKTElement(f"POINT({inst_in.longitude} {inst_in.latitude})", srid=4326)

    db.add(new_inst)
    db.commit()
    db.refresh(new_inst)
    return new_inst

@app.get("/users/{user_id}/profile")
def get_user_profile_data(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Kullanıcının id'sine göre güncel Ad, Soyad, Kan Grubu veya Unvan bilgilerini döner."""
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")
    
    # Donör ise donör bilgilerini dön
    if user.role.name == "DONOR" and user.donor_profile:
        return {
            "ad_soyad": user.donor_profile.ad_soyad,
            "kan_grubu": user.donor_profile.kan_grubu,
            "mahalle": user.donor_profile.neighborhood.name if user.donor_profile.neighborhood else "Belirtilmemiş"
        }
    
    # Personel ise personel bilgilerini dön
    elif user.role.name == "HEALTHCARE" and user.staff_profile:
        return {
            "ad_soyad": user.staff_profile.ad_soyad,
            "unvan": user.staff_profile.unvan,
            "personel_no": user.staff_profile.personel_no,
            "kurum_adi": user.staff_profile.institution.kurum_adi if user.staff_profile.institution else "Bilinmiyor"
        }
    
    # Admin ise
    return {"ad_soyad": "Sistem Yöneticisi", "kan_grubu": "-"}

@app.get("/donor/{user_id}/feed")
def get_donor_feed(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün ana sayfasında (Feed) göreceği aktif kan taleplerini listeler."""
    
    # Aktif olan tüm kan taleplerini (en yeniden eskiye doğru) hastane bilgisiyle çekiyoruz
    active_requests = db.query(models.BloodRequest)\
                        .options(
                            joinedload(models.BloodRequest.institution).joinedload(models.Institution.district),
                            joinedload(models.BloodRequest.institution).joinedload(models.Institution.neighborhood)
                        )\
                        .filter(models.BloodRequest.durum == models.RequestStatusEnum.AKTIF)\
                        .order_by(models.BloodRequest.olusturma_tarihi.desc())\
                        .all()
    
    feed_data = []
    for req in active_requests:
        feed_data.append({
            "talep_id": req.talep_id,
            "kurum_adi": req.institution.kurum_adi if req.institution else "Sağlık Kurumu",
            "ilce": req.institution.district.name if req.institution and req.institution.district else "İzmir",
            "mahalle": req.institution.neighborhood.name if req.institution and req.institution.neighborhood else "",
            "istenen_kan_grubu": req.istenen_kan_grubu,
            "unite_sayisi": req.unite_sayisi,
            "aciliyet_durumu": req.aciliyet_durumu,
            "olusturma_tarihi": req.olusturma_tarihi
        })
        
    return feed_data