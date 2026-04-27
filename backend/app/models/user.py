# app/models/user.py
"""
Kullanıcı ve profil ORM modelleri:
  User, DonorProfile, StaffProfile, HealthStatus
"""
import uuid
from datetime import datetime

from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from sqlalchemy import Enum as SQLEnum
from geoalchemy2 import Geometry

from app.models.base import Base
from app.models.enums import UserRoleEnum, GenderEnum, BloodTypeEnum


class User(Base):
    __tablename__ = "users"

    user_id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email            = Column(String, unique=True, index=True, nullable=False)
    hashed_password  = Column(String, nullable=False)
    role             = Column(
        SQLEnum(UserRoleEnum, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=UserRoleEnum.DONOR,
    )
    is_active        = Column(Boolean, default=True)
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)

    donor_profile     = relationship("DonorProfile", back_populates="user", uselist=False)
    staff_profile     = relationship("StaffProfile",  back_populates="user", uselist=False)
    agent_logs        = relationship("AgentLog",       back_populates="user")
    notification_logs = relationship("NotificationLog", back_populates="user")


class DonorProfile(Base):
    __tablename__ = "donor_profiles"

    user_id         = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), primary_key=True)
    ad_soyad        = Column(String, nullable=False)
    telefon         = Column(String, unique=True, nullable=False)
    cinsiyet        = Column(
        SQLEnum(GenderEnum, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    dogum_tarihi    = Column(DateTime, nullable=False)
    kilo            = Column(Float, nullable=False)
    kan_grubu       = Column(
        SQLEnum(BloodTypeEnum, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    son_bagis_tarihi  = Column(DateTime, nullable=True)
    kan_verebilir_mi  = Column(Boolean, default=True)
    konum             = Column(Geometry(geometry_type="POINT", srid=4326), nullable=True)
    neighborhood_id   = Column(
        UUID(as_uuid=True), ForeignKey("neighborhoods.neighborhood_id"), nullable=True
    )
    fcm_token = Column(String, nullable=True)

    user             = relationship("User",            back_populates="donor_profile")
    neighborhood     = relationship("Neighborhood",    back_populates="donors")
    health_status    = relationship("HealthStatus",    back_populates="donor", uselist=False)
    ml_features      = relationship("MLFeature",       back_populates="donor", uselist=False)
    gamification     = relationship("GamificationData", back_populates="donor", uselist=False)
    donation_history = relationship("DonationHistory", back_populates="donor")


class StaffProfile(Base):
    __tablename__ = "staff_profiles"

    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), primary_key=True)
    kurum_id   = Column(UUID(as_uuid=True), ForeignKey("institutions.kurum_id"))
    ad_soyad   = Column(String, nullable=False)
    unvan      = Column(String, nullable=True)
    personel_no = Column(String, unique=True, nullable=True)

    user        = relationship("User",        back_populates="staff_profile")
    institution = relationship("Institution")


class HealthStatus(Base):
    __tablename__ = "health_status"

    form_id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id             = Column(UUID(as_uuid=True), ForeignKey("donor_profiles.user_id"), unique=True)
    son_dovme_tarihi    = Column(DateTime, nullable=True)
    son_ameliyat_tarihi = Column(DateTime, nullable=True)
    kronik_hastalik     = Column(Boolean, default=False)
    guncelleme_tarihi   = Column(DateTime, default=datetime.utcnow)

    donor = relationship("DonorProfile", back_populates="health_status")
