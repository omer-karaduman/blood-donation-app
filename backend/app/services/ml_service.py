# app/services/ml_service.py
"""
ML model yukleme ve donor skoru tahmin servisi.
Model yuklenmemisse guvenli fallback (0.5) doner.
"""
import os
import joblib
import pandas as pd
from datetime import datetime
from app.config import ML_MODEL_PATH, ML_SCALER_PATH

_rf_model = None
_scaler   = None


def _load_models() -> None:
    """Modelleri uygulama baslangicindan bir kez yukler."""
    global _rf_model, _scaler

    if os.path.exists(ML_MODEL_PATH):
        try:
            _rf_model = joblib.load(ML_MODEL_PATH)
            print(f"[ML] Model yuklendi: {ML_MODEL_PATH}")
        except Exception as e:
            print(f"[ML] Model yuklenemedi: {e}")
    else:
        print(f"[ML] Model bulunamadi: {ML_MODEL_PATH}")

    if os.path.exists(ML_SCALER_PATH):
        try:
            _scaler = joblib.load(ML_SCALER_PATH)
            print(f"[ML] Scaler yuklendi: {ML_SCALER_PATH}")
        except Exception as e:
            print(f"[ML] Scaler yuklenemedi: {e}")


_load_models()


def calculate_age(birthdate) -> int:
    """Dogum tarihinden yasi hesaplar."""
    if not birthdate:
        return 30
    today = datetime.today().date()
    if isinstance(birthdate, str):
        try:
            from datetime import datetime as _dt
            birthdate = _dt.strptime(birthdate, "%Y-%m-%d").date()
        except Exception:
            return 30
    if hasattr(birthdate, "date"):
        birthdate = birthdate.date()
    return today.year - birthdate.year - (
        (today.month, today.day) < (birthdate.month, birthdate.day)
    )


def predict_donor_scores(donors: list, ml_input_data: list) -> list:
    """
    Verilen donor listesi icin ML tahminleri doner.

    Args:
        donors:        DonorProfile ORM nesneleri listesi.
        ml_input_data: Her donor icin ozellik dict listesi.

    Returns:
        [{"donor": ..., "probability": float}] -- olasilik 0-100 arasi.
    """
    if _rf_model is not None and ml_input_data:
        try:
            df       = pd.DataFrame(ml_input_data)
            features = _scaler.transform(df) if _scaler else df.values
            probs    = _rf_model.predict_proba(features)[:, 1]
            return [
                {"donor": d, "probability": float(p * 100)}
                for d, p in zip(donors, probs)
            ]
        except Exception as e:
            print(f"[ML] Tahmin hatasi: {e}")

    return [{"donor": d, "probability": 50.0} for d in donors]


def is_model_loaded() -> bool:
    """Model yuklu mu kontrol eder."""
    return _rf_model is not None
