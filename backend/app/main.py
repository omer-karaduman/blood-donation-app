# app/main.py
"""
FastAPI uygulama factory.
Tüm router'ları bağlar, CORS ve DB hazırlığını yapar.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.config import APP_TITLE, APP_VERSION, APP_DESC
from app.database import engine
from app import models  # Tüm ORM modelleri __init__ üzerinden gelir

from app.routers import (
    auth,
    users,
    donors,
    staff,
    blood_requests,
    institutions,
    locations,
    admin,
    ai_agent,
)

# ── PostGIS & Tablo Oluşturma ─────────────────────────────────────────────────
with engine.connect() as conn:
    conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis;"))
    conn.commit()

models.Base.metadata.create_all(bind=engine)

# ── Uygulama ──────────────────────────────────────────────────────────────────
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

app = FastAPI(title=APP_TITLE, version=APP_VERSION, description=APP_DESC)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    print(f"[422 VALIDATION ERROR] URL: {request.url}")
    print(f"[422 VALIDATION ERROR] Errors: {exc.errors()}")
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors()},
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Router'lar ────────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(donors.router)
app.include_router(staff.router)
app.include_router(blood_requests.router)   # /staff/requests* (API uyumlu)
app.include_router(institutions.router)
app.include_router(locations.router)
app.include_router(admin.router)
app.include_router(ai_agent.router)


@app.get("/", tags=["Root"])
def read_root():
    return {
        "status":  "Online",
        "message": "Akıllı Kan Bağışı Sistemi — Kurumsal Mimari ile Aktif.",
        "docs":    "/docs",
        "version": APP_VERSION,
    }
