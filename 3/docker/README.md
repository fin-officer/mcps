# Uruchamianie Ollama API w Docker

Ten dokument zawiera instrukcje dotyczące uruchamiania serwera Ollama oraz API serwera w kontenerach Docker za pomocą Docker Compose.

## Wymagania

- Docker i Docker Compose
- Dla akceleracji GPU (opcjonalnie):
  - NVIDIA Container Toolkit (dla kart NVIDIA)
  - Sterowniki NVIDIA

## Struktura projektu

```
.
├── docker-compose.yml        # Główny plik konfiguracyjny Docker Compose
├── docker-compose.minimal.yml # Uproszczona wersja bez zaawansowanych ustawień
├── Dockerfile                # Definicja obrazu dla serwera API
├── server.py                 # Kod serwera API
└── .env                      # Opcjonalny plik z konfiguracją (tworzony automatycznie)
```

## Szybki start

1. Umieść wszystkie pliki w jednym katalogu
2. Uruchom kontenery za pomocą Docker Compose:

```bash
docker compose up -d
```

3. Serwer API będzie dostępny pod adresem: http://localhost:5001

## Konfiguracja

### Zmienne środowiskowe

Możesz zmienić konfigurację poprzez zmienne środowiskowe w pliku `docker-compose.yml` lub utworzenie pliku `.env`:

```
OLLAMA_URL=http://ollama:11434  # URL serwera Ollama
SERVER_PORT=5001                # Port serwera API
MODEL_NAME=tinyllama:latest     # Nazwa używanego modelu
TEMPERATURE=0.7                 # Temperatura generowania
MAX_TOKENS=1000                 # Maksymalna liczba tokenów
```

### Wolumeny

- `ollama_data`: Przechowuje pobrane modele i konfigurację Ollama

### Porty

- `11434`: Port serwera Ollama
- `5001`: Port serwera API

## Zaawansowane opcje

### Akceleracja GPU

Domyślnie, konfiguracja próbuje używać GPU NVIDIA, jeśli są dostępne. Jeśli nie masz karty NVIDIA lub nie chcesz używać GPU, możesz:

1. Zakomentować lub usunąć sekcję `deploy` w pliku `docker-compose.yml`
2. Alternatywnie użyć pliku `docker-compose.minimal.yml`

```bash
docker compose -f docker-compose.minimal.yml up -d
```

### Własne modele

Aby używać innego modelu niż tinyllama:

1. Zmień wartość zmiennej `MODEL_NAME` w pliku `docker-compose.yml`
2. Zmień model pobierany przez usługę `model-puller`

```yaml
command: >
  "if ollama list | grep -q 'llama2'; then
     echo 'Model llama2 już istnieje';
   else
     echo 'Pobieranie modelu llama2...';
     ollama pull llama2;
   fi"
```

## Zarządzanie kontenerami

### Uruchamianie

```bash
docker compose up -d
```

### Zatrzymywanie

```bash
docker compose down
```

### Monitoring logów

```bash
# Wszystkie serwisy
docker compose logs -f

# Tylko serwer API
docker compose logs -f api-server

# Tylko Ollama
docker compose logs -f ollama
```

### Przebudowanie obrazów

```bash
docker compose build --no-cache
```

## Rozwiązywanie problemów

### Serwer API nie może połączyć się z Ollama

Problem może wynikać z tego, że serwer Ollama nie zdążył się uruchomić przed serwerem API. Spróbuj:

1. Uruchomić ponownie kontener API:
   ```bash
   docker compose restart api-server
   ```

2. Sprawdzić, czy serwer Ollama działa:
   ```bash
   curl http://localhost:11434/api/tags
   ```

### Problemy z dostępem do zasobów GPU

Jeśli masz problemy z dostępem do GPU:

1. Upewnij się, że masz zainstalowany NVIDIA Container Toolkit:
   ```bash
   nvidia-smi
   docker run --gpus all nvidia/cuda:11.0-base nvidia-smi
   ```

2. Użyj wersji bez GPU:
   ```bash
   docker compose -f docker-compose.minimal.yml up -d
   ```

## Bezpieczeństwo

Domyślnie, serwery są dostępne tylko lokalnie. Jeśli chcesz udostępnić je na zewnątrz:

1. Zmień konfigurację portów w `docker-compose.yml`:
   ```yaml
   ports:
     - "0.0.0.0:5001:5001"  # Dostęp z dowolnego adresu IP
   ```

2. Rozważ dodanie warstwy uwierzytelniania lub zapory sieciowej

## Wersja minimalna

Jeśli potrzebujesz tylko podstawowej funkcjonalności bez zaawansowanych opcji, możesz użyć uproszczonej konfiguracji:

```bash
docker compose -f docker-compose.minimal.yml up -d
```

Ta wersja:
- Nie ma monitoringu zdrowia usług
- Nie zawiera automatycznego pobierania modeli
- Nie konfiguruje akceleracji GPU
- Zawiera tylko niezbędne ustawienia