import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, precision_score, f1_score, classification_report, confusion_matrix
import joblib
import os

def train_and_evaluate():
    # 1. Klasör Yollarını Dinamik Olarak Belirle
    # Scriptin çalıştığı klasörü (backend/) bulur
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    
    # Veri ve Model klasörlerini mutlak yollarla tanımla
    DATA_PATH = os.path.join(BASE_DIR, 'data', 'mock_donors.csv')
    MODEL_DIR = os.path.join(BASE_DIR, 'ml_models')
    
    print(f"1. Veri yükleniyor: {DATA_PATH}")
    
    if not os.path.exists(DATA_PATH):
        print(f"❌ HATA: '{DATA_PATH}' bulunamadı!")
        print("Lütfen önce 'generate_mock_donors.py' scriptini çalıştırın.")
        return

    df = pd.read_csv(DATA_PATH)

    # Boş verileri temizle
    df.fillna(df.median(numeric_only=True), inplace=True)

    # 2. Model Özellikleri (Features) ve Hedef (Target)
    # ÖNEMLİ: main.py içindeki sırayla birebir aynı olmalı
    features = [
        'age', 
        'past_donations', 
        'days_since_last_donation', 
        'response_rate', 
        'sensitivity_level', 
        'preferred_hour'
    ]
    
    X = df[features]
    y = df['will_donate']

    # 3. Eğitim ve Test Setine Ayır (%80 - %20)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    print("2. Veriler ölçeklendiriliyor (StandardScaler)...")
    scaler = StandardScaler()
    
    # RandomForest için ölçeklendirme
    X_train_scaled = pd.DataFrame(scaler.fit_transform(X_train), columns=features)
    X_test_scaled = pd.DataFrame(scaler.transform(X_test), columns=features)

    print("3. Random Forest modeli eğitiliyor...")
    model = RandomForestClassifier(
        n_estimators=150,
        max_depth=12,
        random_state=42, 
        class_weight='balanced'
    )
    model.fit(X_train_scaled, y_train)

    print("4. Performans raporu hazırlanıyor...")
    y_pred = model.predict(X_test_scaled)

    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)

    print("\n" + "="*55)
    print("📊 TEZ MODEL PERFORMANS RAPORU")
    print("="*55)
    print(f"Accuracy (Doğruluk) : {accuracy:.4f}")
    print(f"Precision (Kesinlik): {precision:.4f}")
    print(f"F1 Score            : {f1:.4f}")
    print("-" * 55)
    print("Karmaşıklık Matrisi (Confusion Matrix):")
    print(confusion_matrix(y_test, y_pred))
    print("="*55 + "\n")

    # 5. Kayıt İşlemi
    os.makedirs(MODEL_DIR, exist_ok=True)
    
    model_path = os.path.join(MODEL_DIR, 'donor_rf_model.pkl')
    scaler_path = os.path.join(MODEL_DIR, 'scaler.pkl')
    
    joblib.dump(model, model_path)
    joblib.dump(scaler, scaler_path)

    print(f"✅ Model kaydedildi -> {model_path}")
    print(f"✅ Scaler kaydedildi -> {scaler_path}")
    print("🚀 Sistem artık en güncel beyinle çalışmaya hazır!")

if __name__ == "__main__":
    train_and_evaluate()