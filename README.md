# Kan Bağışı ve Akıllı Donör Seçimi Uygulaması

Bu proje, kan bağışı süreçlerini dijitalleştirmek, hızlandırmak ve makine öğrenimi yardımıyla doğru donörlere daha hızlı bir şekilde ulaşmak amacıyla geliştirilmiştir. Sistem; sağlık personeli, kurum yöneticileri ve gönüllü donörler için farklı modüller içermektedir.

## Proje Mimarisi

- Backend: FastAPI (Python), SQLAlchemy
- Frontend: Flutter (Dart)
- Veritabanı: PostgreSQL
- Makine Öğrenimi: Scikit-learn (Random Forest tabanlı donör önceliklendirme modeli)
- Konteynerizasyon: Docker & Docker Compose

## Kurulum ve Çalıştırma

Projenin gereksinimleri farklı çalışma ortamlarına uygun olarak yapılandırılmıştır.

### 1. Yerel Kurulum (Geliştirme Ortamı)

Donanım kaynaklarını daha verimli kullanmak veya spesifik geliştirme yapmak isteyen geliştiriciler için:

1. Sisteminizde PostgreSQL kurulumunu gerçekleştirin.
2. PostgreSQL (örneğin pgAdmin) üzerinden `blood_donation` isimli bir veritabanı oluşturun.
3. Terminal veya komut satırı üzerinden `backend` klasörüne gidin.
4. Python sanal ortamını oluşturun ve aktif edin:
   - Windows için: `python -m venv venv` ardından `venv\Scripts\activate`
   - macOS/Linux için: `python3 -m venv venv` ardından `source venv/bin/activate`
5. Gerekli bağımlılıkları yükleyin:
   `pip install -r requirements.txt`
6. `backend` klasörü içerisinde `.env` dosyasını oluşturarak veritabanı bağlantı bilgilerinizi (kullanıcı adı ve şifre gibi) tanımlayın.

### 2. Docker Kullanarak Kurulum

Tüm hizmetlerin (veritabanı, backend, varsa diğer servisler) izole ve eksiksiz bir şekilde çalıştırılması için Docker tercih edilebilir.

Projenin ana dizininde aşağıdaki komutu çalıştırarak tüm yapıyı başlatabilirsiniz:

```bash
docker-compose up --build -d
```

## Temel Özellikler

- Donör Yönetimi: Kan bağışçılarının profilleri, sağlık durumları ve bağış geçmişlerinin takibi.
- Kurum ve Personel Yönetimi: Hastaneler ile kan merkezleri arasında hiyerarşik yapı kurulumu ve personel yetkilendirmesi.
- Makine Öğrenimi Entegrasyonu: Aktif kan taleplerinde, sistemdeki uygun donörleri konum, kan grubu ve geçmiş verilerine göre analiz eden filtreleme sistemi.
- Admin ve Log Paneli: Sistemdeki tüm hareketlerin, talep istatistiklerinin ve model doğruluk performansının izlenebildiği yönetim arayüzü.