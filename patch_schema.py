src = r'C:\Users\grapl\Desktop\tez\blood-donation-app\backend\app\schemas\blood_request.py'
with open(src, encoding='utf-8') as f:
    content = f.read()

old_donor = '''class DonorReactionSummary(BaseModel):
    log_id:           UUID
    donor_ad_soyad:   str
    reaksiyon:        NotificationReactionEnum
    reaksiyon_zamani: Optional[datetime] = None
    ml_score:         float = 0.0
    model_config = ConfigDict(from_attributes=True)


class BloodRequestDetailResponse(BaseModel):
    talep_id:               UUID
    istenen_kan_grubu:      BloodTypeEnum
    unite_sayisi:           int
    durum:                  RequestStatusEnum
    olusturma_tarihi:       datetime
    gecerlilik_suresi_saat: int
    aciliyet_durumu:        UrgencyEnum
    donor_yanitlari:        List[DonorReactionSummary] = []
    model_config = ConfigDict(from_attributes=True)'''

new_donor = '''class DonorReactionSummary(BaseModel):
    log_id:           str
    donor_ad_soyad:   str
    reaksiyon:        str
    reaksiyon_zamani: Optional[str] = None
    ml_score:         float = 0.0
    model_config = ConfigDict(from_attributes=True)


class BloodRequestDetailResponse(BaseModel):
    talep_id:               str
    istenen_kan_grubu:      str
    unite_sayisi:           int
    durum:                  str
    olusturma_tarihi:       str
    gecerlilik_suresi_saat: int
    aciliyet_durumu:        str
    donor_yanitlari:        List[DonorReactionSummary] = []
    model_config = ConfigDict(from_attributes=True)'''

if old_donor in content:
    content = content.replace(old_donor, new_donor, 1)
    with open(src, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Schema patched OK')
else:
    print('NOT FOUND - trying char search')
    idx = content.find('DonorReactionSummary')
    print(repr(content[idx:idx+400]))
