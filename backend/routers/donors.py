from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from geoalchemy2.elements import WKTElement
from typing import List
import uuid
from datetime import datetime

import models
import schemas
from database import get_db

# Donör endpointleri için prefix (ön ek) tanımlıyoruz
router = APIRouter(
    prefix="/donors",
    tags=["Donör İşlemleri"]
)

def update_donor_sensitivity(db: Session, user_id: uuid.UUID):
    """
    Donörün geçmiş reaksiyonlarına (hız ve aciliyet) bakarak 
    'Duyarlılık Seviyesini' (1-5 arası) dinamik olarak günceller.
    (Sadece bu router içinde kullanılan yardımcı bir yapay zeka fonksiyonudur)
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


@router.post("/register", response_model=schemas.UserResponse)
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


@router.get("/{user_id}/feed", response_model=List[schemas.DonorFeedResponse])
def get_donor_feed(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """
    SADECE DONÖRE ÖZEL FEED: Donörün kendi NotificationLog'unda bulunan ve 
    ilgili talebin 'AKTIF' olduğu durumları gösterir.
    """
    my_logs = db.query(models.NotificationLog)\
                .options(
                    # DÜZELTME 1: "request" yerine "blood_request" yazıldı
                    joinedload(models.NotificationLog.blood_request).joinedload(models.BloodRequest.institution).joinedload(models.Institution.district),
                    joinedload(models.NotificationLog.blood_request).joinedload(models.BloodRequest.institution).joinedload(models.Institution.neighborhood)
                )\
                .filter(
                    models.NotificationLog.user_id == user_id,
                    models.NotificationLog.kullanici_reaksiyonu == models.NotificationReactionEnum.BEKLIYOR
                ).all()
    
    feed_data = []
    for log in my_logs:
        # DÜZELTME 2: "log.request" yerine "log.blood_request" yazıldı
        req = log.blood_request
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


@router.post("/{user_id}/respond/{log_id}")
def respond_to_notification(
    user_id: uuid.UUID, 
    log_id: uuid.UUID, 
    reaksiyon: models.NotificationReactionEnum = Query(..., description="'Kabul' veya 'Red' gönderin"), 
    db: Session = Depends(get_db)
):
    """
    Donör mobil uygulamadan bildirime Kabul veya Ret yanıtı verir.
    Bu işlem Yapay Zeka için Olumlu Yanıt oranını ve Duyarlılık Seviyesini dinamik olarak günceller.
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