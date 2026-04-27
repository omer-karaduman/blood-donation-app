# app/models/__init__.py
"""
Models paketi — tüm ORM sınıflarını ve enum'ları tek noktadan dışa aktarır.
Router'lar sadece `from app import models` yapıp `models.User` gibi kullanabilir.
"""
from app.models.base import Base  # noqa: F401

# Enums
from app.models.enums import (  # noqa: F401
    UserRoleEnum,
    GenderEnum,
    BloodTypeEnum,
    UrgencyEnum,
    RequestStatusEnum,
    DonationResultEnum,
    NotificationDeliveryEnum,
    NotificationReactionEnum,
    InstitutionTypeEnum,
)

# Domain modelleri
from app.models.institution import District, Neighborhood, Institution  # noqa: F401
from app.models.user import User, DonorProfile, StaffProfile, HealthStatus  # noqa: F401
from app.models.blood_request import BloodRequest, DonationHistory, NotificationLog  # noqa: F401
from app.models.ml import MLFeature, GamificationData, AgentLog  # noqa: F401
