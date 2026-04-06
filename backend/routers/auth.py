from fastapi import APIRouter, Depends, HTTPException
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
    """Kullanıcı e-posta ve şifresini doğrular, rol bilgisini döner."""
    user = db.query(models.User)\
             .options(joinedload(models.User.donor_profile), joinedload(models.User.staff_profile))\
             .filter(models.User.email == login_data.email).first()
    
    if not user or user.hashed_password != login_data.password:
        raise HTTPException(status_code=401, detail="E-posta veya şifre hatalı.")
    
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Hesabınız askıya alınmıştır.")
        
    return user