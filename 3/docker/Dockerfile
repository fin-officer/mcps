# Użycie oficjalnego obrazu Pythona jako podstawy
FROM python:3.11-slim

# Ustawienie zmiennych środowiskowych
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Ustawienie katalogu roboczego
WORKDIR /app

# Instalacja zależności
RUN pip install --upgrade pip && \
    pip install flask requests python-dotenv

# Kopiowanie pliku serwera
COPY ../server.py /app/
COPY ../.env /app/ 2>/dev/null || echo "No .env file found, using default configuration"

# Informacja o porcie
EXPOSE 5001

# Uruchomienie serwera przy starcie kontenera
CMD ["python", "server.py"]

# Informacja o kontenerze
LABEL maintainer="APIServer" \
      description="Ollama API Server" \
      version="1.0"