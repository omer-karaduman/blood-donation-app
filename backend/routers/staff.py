import os
import joblib
import pandas as pd
import uuid
# 🚀 timedelta EKLENDİ
from datetime import datetime, timedelta 
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func

import models
import schemas
from database import get_db
from services.notification_service import notify_donor


# Personel ve Talep endpointleri için prefix (ön ek) tanımlıyoruz
router = APIRouter(
    prefix="/staff",
    tags=["Personel ve Kan Talebi İşlemleri"]
)

# ======================================================================
# --- ML MODELİNİ YÜKLE ---
# ======================================================================
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MODEL_PATH = os.path.join(BASE_DIR, "ml_models", "donor_rf_model.pkl")
SCALER_PATH = os.path.join(BASE_DIR, "ml_models", "scaler.pkl")

rf_model = None
scaler = None

if os.path.exists(MODEL_PATH):
    try:
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


# ======================================================================
# --- KAN TALEBİ VE ML EŞLEŞTİRME (STAFF REQUESTS) ---
# ======================================================================

@router.post("/requests")
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
        gecerlilik_suresi_saat=request_in.gecerlilik_suresi_saat,
        durum=models.RequestStatusEnum.AKTIF
    )
    db.add(new_request)
    db.flush() 

    # =========================================================================
    # AŞAMA 1: POSTGIS İLE KONUM BAZLI FİLTRELEME (Maksimum 10 KM Çap)
    # =========================================================================
    MAX_DISTANCE_METERS = 10000 
    
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
        
        days_since = 999 
        if donor.son_bagis_tarihi:
            days_since = (current_time - donor.son_bagis_tarihi).days
            
            if donor.cinsiyet == 'E' and days_since < 90:
                continue 
                
            if donor.cinsiyet == 'K' and days_since < 120:
                continue 
                
        distance_km = distance_meters / 1000.0
        valid_donors.append(donor) 
        
        if rf_model is not None:
            age = calculate_age(donor.dogum_tarihi)
            gender_numeric = 1 if donor.cinsiyet == 'E' else 0
            
            feat = donor.ml_features
            past_donations = feat.basarili_bagis_sayisi if feat else 0
            
            if feat and feat.toplam_bildirim_sayisi > 0:
                response_rate = feat.olumlu_yanit_sayisi / feat.toplam_bildirim_sayisi
            else:
                response_rate = 0.5 
                
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

    if not valid_donors:
        db.commit()
        return {"message": "10 km çapında donörler bulundu ancak tıbbi bekleme süreleri dolmadığı için bildirim atılamadı.", "hedeflenen_donor_sayisi": 0}

    donor_predictions = []
    
    if rf_model is not None and ml_input_data:
        try:
            df = pd.DataFrame(ml_input_data)
            if scaler:
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
        for donor in valid_donors:
            donor_predictions.append({"donor": donor, "probability": 50.0})

    # =========================================================================
    # AŞAMA 3: OYUNLAŞTIRMA VE AKILLI BİLDİRİM (Top 30 Kişi)
    # =========================================================================
    donor_predictions.sort(key=lambda x: x["probability"], reverse=True)
    top_30_donors = donor_predictions[:30]

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
        
        if donor.ml_features:
            donor.ml_features.toplam_bildirim_sayisi += 1
        kurum_adi = institution.kurum_adi if institution else "Sağlık Kurumu"
        aciliyet = request_in.aciliyet_durumu.name if hasattr(request_in.aciliyet_durumu, 'name') else str(request_in.aciliyet_durumu)
        
        # Servis, FCM Token yoksa otomatik olarak SMS'e düşecek şekilde ayarlandı
        notify_donor(donor, new_request.talep_id, kurum_adi, aciliyet)
    db.commit()
    db.refresh(new_request)

    return {
        "message": "Talep başarıyla oluşturuldu ve tıbbi kısıtlamalar kontrol edilerek ML eşleştirmesi yapıldı.",
        "tibbi_uygun_bulunan_donor": len(valid_donors),
        "bildirim_gonderilen_kisi_sayisi": len(top_30_donors),
        "talep_id": new_request.talep_id
    }


@router.get("/my-requests", response_model=List[schemas.BloodRequestDetailResponse])
def get_staff_requests(personel_id: uuid.UUID, db: Session = Depends(get_db)):
    """Personelin kendi taleplerini ve ML önerilerinin sonuçlarını izlemesini sağlar. (Süresi dolanları otomatik iptal eder)"""
    requests = db.query(models.BloodRequest)\
                 .options(joinedload(models.BloodRequest.bildirimler).joinedload(models.NotificationLog.user))\
                 .filter(models.BloodRequest.olusturan_personel_id == personel_id)\
                 .order_by(models.BloodRequest.olusturma_tarihi.desc())\
                 .all()
    
    output = []
    su_an = datetime.utcnow()
    durum_degisikligi_var_mi = False

    for r in requests:
        # 🚀 AŞAMA 1: SÜRE KONTROLÜ VE OTOMATİK İPTAL
        if r.durum == models.RequestStatusEnum.AKTIF:
            bitis_zamani = r.olusturma_tarihi + timedelta(hours=r.gecerlilik_suresi_saat)
            if su_an >= bitis_zamani:
                r.durum = models.RequestStatusEnum.IPTAL
                durum_degisikligi_var_mi = True

        # AŞAMA 2: DONÖR YANITLARINI TOPLA
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
            "durum": r.durum, # Eğer az önce IPTAL olduysa, UI'a güncel halini gönderir
            "olusturma_tarihi": r.olusturma_tarihi,
            "donor_yanitlari": donor_yanitlari,
            "gecerlilik_suresi_saat": r.gecerlilik_suresi_saat
        })
        
    # Eğer listedeki en az 1 talebin süresi dolup durumu değiştiyse, veritabanına kaydet
    if durum_degisikligi_var_mi:
        db.commit()
        
    return output


# ======================================================================
# --- PERSONEL YÖNETİMİ (CRUD) ---
# ======================================================================

@router.get("/")
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


@router.post("/", response_model=schemas.UserResponse)
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


@router.put("/{user_id}")
def update_staff(user_id: uuid.UUID, update_data: dict, db: Session = Depends(get_db)):
    """Personel bilgilerini günceller."""
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == user_id).first()
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    
    if not staff or not user:
        raise HTTPException(status_code=404, detail="Bulunamadı")
    
    # 1. Temel Bilgiler
    if "ad_soyad" in update_data: 
        staff.ad_soyad = update_data["ad_soyad"]
        
    if "email" in update_data: 
        user.email = update_data["email"]
        
    # 2. Kurum ve Ünvan Bilgileri (Eksik Olan Kısım Eklendi!)
    if "kurum_id" in update_data and update_data["kurum_id"]: 
        staff.kurum_id = update_data["kurum_id"]
        
    if "unvan" in update_data: 
        staff.unvan = update_data["unvan"]
        
    # 3. Hesap Durumu (Aktif / Pasif)
    if "is_active" in update_data:
        user.is_active = update_data["is_active"]
        
    # 4. İsteğe Bağlı Şifre Güncelleme
    if "password" in update_data and update_data["password"]:
        user.hashed_password = update_data["password"]

    db.commit()
    return {"message": "Personel başarıyla güncellendi."}


@router.delete("/{user_id}")
def delete_staff(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Personeli sistemden tamamen siler."""
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == user_id).first()
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if staff: db.delete(staff)
    if user: db.delete(user)
    db.commit()
    return {"message": "Silindi"}




@router.put("/requests/{talep_id}/cancel")
def cancel_blood_request(talep_id: uuid.UUID, personel_id: uuid.UUID = Query(...), db: Session = Depends(get_db)):
    """Talebi iptal eder ve donörlerin listesinden kaldırılmasını sağlar."""
    req = db.query(models.BloodRequest).filter(
        models.BloodRequest.talep_id == talep_id, 
        models.BloodRequest.olusturan_personel_id == personel_id
    ).first()
    
    if not req:
        raise HTTPException(status_code=404, detail="Talep bulunamadı veya yetkiniz yok.")
        
    if req.durum != models.RequestStatusEnum.AKTIF:
        raise HTTPException(status_code=400, detail="Bu talep zaten aktif değil.")

    # 1. Ana talebin durumunu IPTAL yap
    req.durum = models.RequestStatusEnum.IPTAL

    # 2. 🚀 KRİTİK: Bu talebe ait "BEKLEYEN" bildirimleri "GORMEZDEN_GELDI" (veya silindi) statüsüne çek
    # Böylece donör tarafındaki feed sorgusu bunları getirmeyecektir.
    db.query(models.NotificationLog).filter(
        models.NotificationLog.talep_id == talep_id,
        models.NotificationLog.kullanici_reaksiyonu == models.NotificationReactionEnum.BEKLIYOR
    ).update({"kullanici_reaksiyonu": models.NotificationReactionEnum.GORMEZDEN_GELDI})

    db.commit()
    
    # (Opsiyonel) Eğer talep çok acilse ve kabul eden donörler varsa 
    # onlara "Talep iptal edildi, gelmenize gerek yok" bildirimi de atılabilir.
    
    return {"message": "Talep ve bağlı bildirimler başarıyla iptal edildi."}


# backend/routers/staff.py dosyasına eklenecek:

@router.put("/requests/{talep_id}/extend")
def extend_blood_request(talep_id: uuid.UUID, personel_id: uuid.UUID = Query(...), ek_saat: int = Query(...), db: Session = Depends(get_db)):
    """Aktif bir talebin geçerlilik süresini (saat olarak) uzatır."""
    req = db.query(models.BloodRequest).filter(
        models.BloodRequest.talep_id == talep_id, 
        models.BloodRequest.olusturan_personel_id == personel_id
    ).first()
    
    if not req:
        raise HTTPException(status_code=404, detail="Talep bulunamadı veya yetkiniz yok.")
        
    if req.durum != models.RequestStatusEnum.AKTIF:
        raise HTTPException(status_code=400, detail="Sadece aktif taleplerin süresi uzatılabilir.")

    req.gecerlilik_suresi_saat += ek_saat
    db.commit()
    return {"message": f"Talep süresi {ek_saat} saat uzatıldı."}