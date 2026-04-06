from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List

import models
import schemas
from database import get_db

# Admin endpointleri için prefix (ön ek) tanımlıyoruz
router = APIRouter(
    prefix="/admin",
    tags=["Admin İşlemleri"]
)

@router.get("/summary")
def get_admin_summary(db: Session = Depends(get_db)):
    """Admin paneli için toplam donör ve aktif talep sayılarını döner."""
    donor_count = db.query(models.DonorProfile).count()
    active_requests = db.query(models.BloodRequest).filter(models.BloodRequest.durum == models.RequestStatusEnum.AKTIF).count()
    return {"total_donors": donor_count, "active_requests": active_requests}


@router.get("/system-logs", response_model=List[schemas.AdminRequestLogResponse])
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