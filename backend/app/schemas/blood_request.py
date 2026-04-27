# app/schemas/blood_request.py
from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime
from uuid import UUID
from app.models.enums import BloodTypeEnum, UrgencyEnum, RequestStatusEnum, NotificationReactionEnum


class BloodRequestCreate(BaseModel):
    """
    Kan talebi oluşturma şeması.
    """
    istenen_kan_grubu:      BloodTypeEnum
    unite_sayisi:           int
    aciliyet_durumu:        UrgencyEnum = UrgencyEnum.NORMAL
    gecerlilik_suresi_saat: int = 24

    model_config = ConfigDict(populate_by_name=True)


class DonorReactionSummary(BaseModel):
    log_id:           str
    donor_ad_soyad:   str
    reaksiyon:        str
    reaksiyon_zamani: Optional[str] = None
    ml_score:         float = 0.0
    model_config = ConfigDict(from_attributes=True)


class BloodRequestDetailResponse(BaseModel):
    talep_id:               str
    istenen_kan_grubu:      str
    unite_sayisi:           int
    durum:                  str
    olusturma_tarihi:       str
    gecerlilik_suresi_saat: int
    aciliyet_durumu:        str
    donor_yanitlari:        List[DonorReactionSummary] = []
    model_config = ConfigDict(from_attributes=True)


class AdminRequestLogResponse(BaseModel):
    talep_id:              UUID
    kurum_adi:             str
    staff_ad_soyad:        str
    olusturma_tarihi:      datetime
    istenen_kan_grubu:     BloodTypeEnum
    onerilen_donor_sayisi: int
    model_config = ConfigDict(from_attributes=True)
