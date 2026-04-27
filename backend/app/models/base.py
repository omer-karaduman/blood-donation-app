# app/models/base.py
"""
SQLAlchemy declarative base — tüm modeller buradan türer.
"""
from sqlalchemy.orm import declarative_base

Base = declarative_base()
