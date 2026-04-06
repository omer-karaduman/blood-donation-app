from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session, joinedload
from geoalchemy2.elements import WKTElement
from typing import List
import uuid

import models
import schemas
from database import get_db

# Hastane/Kurum endpointleri için prefix (ön ek) tanımlıyoruz
router = APIRouter(
    prefix="/institutions",
    tags=["Kurum ve Hastane İşlemleri"]
)

@router.get("/", response_model=List[schemas.InstitutionResponse])
def get_institutions(district_id: uuid.UUID = None, tipi: models.InstitutionTypeEnum = None, db: Session = Depends(get_db)):
    """Kurumları ilçe ID'si veya tipine (Hastane / Kan Merkezi) göre filtreler."""
    query = db.query(models.Institution).options(
        joinedload(models.Institution.district),
        joinedload(models.Institution.neighborhood)
    )
    if district_id:
        query = query.filter(models.Institution.district_id == district_id)
    if tipi:
        query = query.filter(models.Institution.tipi == tipi)
    return query.all()


@router.post("/", response_model=schemas.InstitutionResponse)
def create_institution(inst_in: schemas.InstitutionCreate, db: Session = Depends(get_db)):
    """Adminin yeni bir hastane veya kan merkezi eklemesini sağlar (PostGIS İlişkisel konumla)."""
    new_inst = models.Institution(
        kurum_adi=inst_in.kurum_adi,
        tipi=inst_in.tipi,
        district_id=inst_in.district_id,
        neighborhood_id=inst_in.neighborhood_id,
        tam_adres=inst_in.tam_adres,
        parent_id=inst_in.parent_id
    )
    
    # Harita koordinatları geldiyse PostGIS Geometry objesine çevir
    if inst_in.latitude is not None and inst_in.longitude is not None:
        new_inst.konum = WKTElement(f"POINT({inst_in.longitude} {inst_in.latitude})", srid=4326)

    db.add(new_inst)
    db.commit()
    db.refresh(new_inst)
    return new_inst


@router.get("/{institution_id}/staff")
def get_institution_staff(institution_id: uuid.UUID, db: Session = Depends(get_db)):
    """Sadece belirli bir kuruma (hastaneye) kayıtlı personelleri listeler."""
    staff_list = db.query(models.StaffProfile).filter(models.StaffProfile.kurum_id == institution_id).all()
    result = []
    for s in staff_list:
        result.append({
            "user_id": str(s.user_id),
            "ad_soyad": s.ad_soyad or "İsimsiz Personel",
            "unvan": s.unvan or "Belirtilmemiş",
            "personel_no": s.personel_no,
            "email": s.user.email if s.user else "Bilinmiyor",
            "is_active": s.user.is_active if s.user else False,
            "kurum_adi": s.institution.kurum_adi if s.institution else "Bilinmiyor"
        })
    return result