# Kan Bağışı ve Akıllı Donör Seçimi Uygulaması

## 🚀 Kurulum (Nasıl Başlarız?)

Bu projede hibrit bir çalışma düzeni kullanıyoruz.

### 1. Melih ve İsmail İçin (Docker Kullanmadan)
Bilgisayarınızı yormamak için yerel kurulum yapın.

1. **PostgreSQL Kurun:** Bilgisayarınıza PostgreSQL indirin ve kurun.
2. **Veritabanı Oluşturun:** `pgAdmin` üzerinden `blood_donation` adında boş bir veritabanı açın.
3. **Python Ortamı:**
   - İlgili klasöre gidin (örn: `cd backend`).
   - Sanal ortam oluşturun: `python -m venv venv`
   - Aktif edin: `source venv/bin/activate` (Mac) veya `venv\Scripts\activate` (Win).
   - Kütüphaneleri yükleyin: `pip install -r requirements.txt`
4. **.env Dosyası:** `backend` klasöründe `.env` dosyası oluşturun ve kendi şifrenizi yazın.

### 2. Ömer İçin (Docker İle)
Ben tüm sistemi Docker ile ayağa kaldırıyorum.

```bash
docker-compose up -d