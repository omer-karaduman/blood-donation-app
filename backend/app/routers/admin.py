# app/routers/admin.py
"""
Admin paneli: özet istatistikler, system-logs ve talep detayı.
"""
import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload

from app import models, schemas
from app.database import get_db

router = APIRouter(prefix="/admin", tags=["Admin İşlemleri"])


@router.get("/summary")
def get_admin_summary(db: Session = Depends(get_db)):
    """Admin paneli için sistem geneli özet istatistikler."""
    return {
        "total_donors":      db.query(models.DonorProfile).count(),
        "active_requests":   db.query(models.BloodRequest)
                               .filter(models.BloodRequest.durum == models.RequestStatusEnum.AKTIF)
                               .count(),
        "total_institutions": db.query(models.Institution).count(),
        "total_staff":       db.query(models.StaffProfile).count(),
    }


@router.get("/system-logs", response_model=List[schemas.AdminRequestLogResponse])
def get_admin_logs(db: Session = Depends(get_db)):
    """Tüm talepleri ve her talep için ML öneri sayısını listeler."""
    logs = (
        db.query(models.BloodRequest)
        .order_by(models.BloodRequest.olusturma_tarihi.desc())
        .all()
    )
    return [
        {
            "talep_id":            log.talep_id,
            "kurum_adi":           log.institution.kurum_adi if log.institution else "Bilinmiyor",
            "staff_ad_soyad":      (
                log.personel.staff_profile.ad_soyad
                if log.personel and log.personel.staff_profile
                else "Sistem"
            ),
            "olusturma_tarihi":    log.olusturma_tarihi,
            "istenen_kan_grubu":   log.istenen_kan_grubu,
            "onerilen_donor_sayisi": len(log.bildirimler),
        }
        for log in logs
    ]


@router.get("/requests/{talep_id}/detail")
def get_request_detail(talep_id: str, db: Session = Depends(get_db)):
    """Belirli bir kan talebinin tam detayını döner (bildirimler + bağışlar)."""
    try:
        talep_uuid = uuid.UUID(talep_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Geçersiz talep ID formatı.")

    talep = (
        db.query(models.BloodRequest)
        .options(
            joinedload(models.BloodRequest.institution),
            joinedload(models.BloodRequest.personel).joinedload(models.User.staff_profile),
            joinedload(models.BloodRequest.bildirimler)
            .joinedload(models.NotificationLog.user)
            .joinedload(models.User.donor_profile),
        )
        .filter(models.BloodRequest.talep_id == talep_uuid)
        .first()
    )
    if not talep:
        raise HTTPException(status_code=404, detail="Talep bulunamadı.")

    bagislar = (
        db.query(models.DonationHistory)
        .options(joinedload(models.DonationHistory.donor))
        .filter(models.DonationHistory.talep_id == talep_uuid)
        .all()
    )

    bildirimler = [
        {
            "log_id":         str(b.log_id),
            "donor_ad_soyad": (
                b.user.donor_profile.ad_soyad
                if b.user and b.user.donor_profile
                else "Bilinmiyor"
            ),
            "kan_grubu":      b.user.donor_profile.kan_grubu if b.user and b.user.donor_profile else None,
            "reaksiyon":      b.kullanici_reaksiyonu.value if hasattr(b.kullanici_reaksiyonu, "value") else str(b.kullanici_reaksiyonu),
            "ml_skoru":       round(b.ml_skoru_o_an or 0.0, 1),
            "reaksiyon_zamani": b.reaksiyon_zamani.isoformat() if b.reaksiyon_zamani else None,
            "gonderim_zamani":  b.gonderim_zamani.isoformat() if b.gonderim_zamani else None,
        }
        for b in talep.bildirimler
    ]

    bagis_listesi = [
        {
            "bagis_id":      str(bg.bagis_id),
            "donor_ad_soyad": bg.donor.ad_soyad if bg.donor else "Bilinmiyor",
            "kan_grubu":     bg.donor.kan_grubu if bg.donor else None,
            "bagis_tarihi":  bg.bagis_tarihi.isoformat() if bg.bagis_tarihi else None,
            "islem_sonucu":  bg.islem_sonucu.value if hasattr(bg.islem_sonucu, "value") else str(bg.islem_sonucu),
        }
        for bg in bagislar
    ]

    kan_grubu_str = (
        talep.istenen_kan_grubu.value
        if hasattr(talep.istenen_kan_grubu, "value")
        else str(talep.istenen_kan_grubu)
    )

    return {
        "talep_id":         str(talep.talep_id),
        "kurum_adi":        talep.institution.kurum_adi if talep.institution else "Bilinmiyor",
        "kurum_adres":      talep.institution.tam_adres if talep.institution else "",
        "olusturan_personel": (
            talep.personel.staff_profile.ad_soyad
            if talep.personel and talep.personel.staff_profile
            else "Sistem"
        ),
        "istenen_kan_grubu":    kan_grubu_str,
        "unite_sayisi":         talep.unite_sayisi,
        "aciliyet_durumu":      talep.aciliyet_durumu.value if hasattr(talep.aciliyet_durumu, "value") else str(talep.aciliyet_durumu),
        "durum":                talep.durum.value if hasattr(talep.durum, "value") else str(talep.durum),
        "olusturma_tarihi":     talep.olusturma_tarihi.isoformat() if talep.olusturma_tarihi else None,
        "gecerlilik_suresi_saat": talep.gecerlilik_suresi_saat,
        "toplam_bildirim":      len(talep.bildirimler),
        "toplam_bagis":         len(bagis_listesi),
        "bildirimler":          bildirimler,
        "bagislar":             bagis_listesi,
    }
