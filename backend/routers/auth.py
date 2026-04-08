from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

import models
import schemas
from database import get_db

router = APIRouter(
    prefix="/auth",
    tags=["Kimlik Doğrulama"]
)

@router.post("/login", response_model=schemas.UserResponse)
def login(login_data: schemas.LoginRequest, db: Session = Depends(get_db)):
    """
    Kullanıcı girişini doğrular ve Donör ise cihazın bildirim anahtarını (FCM Token) günceller.
    """
    # 1. Kullanıcıyı profilleriyle birlikte (Eager Loading) getiriyoruz
    user = db.query(models.User)\
             .options(
                 joinedload(models.User.donor_profile), 
                 joinedload(models.User.staff_profile)
             )\
             .filter(models.User.email == login_data.email).first()
    
    # 2. Kimlik Doğrulama Kontrolleri
    if not user or user.hashed_password != login_data.password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="E-posta veya şifre hatalı."
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Hesabınız askıya alınmıştır."
        )
        
    # =======================================================
    # AKILLI BİLDİRİM KAYDI (FCM TOKEN GÜNCELLEME)
    # =======================================================
    # Eğer giriş yapan bir donörse ve cihazından bir token geldiyse veritabanını güncelliyoruz.
    if login_data.fcm_token and user.role == models.UserRoleEnum.DONOR:
        if user.donor_profile:
            # Sadece token değişmişse commit yaparak veritabanını yormuyoruz
            if user.donor_profile.fcm_token != login_data.fcm_token:
                user.donor_profile.fcm_token = login_data.fcm_token
                try:
                    db.commit()
                    db.refresh(user)
                except Exception as e:
                    db.rollback()
                    print(f"⚠️ FCM Token güncellenirken hata oluştu: {e}")
        
    return user