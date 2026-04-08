import firebase_admin
from firebase_admin import credentials, messaging, db # 🚀 db modülü eklendi
import os

# Ayarları Oku
DATABASE_URL = os.getenv("FIREBASE_DATABASE_URL") # 🚀 RTDB URL'si için yeni env

# Firebase Başlatma (Hata almamak için kontrol)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIREBASE_KEY_PATH = os.path.join(BASE_DIR, "serviceAccountKey.json")

if not firebase_admin._apps:
    if os.path.exists(FIREBASE_KEY_PATH):
        cred = credentials.Certificate(FIREBASE_KEY_PATH)
        # 🚀 SADECE BURASI DEĞİŞTİ: RTDB linkini de vererek başlatıyoruz
        firebase_admin.initialize_app(cred, {
            'databaseURL': DATABASE_URL
        })
        print("✅ Firebase Admin (FCM + RTDB) Hazır.")

# ---------------------------------------------------------
# YARDIMCI FONKSİYONLAR
# ---------------------------------------------------------

def format_blood_type(bt_enum):
    """BloodTypeEnum.A_POS -> A+ formatına çevirir."""
    s = str(bt_enum).split('.')[-1]
    return s.replace('_POS', '+').replace('_NEG', '-').replace('AB', 'AB').replace('O', '0')

# ---------------------------------------------------------
# REALTIME DATABASE (ONLINE/OFFLINE TAKİBİ)
# ---------------------------------------------------------

def is_donor_online(donor_id: str):
    """
    Kullanıcının o an uygulamada aktif (online) olup olmadığını kontrol eder.
    Flutter tarafı RTDB'ye 'presence/{donor_id}' altına veri yazmalıdır.
    """
    if not DATABASE_URL:
        print("⚠️ RTDB URL eksik, online durumu her zaman False dönecek.")
        return False
        
    try:
        # Firebase Realtime Database'e gidip kullanıcının durumuna bakıyoruz
        ref = db.reference(f'presence/{donor_id}')
        status = ref.get()
        
        # Eğer veri varsa ve 'online' değeri True ise True dön
        if status and isinstance(status, dict):
            return status.get('online', False)
        return False
    except Exception as e:
        print(f"❌ RTDB Bağlantı Hatası: {e}")
        return False

# ---------------------------------------------------------
# GÖNDERİM SERVİSİ (SADECE PUSH)
# ---------------------------------------------------------

def send_push_notification(token: str, title: str, body: str, data: dict = None):
    """Firebase üzerinden anlık mobil bildirim gönderir."""
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    sound='default',
                    color='#E53935',
                    click_action='FLUTTER_NOTIFICATION_CLICK'
                ),
            ),
            data=data if data else {},
            token=token,
        )
        response = messaging.send(message)
        print(f"✅ Push Gönderildi: {response}")
        return True
    except Exception as e:
        print(f"❌ Push Hatası: {e}")
        return False

# ---------------------------------------------------------
# ANA KARAR MEKANİZMASI (Tetikleyici)
# ---------------------------------------------------------

def notify_donor(donor, talep_id: str, kurum_adi: str, aciliyet: str):
    """Her durumda (Acil veya Normal) sadece mobil bildirim gönderir."""
    kan_grubu_temiz = format_blood_type(donor.kan_grubu)
    status = str(aciliyet).upper()
    is_emergency = status in ["ACIL", "AFET", "ACİL"]
    
    # 🚀 İSTEĞE BAĞLI KULLANIM: Donörün online olup olmadığını kontrol edebilirsin
    # is_online = is_donor_online(str(donor.id))
    # if is_online:
    #     print(f"🟢 {donor.ad_soyad} şu an ONLINE!")
    
    if hasattr(donor, 'fcm_token') and donor.fcm_token:
        if is_emergency:
            title = f"🚨 ACİL KAN: {kan_grubu_temiz}"
            body = f"Sayın {donor.ad_soyad}, {kurum_adi} kurumunda acil kana ihtiyaç vardır. Lütfen uygulamayı kontrol ediniz. 🩸"
        else:
            title = f"🏥 Kan Bağışı: {kan_grubu_temiz}"
            body = f"Sayın {donor.ad_soyad}, {kurum_adi} kurumundaki kan ihtiyacı için uygun görünüyorsunuz. 🩸"
            
        send_push_notification(donor.fcm_token, title, body, {"talep_id": str(talep_id)})
    else:
        print(f"⚠️ {donor.ad_soyad} için bildirim gönderilemedi (Mobil cihaz token'ı yok).")