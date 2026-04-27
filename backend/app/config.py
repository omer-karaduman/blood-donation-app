# app/config.py
"""
Uygulama genelindeki yapılandırma ayarları.
Ortam değişkenlerini .env dosyasından okur.
"""
import os
from dotenv import load_dotenv

load_dotenv()

# ── Veritabanı ────────────────────────────────────────────────────────────────
DATABASE_URL: str = os.getenv(
    "DATABASE_URL",
    "postgresql://admin:password123@localhost:5433/blood_donation"
)

# ── Firebase ──────────────────────────────────────────────────────────────────
FIREBASE_DATABASE_URL: str = os.getenv("FIREBASE_DATABASE_URL", "")

# ── ML Model Yolları ──────────────────────────────────────────────────────────
BASE_DIR: str = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ML_MODELS_DIR: str = os.path.join(BASE_DIR, "app", "ml_models")
ML_MODEL_PATH: str = os.path.join(ML_MODELS_DIR, "donor_rf_model.pkl")
ML_SCALER_PATH: str = os.path.join(ML_MODELS_DIR, "scaler.pkl")

# ── Firebase Anahtar Dosyası ───────────────────────────────────────────────────
FIREBASE_KEY_RENDER: str = "/etc/secrets/serviceAccountKey.json"
FIREBASE_KEY_LOCAL: str  = os.path.join(BASE_DIR, "serviceAccountKey.json")

# ── API & Uygulama ────────────────────────────────────────────────────────────
APP_TITLE: str   = "Blood Donation AI API"
APP_VERSION: str = "2.0.0"
APP_DESC: str    = "Akıllı Kan Bağışı Sistemi — Kurumsal Mimari"

# ── Gemini AI ─────────────────────────────────────────────────────────────────
GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
