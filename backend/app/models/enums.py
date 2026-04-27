# app/models/enums.py
"""
Uygulama genelindeki tüm Enum tanımlamaları.
"""
import enum


class UserRoleEnum(str, enum.Enum):
    DONOR = "donor"
    staff = "staff"
    ADMIN = "admin"


class GenderEnum(str, enum.Enum):
    E = "E"
    K = "K"


class BloodTypeEnum(str, enum.Enum):
    A_POS  = "A+"
    A_NEG  = "A-"
    B_POS  = "B+"
    B_NEG  = "B-"
    AB_POS = "AB+"
    AB_NEG = "AB-"
    O_POS  = "O+"
    O_NEG  = "O-"


class UrgencyEnum(str, enum.Enum):
    NORMAL = "Normal"
    ACIL   = "Acil"
    AFET   = "Afet"


class RequestStatusEnum(str, enum.Enum):
    AKTIF      = "Aktif"
    TAMAMLANDI = "Tamamlandi"
    IPTAL      = "Iptal"


class DonationResultEnum(str, enum.Enum):
    BASARILI   = "Basarili"
    REDDEDILDI = "Reddedildi"


class NotificationDeliveryEnum(str, enum.Enum):
    BASARILI  = "Basarili"
    BASARISIZ = "Basarisiz"


class NotificationReactionEnum(str, enum.Enum):
    BEKLIYOR       = "Bekliyor"
    KABUL          = "Kabul"
    RED            = "Red"
    GORMEZDEN_GELDI = "Gormezden_Geldi"
    TAMAMLANDI     = "Tamamlandi"


class InstitutionTypeEnum(str, enum.Enum):
    HASTANE    = "Hastane"
    KAN_MERKEZI = "Kan Merkezi"
