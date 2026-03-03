FROM python:3.11-slim

# Çevresel değişkenleri ayarla ki Python çıktıları tamponlamadan göndersin
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /app

# PostgreSQL bağlantısı için gerekli sistem bağımlılıklarını kur
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# requirements.txt içindeki paketleri kur
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

# Komutu "python -m" ile başlatarak PATH sorununu dolaylı yoldan çözeriz
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]