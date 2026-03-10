import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, f1_score, classification_report
import joblib
import os

def train_and_evaluate():
    print("1. Sentetik donör verisi yükleniyor...")
    data_path = 'data/mock_donors.csv'
    
    if not os.path.exists(data_path):
        print(f"Hata: {data_path} bulunamadı!")
        return

    df = pd.read_csv(data_path)

    # 2. Modelin öğreneceği özellikler (Features) ve tahmin edeceği hedef (Target)
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

    # 3. Veriyi Eğitim (%80) ve Test (%20) olarak ayır
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    print("2. Random Forest modeli eğitiliyor...")
    # n_estimators: Ormandaki ağaç sayısı
    model = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
    model.fit(X_train, y_train)

    print("3. Model test ediliyor ve metrikler hesaplanıyor...")
    y_pred = model.predict(X_test)

    # Tezde belirtilen başarı ölçütleri
    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)

    print("\n" + "="*40)
    print("📊 MODEL PERFORMANS RAPORU")
    print("="*40)
    print(f"Accuracy (Doğruluk) : {accuracy:.4f}  (Modelin genel doğru bilme oranı)")
    print(f"Precision (Kesinlik): {precision:.4f}  (Gelir dediği donörlerin gerçekten gelme oranı)")
    print(f"F1 Score            : {f1:.4f}  (Dengeli başarı skoru)")
    print("="*40 + "\n")

    # 4. Modeli FastAPI'de kullanmak üzere kaydet
    os.makedirs('ml_models', exist_ok=True)
    model_filename = 'ml_models/donor_rf_model.pkl'
    joblib.dump(model, model_filename)

    print(f"✅ Model başarıyla eğitildi ve '{model_filename}' konumuna kaydedildi.")
    print("Artık FastAPI bu .pkl dosyasını okuyup gerçek zamanlı skorlama yapabilir!")

if __name__ == "__main__":
    train_and_evaluate()