# app/models/institution.py
"""
Konum (İlçe/Mahalle) ve Kurum ORM modelleri.
"""
import uuid
from sqlalchemy import Column, String, Integer, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship, backref
from geoalchemy2 import Geometry
from sqlalchemy import Enum as SQLEnum

from app.models.base import Base
from app.models.enums import InstitutionTypeEnum


class District(Base):
    __tablename__ = "districts"

    district_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name        = Column(String, nullable=False, index=True)
    city_code   = Column(Integer, default=35)

    neighborhoods = relationship(
        "Neighborhood", back_populates="district", cascade="all, delete-orphan"
    )
    institutions = relationship("Institution", back_populates="district")


class Neighborhood(Base):
    __tablename__ = "neighborhoods"

    neighborhood_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    district_id     = Column(
        UUID(as_uuid=True), ForeignKey("districts.district_id"), nullable=False
    )
    name = Column(String, nullable=False, index=True)

    district     = relationship("District", back_populates="neighborhoods")
    donors       = relationship("DonorProfile", back_populates="neighborhood")
    institutions = relationship("Institution", back_populates="neighborhood")


class Institution(Base):
    __tablename__ = "institutions"

    kurum_id  = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    kurum_adi = Column(String, nullable=False, index=True)
    tipi      = Column(
        SQLEnum(InstitutionTypeEnum, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    parent_id = Column(
        UUID(as_uuid=True), ForeignKey("institutions.kurum_id"), nullable=True
    )
    konum           = Column(Geometry(geometry_type="POINT", srid=4326), nullable=False)
    district_id     = Column(UUID(as_uuid=True), ForeignKey("districts.district_id"), nullable=True)
    neighborhood_id = Column(
        UUID(as_uuid=True), ForeignKey("neighborhoods.neighborhood_id"), nullable=True
    )
    tam_adres = Column(String, nullable=False)

    donations    = relationship("DonationHistory", back_populates="institution")
    district     = relationship("District", back_populates="institutions")
    neighborhood = relationship("Neighborhood", back_populates="institutions")
    sub_units    = relationship(
        "Institution",
        backref=backref("parent", remote_side=[kurum_id]),
        cascade="all, delete-orphan",
    )
