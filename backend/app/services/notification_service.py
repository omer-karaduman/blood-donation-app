# app/services/notification_service.py
"""
Firebase FCM push bildirimi ve Realtime Database online durumu servisi.
"""
import os
import firebase_admin
from firebase_admin import credentials, messaging, db
from app.config import FIREBASE_DATABASE_URL, FIREBASE_KEY_RENDER, FIREBASE_KEY_LOCAL

FIREBASE_KEY_PATH = (
    FIREBASE_KEY_RENDER if os.path.exists(FIREBASE_KEY_RENDER) else FIREBASE_KEY_LOCAL
)

if not firebase_admin._apps:
    if os.path.exists(FIREBASE_KEY_PATH):
        cred = credentials.Certificate(FIREBASE_KEY_PATH)
        firebase_admin.initialize_app(cred, {"databaseURL": FIREBASE_DATABASE_URL})
        print("[Firebase] Admin SDK baslatildi.")
    else:
        print("[Firebase] serviceAccountKey.json bulunamadi!")


def format_blood_type(bt_enum) -> str:
    s = str(bt_enum).split(".")[-1]
    return s.replace("_POS", "+").replace("_NEG", "-")


def is_donor_online(donor_id: str) -> bool:
    if not FIREBASE_DATABASE_URL:
        return False
    try:
        ref    = db.reference(f"presence/{donor_id}")
        status = ref.get()
        if status and isinstance(status, dict):
            return status.get("online", False)
        return False
    except Exception as e:
        print(f"[Firebase] RTDB hatasi: {e}")
        return False


def send_push_notification(token: str, title: str, body: str, data: dict = None) -> bool:
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                    color="#E53935",
                    click_action="FLUTTER_NOTIFICATION_CLICK",
                ),
            ),
            data=data or {},
            token=token,
        )
        response = messaging.send(message)
        print(f"[FCM] Bildirim gonderildi: {response}")
        return True
    except Exception as e:
        print(f"[FCM] Bildirim hatasi: {e}")
        return False


def notify_donor(donor, talep_id, kurum_adi: str, aciliyet: str) -> None:
    kan_grubu_temiz = format_blood_type(donor.kan_grubu)
    is_emergency    = str(aciliyet).upper() in ("ACIL", "AFET", "ACIL")

    if hasattr(donor, "fcm_token") and donor.fcm_token:
        if is_emergency:
            title = f"ACIL KAN: {kan_grubu_temiz}"
            body  = (
                f"Sayin {donor.ad_soyad}, {kurum_adi} kurumunda acil kana "
                f"ihtiyac vardir. Lutfen uygulamayi kontrol ediniz."
            )
        else:
            title = f"Kan Bagisi: {kan_grubu_temiz}"
            body  = (
                f"Sayin {donor.ad_soyad}, {kurum_adi} kurumundaki kan ihtiyaci "
                f"icin uygun gorunuyorsunuz."
            )
        send_push_notification(donor.fcm_token, title, body, {"talep_id": str(talep_id)})
    else:
        print(f"[FCM] {donor.ad_soyad} icin bildirim goenderilemedi (token yok).")
