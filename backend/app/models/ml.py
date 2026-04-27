# app/models/ml.py
"""
ML özellik vektörü, oyunlaştırma ve AI ajan log modelleri.
"""
import uuid
from datetime import datetime

from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship

from app.models.base import Base


class MLFeature(Base):
    __tablename__ = "ml_features"

    user_id                 = Column(UUID(as_uuid=True), ForeignKey("donor_profiles.user_id"), primary_key=True)
    toplam_bildirim_sayisi  = Column(Integer, default=0)
    olumlu_yanit_sayisi     = Column(Integer, default=0)
    basarili_bagis_sayisi   = Column(Integer, default=0)
    tercih_edilen_saatler   = Column(JSONB, default=[12, 15, 18])
    maks_kabul_mesafesi     = Column(Float, nullable=True)
    ml_tahmin_skoru         = Column(Float, default=0.0)
    duyarlilik_seviyesi     = Column(Integer, default=3)

    donor = relationship("DonorProfile", back_populates="ml_features")


class GamificationData(Base):
    __tablename__ = "gamification_data"

    user_id      = Column(UUID(as_uuid=True), ForeignKey("donor_profiles.user_id"), primary_key=True)
    toplam_puan  = Column(Integer, default=0)
    seviye       = Column(Integer, default=1)
    rozet_listesi = Column(JSONB, default=[])

    donor = relationship("DonorProfile", back_populates="gamification")


class AgentLog(Base):
    __tablename__ = "agent_logs"

    log_id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id          = Column(UUID(as_uuid=True), ForeignKey("users.user_id"))
    kullanici_mesaji = Column(String, nullable=False)
    agent_yaniti     = Column(String, nullable=False)
    islem_tarihi     = Column(DateTime, default=datetime.utcnow)
    kategori         = Column(String, nullable=True)

    user = relationship("User", back_populates="agent_logs")
