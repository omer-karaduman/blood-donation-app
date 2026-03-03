# backend/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os

# Docker-compose'dan gelen environment variable'ı alıyoruz
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL")

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)