from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
import uuid

import models
import schemas
from database import get_db

# Lokasyon endpointleri için prefix (ön ek) tanımlıyoruz
router = APIRouter(
    prefix="/locations",
    tags=["Lokasyon İşlemleri (İlçe ve Mahalleler)"]
)

@router.get("/districts", response_model=List[schemas.DistrictResponse])
def get_districts(db: Session = Depends(get_db)):
    """İzmir'in tüm ilçelerini listeler."""
    return db.query(models.District).order_by(models.District.name).all()


@router.get("/districts/{district_id}/neighborhoods", response_model=List[schemas.NeighborhoodResponse])
def get_neighborhoods(district_id: uuid.UUID, db: Session = Depends(get_db)):
    """Seçilen ilçeye ait mahalleleri listeler."""
    return db.query(models.Neighborhood).filter(
        models.Neighborhood.district_id == district_id
    ).order_by(models.Neighborhood.name).all()