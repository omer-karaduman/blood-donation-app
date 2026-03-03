from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session, joinedload
from geoalchemy2.elements import WKTElement
import models
import schemas
from database import engine, SessionLocal

# Tabloları oluştur
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Blood Donation AI API - V2")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Tüm kaynaklara izin ver (Test aşaması için ferah bir çözüm)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def read_root():
    return {"status": "Online", "message": "Bileşim Mimarisi (User + Profile) aktif."}

# --- YENİ KAYIT MANTIĞI ---
@app.post("/register/donor/", response_model=schemas.UserResponse)
def register_donor(user_in: schemas.DonorCreate, db: Session = Depends(get_db)):
    # 1. Email kontrolü (Auth tablosu için)
    db_user = db.query(models.User).filter(models.User.email == user_in.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Bu email adresi zaten kullanımda.")

    # 2. Ana Kullanıcıyı (Auth) Oluştur
    new_user = models.User(
        email=user_in.email,
        hashed_password=user_in.password, # Gerçekte passlib ile hash'lenmeli
        role=models.UserRoleEnum.DONOR
    )
    db.add(new_user)
    db.flush() # user_id'yi almak için veritabanına gönder ama henüz commit etme

    # 3. Donör Profilini Oluştur
    donor_data = user_in.model_dump(exclude={"email", "password", "latitude", "longitude"})
    new_profile = models.DonorProfile(
        user_id=new_user.user_id,
        **donor_data
    )

    # Konum verisi varsa PostGIS formatına çevir
    if user_in.latitude is not None and user_in.longitude is not None:
        new_profile.konum = WKTElement(f"POINT({user_in.longitude} {user_in.latitude})", srid=4326)

    db.add(new_profile)
    db.commit()
    db.refresh(new_user)
    return new_user

# --- MOBİL UYGULAMA İÇİN DONÖR LİSTESİ ---
@app.get("/donors/", response_model=list[schemas.DonorProfileResponse])
def get_donor_list(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    # DonorProfile tablosunu User tablosuyla birleştirerek getiriyoruz (Joined Load)
    return db.query(models.DonorProfile).options(joinedload(models.DonorProfile.user)).offset(skip).limit(limit).all()

@app.get("/institutions/", response_model=list[schemas.InstitutionResponse])
def get_institutions(ilce: str = None, db: Session = Depends(get_db)):
    query = db.query(models.Institution)
    
    # Filtreleme: "Tümü" seçili değilse ilçe bazlı süz
    if ilce and ilce != "Tümü":
        query = query.filter(models.Institution.iletisim.ilike(f"%{ilce}%"))
    
    raw_results = query.all()
    cleaned_data = {}

    for r in raw_results:
        # 1. Kök İsim (Örn: Ege Üniversitesi)
        words = r.kurum_adi.split()
        root_name = " ".join(words[:2]).strip() if len(words) >= 2 else r.kurum_adi
        
        # 2. İlçe Ayıklama (Daha sağlam: '/' yoksa tüm adresi alıp temizle)
        # Ödemiş ve Bornova'yı birbirinden ayırmak için .upper() kullanıyoruz
        if '/' in r.iletisim:
            current_district = r.iletisim.split('/')[0].strip().upper()
        else:
            # Eğer format farklıysa iletişim bilgisinden ilçe listemizdeki kelimeleri ara
            current_district = "IZMIR" 
        
        # 3. BENZERSİZ ANAHTAR: "Kök İsim + İlçe"
        # Bu sayede 'EGE ÜNİVERSİTESİ_BORNOVA' ve 'EGE ÜNİVERSİTESİ_ÖDEMİŞ' ayrı iki kayıt olur.
        unique_key = f"{root_name.upper()}_{current_district}"
        
        if unique_key not in cleaned_data:
            cleaned_data[unique_key] = r

    return list(cleaned_data.values())