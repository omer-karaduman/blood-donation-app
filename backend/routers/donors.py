# backend/routers/donors.py
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from geoalchemy2.elements import WKTElement
from typing import List
import uuid
from datetime import datetime, timedelta

import models
import schemas
from database import get_db
import enum

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
# KAYIT VE ANA FEED
# ---------------------------------------------------------

@router.post("/register", response_model=schemas.UserResponse)
def register_donor(user_in: schemas.DonorCreate, db: Session = Depends(get_db)):
    """Yeni donör kaydı yapar ve PostGIS konum verisini işler."""
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

@router.get("/{user_id}/feed") # response_model'i schemas.DonorFeedResponse olarak kontrol et
def get_donor_feed(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """
    Donörün bekleyen (BEKLIYOR) ve zaten onayladığı (KABUL) aktif talepleri listeler.
    """
    # 🚀 DÜZELTME: Sadece BEKLIYOR değil, KABUL edilenleri de kapsıyoruz.
    my_logs = db.query(models.NotificationLog)\
                .join(models.BloodRequest)\
                .options(
                    joinedload(models.NotificationLog.blood_request).joinedload(models.BloodRequest.institution).joinedload(models.Institution.district),
                    joinedload(models.NotificationLog.blood_request).joinedload(models.BloodRequest.institution).joinedload(models.Institution.neighborhood)
                )\
                .filter(
                    models.NotificationLog.user_id == user_id,
                    # 🚀 KRİTİK DEĞİŞİKLİK: 'in_' kullanarak iki durumu da dahil ediyoruz
                    models.NotificationLog.kullanici_reaksiyonu.in_([
                        models.NotificationReactionEnum.BEKLIYOR,
                        models.NotificationReactionEnum.KABUL
                    ]),
                    models.BloodRequest.durum == models.RequestStatusEnum.AKTIF
                ).all()
    
    feed_data = []
    su_an = datetime.utcnow()
    durum_degisikligi_var_mi = False

    for log in my_logs:
        req = log.blood_request
        if not req:
            continue

        bitis_zamani = req.olusturma_tarihi + timedelta(hours=req.gecerlilik_suresi_saat)
        
        if su_an < bitis_zamani:
            feed_data.append({
                "log_id": log.log_id, 
                "talep_id": req.talep_id,
                # 🚀 KRİTİK EKLEME: Flutter'ın 'Kabul' olanı ayırt etmesi için bu alan şart
                "reaksiyon": log.kullanici_reaksiyonu, 
                "kurum_adi": req.institution.kurum_adi if req.institution else "Sağlık Kurumu",
                "ilce": req.institution.district.name if req.institution and req.institution.district else "İzmir",
                "istenen_kan_grubu": req.istenen_kan_grubu,
                "unite_sayisi": req.unite_sayisi,
                "aciliyet_durumu": req.aciliyet_durumu,
                "olusturma_tarihi": req.olusturma_tarihi,
                "gecerlilik_suresi_saat": req.gecerlilik_suresi_saat 
            })
        else:
            # Süresi dolmuşsa iptale çek
            req.durum = models.RequestStatusEnum.IPTAL
            durum_degisikligi_var_mi = True
    
    if durum_degisikligi_var_mi:
        db.commit()
    
    feed_data.sort(key=lambda x: x["olusturma_tarihi"], reverse=True)
    return feed_data

@router.post("/{user_id}/respond/{log_id}")
def respond_to_notification(user_id: uuid.UUID, log_id: uuid.UUID, reaksiyon: models.NotificationReactionEnum = Query(...), db: Session = Depends(get_db)):
    """Bildirime yanıt verir ve duyarlılık motorunu günceller."""
    log = db.query(models.NotificationLog).filter(models.NotificationLog.log_id == log_id, models.NotificationLog.user_id == user_id).first()
    
    if not log:
        raise HTTPException(status_code=404, detail="Geçersiz bildirim.")

    # 🚀 DÜZELTME BURADA: Sadece 'BEKLIYOR' iken değil, 'KABUL' edilmişken de işlem yapılmasına izin ver.
    if log.kullanici_reaksiyonu not in [models.NotificationReactionEnum.BEKLIYOR, models.NotificationReactionEnum.KABUL]:
        raise HTTPException(status_code=400, detail="Bu bildirim zaten kapatılmış veya değiştirilemez.")

    # 🚀 YENİ MANTIK: Eğer donör daha önce KABUL etmiş ama şimdi İPTAL ediyorsa (KABUL -> RED)
    if log.kullanici_reaksiyonu == models.NotificationReactionEnum.KABUL and reaksiyon == models.NotificationReactionEnum.RED:
        ml_feat = db.query(models.MLFeature).filter(models.MLFeature.user_id == user_id).first()
        if ml_feat and ml_feat.olumlu_yanit_sayisi > 0:
            ml_feat.olumlu_yanit_sayisi -= 1 # İptal ettiği için ML modelindeki skoru geri alınıyor

    # Klasik İlk Onay Durumu: (BEKLIYOR -> KABUL)
    elif log.kullanici_reaksiyonu == models.NotificationReactionEnum.BEKLIYOR and reaksiyon == models.NotificationReactionEnum.KABUL:
        ml_feat = db.query(models.MLFeature).filter(models.MLFeature.user_id == user_id).first()
        if ml_feat: 
            ml_feat.olumlu_yanit_sayisi += 1

    # Durumu güncelle
    log.kullanici_reaksiyonu = reaksiyon
    log.reaksiyon_zamani = datetime.utcnow()
        
    db.commit()
    update_donor_sensitivity(db, user_id)
    return {"message": "Yanıt kaydedildi."}

# ---------------------------------------------------------
# PROFİL, GEÇMİŞ VE OYUNLAŞTIRMA
# ---------------------------------------------------------

@router.get("/{user_id}/profile")
def get_donor_profile(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donör profilini, kullanıcı ve tam konum hiyerarşisiyle (İlçe dahil) döner."""
    profile = db.query(models.DonorProfile)\
                .options(
                    joinedload(models.DonorProfile.neighborhood).joinedload(models.Neighborhood.district),
                    joinedload(models.DonorProfile.user)
                )\
                .filter(models.DonorProfile.user_id == user_id).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profil bulunamadı.")
    
    mahalle_adi = "Bilinmiyor"
    ilce_adi = "İlçe Seçilmedi"
    
    if profile.neighborhood:
        mahalle_adi = profile.neighborhood.name
        if profile.neighborhood.district:
            ilce_adi = profile.neighborhood.district.name

    return {
        "user_id": str(profile.user_id),
        "ad_soyad": profile.ad_soyad,
        "telefon": profile.telefon,
        "cinsiyet": profile.cinsiyet,
        "kilo": profile.kilo,
        "kan_grubu": profile.kan_grubu,
        "kan_verebilir_mi": profile.kan_verebilir_mi,
        # 🚀 İŞTE EKSİK OLAN VE SAYACI BOZAN SATIR GERİ GELDİ:
        "son_bagis_tarihi": profile.son_bagis_tarihi.isoformat() if profile.son_bagis_tarihi else None,
        "neighborhood_id": str(profile.neighborhood_id) if profile.neighborhood_id else None,
        "user": {
            "email": profile.user.email if profile.user else "E-posta Yok"
        },
        "neighborhood": {
            "name": mahalle_adi,
            "district": {
                "name": ilce_adi
            }
        }
    }

@router.put("/{user_id}/update")
def update_donor_profile(user_id: uuid.UUID, update_data: dict, db: Session = Depends(get_db)):
    """Profil bilgilerini ve mahalle seçimini günceller."""
    profile = db.query(models.DonorProfile).filter(models.DonorProfile.user_id == user_id).first()
    if not profile: raise HTTPException(status_code=404, detail="Profil bulunamadı.")
    
    if "ad_soyad" in update_data: profile.ad_soyad = update_data["ad_soyad"]
    if "telefon" in update_data: profile.telefon = update_data["telefon"]
    if "kilo" in update_data: profile.kilo = update_data["kilo"]
    
    # 📍 Mahalle Güncelleme
    if "neighborhood_id" in update_data:
        n_id = update_data["neighborhood_id"]
        profile.neighborhood_id = uuid.UUID(n_id) if n_id else None
        
    # 🌍 Coğrafi Konum (Latitude/Longitude) Güncelleme
    if "latitude" in update_data and "longitude" in update_data:
        lat = update_data["latitude"]
        lon = update_data["longitude"]
        if lat is not None and lon is not None:
            profile.konum = WKTElement(f"POINT({lon} {lat})", srid=4326)
    
    db.commit()
    return {"status": "success"}

@router.get("/{user_id}/history")
def get_donor_history(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün bağış geçmişini ÇÖKMEYECEK %100 güvenli bir JSON olarak paketler."""
    try:
        history_records = db.query(models.DonationHistory)\
            .options(joinedload(models.DonationHistory.institution))\
            .filter(models.DonationHistory.user_id == user_id)\
            .order_by(models.DonationHistory.bagis_tarihi.desc())\
            .all()

        result = []
        for record in history_records:
            # 🛡️ 1. GÜVENLİK: Durum (Enum) verisini kesin olarak metne (String) çevirme
            status_str = "Beklemede"
            if record.islem_sonucu:
                if hasattr(record.islem_sonucu, 'value'):
                    status_str = record.islem_sonucu.value
                elif isinstance(record.islem_sonucu, enum.Enum):
                    status_str = record.islem_sonucu.name
                else:
                    status_str = str(record.islem_sonucu)

            # 🛡️ 2. GÜVENLİK: Hastane bilgilerini Null-Safe olarak alma
            institution_data = None
            if record.institution:
                institution_data = {
                    "kurum_id": str(record.institution.kurum_id),
                    "kurum_adi": record.institution.kurum_adi
                }

            # 🛡️ 3. GÜVENLİK: Tüm UUID ve Tarihleri güvenle String formata dönüştürme
            result.append({
                "bagis_id": str(record.bagis_id),
                "user_id": str(record.user_id),
                "kurum_id": str(record.kurum_id) if record.kurum_id else None,
                "talep_id": str(record.talep_id) if record.talep_id else None,
                "bagis_tarihi": record.bagis_tarihi.isoformat() if record.bagis_tarihi else None,
                "islem_sonucu": status_str,
                "institution": institution_data
            })

        return result

    except Exception as e:
        # Eğer sunucuda bir hata olursa terminale yazdır, böylece ne olduğunu tam görebiliriz
        print(f"❌ BAĞIŞ GEÇMİŞİ ÇEKİLİRKEN KRİTİK HATA: {e}")
        raise HTTPException(status_code=500, detail=f"Sunucu Hatası: {str(e)}")


@router.get("/{user_id}/gamification")
def get_donor_gamification(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün puan ve rozet bilgilerini getirir."""
    data = db.query(models.GamificationData).filter(models.GamificationData.user_id == user_id).first()
    if not data: raise HTTPException(status_code=404, detail="Veri yok.")
    return data