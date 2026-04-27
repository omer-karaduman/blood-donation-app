# app/schemas/location.py
from pydantic import BaseModel, ConfigDict
from typing import Optional
from uuid import UUID


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
