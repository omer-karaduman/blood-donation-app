# app/schemas/institution.py
from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from uuid import UUID
from app.models.enums import InstitutionTypeEnum
from app.schemas.location import DistrictResponse, NeighborhoodResponse


class InstitutionBase(BaseModel):
    kurum_adi: str
    tipi:      InstitutionTypeEnum
    tam_adres: str


class InstitutionCreate(InstitutionBase):
    district_id:     UUID
    neighborhood_id: UUID
    latitude:        float
    longitude:       float
    parent_id:       Optional[UUID] = None


class InstitutionResponse(InstitutionBase):
    kurum_id:    UUID
    parent_id:   Optional[UUID] = None
    district:    Optional[DistrictResponse] = None
    neighborhood: Optional[NeighborhoodResponse] = None
    sub_units:   List["InstitutionResponse"] = []
    model_config = ConfigDict(from_attributes=True)
