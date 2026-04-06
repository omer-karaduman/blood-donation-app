from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

load_dotenv()

# Docker-compose'daki ayarlara göre senin HOST (Windows) üzerinden bağlanma adresin:
# Kullanıcı: admin, Şifre: password123, DB: blood_donation, Port: 5432 (localhost)
DEFAULT_LOCAL_URL = "postgresql://admin:password123@127.0.0.1:5432/blood_donation"

# Eğer Docker içindeyse ortam değişkenini (DATABASE_URL) alır, 
# Eğer sen terminalden 'uvicorn' çalıştırırsan DEFAULT_LOCAL_URL'i (localhost) kullanır.
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", DEFAULT_LOCAL_URL)

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)



def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()