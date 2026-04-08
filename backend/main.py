from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text # Hatayı çözmek için eklendi
import models
from database import engine

# ROUTER'LARIN İÇERİ AKTARILMASI
from routers import admin, auth, donors, institutions, locations, staff, users

# ======================================================================
# --- VERİTABANI ÖN HAZIRLIK (PostGIS Entegrasyonu) ---
# ======================================================================
# Konum (geometry) hatasını çözmek için PostGIS eklentisini aktif ediyoruz
with engine.connect() as conn:
    conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis;"))
    conn.commit()

# Veritabanı tablolarını şimdi güvenle otomatik oluşturabiliriz
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Blood Donation AI API - V7 (Modular)",
    description="Akıllı Kan Bağışı Sistemi - Modüler Mimarili Arka Yüz",
    version="7.0.1"
)

# CORS Ayarları: Mobil ve Web erişimi için tüm kaynaklara izin veriliyor
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ======================================================================
# --- ROUTER ENTEGRASYONLARI (Modülleri Uygulamaya Bağla) ---
# ======================================================================
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(donors.router)
app.include_router(staff.router)
app.include_router(admin.router)
app.include_router(institutions.router)
app.include_router(locations.router)

@app.get("/", tags=["Root"])
def read_root():
    return {
        "status": "Online", 
        "message": "Akıllı Kan Bağışı Sistemi Modüler Mimari ile Aktif.",
        "docs": "/docs"
    }