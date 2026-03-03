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
def get_institutions(ilce: str = None, tipi: str = None, db: Session = Depends(get_db)):
    # 1. Sorguyu başlat ve 'sub_units' (alt birimler) ilişkisini önceden yükle (Eager Loading)
    query = db.query(models.Institution).options(joinedload(models.Institution.sub_units))

    # 2. Filtreleri Uygula
    if ilce and ilce != "Tümü":
        def upper_tr(text):
            return text.replace("i", "İ").replace("ı", "I").upper()
        # Veritabanındaki 'ilce' kolonu üzerinden filtrele
        query = query.filter(models.Institution.ilce.ilike(f"%{upper_tr(ilce)}%"))
    
    if tipi and tipi != "Tümü":
        # 'Hastane' veya 'Kan Merkezi' filtrelemesi
        query = query.filter(models.Institution.tipi == tipi)

    # 3. KRİTİK NOKTA: Sadece 'Root' (Kök) kurumları döndür.
    # parent_id'si None olanlar ya bir ana hastanedir ya da bağımsız bir merkezdir.
    # Alt birimler (Child), Pydantic'in sub_units alanı sayesinde bunların içinde dönecektir.
    results = query.filter(models.Institution.parent_id == None).all()
    
    return results