# app/routers/ai_agent.py
"""
Gemini tabanlı bağış asistanı chat endpoint'i.
"""
import os
from datetime import datetime

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session, joinedload
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage, SystemMessage

from app import models
from app.database import get_db
from app.config import GEMINI_API_KEY

router = APIRouter(prefix="/api/ai", tags=["AI Agent"])


class ChatRequest(BaseModel):
    message: str
    user_id: str


BASE_SYSTEM_PROMPT = """
Sen "Bağış Asistanı" adlı yapay zekâ destekli bir dijital asistansın.
Kan bağışı mobil uygulamasının içinde, donörlere rehberlik ediyorsun.

TEMEL KURALLARIN:
- Kısa, sıcak ve motive edici bir dil kullan.
- KESİNLİKLE Markdown kullanma (**, *, # işaretleri yasak).
- Vurgu için sadece BÜYÜK HARF kullan.
- Listeleri "1) ... 2) ..." veya "• ..." şeklinde yap.

UYGULAMA VE ML ÖZELLİKLERİ:
- ML modelimiz donörleri sadece uygun olduklarında acil çağrılarla eşleştirir.
- Oyunlaştırma sistemiyle bağış yaptıkça puan ve rozet kazanılır.

BAĞIŞ PERİYOTLARI:
- ERKEKLER için en az 3 AY, KADINLAR için en az 4 AY bekleme süresi vardır.
"""


@router.post("/chat")
async def chat_with_ai(request: ChatRequest, db: Session = Depends(get_db)):
    api_key = GEMINI_API_KEY
    if not api_key:
        raise HTTPException(status_code=500, detail="Gemini API Key bulunamadı.")

    try:
        donor = (
            db.query(models.DonorProfile)
            .options(joinedload(models.DonorProfile.gamification))
            .filter(models.DonorProfile.user_id == request.user_id)
            .first()
        )

        current_date    = datetime.now()
        dynamic_context = ""

        if donor:
            isim     = donor.ad_soyad.split()[0] if donor.ad_soyad else "Bağışçı"
            cinsiyet = "Erkek" if donor.cinsiyet == models.GenderEnum.E else "Kadın"
            son_bagis = donor.son_bagis_tarihi
            kan_grubu = donor.kan_grubu.value if donor.kan_grubu else "Bilinmiyor"
            puan      = donor.gamification.toplam_puan if donor.gamification else 0

            gecmis_bagislar = (
                db.query(models.DonationHistory)
                .options(joinedload(models.DonationHistory.institution))
                .filter(
                    models.DonationHistory.user_id == request.user_id,
                    models.DonationHistory.islem_sonucu == models.DonationResultEnum.BASARILI,
                )
                .order_by(models.DonationHistory.bagis_tarihi.desc())
                .limit(3)
                .all()
            )
            hastane_isimleri = list({
                b.institution.kurum_adi for b in gecmis_bagislar if b.institution
            })
            hastane_metni = ", ".join(hastane_isimleri) if hastane_isimleri else "Kayıtlı bağışı yok."

            bagis_notu = "Sistemde henüz bağışın yok."
            if son_bagis:
                ay_farki   = (current_date - son_bagis).days // 30
                bagis_notu = f"En son {son_bagis.strftime('%d.%m.%Y')} tarihinde ({ay_farki} ay önce) bağış yapmış."

            dynamic_context = f"""
            GİZLİ KULLANICI PROFİLİ (SADECE ARKA PLAN BİLGİSİ OLARAK KULLAN):
            - İsim: {isim} | Cinsiyet: {cinsiyet} | Kan Grubu: {kan_grubu}
            - Toplam Puan: {puan}
            - Geçmiş Kurumlar: {hastane_metni}
            - Son Bağış Durumu: {bagis_notu}
            - Bugünün Tarihi: {current_date.strftime('%d.%m.%Y')}

            KESİN İLETİŞİM KURALLARI:
            1) BİLGİ KUSMA YASAĞI: Bu bilgileri her mesajda kullanma.
            2) DOĞALLIK: "Verilerine göre" gibi robotik ifadeler kullanma.
            3) ÖNCELİK: Kullanıcının sorusuna odaklan.
            4) HİTAP: "{isim}" ismini sadece sohbet başında kullan.
            """

        llm = ChatGoogleGenerativeAI(model="gemini-2.5-flash", google_api_key=api_key)
        messages = [
            SystemMessage(content=BASE_SYSTEM_PROMPT + dynamic_context),
            HumanMessage(content=request.message),
        ]
        response = llm.invoke(messages)
        return {"reply": response.content}

    except Exception as e:
        print(f"[AI ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))
