from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from geoalchemy2.elements import WKTElement
from typing import List
import uuid
from datetime import datetime, timedelta

import models
import schemas
from database import get_db

# Donör endpointleri için prefix (ön ek) tanımlıyoruz
router = APIRouter(
    prefix="/donors",
    tags=["Donör İşlemleri"]
)

# ---------------------------------------------------------
# YARDIMCI FONKSİYONLAR
# ---------------------------------------------------------

def update_donor_sensitivity(db: Session, user_id: uuid.UUID):
    """
    Donörün geçmiş reaksiyonlarına bakarak 'Duyarlılık Seviyesini' dinamik günceller.
    """
    ml_feature = db.query(models.MLFeature).filter(models.MLFeature.user_id == user_id).first()
    if not ml_feature: return

    logs = db.query(models.NotificationLog).filter(models.NotificationLog.user_id == user_id).all()
    if not logs: return

    base_score = 3.0 
    
    for log in logs:
        if log.kullanici_reaksiyonu == models.NotificationReactionEnum.GORMEZDEN_GELDI:
            base_score -= 0.1 
            continue
            
        if log.reaksiyon_zamani and log.gonderim_zamani:
            minutes_taken = (log.reaksiyon_zamani - log.gonderim_zamani).total_seconds() / 60.0
            req = log.blood_request
            
            if log.kullanici_reaksiyonu == models.NotificationReactionEnum.KABUL:
                base_score += 0.3
                if minutes_taken <= 15: base_score += 0.4 
                elif minutes_taken <= 60: base_score += 0.2
                if req and req.aciliyet_durumu == models.UrgencyEnum.ACIL: base_score += 0.3
            elif log.kullanici_reaksiyonu == models.NotificationReactionEnum.RED:
                if minutes_taken <= 15: base_score += 0.1 
                else: base_score -= 0.1
                
    ml_feature.duyarlilik_seviyesi = int(max(1, min(5, round(base_score))))
    db.commit()

# ---------------------------------------------------------
# KAYIT VE ANA FEED (BİLDİRİMLER)
# ---------------------------------------------------------

@router.post("/register", response_model=schemas.UserResponse)
def register_donor(user_in: schemas.DonorCreate, db: Session = Depends(get_db)):
    """Yeni donör kaydı (PostGIS Destekli)."""
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
    db.add(models.MLFeature(user_id=new_user.user_id))
    db.add(models.GamificationData(user_id=new_user.user_id))

    db.commit()
    db.refresh(new_user)
    return new_user

@router.get("/{user_id}/feed", response_model=List[schemas.DonorFeedResponse])
def get_donor_feed(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün bekleyen ve süresi dolmamış kan taleplerini listeler."""
    my_logs = db.query(models.NotificationLog)\
                .options(
                    joinedload(models.NotificationLog.blood_request).joinedload(models.BloodRequest.institution).joinedload(models.Institution.district),
                    joinedload(models.NotificationLog.blood_request).joinedload(models.BloodRequest.institution).joinedload(models.Institution.neighborhood)
                )\
                .filter(
                    models.NotificationLog.user_id == user_id,
                    models.NotificationLog.kullanici_reaksiyonu == models.NotificationReactionEnum.BEKLIYOR
                ).all()
    
    feed_data = []
    for log in my_logs:
        req = log.blood_request
        if req and req.durum == models.RequestStatusEnum.AKTIF:
            bitis_zamani = req.olusturma_tarihi + timedelta(hours=req.gecerlilik_suresi_saat)
            if datetime.utcnow() < bitis_zamani:
                feed_data.append({
                    "log_id": log.log_id, 
                    "talep_id": req.talep_id,
                    "kurum_adi": req.institution.kurum_adi if req.institution else "Sağlık Kurumu",
                    "ilce": req.institution.district.name if req.institution and req.institution.district else "İzmir",
                    "mahalle": req.institution.neighborhood.name if req.institution and req.institution.neighborhood else "",
                    "istenen_kan_grubu": req.istenen_kan_grubu,
                    "unite_sayisi": req.unite_sayisi,
                    "aciliyet_durumu": req.aciliyet_durumu,
                    "olusturma_tarihi": req.olusturma_tarihi,
                    "gecerlilik_suresi_saat": req.gecerlilik_suresi_saat 
                })
    
    feed_data.sort(key=lambda x: x["olusturma_tarihi"], reverse=True)
    return feed_data

@router.post("/{user_id}/respond/{log_id}")
def respond_to_notification(user_id: uuid.UUID, log_id: uuid.UUID, reaksiyon: models.NotificationReactionEnum = Query(...), db: Session = Depends(get_db)):
    """Bildirime yanıt verir ve duyarlılık motorunu tetikler."""
    log = db.query(models.NotificationLog).filter(models.NotificationLog.log_id == log_id, models.NotificationLog.user_id == user_id).first()
    if not log or log.kullanici_reaksiyonu != models.NotificationReactionEnum.BEKLIYOR:
        raise HTTPException(status_code=400, detail="Geçersiz bildirim veya zaten yanıtlanmış.")

    log.kullanici_reaksiyonu = reaksiyon
    log.reaksiyon_zamani = datetime.utcnow()
    
    if reaksiyon == models.NotificationReactionEnum.KABUL:
        ml_feat = db.query(models.MLFeature).filter(models.MLFeature.user_id == user_id).first()
        if ml_feat: ml_feat.olumlu_yanit_sayisi += 1
        
    db.commit()
    update_donor_sensitivity(db, user_id)
    return {"message": "Yanıt kaydedildi."}

# ---------------------------------------------------------
# 🚀 YENİ EKLENEN ENDPOINTLER (MODÜLER TABLAR İÇİN)
# ---------------------------------------------------------

@router.get("/{user_id}/history")
def get_donor_history(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün geçmiş bağışlarını getirir."""
    return db.query(models.DonationHistory)\
             .options(joinedload(models.DonationHistory.institution))\
             .filter(models.DonationHistory.user_id == user_id)\
             .order_by(models.DonationHistory.bagis_tarihi.desc()).all()

@router.get("/{user_id}/gamification")
def get_donor_gamification(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün puan ve rozet bilgilerini getirir."""
    data = db.query(models.GamificationData).filter(models.GamificationData.user_id == user_id).first()
    if not data: raise HTTPException(status_code=404, detail="Veri yok.")
    return data

@router.put("/{user_id}/update")
def update_donor_profile(user_id: uuid.UUID, update_data: dict, db: Session = Depends(get_db)):
    """Profil bilgilerini günceller (Ad, Telefon, Kilo)."""
    profile = db.query(models.DonorProfile).filter(models.DonorProfile.user_id == user_id).first()
    if not profile: raise HTTPException(status_code=404, detail="Profil bulunamadı.")
    
    if "ad_soyad" in update_data: profile.ad_soyad = update_data["ad_soyad"]
    if "telefon" in update_data: profile.telefon = update_data["telefon"]
    if "kilo" in update_data: profile.kilo = update_data["kilo"]
    
    db.commit()
    return {"status": "success"}