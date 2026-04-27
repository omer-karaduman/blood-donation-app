# app/schemas/staff.py
from pydantic import ConfigDict
from typing import Optional
from uuid import UUID
from app.schemas.auth import UserCreateBase


class StaffCreate(UserCreateBase):
    ad_soyad:   str
    kurum_id:   UUID
    unvan:      Optional[str] = "Personel"
    personel_no: Optional[str] = None
