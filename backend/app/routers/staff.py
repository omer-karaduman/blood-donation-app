# app/routers/staff.py
"""
Personel CRUD işlemleri.
Kan talebi/ML işlemleri app/routers/blood_requests.py dosyasına ayrıldı.
"""
import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.database import get_db

router = APIRouter(prefix="/staff", tags=["Personel Yönetimi"])


@router.get("/")
def get_all_staff(db: Session = Depends(get_db)):
    """Tüm personeli listeler."""
    return [
        {
            "user_id":    str(s.user_id),
            "ad_soyad":  s.ad_soyad or "İsimsiz Personel",
            "unvan":     s.unvan or "Belirtilmemiş",
            "personel_no": s.personel_no,
            "email":     s.user.email if s.user else "Bilinmiyor",
            "is_active": s.user.is_active if s.user else False,
            "kurum_id":  str(s.kurum_id) if s.kurum_id else None,
            "kurum_adi": s.institution.kurum_adi if s.institution else "Bilinmiyor",
        }
        for s in db.query(models.StaffProfile).all()
    ]


@router.post("/", response_model=schemas.UserResponse)
def create_staff(staff_in: schemas.StaffCreate, db: Session = Depends(get_db)):
    """Yeni sağlık personeli kaydı oluşturur."""
    if db.query(models.User).filter(models.User.email == staff_in.email).first():
        raise HTTPException(status_code=400, detail="Email kullanımda.")

    new_user = models.User(
        email=staff_in.email,
        hashed_password=staff_in.password,
        role=models.UserRoleEnum.staff,
    )
    db.add(new_user)
    db.flush()

    db.add(
        models.StaffProfile(
            user_id=new_user.user_id,
            kurum_id=staff_in.kurum_id,
            ad_soyad=staff_in.ad_soyad,
            unvan=staff_in.unvan,
            personel_no=staff_in.personel_no,
        )
    )
    db.commit()
    db.refresh(new_user)
    return new_user


@router.put("/{user_id}")
def update_staff(user_id: uuid.UUID, update_data: dict, db: Session = Depends(get_db)):
    """Personel bilgilerini günceller."""
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == user_id).first()
    user  = db.query(models.User).filter(models.User.user_id == user_id).first()

    if not staff or not user:
        raise HTTPException(status_code=404, detail="Personel bulunamadı.")

    if "ad_soyad"  in update_data: staff.ad_soyad  = update_data["ad_soyad"]
    if "email"     in update_data: user.email      = update_data["email"]
    if "kurum_id"  in update_data and update_data["kurum_id"]:
        staff.kurum_id = update_data["kurum_id"]
    if "unvan"     in update_data: staff.unvan     = update_data["unvan"]
    if "is_active" in update_data: user.is_active  = update_data["is_active"]
    if "password"  in update_data and update_data["password"]:
        user.hashed_password = update_data["password"]

    db.commit()
    return {"message": "Personel başarıyla güncellendi."}


@router.delete("/{user_id}")
def delete_staff(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Personeli sistemden siler."""
    staff = db.query(models.StaffProfile).filter(models.StaffProfile.user_id == user_id).first()
    user  = db.query(models.User).filter(models.User.user_id == user_id).first()
    if staff: db.delete(staff)
    if user:  db.delete(user)
    db.commit()
    return {"message": "Silindi."}
