# app/models/blood_request.py
"""
Kan talebi, bağış geçmişi ve bildirim log ORM modelleri.
"""
import uuid
from datetime import datetime

from sqlalchemy import Column, Integer, Float, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy import Enum as SQLEnum

from app.models.base import Base
from app.models.enums import (
    BloodTypeEnum,
    UrgencyEnum,
    RequestStatusEnum,
    DonationResultEnum,
    NotificationDeliveryEnum,
    NotificationReactionEnum,
)


class BloodRequest(Base):
    __tablename__ = "blood_requests"

    talep_id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    kurum_id              = Column(UUID(as_uuid=True), ForeignKey("institutions.kurum_id"))
    olusturan_personel_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    istenen_kan_grubu     = Column(
        SQLEnum(BloodTypeEnum, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    unite_sayisi          = Column(Integer, nullable=False)
    aciliyet_durumu       = Column(
        SQLEnum(UrgencyEnum, values_callable=lambda x: [e.value for e in x]),
        default=UrgencyEnum.NORMAL,
    )
    gecerlilik_suresi_saat = Column(Integer, default=24)
    durum                  = Column(
        SQLEnum(RequestStatusEnum, values_callable=lambda x: [e.value for e in x]),
        default=RequestStatusEnum.AKTIF,
    )
    olusturma_tarihi = Column(DateTime, default=datetime.utcnow)

    personel    = relationship("User",        foreign_keys=[olusturan_personel_id])
    institution = relationship("Institution")
    bildirimler = relationship("NotificationLog", back_populates="blood_request")


class DonationHistory(Base):
    __tablename__ = "donation_history"

    bagis_id     = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id      = Column(UUID(as_uuid=True), ForeignKey("donor_profiles.user_id"))
    kurum_id     = Column(UUID(as_uuid=True), ForeignKey("institutions.kurum_id"))
    talep_id     = Column(UUID(as_uuid=True), ForeignKey("blood_requests.talep_id"), nullable=True)
    bagis_tarihi = Column(DateTime, default=datetime.utcnow)
    islem_sonucu = Column(
        SQLEnum(DonationResultEnum, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )

    institution = relationship("Institution", back_populates="donations")
    donor       = relationship("DonorProfile", back_populates="donation_history")


class NotificationLog(Base):
    __tablename__ = "notification_logs"

    log_id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id           = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    talep_id          = Column(UUID(as_uuid=True), ForeignKey("blood_requests.talep_id"), nullable=False)
    ml_skoru_o_an     = Column(Float, nullable=True)
    gonderim_zamani   = Column(DateTime, default=datetime.utcnow)
    iletilme_durumu   = Column(
        SQLEnum(NotificationDeliveryEnum, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    kullanici_reaksiyonu = Column(
        SQLEnum(NotificationReactionEnum, values_callable=lambda x: [e.value for e in x]),
        default=NotificationReactionEnum.BEKLIYOR,
    )
    reaksiyon_zamani = Column(DateTime, nullable=True)

    user         = relationship("User",         back_populates="notification_logs")
    blood_request = relationship("BloodRequest", back_populates="bildirimler")
