from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

load_dotenv()

# 1. Docker-compose'daki ayarlara göre Windows (Host) üzerinden bağlanma adresi:
# (PowerShell'den script çalıştırdığında burası kullanılır)
DEFAULT_LOCAL_URL = "postgresql://admin:password123@localhost:5433/blood_donation"

# 2. ÖNEMLİ DÜZELTME: 
# Eğer Docker içindeyse DATABASE_URL ortam değişkeni 'db:5432' olarak dolu gelir.
# Eğer Docker dışındaysan (PowerShell), bu değişken boştur ve DEFAULT_LOCAL_URL kullanılır.
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", DEFAULT_LOCAL_URL)

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()