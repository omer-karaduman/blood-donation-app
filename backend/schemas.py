from pydantic import BaseModel, EmailStr, Field, ConfigDict
from typing import Optional, List
from datetime import datetime, date
from uuid import UUID
from models import (
    UserRoleEnum, 
    GenderEnum, 
    BloodTypeEnum, 
    UrgencyEnum, 
    RequestStatusEnum, 
    NotificationReactionEnum,
    InstitutionTypeEnum
)

# --- 1. KONUM ŞEMALARI (YENİ) ---

class DistrictResponse(BaseModel):
    district_id: UUID
    name: str
    city_code: int
    model_config = ConfigDict(from_attributes=True)

class NeighborhoodResponse(BaseModel):
    neighborhood_id: UUID
    district_id: UUID
    name: str
    district: Optional[DistrictResponse] = None
    model_config = ConfigDict(from_attributes=True)

# --- 2. TEMEL AUTH ŞEMALARI ---

class UserBase(BaseModel):
    email: EmailStr

class UserCreateBase(UserBase):
    password: str = Field(..., min_length=6, description="Kullanıcı şifresi")

class UserResponse(UserBase):
    user_id: UUID
    role: UserRoleEnum
    is_active: bool
    olusturma_tarihi: datetime
    model_config = ConfigDict(from_attributes=True)

# --- 3. DONÖR ŞEMALARI ---

class DonorCreate(UserCreateBase):
    """Mobil uygulamadan donör kaydı alırken kullanılan şema"""
    ad_soyad: str
    telefon: str
    cinsiyet: GenderEnum
    dogum_tarihi: date
    kilo: float
    kan_grubu: BloodTypeEnum
    # İlişkisel Konum:
    neighborhood_id: Optional[UUID] = None 
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class DonorProfileResponse(BaseModel):
    user_id: UUID
    ad_soyad: str
    telefon: str  # YENİ EKLENDİ
    kilo: float   # YENİ EKLENDİ
    kan_grubu: BloodTypeEnum
    kan_verebilir_mi: bool
    son_bagis_tarihi: Optional[datetime] = None
    neighborhood: Optional[NeighborhoodResponse] = None
    user: UserResponse 
    model_config = ConfigDict(from_attributes=True)

# --- 4. KURUM (HASTANE & KAN MERKEZİ) ŞEMALARI ---

class InstitutionBase(BaseModel):
    kurum_adi: str
    tipi: InstitutionTypeEnum
    tam_adres: str

class InstitutionCreate(InstitutionBase):
    # String 'ilce' yerine veritabanı ID'leri geldi
    district_id: UUID
    neighborhood_id: UUID
    latitude: float  # Verideki ENLEM
    longitude: float # Verideki BOYLAM
    parent_id: Optional[UUID] = None

class InstitutionResponse(InstitutionBase):
    kurum_id: UUID
    parent_id: Optional[UUID] = None
    # İlişkisel veriler
    district: Optional[DistrictResponse] = None
    neighborhood: Optional[NeighborhoodResponse] = None
    
    # Özyinelemeli (Recursive) yapı
    sub_units: List["InstitutionResponse"] = [] 
    
    model_config = ConfigDict(from_attributes=True)

# --- 5. SAĞLIK ÇALIŞANI ŞEMALARI ---

class StaffCreate(UserCreateBase):
    ad_soyad: str
    kurum_id: UUID
    unvan: Optional[str] = "Personel"
    personel_no: Optional[str] = None

# --- 6. GİRİŞ VE İŞLEM ŞEMALARI ---

class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    fcm_token: Optional[str] = None

    
class BloodRequestCreate(BaseModel):
    istenen_kan_grubu: BloodTypeEnum
    unite_sayisi: int
    aciliyet_durumu: UrgencyEnum = UrgencyEnum.NORMAL
    gecerlilik_suresi_saat: int = 24

class DonorReactionSummary(BaseModel):
    donor_ad_soyad: str
    reaksiyon: NotificationReactionEnum
    reaksiyon_zamani: Optional[datetime]
    model_config = ConfigDict(from_attributes=True)

class BloodRequestDetailResponse(BaseModel):
    talep_id: UUID
    istenen_kan_grubu: BloodTypeEnum
    unite_sayisi: int
    durum: RequestStatusEnum
    olusturma_tarihi: datetime
    donor_yanitlari: List[DonorReactionSummary] = []
    model_config = ConfigDict(from_attributes=True)

class AdminRequestLogResponse(BaseModel):
    talep_id: UUID
    kurum_adi: str
    staff_ad_soyad: str
    olusturma_tarihi: datetime
    istenen_kan_grubu: BloodTypeEnum
    onerilen_donor_sayisi: int
    model_config = ConfigDict(from_attributes=True)

# ==========================================================
# --- 7. YENİ EKLENEN: DONÖR FEED (BİLDİRİM EKRANI) ŞEMASI
# ==========================================================
class DonorFeedResponse(BaseModel):
    """Donörün mobil uygulamada göreceği 'Bana Gelen Kan Talepleri' kartı"""
    log_id: UUID
    talep_id: UUID
    kurum_adi: str
    ilce: str
    mahalle: str
    istenen_kan_grubu: BloodTypeEnum
    unite_sayisi: int
    aciliyet_durumu: UrgencyEnum
    olusturma_tarihi: datetime
    # 🚀 YENİ: Donöre süreyi gönderiyoruz ki Flutter'da geri sayım sayacı yapalım
    gecerlilik_suresi_saat: int 
    model_config = ConfigDict(from_attributes=True)