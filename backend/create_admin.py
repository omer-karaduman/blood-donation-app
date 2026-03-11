from database import SessionLocal
import models
import uuid

def create_admin_user():
    db = SessionLocal()
    try:
        # Özel admin bilgileriniz
        admin_email = "a@k.com"
        admin_password = "123456" # Gerçek uygulamada hash'lenmelidir

        # Email kontrolü
        exists = db.query(models.User).filter(models.User.email == admin_email).first()
        if exists:
            print("Admin kullanıcısı zaten mevcut.")
            return

        new_admin = models.User(
            user_id=uuid.uuid4(),
            email=admin_email,
            hashed_password=admin_password,
            role=models.UserRoleEnum.ADMIN,
            is_active=True
        )
        
        db.add(new_admin)
        db.commit()
        print(f"✅ Admin kullanıcısı oluşturuldu: {admin_email}")
    finally:
        db.close()

if __name__ == "__main__":
    create_admin_user()