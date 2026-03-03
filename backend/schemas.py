from pydantic import BaseModel, EmailStr, Field, ConfigDict
from typing import Optional
from datetime import datetime, date
from uuid import UUID
from models import GenderEnum, BloodTypeEnum, UserRoleEnum

# --- TEMEL AUTH ŞEMALARI ---

class UserBase(BaseModel):
    email: EmailStr

class UserCreateBase(UserBase):
    password: str = Field(..., min_length=6, description="Kullanıcı şifresi")

# --- DONÖR ŞEMALARI ---

class DonorCreate(UserCreateBase):
    """Mobil uygulamadan donör kaydı alırken kullanılan şema"""
    ad_soyad: str
    telefon: str
    cinsiyet: GenderEnum
    dogum_tarihi: date
    kilo: float
    kan_grubu: BloodTypeEnum
    latitude: Optional[float] = Field(None, description="Enlem")
    longitude: Optional[float] = Field(None, description="Boylam")

class UserResponse(UserBase):
    """Genel kullanıcı yanıtı (Auth sonrası)"""
    user_id: UUID
    role: UserRoleEnum
    is_active: bool
    olusturma_tarihi: datetime

    model_config = ConfigDict(from_attributes=True)

# --- PROFİL YANIT ŞEMALARI ---

class DonorProfileResponse(BaseModel):
    """Donör listesi gösterilirken kullanılan detaylı şema"""
    user_id: UUID
    ad_soyad: str
    kan_grubu: BloodTypeEnum
    kan_verebilir_mi: bool
    son_bagis_tarihi: Optional[datetime] = None
    user: UserResponse 

    model_config = ConfigDict(from_attributes=True)

# --- KURUM (HASTANE) ŞEMALARI ---
# İşte eksik olan ve hata veren kısım burasıydı:

class InstitutionBase(BaseModel):
    kurum_adi: str
    yetkili_kisi: str
    iletisim: str

class InstitutionResponse(InstitutionBase):
    """API'den dönecek olan hastane verisi şeması"""
    kurum_id: UUID # Veritabanındaki otomatik artan ID
    parent_id: Optional[UUID] = None
    model_config = ConfigDict(from_attributes=True)

# --- SAĞLIK ÇALIŞANI ŞEMALARI ---

class StaffCreate(UserCreateBase):
    """Sağlık çalışanı kaydı için"""
    ad_soyad: str
    kurum_id: UUID
    unvan: Optional[str] = None
    personel_no: Optional[str] = None

# --- GİRİŞ (LOGIN) ŞEMASI ---
class LoginRequest(BaseModel):
    email: EmailStr
    password: str