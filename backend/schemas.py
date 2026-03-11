from pydantic import BaseModel, EmailStr, Field, ConfigDict
from typing import Optional, List # List ekledik
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

# --- TEMEL AUTH ŞEMALARI ---

class UserBase(BaseModel):
    email: EmailStr

class UserCreateBase(UserBase):
    password: str = Field(..., min_length=6, description="Kullanıcı şifresi")

class UserResponse(UserBase):
    """Genel kullanıcı yanıtı (Auth sonrası)"""
    user_id: UUID
    role: UserRoleEnum
    is_active: bool
    olusturma_tarihi: datetime
    model_config = ConfigDict(from_attributes=True)

# --- DONÖR ŞEMALARI ---

class DonorCreate(UserCreateBase):
    """Mobil uygulamadan donör kaydı alırken kullanılan şema"""
    ad_soyad: str
    telefon: str
    cinsiyet: GenderEnum
    dogum_tarihi: date
    kilo: float
    kan_grubu: BloodTypeEnum
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class DonorProfileResponse(BaseModel):
    user_id: UUID
    ad_soyad: str
    kan_grubu: BloodTypeEnum
    kan_verebilir_mi: bool
    son_bagis_tarihi: Optional[datetime] = None
    user: UserResponse 
    model_config = ConfigDict(from_attributes=True)

# --- KURUM (HASTANE & KAN MERKEZİ) ŞEMALARI ---

class InstitutionBase(BaseModel):
    kurum_adi: str
    tipi: str           # 'Hastane' veya 'Kan Merkezi'
    ilce: str           # İzmir'in ilçesi
    tam_adres: str      # İletişim yerine tam adres eklendi

class InstitutionResponse(InstitutionBase):
    kurum_id: UUID
    parent_id: Optional[UUID] = None
    
    # KRİTİK GÜNCELLEME: Özyinelemeli (Recursive) yapı
    # Tırnak içinde "InstitutionResponse" yazarak modelin henüz tanımlanma 
    # aşamasında olduğunu Pydantic'e bildiriyoruz.
    sub_units: List["InstitutionResponse"] = [] 
    
    model_config = ConfigDict(from_attributes=True)

# --- SAĞLIK ÇALIŞANI ŞEMALARI ---

class StaffCreate(UserCreateBase):
    ad_soyad: str
    kurum_id: UUID
    unvan: Optional[str] = "Doktor"
    personel_no: Optional[str] = None

# --- GİRİŞ (LOGIN) ŞEMASI ---

class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class BloodRequestCreate(BaseModel):
    """Staff'ın sadece ihtiyacı girdiği şema"""
    istenen_kan_grubu: BloodTypeEnum
    unite_sayisi: int
    aciliyet_durumu: UrgencyEnum = UrgencyEnum.NORMAL

class DonorReactionSummary(BaseModel):
    """Staff'ın 'Kimler geliyor?' listesinde göreceği veri"""
    donor_ad_soyad: str
    reaksiyon: NotificationReactionEnum
    reaksiyon_zamani: Optional[datetime]
    model_config = ConfigDict(from_attributes=True)

class BloodRequestDetailResponse(BaseModel):
    """Staff'ın kendi talebini ve donör yanıtlarını izleyeceği şema"""
    talep_id: UUID
    istenen_kan_grubu: BloodTypeEnum
    unite_sayisi: int
    durum: RequestStatusEnum
    olusturma_tarihi: datetime
    # Donörlerin verdiği yanıtların listesi
    donor_yanitlari: List[DonorReactionSummary] = []
    model_config = ConfigDict(from_attributes=True)

class AdminRequestLogResponse(BaseModel):
    """Admin'in sistemdeki tüm trafiği izleyeceği şema"""
    talep_id: UUID
    kurum_adi: str
    staff_ad_soyad: str
    olusturma_tarihi: datetime
    istenen_kan_grubu: BloodTypeEnum
    # ML modelinin önerdiği donör sayısı ve başarı durumu
    onerilen_donor_sayisi: int
    model_config = ConfigDict(from_attributes=True)



class InstitutionCreate(BaseModel):
    kurum_adi: str
    tipi: InstitutionTypeEnum
    ilce: str
    tam_adres: str
    latitude: float  # Verideki ENLEM
    longitude: float # Verideki BOYLAM
    parent_id: Optional[UUID] = None

    model_config = ConfigDict(from_attributes=True)