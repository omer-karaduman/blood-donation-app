# app/routers/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from app import models, schemas
from app.database import get_db

router = APIRouter(prefix="/auth", tags=["Kimlik Doğrulama"])


@router.post("/login", response_model=schemas.UserResponse)
def login(login_data: schemas.LoginRequest, db: Session = Depends(get_db)):
    """
    Kullanıcı girişini doğrular.
    Donör ise cihazın FCM token'ını günceller.
    """
    user = (
        db.query(models.User)
        .options(
            joinedload(models.User.donor_profile),
            joinedload(models.User.staff_profile),
        )
        .filter(models.User.email == login_data.email)
        .first()
    )

    if not user or user.hashed_password != login_data.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-posta veya şifre hatalı.",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Hesabınız askıya alınmıştır.",
        )

    # FCM Token güncelleme (sadece donörler için)
    if login_data.fcm_token and user.role == models.UserRoleEnum.DONOR:
        if user.donor_profile and user.donor_profile.fcm_token != login_data.fcm_token:
            user.donor_profile.fcm_token = login_data.fcm_token
            try:
                db.commit()
                db.refresh(user)
            except Exception as e:
                db.rollback()
                print(f"⚠️ FCM Token güncellenirken hata: {e}")

    return user
