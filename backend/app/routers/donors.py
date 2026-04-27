# app/routers/donors.py
"""
Donör işlemleri: kayıt, feed, yanıt, profil, güncelleme, geçmiş, oyunlaştırma.
Orijinal iş mantığı tamamen korundu.
"""
import uuid
import enum as pyenum
from datetime import datetime, timedelta
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from geoalchemy2.elements import WKTElement

from app import models, schemas
from app.database import get_db

router = APIRouter(prefix="/donors", tags=["Donör İşlemleri"])


# ─── Yardımcı ─────────────────────────────────────────────────────────────────

def update_donor_sensitivity(db: Session, user_id: uuid.UUID) -> None:
    """Geçmiş reaksiyonlara göre duyarlılık seviyesini dinamik günceller."""
    ml_feature = db.query(models.MLFeature).filter(models.MLFeature.user_id == user_id).first()
    if not ml_feature:
        return

    logs = db.query(models.NotificationLog).filter(models.NotificationLog.user_id == user_id).all()
    if not logs:
        return

    base_score = 3.0
    for log in logs:
        if log.kullanici_reaksiyonu == models.NotificationReactionEnum.GORMEZDEN_GELDI:
            base_score -= 0.1
            continue
        if log.reaksiyon_zamani and log.gonderim_zamani:
            minutes = (log.reaksiyon_zamani - log.gonderim_zamani).total_seconds() / 60.0
            req = log.blood_request
            if log.kullanici_reaksiyonu == models.NotificationReactionEnum.KABUL:
                base_score += 0.3
                if minutes <= 15:
                    base_score += 0.4
                elif minutes <= 60:
                    base_score += 0.2
                if req and req.aciliyet_durumu == models.UrgencyEnum.ACIL:
                    base_score += 0.3
            elif log.kullanici_reaksiyonu == models.NotificationReactionEnum.RED:
                base_score += 0.1 if minutes <= 15 else -0.1

    ml_feature.duyarlilik_seviyesi = int(max(1, min(5, round(base_score))))
    db.commit()


# ─── Kayıt ────────────────────────────────────────────────────────────────────

@router.post("/register", response_model=schemas.UserResponse)
def register_donor(user_in: schemas.DonorCreate, db: Session = Depends(get_db)):
    """Yeni donör kaydı yapar ve PostGIS konum verisini işler."""
    if db.query(models.User).filter(models.User.email == user_in.email).first():
        raise HTTPException(status_code=400, detail="Email kullanımda.")

    new_user = models.User(
        email=user_in.email,
        hashed_password=user_in.password,
        role=models.UserRoleEnum.DONOR,
    )
    db.add(new_user)
    db.flush()

    donor_data   = user_in.model_dump(exclude={"email", "password", "latitude", "longitude"})
    new_profile  = models.DonorProfile(user_id=new_user.user_id, **donor_data)

    if user_in.latitude is not None and user_in.longitude is not None:
        new_profile.konum = WKTElement(
            f"POINT({user_in.longitude} {user_in.latitude})", srid=4326
        )

    db.add(new_profile)
    db.add(models.MLFeature(user_id=new_user.user_id))
    db.add(models.GamificationData(user_id=new_user.user_id))
    db.commit()
    db.refresh(new_user)
    return new_user


# ─── Feed ─────────────────────────────────────────────────────────────────────

@router.get("/{user_id}/feed")
def get_donor_feed(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün bekleyen ve onayladığı aktif talepleri listeler."""
    my_logs = (
        db.query(models.NotificationLog)
        .join(models.BloodRequest)
        .options(
            joinedload(models.NotificationLog.blood_request)
            .joinedload(models.BloodRequest.institution)
            .joinedload(models.Institution.district),
            joinedload(models.NotificationLog.blood_request)
            .joinedload(models.BloodRequest.institution)
            .joinedload(models.Institution.neighborhood),
        )
        .filter(
            models.NotificationLog.user_id == user_id,
            models.NotificationLog.kullanici_reaksiyonu.in_(
                [models.NotificationReactionEnum.BEKLIYOR, models.NotificationReactionEnum.KABUL]
            ),
            models.BloodRequest.durum == models.RequestStatusEnum.AKTIF,
        )
        .all()
    )

    feed_data = []
    su_an     = datetime.utcnow()
    changed   = False

    for log in my_logs:
        req = log.blood_request
        if not req:
            continue
        bitis = req.olusturma_tarihi + timedelta(hours=req.gecerlilik_suresi_saat)
        if su_an < bitis:
            feed_data.append({
                "log_id":               str(log.log_id),
                "talep_id":             str(req.talep_id),
                "reaksiyon":            log.kullanici_reaksiyonu.value if hasattr(log.kullanici_reaksiyonu, 'value') else str(log.kullanici_reaksiyonu),
                "kurum_adi":            req.institution.kurum_adi if req.institution else "Sağlık Kurumu",
                "ilce":                 req.institution.district.name if req.institution and req.institution.district else "İzmir",
                "istenen_kan_grubu":    req.istenen_kan_grubu.value if hasattr(req.istenen_kan_grubu, 'value') else str(req.istenen_kan_grubu),
                "unite_sayisi":         req.unite_sayisi,
                "aciliyet_durumu":      req.aciliyet_durumu.value if hasattr(req.aciliyet_durumu, 'value') else str(req.aciliyet_durumu),
                "olusturma_tarihi":     req.olusturma_tarihi.isoformat() if req.olusturma_tarihi else None,
                "gecerlilik_suresi_saat": req.gecerlilik_suresi_saat,
            })
        else:
            req.durum = models.RequestStatusEnum.IPTAL
            changed   = True

    if changed:
        db.commit()

    feed_data.sort(key=lambda x: x["olusturma_tarihi"], reverse=True)
    return feed_data


# ─── Bildirime Yanıt ──────────────────────────────────────────────────────────

@router.post("/{user_id}/respond/{log_id}")
def respond_to_notification(
    user_id:   uuid.UUID,
    log_id:    uuid.UUID,
    reaksiyon: models.NotificationReactionEnum = Query(...),
    db:        Session = Depends(get_db),
):
    """Bildirime yanıt verir ve duyarlılık motorunu günceller."""
    log = (
        db.query(models.NotificationLog)
        .filter(
            models.NotificationLog.log_id == log_id,
            models.NotificationLog.user_id == user_id,
        )
        .first()
    )
    if not log:
        raise HTTPException(status_code=404, detail="Geçersiz bildirim.")

    if log.kullanici_reaksiyonu not in [
        models.NotificationReactionEnum.BEKLIYOR,
        models.NotificationReactionEnum.KABUL,
    ]:
        raise HTTPException(status_code=400, detail="Bu bildirim zaten kapatılmış.")

    # KABUL → RED: ML skoru geri al
    if (
        log.kullanici_reaksiyonu == models.NotificationReactionEnum.KABUL
        and reaksiyon == models.NotificationReactionEnum.RED
    ):
        ml_feat = db.query(models.MLFeature).filter(models.MLFeature.user_id == user_id).first()
        if ml_feat and ml_feat.olumlu_yanit_sayisi > 0:
            ml_feat.olumlu_yanit_sayisi -= 1

    # BEKLIYOR → KABUL: ML skoru artır
    elif (
        log.kullanici_reaksiyonu == models.NotificationReactionEnum.BEKLIYOR
        and reaksiyon == models.NotificationReactionEnum.KABUL
    ):
        ml_feat = db.query(models.MLFeature).filter(models.MLFeature.user_id == user_id).first()
        if ml_feat:
            ml_feat.olumlu_yanit_sayisi += 1

    log.kullanici_reaksiyonu = reaksiyon
    log.reaksiyon_zamani     = datetime.utcnow()
    db.commit()
    update_donor_sensitivity(db, user_id)
    return {"message": "Yanıt kaydedildi."}


# ─── Profil ───────────────────────────────────────────────────────────────────

@router.get("/{user_id}/profile")
def get_donor_profile(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donör profilini tam konum hiyerarşisiyle döner."""
    profile = (
        db.query(models.DonorProfile)
        .options(
            joinedload(models.DonorProfile.neighborhood).joinedload(models.Neighborhood.district),
            joinedload(models.DonorProfile.user),
        )
        .filter(models.DonorProfile.user_id == user_id)
        .first()
    )
    if not profile:
        raise HTTPException(status_code=404, detail="Profil bulunamadı.")

    mahalle_adi   = None
    ilce_adi      = None
    mahalle_id    = None
    ilce_id       = None

    if profile.neighborhood:
        mahalle_adi = profile.neighborhood.name
        mahalle_id  = str(profile.neighborhood.neighborhood_id)
        if profile.neighborhood.district:
            ilce_adi = profile.neighborhood.district.name
            ilce_id  = str(profile.neighborhood.district.district_id)

    return {
        "user_id":        str(profile.user_id),
        "ad_soyad":      profile.ad_soyad,
        "telefon":        profile.telefon,
        "cinsiyet":       profile.cinsiyet,
        "kilo":           profile.kilo,
        "kan_grubu":      profile.kan_grubu,
        "kan_verebilir_mi": profile.kan_verebilir_mi,
        "son_bagis_tarihi": profile.son_bagis_tarihi.isoformat() if profile.son_bagis_tarihi else None,
        "neighborhood_id": str(profile.neighborhood_id) if profile.neighborhood_id else None,
        "user":           {"email": profile.user.email if profile.user else "E-posta Yok"},
        "neighborhood": {
            "neighborhood_id": mahalle_id,
            "name":            mahalle_adi,
            "district": {
                "district_id": ilce_id,
                "name":        ilce_adi,
            } if ilce_id else None,
        } if mahalle_id else None,
    }


@router.put("/{user_id}/update")
def update_donor_profile(user_id: uuid.UUID, update_data: dict, db: Session = Depends(get_db)):
    """Profil bilgilerini ve konum bilgisini günceller."""
    profile = db.query(models.DonorProfile).filter(models.DonorProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profil bulunamadı.")

    for field in ("ad_soyad", "telefon", "kilo"):
        if field in update_data:
            setattr(profile, field, update_data[field])

    if "neighborhood_id" in update_data:
        n_id = update_data["neighborhood_id"]
        profile.neighborhood_id = uuid.UUID(n_id) if n_id else None

    if "latitude" in update_data and "longitude" in update_data:
        lat, lon = update_data["latitude"], update_data["longitude"]
        if lat is not None and lon is not None:
            profile.konum = WKTElement(f"POINT({lon} {lat})", srid=4326)

    db.commit()
    return {"status": "success"}


# ─── Geçmiş & Oyunlaştırma ───────────────────────────────────────────────────

@router.get("/{user_id}/history")
def get_donor_history(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün bağış geçmişini güvenli JSON olarak döner."""
    try:
        records = (
            db.query(models.DonationHistory)
            .options(joinedload(models.DonationHistory.institution))
            .filter(models.DonationHistory.user_id == user_id)
            .order_by(models.DonationHistory.bagis_tarihi.desc())
            .all()
        )
        result = []
        for r in records:
            if hasattr(r.islem_sonucu, "value"):
                status_str = r.islem_sonucu.value
            elif isinstance(r.islem_sonucu, pyenum.Enum):
                status_str = r.islem_sonucu.name
            else:
                status_str = str(r.islem_sonucu)

            institution_data = None
            if r.institution:
                institution_data = {
                    "kurum_id":  str(r.institution.kurum_id),
                    "kurum_adi": r.institution.kurum_adi,
                }

            result.append({
                "bagis_id":    str(r.bagis_id),
                "user_id":     str(r.user_id),
                "kurum_id":    str(r.kurum_id) if r.kurum_id else None,
                "talep_id":    str(r.talep_id) if r.talep_id else None,
                "bagis_tarihi": r.bagis_tarihi.isoformat() if r.bagis_tarihi else None,
                "islem_sonucu": status_str,
                "institution": institution_data,
            })
        return result

    except Exception as e:
        print(f"❌ BAĞIŞ GEÇMİŞİ HATASI: {e}")
        raise HTTPException(status_code=500, detail=f"Sunucu Hatası: {str(e)}")


@router.get("/{user_id}/gamification")
def get_donor_gamification(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün puan ve rozet bilgilerini getirir."""
    data = db.query(models.GamificationData).filter(models.GamificationData.user_id == user_id).first()
    if not data:
        raise HTTPException(status_code=404, detail="Veri yok.")

    # Gercek basarili bagis sayisini DonationHistory'den cek
    basarili_bagis = db.query(models.DonationHistory).filter(
        models.DonationHistory.user_id == user_id,
        models.DonationHistory.islem_sonucu == models.DonationResultEnum.BASARILI,
    ).count()

    return {
        "toplam_puan":  data.toplam_puan or 0,
        "toplam_bagis": basarili_bagis,
        "seviye":       data.seviye or 1,
        "rozet_listesi": data.rozet_listesi or [],
    }


@router.get("/{user_id}/all-logs")
def get_donor_all_logs(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün tüm bildirim loglarını (kabul, red, görmezden, tamamlandı) getirir."""
    logs = (
        db.query(models.NotificationLog)
        .options(
            joinedload(models.NotificationLog.blood_request)
            .joinedload(models.BloodRequest.institution)
        )
        .filter(models.NotificationLog.user_id == user_id)
        .order_by(models.NotificationLog.gonderim_zamani.desc())
        .all()
    )
    result = []
    for log in logs:
        req = log.blood_request
        kurum_adi = None
        if req and req.institution:
            kurum_adi = req.institution.kurum_adi

        reaksiyon_str = (
            log.kullanici_reaksiyonu.value
            if hasattr(log.kullanici_reaksiyonu, "value")
            else str(log.kullanici_reaksiyonu)
        )

        result.append({
            "log_id":        str(log.log_id),
            "talep_id":      str(req.talep_id) if req else None,
            "kurum_adi":     kurum_adi or "Bilinmeyen Kurum",
            "reaksiyon":     reaksiyon_str,
            "gonderim_zamani": log.gonderim_zamani.isoformat() if log.gonderim_zamani else None,
            "reaksiyon_zamani": log.reaksiyon_zamani.isoformat() if log.reaksiyon_zamani else None,
            "kan_grubu":     req.istenen_kan_grubu.value if req and hasattr(req.istenen_kan_grubu, "value") else None,
        })
    return result
