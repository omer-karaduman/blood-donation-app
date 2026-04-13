from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, ForeignKey, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import declarative_base, relationship, backref
from geoalchemy2 import Geometry

import uuid
import enum
from datetime import datetime

Base = declarative_base()

# --- 1. ENUM TANIMLAMALARI ---

class UserRoleEnum(str, enum.Enum):
    DONOR = "donor"
    staff = "staff"
    ADMIN = "admin"

class GenderEnum(str, enum.Enum):
    E = 'E'
    K = 'K'

class BloodTypeEnum(str, enum.Enum):
    A_POS = 'A+'
    A_NEG = 'A-'
    B_POS = 'B+'
    B_NEG = 'B-'
    AB_POS = 'AB+'
    AB_NEG = 'AB-'
    O_POS = 'O+'
    O_NEG = 'O-'

class UrgencyEnum(str, enum.Enum):
    NORMAL = 'Normal'
    ACIL = 'Acil'
    AFET = 'Afet'

class RequestStatusEnum(str, enum.Enum):
    AKTIF = 'Aktif'
    TAMAMLANDI = 'Tamamlandi'
    IPTAL = 'Iptal'

class DonationResultEnum(str, enum.Enum):
    BASARILI = 'Basarili'
    REDDEDILDI = 'Reddedildi'

class NotificationDeliveryEnum(str, enum.Enum):
    BASARILI = 'Basarili'
    BASARISIZ = 'Basarisiz'

class NotificationReactionEnum(str, enum.Enum):
    BEKLIYOR = 'Bekliyor' # YENİ EKLENDİ: Bildirim ilk gittiğinde bu statüde olur
    KABUL = 'Kabul'
    RED = 'Red'
    GORMEZDEN_GELDI = 'Gormezden_Geldi'
    TAMAMLANDI = 'Tamamlandi'
    
class InstitutionTypeEnum(str, enum.Enum):
    HASTANE = 'Hastane'
    KAN_MERKEZI = 'Kan Merkezi'

# --- 2. KONUM HİYERARŞİSİ (İZMİR ÖZEL) ---

class District(Base):
    __tablename__ = "districts"
    district_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False, index=True)
    city_code = Column(Integer, default=35) # İzmir

    neighborhoods = relationship("Neighborhood", back_populates="district", cascade="all, delete-orphan")
    institutions = relationship("Institution", back_populates="district")

class Neighborhood(Base):
    __tablename__ = "neighborhoods"
    neighborhood_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    district_id = Column(UUID(as_uuid=True), ForeignKey("districts.district_id"), nullable=False)
    name = Column(String, nullable=False, index=True)

    district = relationship("District", back_populates="neighborhoods")
    donors = relationship("DonorProfile", back_populates="neighborhood")
    institutions = relationship("Institution", back_populates="neighborhood")

# --- 3. ANA KULLANICI TABLOSU ---

class User(Base):
    __tablename__ = "users"
    user_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    role = Column(SQLEnum(UserRoleEnum), nullable=False, default=UserRoleEnum.DONOR)
    is_active = Column(Boolean, default=True)
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)

    donor_profile = relationship("DonorProfile", back_populates="user", uselist=False)
    staff_profile = relationship("StaffProfile", back_populates="user", uselist=False)
    agent_logs = relationship("AgentLog", back_populates="user")
    notification_logs = relationship("NotificationLog", back_populates="user")

# --- 4. DONÖR PROFİLİ ---

class DonorProfile(Base):
    __tablename__ = "donor_profiles"
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), primary_key=True)
    ad_soyad = Column(String, nullable=False)
    telefon = Column(String, unique=True, nullable=False)
    cinsiyet = Column(SQLEnum(GenderEnum), nullable=False)
    dogum_tarihi = Column(DateTime, nullable=False)
    kilo = Column(Float, nullable=False)
    kan_grubu = Column(SQLEnum(BloodTypeEnum), nullable=False)
    son_bagis_tarihi = Column(DateTime, nullable=True)
    kan_verebilir_mi = Column(Boolean, default=True)
    fcm_token = Column(String, nullable=True)
    # Lokasyon Verileri
    konum = Column(Geometry(geometry_type='POINT', srid=4326), nullable=True)
    neighborhood_id = Column(UUID(as_uuid=True), ForeignKey("neighborhoods.neighborhood_id"), nullable=True)
    fcm_token = Column(String, nullable=True)

    # İlişkiler
    user = relationship("User", back_populates="donor_profile")
    neighborhood = relationship("Neighborhood", back_populates="donors")
    health_status = relationship("HealthStatus", back_populates="donor", uselist=False)
    ml_features = relationship("MLFeature", back_populates="donor", uselist=False)
    gamification = relationship("GamificationData", back_populates="donor", uselist=False)
    donation_history = relationship("DonationHistory", back_populates="donor")

# --- 5. HASTANE VE KURUMLAR ---

class Institution(Base):
    __tablename__ = "institutions"
    kurum_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    kurum_adi = Column(String, nullable=False, index=True)
    tipi = Column(SQLEnum(InstitutionTypeEnum), nullable=False) 
    parent_id = Column(UUID(as_uuid=True), ForeignKey("institutions.kurum_id"), nullable=True)
    
    # Konum ve Adres (İlçe string'den ID'ye çekildi)
    konum = Column(Geometry(geometry_type='POINT', srid=4326), nullable=False)
    district_id = Column(UUID(as_uuid=True), ForeignKey("districts.district_id"), nullable=True)
    neighborhood_id = Column(UUID(as_uuid=True), ForeignKey("neighborhoods.neighborhood_id"), nullable=True)
    tam_adres = Column(String, nullable=False) 

    # İlişkiler
    donations = relationship("DonationHistory", back_populates="institution")
    district = relationship("District", back_populates="institutions")
    neighborhood = relationship("Neighborhood", back_populates="institutions")
    sub_units = relationship(
        "Institution", 
        backref=backref('parent', remote_side=[kurum_id]),
        cascade="all, delete-orphan"
    )

# --- 6. DİĞER PROFİLLER VE SİSTEM TABLOLARI ---

class StaffProfile(Base):
    __tablename__ = "staff_profiles"
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), primary_key=True)
    kurum_id = Column(UUID(as_uuid=True), ForeignKey("institutions.kurum_id"))
    ad_soyad = Column(String, nullable=False)
    unvan = Column(String, nullable=True)
    personel_no = Column(String, unique=True, nullable=True)

    user = relationship("User", back_populates="staff_profile")
    institution = relationship("Institution")

class HealthStatus(Base):
    __tablename__ = "health_status"
    form_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("donor_profiles.user_id"), unique=True)
    son_dovme_tarihi = Column(DateTime, nullable=True)
    son_ameliyat_tarihi = Column(DateTime, nullable=True)
    kronik_hastalik = Column(Boolean, default=False)
    guncelleme_tarihi = Column(DateTime, default=datetime.utcnow)
    
    donor = relationship("DonorProfile", back_populates="health_status")

class BloodRequest(Base):
    __tablename__ = "blood_requests"
    talep_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    kurum_id = Column(UUID(as_uuid=True), ForeignKey("institutions.kurum_id"))
    olusturan_personel_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    istenen_kan_grubu = Column(SQLEnum(BloodTypeEnum), nullable=False)
    unite_sayisi = Column(Integer, nullable=False)
    aciliyet_durumu = Column(SQLEnum(UrgencyEnum), default=UrgencyEnum.NORMAL)
    
    # 🚀 YENİ EKLENDİ: Talebin geçerlilik süresi (Saat cinsinden, varsayılan 24 saat)
    gecerlilik_suresi_saat = Column(Integer, default=24) 
    
    durum = Column(SQLEnum(RequestStatusEnum), default=RequestStatusEnum.AKTIF)
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)

    personel = relationship("User", foreign_keys=[olusturan_personel_id])
    institution = relationship("Institution")
    bildirimler = relationship("NotificationLog", back_populates="blood_request")

class DonationHistory(Base):
    __tablename__ = "donation_history"
    bagis_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("donor_profiles.user_id"))
    kurum_id = Column(UUID(as_uuid=True), ForeignKey("institutions.kurum_id"))
    talep_id = Column(UUID(as_uuid=True), ForeignKey("blood_requests.talep_id"), nullable=True)
    bagis_tarihi = Column(DateTime, default=datetime.utcnow)
    islem_sonucu = Column(SQLEnum(DonationResultEnum), nullable=False)
    institution = relationship("Institution", back_populates="donations")
    donor = relationship("DonorProfile", back_populates="donation_history")

class MLFeature(Base):
    __tablename__ = "ml_features"
    user_id = Column(UUID(as_uuid=True), ForeignKey("donor_profiles.user_id"), primary_key=True)
    toplam_bildirim_sayisi = Column(Integer, default=0)
    olumlu_yanit_sayisi = Column(Integer, default=0)
    basarili_bagis_sayisi = Column(Integer, default=0)
    
    # YENİ EKLENDİ: None hatası almamak için varsayılan saat ataması
    tercih_edilen_saatler = Column(JSONB, default=[12, 15, 18]) 
    maks_kabul_mesafesi = Column(Float, nullable=True)
    ml_tahmin_skoru = Column(Float, default=0.0)
    
    # YENİ EKLENDİ: Modelin temel parametresi, varsayılan değer 3 (Nötr)
    duyarlilik_seviyesi = Column(Integer, default=3)

    donor = relationship("DonorProfile", back_populates="ml_features")

class GamificationData(Base):
    __tablename__ = "gamification_data"
    user_id = Column(UUID(as_uuid=True), ForeignKey("donor_profiles.user_id"), primary_key=True)
    toplam_puan = Column(Integer, default=0)
    seviye = Column(Integer, default=1)
    rozet_listesi = Column(JSONB, default=[])

    donor = relationship("DonorProfile", back_populates="gamification")

class AgentLog(Base):
    __tablename__ = "agent_logs"
    log_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"))
    kullanici_mesaji = Column(String, nullable=False)
    agent_yaniti = Column(String, nullable=False)
    islem_tarihi = Column(DateTime, default=datetime.utcnow)
    kategori = Column(String, nullable=True)

    user = relationship("User", back_populates="agent_logs")

class NotificationLog(Base):
    __tablename__ = "notification_logs"
    log_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    talep_id = Column(UUID(as_uuid=True), ForeignKey("blood_requests.talep_id"), nullable=False)
    ml_skoru_o_an = Column(Float, nullable=True) 
    gonderim_zamani = Column(DateTime, default=datetime.utcnow)
    iletilme_durumu = Column(SQLEnum(NotificationDeliveryEnum), nullable=False)
    
    # YENİ DEĞİŞTİRİLDİ: Bildirim atıldığında durumu varsayılan olarak "Bekliyor" olmalı
    kullanici_reaksiyonu = Column(SQLEnum(NotificationReactionEnum), default=NotificationReactionEnum.BEKLIYOR) 
    reaksiyon_zamani = Column(DateTime, nullable=True) 

    user = relationship("User", back_populates="notification_logs")
    blood_request = relationship("BloodRequest", back_populates="bildirimler")