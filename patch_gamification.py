"""
Fix all backend issues:
1. Gamification endpoint - count completed donations from NotificationLog
2. Add history-all endpoint that returns all log reactions
"""
src_donors = r'C:\Users\grapl\Desktop\tez\blood-donation-app\backend\app\routers\donors.py'

with open(src_donors, encoding='utf-8') as f:
    content = f.read()

# 1. Fix gamification endpoint to count real donations
old_gamification = '''@router.get("/{user_id}/gamification")
def get_donor_gamification(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün puan ve rozet bilgilerini getirir."""
    data = db.query(models.GamificationData).filter(models.GamificationData.user_id == user_id).first()
    if not data:
        raise HTTPException(status_code=404, detail="Veri yok.")
    return data'''

new_gamification = '''@router.get("/{user_id}/gamification")
def get_donor_gamification(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün puan ve rozet bilgilerini getirir."""
    data = db.query(models.GamificationData).filter(models.GamificationData.user_id == user_id).first()
    if not data:
        raise HTTPException(status_code=404, detail="Veri yok.")

    # Gercek basarili bagis sayisini DonationHistory'den cek
    basarili_bagis = db.query(models.DonationHistory).filter(
        models.DonationHistory.user_id == user_id,
        models.DonationHistory.islem_sonucu == models.DonationResultEnum.BASARILI,
    ).count()

    return {
        "toplam_puan":  data.toplam_puan or 0,
        "toplam_bagis": basarili_bagis,
        "seviye":       data.seviye or 1,
        "rozet_listesi": data.rozet_listesi or [],
    }


@router.get("/{user_id}/all-logs")
def get_donor_all_logs(user_id: uuid.UUID, db: Session = Depends(get_db)):
    """Donörün tüm bildirim loglarını (kabul, red, görmezden, tamamlandı) getirir."""
    logs = (
        db.query(models.NotificationLog)
        .options(
            joinedload(models.NotificationLog.blood_request)
            .joinedload(models.BloodRequest.institution)
        )
        .filter(models.NotificationLog.user_id == user_id)
        .order_by(models.NotificationLog.gonderim_zamani.desc())
        .all()
    )
    result = []
    for log in logs:
        req = log.blood_request
        kurum_adi = None
        if req and req.institution:
            kurum_adi = req.institution.kurum_adi

        reaksiyon_str = (
            log.kullanici_reaksiyonu.value
            if hasattr(log.kullanici_reaksiyonu, "value")
            else str(log.kullanici_reaksiyonu)
        )

        result.append({
            "log_id":        str(log.log_id),
            "talep_id":      str(req.talep_id) if req else None,
            "kurum_adi":     kurum_adi or "Bilinmeyen Kurum",
            "reaksiyon":     reaksiyon_str,
            "gonderim_zamani": log.gonderim_zamani.isoformat() if log.gonderim_zamani else None,
            "reaksiyon_zamani": log.reaksiyon_zamani.isoformat() if log.reaksiyon_zamani else None,
            "kan_grubu":     req.istenen_kan_grubu.value if req and hasattr(req.istenen_kan_grubu, "value") else None,
        })
    return result'''

if old_gamification in content:
    content = content.replace(old_gamification, new_gamification, 1)
    with open(src_donors, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Gamification endpoint fixed!")
else:
    print("Pattern not found in gamification!")
    idx = content.find('def get_donor_gamification')
    print(repr(content[idx:idx+300]))
