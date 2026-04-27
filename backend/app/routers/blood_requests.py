# app/routers/blood_requests.py
"""
Kan talebi oluşturma, listeleme, iptal, uzatma, tamamlama ve bağış onaylama.
Prefix: /staff (eski API ile tam uyumlu)
"""
import uuid
from datetime import datetime, timedelta
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func

from app import models, schemas
from app.database import get_db
from app.services.notification_service import notify_donor
from app.services.ml_service import calculate_age, predict_donor_scores

# Prefix bilinçli olarak /staff tutuldu — mobile API'si değişmez
router = APIRouter(prefix="/staff", tags=["Kan Talebi ve ML İşlemleri"])


# ─── Talebi Oluştur (Ana ML Fonksiyonu) ──────────────────────────────────────

@router.post("/requests")
def create_smart_blood_request(
    request_in: schemas.BloodRequestCreate,
    personel_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """
    Personel kan talebi oluşturur.
    Sistem 10 km çapındaki uygun donörleri ML ile sıralayıp top-30'a bildirim atar.
    """
    staff = db.query(models.StaffProfile).filter(
        models.StaffProfile.user_id == personel_id
    ).first()
    if not staff:
        raise HTTPException(status_code=404, detail="Personel yetkisi bulunamadı.")

    institution = db.query(models.Institution).filter(
        models.Institution.kurum_id == staff.kurum_id
    ).first()
    if not institution or not institution.konum:
        raise HTTPException(status_code=400, detail="Kurumun konum verisi eksik.")

    # Kan grubunu al
    kan_grubu = request_in.istenen_kan_grubu

    new_request = models.BloodRequest(
        kurum_id=institution.kurum_id,
        olusturan_personel_id=personel_id,
        istenen_kan_grubu=kan_grubu,
        unite_sayisi=request_in.unite_sayisi,
        aciliyet_durumu=request_in.aciliyet_durumu,
        gecerlilik_suresi_saat=request_in.gecerlilik_suresi_saat,
        durum=models.RequestStatusEnum.AKTIF,
    )
    db.add(new_request)
    db.flush()

    # PostGIS: 10 km çapında uygun donörler
    MAX_DIST = 10_000
    nearby = db.query(
        models.DonorProfile,
        func.ST_DistanceSphere(models.DonorProfile.konum, institution.konum).label("dist"),
    ).options(
        joinedload(models.DonorProfile.ml_features)
    ).filter(
        models.DonorProfile.kan_grubu == kan_grubu,
        models.DonorProfile.kan_verebilir_mi == True,
        models.DonorProfile.konum != None,
        func.ST_DistanceSphere(models.DonorProfile.konum, institution.konum) <= MAX_DIST,
    ).all()

    if not nearby:
        db.commit()
        return {"message": "Talep oluşturuldu ancak uygun donör bulunamadı.", "hedeflenen_donor_sayisi": 0}

    now = datetime.utcnow()
    valid_donors = []
    ml_inputs    = []

    for donor, dist_m in nearby:
        days_since = 999
        if donor.son_bagis_tarihi:
            days_since = (now - donor.son_bagis_tarihi).days
            if donor.cinsiyet == "E" and days_since < 90:
                continue
            if donor.cinsiyet == "K" and days_since < 120:
                continue

        valid_donors.append(donor)
        feat = donor.ml_features
        past_donations = feat.basarili_bagis_sayisi if feat else 0
        response_rate  = (
            feat.olumlu_yanit_sayisi / feat.toplam_bildirim_sayisi
            if feat and feat.toplam_bildirim_sayisi > 0
            else 0.5
        )
        ml_inputs.append({
            "age":                       calculate_age(donor.dogum_tarihi),
            "past_donations":            past_donations,
            "days_since_last_donation":  days_since,
            "response_rate":             response_rate,
            "sensitivity_level":         getattr(feat, "duyarlilik_seviyesi", 3) if feat else 3,
            "preferred_hour":            feat.tercih_edilen_saatler[0] if feat and feat.tercih_edilen_saatler else 12,
        })

    if not valid_donors:
        db.commit()
        return {"message": "Tıbbi bekleme süresi dolmamış, bildirim atılamadı.", "hedeflenen_donor_sayisi": 0}

    predictions = predict_donor_scores(valid_donors, ml_inputs)
    predictions.sort(key=lambda x: x["probability"], reverse=True)
    top_30 = predictions[:30]

    kurum_adi = institution.kurum_adi
    aciliyet  = request_in.aciliyet_durumu.name if hasattr(request_in.aciliyet_durumu, "name") else str(request_in.aciliyet_durumu)

    for dp in top_30:
        donor = dp["donor"]
        db.add(models.NotificationLog(
            user_id=donor.user_id,
            talep_id=new_request.talep_id,
            ml_skoru_o_an=dp["probability"],
            iletilme_durumu=models.NotificationDeliveryEnum.BASARILI,
            kullanici_reaksiyonu=models.NotificationReactionEnum.BEKLIYOR,
            gonderim_zamani=now,
        ))
        if donor.ml_features:
            donor.ml_features.toplam_bildirim_sayisi += 1
        notify_donor(donor, new_request.talep_id, kurum_adi, aciliyet)

    db.commit()
    db.refresh(new_request)

    return {
        "message": "Talep oluşturuldu ve ML eşleştirmesi yapıldı.",
        "tibbi_uygun_bulunan_donor": len(valid_donors),
        "bildirim_gonderilen_kisi_sayisi": len(top_30),
        "talep_id": new_request.talep_id,
    }


# ─── Listeleme ────────────────────────────────────────────────────────────────

@router.get("/my-requests", response_model=List[schemas.BloodRequestDetailResponse])
def get_staff_requests(personel_id: uuid.UUID, db: Session = Depends(get_db)):
    """Personelin kendi taleplerini ve ML sonuçlarını gösterir."""
    requests = (
        db.query(models.BloodRequest)
        .options(
            joinedload(models.BloodRequest.bildirimler)
            .joinedload(models.NotificationLog.user)
        )
        .filter(models.BloodRequest.olusturan_personel_id == personel_id)
        .order_by(models.BloodRequest.olusturma_tarihi.desc())
        .all()
    )

    output  = []
    su_an   = datetime.utcnow()
    changed = False

    for r in requests:
        if r.durum == models.RequestStatusEnum.AKTIF:
            if su_an >= r.olusturma_tarihi + timedelta(hours=r.gecerlilik_suresi_saat):
                r.durum = models.RequestStatusEnum.IPTAL
                changed = True

        donor_yanitlari = [
            {
                "log_id":         str(b.log_id),
                "donor_ad_soyad": (
                    b.user.donor_profile.ad_soyad
                    if b.user and b.user.donor_profile
                    else "Bilinmeyen Donör"
                ),
                "reaksiyon":      b.kullanici_reaksiyonu.value if hasattr(b.kullanici_reaksiyonu, 'value') else str(b.kullanici_reaksiyonu),
                "reaksiyon_zamani": b.reaksiyon_zamani.isoformat() if b.reaksiyon_zamani else None,
                "ml_score":       b.ml_skoru_o_an or 0.0,
            }
            for b in r.bildirimler
        ]
        output.append({
            "talep_id":             str(r.talep_id),
            "istenen_kan_grubu":    r.istenen_kan_grubu.value if hasattr(r.istenen_kan_grubu, 'value') else str(r.istenen_kan_grubu),
            "unite_sayisi":         r.unite_sayisi,
            "durum":                r.durum.value if hasattr(r.durum, 'value') else str(r.durum),
            "aciliyet_durumu":      r.aciliyet_durumu.value if hasattr(r.aciliyet_durumu, 'value') else str(r.aciliyet_durumu),
            "olusturma_tarihi":     r.olusturma_tarihi.isoformat() if r.olusturma_tarihi else None,
            "donor_yanitlari":      donor_yanitlari,
            "gecerlilik_suresi_saat": r.gecerlilik_suresi_saat,
        })

    if changed:
        db.commit()
    return output


# ─── İptal / Uzat / Tamamla ───────────────────────────────────────────────────

@router.put("/requests/{talep_id}/cancel")
def cancel_blood_request(
    talep_id:   uuid.UUID,
    personel_id: uuid.UUID = Query(...),
    db:         Session = Depends(get_db),
):
    """Talebi iptal eder; bekleyen bildirimleri de kapatır."""
    req = db.query(models.BloodRequest).filter(
        models.BloodRequest.talep_id == talep_id,
        models.BloodRequest.olusturan_personel_id == personel_id,
    ).first()
    if not req:
        raise HTTPException(status_code=404, detail="Talep bulunamadı veya yetki yok.")
    if req.durum != models.RequestStatusEnum.AKTIF:
        raise HTTPException(status_code=400, detail="Bu talep zaten aktif değil.")

    req.durum = models.RequestStatusEnum.IPTAL
    db.query(models.NotificationLog).filter(
        models.NotificationLog.talep_id == talep_id,
        models.NotificationLog.kullanici_reaksiyonu == models.NotificationReactionEnum.BEKLIYOR,
    ).update({"kullanici_reaksiyonu": models.NotificationReactionEnum.GORMEZDEN_GELDI})
    db.commit()
    return {"message": "Talep ve bağlı bildirimler iptal edildi."}


@router.put("/requests/{talep_id}/extend")
def extend_blood_request(
    talep_id:   uuid.UUID,
    personel_id: uuid.UUID = Query(...),
    ek_saat:    int = Query(...),
    db:         Session = Depends(get_db),
):
    """Aktif talebin geçerlilik süresini uzatır."""
    req = db.query(models.BloodRequest).filter(
        models.BloodRequest.talep_id == talep_id,
        models.BloodRequest.olusturan_personel_id == personel_id,
    ).first()
    if not req:
        raise HTTPException(status_code=404, detail="Talep bulunamadı veya yetki yok.")
    if req.durum != models.RequestStatusEnum.AKTIF:
        raise HTTPException(status_code=400, detail="Sadece aktif talepler uzatılabilir.")

    req.gecerlilik_suresi_saat += ek_saat
    db.commit()
    return {"message": f"Talep süresi {ek_saat} saat uzatıldı."}


@router.put("/requests/{talep_id}/complete")
def complete_blood_request(
    talep_id:   uuid.UUID,
    personel_id: uuid.UUID = Query(...),
    db:         Session = Depends(get_db),
):
    """Talebi tamamlandı olarak işaretler."""
    req = db.query(models.BloodRequest).filter(
        models.BloodRequest.talep_id == talep_id,
        models.BloodRequest.olusturan_personel_id == personel_id,
    ).first()
    if not req:
        raise HTTPException(status_code=404, detail="Talep bulunamadı.")

    req.durum = models.RequestStatusEnum.TAMAMLANDI.value
    db.commit()
    return {"message": "Talep tamamlandı olarak işaretlendi."}


# ─── Bağış Onaylama ───────────────────────────────────────────────────────────

@router.post("/confirm-donation/{log_id}")
def confirm_donation(
    log_id:     uuid.UUID,
    alinan_unite: int = Query(1, ge=1),
    db:         Session = Depends(get_db),
):
    """Bağışı onaylar: ünite düşer, donöre puan verir, cooldown başlatır."""
    log = db.query(models.NotificationLog).filter(
        models.NotificationLog.log_id == log_id
    ).first()
    if not log:
        raise HTTPException(status_code=404, detail="Kayıt bulunamadı.")

    talep   = log.blood_request
    user_id = log.user_id

    if talep:
        talep.unite_sayisi = max(0, talep.unite_sayisi - alinan_unite)
        if talep.unite_sayisi == 0:
            talep.durum = models.RequestStatusEnum.TAMAMLANDI.value

    profile = db.query(models.DonorProfile).filter(
        models.DonorProfile.user_id == user_id
    ).first()
    if profile:
        profile.son_bagis_tarihi = datetime.utcnow()
        profile.kan_verebilir_mi = False

    db.add(models.DonationHistory(
        user_id=user_id,
        kurum_id=talep.kurum_id if talep else None,
        talep_id=talep.talep_id if talep else None,
        islem_sonucu=models.DonationResultEnum.BASARILI.value,
        bagis_tarihi=datetime.utcnow(),
    ))

    gamification = db.query(models.GamificationData).filter(
        models.GamificationData.user_id == user_id
    ).first()
    if gamification:
        gamification.toplam_puan += 100

    log.kullanici_reaksiyonu = models.NotificationReactionEnum.TAMAMLANDI.value
    db.commit()
    return {"status": "success", "message": "Bağış onaylandı."}
