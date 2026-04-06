# routers/users.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import uuid
import models
from database import get_db

router = APIRouter(
    prefix="/users",
    tags=["Kullanıcı Profili"]
)

@router.get("/{user_id}/profile")
def get_user_profile_data(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Kullanıcının id'sine göre güncel Ad, Soyad, Kan Grubu veya Unvan bilgilerini döner."""
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Kullanıcı bulunamadı")
    
    if user.role.name == "DONOR" and user.donor_profile:
        return {
            "ad_soyad": user.donor_profile.ad_soyad,
            "kan_grubu": user.donor_profile.kan_grubu,
            "mahalle": user.donor_profile.neighborhood.name if user.donor_profile.neighborhood else "Belirtilmemiş"
        }
    
    elif user.role.name == "staff" and user.staff_profile:
        return {
            "ad_soyad": user.staff_profile.ad_soyad,
            "unvan": user.staff_profile.unvan,
            "personel_no": user.staff_profile.personel_no,
            "kurum_adi": user.staff_profile.institution.kurum_adi if user.staff_profile.institution else "Bilinmiyor"
        }
    
    return {"ad_soyad": "Sistem Yöneticisi", "kan_grubu": "-"}