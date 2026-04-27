# app/schemas/donor.py
from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime, date
from uuid import UUID
from app.models.enums import GenderEnum, BloodTypeEnum, UrgencyEnum
from app.schemas.auth import UserCreateBase, UserResponse
from app.schemas.location import NeighborhoodResponse


class DonorCreate(UserCreateBase):
    """Mobil uygulamadan donör kaydı alırken kullanılan şema."""
    ad_soyad:        str
    telefon:         str
    cinsiyet:        GenderEnum
    dogum_tarihi:    date
    kilo:            float
    kan_grubu:       BloodTypeEnum
    neighborhood_id: Optional[UUID] = None
    latitude:        Optional[float] = None
    longitude:       Optional[float] = None


class DonorProfileResponse(BaseModel):
    user_id:         UUID
    ad_soyad:        str
    telefon:         str
    kilo:            float
    cinsiyet:        GenderEnum
    kan_grubu:       BloodTypeEnum
    kan_verebilir_mi: bool
    son_bagis_tarihi: Optional[datetime] = None
    neighborhood:    Optional[NeighborhoodResponse] = None
    user:            UserResponse
    model_config = ConfigDict(from_attributes=True)


class DonorFeedResponse(BaseModel):
    """Donörün mobil uygulamada göreceği kan talebi kartı."""
    log_id:               UUID
    talep_id:             UUID
    kurum_adi:            str
    ilce:                 str
    mahalle:              str
    istenen_kan_grubu:    BloodTypeEnum
    unite_sayisi:         int
    aciliyet_durumu:      UrgencyEnum
    olusturma_tarihi:     datetime
    gecerlilik_suresi_saat: int
    model_config = ConfigDict(from_attributes=True)
