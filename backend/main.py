from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from geoalchemy2.elements import WKTElement
import models
import schemas
from database import engine, SessionLocal
import uuid
from datetime import datetime
import traceback
import joblib
import pandas as pd
import numpy as np
import os
from typing import List

# Veritabanı tablolarını otomatik oluştur
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Blood Donation AI API - V6 (Medical Rules & Full AI)")

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

# ======================================================================
# --- ML MODELİNİ UYGULAMA BAŞLARKEN YÜKLE ---
# ======================================================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Modelleri bu klasöre göre arar
MODEL_PATH = os.path.join(BASE_DIR, "ml_models", "donor_rf_model.pkl")
SCALER_PATH = os.path.join(BASE_DIR, "ml_models", "scaler.pkl")

rf_model = None
scaler = None

if os.path.exists(MODEL_PATH):
    try:
        # weights_only=True uyarısını engellemek ve güvenli yükleme için
        rf_model = joblib.load(MODEL_PATH)
        print(f"✅ ML Modeli başarıyla yüklendi: {MODEL_PATH}")
        if os.path.exists(SCALER_PATH):
            scaler = joblib.load(SCALER_PATH)
            print(f"✅ Scaler başarıyla yüklendi: {SCALER_PATH}")
    except Exception as e:
        print(f"⚠️ ML Modeli yüklenirken hata oluştu: {e}")
else:
    print(f"⚠️ ML Modeli bulunamadı! Aranan yol: {MODEL_PATH}")
    print("Sistem test/yedek modunda çalışacak.")


# --- YARDIMCI FONKSİYONLAR ---
def calculate_age(birthdate):
    """Doğum tarihinden yaşı hesaplar"""
    if not birthdate:
        return 30
    today = datetime.today().date()
    if isinstance(birthdate, str):
        try:
            bdate = datetime.strptime(birthdate, "%Y-%m-%d").date()
        except:
            return 30
    else:
        bdate = birthdate
        
    return today.year - bdate.year - ((today.month, today.day) < (bdate.month, bdate.day))

def update_donor_sensitivity(db: Session, user_id: uuid.UUID):
    """
    Donörün geçmiş reaksiyonlarına (hız ve aciliyet) bakarak 
    'Duyarlılık Seviyesini' (1-5 arası) dinamik olarak günceller.
    """
    ml_feature = db.query(models.MLFeature).filter(models.MLFeature.user_id == user_id).first()
    if not ml_feature: return

    logs = db.query(models.NotificationLog).filter(models.NotificationLog.user_id == user_id).all()
    if not logs: return

    base_score = 3.0 # Herkes 3 puanla (nötr) başlar
    
    for log in logs:
        if log.kullanici_reaksiyonu == models.NotificationReactionEnum.GORMEZDEN_GELDI:
            base_score -= 0.1 # Hiç bakmıyorsa duyarlılık düşer
            continue
            
        if log.reaksiyon_zamani and log.gonderim_zamani:
            minutes_taken = (log.reaksiyon_zamani - log.gonderim_zamani).total_seconds() / 60.0
            req = log.blood_request
            
            # KABUL ETTİYSE:
            if log.kullanici_reaksiyonu == models.NotificationReactionEnum.KABUL:
                base_score += 0.3
                if minutes_taken <= 15: base_score += 0.4 # 15 dk içinde çok hızlı
                elif minutes_taken <= 60: base_score += 0.2
                
                if req and req.aciliyet_durumu == models.UrgencyEnum.ACIL: base_score += 0.3
                elif req and req.aciliyet_durumu == models.UrgencyEnum.AFET: base_score += 0.5
                
            # REDDETTİYSE (Ama hızlıca haber verdiyse iyi niyetlidir):
            elif log.kullanici_reaksiyonu == models.NotificationReactionEnum.RED:
                if minutes_taken <= 15: base_score += 0.1 
                else: base_score -= 0.1
                
    # 1 ile 5 arasında sınırla
    final_score = max(1, min(5, round(base_score)))
    ml_feature.duyarlilik_seviyesi = int(final_score)
    db.commit()

# --- ANA DİZİN ---
@app.get("/")
def read_root():
    return {"status": "Online", "message": "Akıllı Kan Bağışı Sistemi Aktif."}

# ======================================================================
# --- KONUM SERVİSLERİ ---
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

# ======================================================================
# --- KİMLİK DOĞRULAMA (LOGIN) ---
# ======================================================================
@app.post("/login", response_model=schemas.UserResponse)
def login(login_data: schemas.LoginRequest, db: Session = Depends(get_db)):
    """Kullanıcı e-posta ve şifresini doğrular, rol bilgisini döner."""
    user = db.query(models.User)\
             .options(joinedload(models.User.donor_profile), joinedload(models.User.staff_profile))\
             .filter(models.User.email == login_data.email).first()
    
    if not user or user.hashed_password != login_data.password:
        raise HTTPException(status_code=401, detail="E-posta veya şifre hatalı.")
    
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Hesabınız askıya alınmıştır.")
        
    return user 

# ======================================================================
# --- 1. PERSONEL (STAFF) İŞ AKIŞI: AKILLI KAN TALEBİ ---
# ======================================================================

@app.post("/requests/")
def create_smart_blood_request(
    request_in: schemas.BloodRequestCreate, 
    personel_id: uuid.UUID, 
    db: Session = Depends(get_db)
):
    """
    Tez Odaklı Özgün Fonksiyon: Personel kan talebi oluşturur. Sistem arka planda 
    hastaneye 10 km çapındaki uygun donörleri bulur, Tıbbi kısıtlamaları (3-4 ay) kontrol eder, 
    ML modeline sokar ve en yüksek ihtimalli ilk 30 kişiye bildirim (NotificationLog) atar.
    """
    
    # 1. Personeli ve Kurumu (Hastaneyi) Bul
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == personel_id).first()
    if not staff:
        raise HTTPException(status_code=404, detail="Personel yetkisi bulunamadı.")

    institution = db.query(models.Institution).filter(models.Institution.kurum_id == staff.kurum_id).first()
    if not institution or not institution.konum:
        raise HTTPException(status_code=400, detail="Kurumun konum verisi eksik, akıllı eşleştirme yapılamaz.")

    # 2. Kan Talebini Veritabanına Kaydet
    new_request = models.BloodRequest(
        kurum_id=institution.kurum_id, 
        olusturan_personel_id=personel_id,
        istenen_kan_grubu=request_in.istenen_kan_grubu,
        unite_sayisi=request_in.unite_sayisi,
        aciliyet_durumu=request_in.aciliyet_durumu,
        durum=models.RequestStatusEnum.AKTIF
    )
    db.add(new_request)
    db.flush() # new_request.talep_id'yi alabilmek için geçici kayıt

    # =========================================================================
    # AŞAMA 1: POSTGIS İLE KONUM BAZLI FİLTRELEME (Maksimum 10 KM Çap)
    # =========================================================================
    MAX_DISTANCE_METERS = 10000 # 15 km'den 10 km'ye düşürüldü
    
    nearby_donors = db.query(
        models.DonorProfile,
        func.ST_DistanceSphere(models.DonorProfile.konum, institution.konum).label("distance_meters")
    ).options(
        joinedload(models.DonorProfile.ml_features)
    ).filter(
        models.DonorProfile.kan_grubu == request_in.istenen_kan_grubu,
        models.DonorProfile.kan_verebilir_mi == True,
        models.DonorProfile.konum != None,
        func.ST_DistanceSphere(models.DonorProfile.konum, institution.konum) <= MAX_DISTANCE_METERS
    ).all()

    if not nearby_donors:
        db.commit()
        return {"message": "Talep oluşturuldu ancak 10 km çapında uygun donör bulunamadı.", "hedeflenen_donor_sayisi": 0}

    # =========================================================================
    # AŞAMA 2: TIBBİ KISITLAMALAR VE ML İLE GELME İHTİMALİ HESAPLAMA
    # =========================================================================
    valid_donors = []
    ml_input_data = []
    
    current_time = datetime.utcnow()

    for donor, distance_meters in nearby_donors:
        
        # --- TIBBİ KISITLAMA (MEDICAL RESTRICTION) KONTROLÜ ---
        days_since = 999 # Varsayılan olarak hiç bağış yapmamış kabul et
        if donor.son_bagis_tarihi:
            days_since = (current_time - donor.son_bagis_tarihi).days
            
            # Erkekler için 3 ay (90 gün) kuralı
            if donor.cinsiyet == 'E' and days_since < 90:
                continue # Bu donörü atla, listeye ekleme
                
            # Kadınlar için 4 ay (120 gün) kuralı
            if donor.cinsiyet == 'K' and days_since < 120:
                continue # Bu donörü atla, listeye ekleme
                
        # Eğer buraya kadar geldiyse tıbbi engeli yoktur, listeye ekle
        distance_km = distance_meters / 1000.0
        valid_donors.append(donor) 
        
        if rf_model is not None:
            age = calculate_age(donor.dogum_tarihi)
            # Cinsiyet Encode (Erkek: 1, Kadın: 0)
            gender_numeric = 1 if donor.cinsiyet == 'E' else 0
            
            # ML_Features tablosundan veriler
            feat = donor.ml_features
            past_donations = feat.basarili_bagis_sayisi if feat else 0
            
            if feat and feat.toplam_bildirim_sayisi > 0:
                response_rate = feat.olumlu_yanit_sayisi / feat.toplam_bildirim_sayisi
            else:
                response_rate = 0.5 # Varsayılan
                
            sensitivity = getattr(feat, 'duyarlilik_seviyesi', 3) if feat else 3
            pref_hour = feat.tercih_edilen_saatler[0] if feat and feat.tercih_edilen_saatler else 12
            
            ml_input_data.append({
                "age": age,
                "past_donations": past_donations,
                "days_since_last_donation": days_since,
                "response_rate": response_rate,
                "sensitivity_level": sensitivity,
                "preferred_hour": pref_hour
            })

    # Eğer tıbbi kısıtlamalardan sonra elde hiç donör kalmadıysa
    if not valid_donors:
        db.commit()
        return {"message": "10 km çapında donörler bulundu ancak tıbbi bekleme süreleri dolmadığı için bildirim atılamadı.", "hedeflenen_donor_sayisi": 0}

    donor_predictions = []
    
    # Model yüklüyse Pandas DataFrame ile toplu tahmin yap
    if rf_model is not None and ml_input_data:
        try:
            df = pd.DataFrame(ml_input_data)
            if scaler:
                # EĞİTİMDE KULLANILAN SCALER İLE ÖLÇEKLENDİR
                features = scaler.transform(df)
            else:
                features = df
                
            probabilities = rf_model.predict_proba(features)[:, 1]
            
            for i, donor in enumerate(valid_donors):
                donor_predictions.append({"donor": donor, "probability": float(probabilities[i] * 100)})
        except Exception as e:
            print(f"ML Modeli Tahmin Hatası: {e}")
            for donor in valid_donors:
                donor_predictions.append({"donor": donor, "probability": 50.0})
    else:
        # Model yoksa rastgele olasılık
        for donor in valid_donors:
            donor_predictions.append({"donor": donor, "probability": 50.0})

    # =========================================================================
    # AŞAMA 3: OYUNLAŞTIRMA VE AKILLI BİLDİRİM (Top 30 Kişi)
    # =========================================================================
    # Gelme ihtimali puanına göre (Büyükten Küçüğe) donörleri sırala
    donor_predictions.sort(key=lambda x: x["probability"], reverse=True)
    
    # Sadece en yüksek ihtimalli ilk 30 kişiyi seç
    top_30_donors = donor_predictions[:30]

    # Seçilen kişilere bildirim veritabanı loglarını yaz
    for dp in top_30_donors:
        donor = dp["donor"]
        score = dp["probability"]
        
        new_log = models.NotificationLog(
            user_id=donor.user_id,
            talep_id=new_request.talep_id,
            ml_skoru_o_an=score,
            iletilme_durumu=models.NotificationDeliveryEnum.BASARILI,
            kullanici_reaksiyonu=models.NotificationReactionEnum.BEKLIYOR,
            gonderim_zamani=datetime.utcnow()
        )
        db.add(new_log)
        
        # Donörün toplam aldığı bildirim sayısını (ML feat) artır
        if donor.ml_features:
            donor.ml_features.toplam_bildirim_sayisi += 1

    db.commit()
    db.refresh(new_request)

    return {
        "message": "Talep başarıyla oluşturuldu ve tıbbi kısıtlamalar kontrol edilerek ML eşleştirmesi yapıldı.",
        "tibbi_uygun_bulunan_donor": len(valid_donors),
        "bildirim_gonderilen_kisi_sayisi": len(top_30_donors),
        "talep_id": new_request.talep_id
    }


@app.get("/staff/my-requests", response_model=List[schemas.BloodRequestDetailResponse])
def get_staff_requests(personel_id: uuid.UUID, db: Session = Depends(get_db)):
    """Personelin kendi taleplerini ve ML önerilerinin sonuçlarını izlemesini sağlar."""
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
# --- 2. DONÖR İŞ AKIŞI: BEHAVIORAL ANALYTICS (REAKSİYON VERME) ---
# ======================================================================

@app.get("/donor/{user_id}/feed", response_model=List[schemas.DonorFeedResponse])
def get_donor_feed(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """
    SADECE DONÖRE ÖZEL FEED: Donörün kendi NotificationLog'unda bulunan ve 
    ilgili talebin 'AKTIF' olduğu durumları gösterir.
    """
    my_logs = db.query(models.NotificationLog)\
                .options(
                    joinedload(models.NotificationLog.request).joinedload(models.BloodRequest.institution).joinedload(models.Institution.district),
                    joinedload(models.NotificationLog.request).joinedload(models.BloodRequest.institution).joinedload(models.Institution.neighborhood)
                )\
                .filter(
                    models.NotificationLog.user_id == user_id,
                    models.NotificationLog.kullanici_reaksiyonu == models.NotificationReactionEnum.BEKLIYOR
                ).all()
    
    feed_data = []
    for log in my_logs:
        req = log.request
        if req and req.durum == models.RequestStatusEnum.AKTIF:
            feed_data.append({
                "log_id": log.log_id, 
                "talep_id": req.talep_id,
                "kurum_adi": req.institution.kurum_adi if req.institution else "Sağlık Kurumu",
                "ilce": req.institution.district.name if req.institution and req.institution.district else "İzmir",
                "mahalle": req.institution.neighborhood.name if req.institution and req.institution.neighborhood else "",
                "istenen_kan_grubu": req.istenen_kan_grubu,
                "unite_sayisi": req.unite_sayisi,
                "aciliyet_durumu": req.aciliyet_durumu,
                "olusturma_tarihi": req.olusturma_tarihi
            })
            
    feed_data.sort(key=lambda x: x["olusturma_tarihi"], reverse=True)
    return feed_data


@app.post("/donor/{user_id}/respond/{log_id}")
def respond_to_notification(
    user_id: uuid.UUID, 
    log_id: uuid.UUID, 
    reaksiyon: models.NotificationReactionEnum = Query(..., description="'Kabul' veya 'Red' gönderin"), 
    db: Session = Depends(get_db)
):
    """
    YENİ ENDPOINT: Donör mobil uygulamadan bildirime Kabul veya Ret yanıtı verir.
    Bu işlem Yapay Zeka için Olumlu Yanıt oranını ve Duyarlılık Seviyesini dinamik olarak günceller!
    """
    log = db.query(models.NotificationLog).filter(
        models.NotificationLog.log_id == log_id, 
        models.NotificationLog.user_id == user_id
    ).first()
    
    if not log:
        raise HTTPException(status_code=404, detail="Bildirim bulunamadı.")
        
    if log.kullanici_reaksiyonu != models.NotificationReactionEnum.BEKLIYOR:
        raise HTTPException(status_code=400, detail="Bu bildirime zaten yanıt verilmiş.")

    # Logu güncelle
    log.kullanici_reaksiyonu = reaksiyon
    log.reaksiyon_zamani = datetime.utcnow()
    
    # Kabul ettiyse olumlu yanıt sayısını artır
    ml_feat = db.query(models.MLFeature).filter(models.MLFeature.user_id == user_id).first()
    if ml_feat and reaksiyon == models.NotificationReactionEnum.KABUL:
        ml_feat.olumlu_yanit_sayisi += 1
        
    db.commit()
    
    # Duyarlılık (Sensitivity) hesaplama motorunu tetikle!
    update_donor_sensitivity(db, user_id)
    
    return {"message": f"Yanıtınız '{reaksiyon}' olarak başarıyla kaydedildi ve yapay zeka profili güncellendi."}

# ======================================================================
# --- 3. ADMİN İŞ AKIŞI: SİSTEM DENETİMİ VE ÖZET ---
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
# --- 4. GENEL YÖNETİM (Kayıt, Kurum, Personel) ---
# ======================================================================

@app.post("/register/donor/", response_model=schemas.UserResponse)
def register_donor(user_in: schemas.DonorCreate, db: Session = Depends(get_db)):
    """Yeni donör kaydı oluşturur (PostGIS Konum Destekli)."""
    db_user = db.query(models.User).filter(models.User.email == user_in.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email kullanımda.")

    new_user = models.User(email=user_in.email, hashed_password=user_in.password, role=models.UserRoleEnum.DONOR)
    db.add(new_user)
    db.flush()

    # DonorProfile verisi - latitude ve longitude hariç
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
    """Tüm personeli listeler."""
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

    new_user = models.User(email=staff.email, hashed_password=staff.password, role=models.UserRoleEnum.staff)
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
    
    # Donör ise
    if user.role.name == "DONOR" and user.donor_profile:
        return {
            "ad_soyad": user.donor_profile.ad_soyad,
            "kan_grubu": user.donor_profile.kan_grubu,
            "mahalle": user.donor_profile.neighborhood.name if user.donor_profile.neighborhood else "Belirtilmemiş"
        }
    
    # Personel ise
    elif user.role.name == "staff" and user.staff_profile:
        return {
            "ad_soyad": user.staff_profile.ad_soyad,
            "unvan": user.staff_profile.unvan,
            "personel_no": user.staff_profile.personel_no,
            "kurum_adi": user.staff_profile.institution.kurum_adi if user.staff_profile.institution else "Bilinmiyor"
        }
    
    # Admin ise
    return {"ad_soyad": "Sistem Yöneticisi", "kan_grubu": "-"}