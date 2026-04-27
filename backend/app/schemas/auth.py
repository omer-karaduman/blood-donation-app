# app/schemas/auth.py
from pydantic import BaseModel, EmailStr, Field, ConfigDict
from typing import Optional
from datetime import datetime
from uuid import UUID
from app.models.enums import UserRoleEnum


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    fcm_token: Optional[str] = None


class UserBase(BaseModel):
    email: EmailStr


class UserCreateBase(UserBase):
    password: str = Field(..., min_length=6)


class UserResponse(UserBase):
    user_id: UUID
    role: UserRoleEnum
    is_active: bool
    olusturma_tarihi: datetime
    model_config = ConfigDict(from_attributes=True)
