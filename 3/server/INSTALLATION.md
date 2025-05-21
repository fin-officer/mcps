# Instrukcja Instalacji Ollama Server

Ten przewodnik przedstawia jak zainstalować i skonfigurować Ollama Server przy użyciu Poetry. Poetry to nowoczesne narzędzie do zarządzania zależnościami w Pythonie, które ułatwia tworzenie, publikowanie i zarządzanie pakietami.

## Wymagania systemowe

- Python 3.8 lub nowszy
- [Ollama](https://ollama.com/download) (zainstalowane na komputerze)
- [Poetry](https://python-poetry.org/docs/#installation) (do zarządzania zależnościami)

## Instalacja przy użyciu Poetry

### 1. Zainstaluj Poetry

Jeśli nie masz jeszcze zainstalowanego Poetry, wykonaj poniższe polecenie w terminalu:

**Linux/macOS:**
```bash
curl -sSL https://install.python-poetry.org | python3 -
```

**Windows (PowerShell):**
```powershell
(Invoke-WebRequest -Uri https://install.python-poetry.org -UseBasicParsing).Content | python -
```

### 2. Sklonuj repozytorium

```bash
git clone https://github.com/username/ollama-server.git
cd ollama-server
```

### 3. Zainstaluj zależności

```bash
poetry install
```

To polecenie utworzy wirtualne środowisko i zainstaluje wszystkie zależności zdefiniowane w pliku `pyproject.toml`.

### 4. Aktywuj środowisko wirtualne

```bash
poetry shell
```

## Instalacja bez Poetry (przy użyciu pip)

Jeśli wolisz nie używać Poetry, możesz zainstalować pakiet bezpośrednio za pomocą pip:

### 1. Sklonuj repozytorium

```bash
git clone https://github.com/username/ollama-server.git
cd ollama-server
```

### 2. (Opcjonalnie) Utwórz wirtualne środowisko

```bash
python -m venv venv
source venv/bin/activate  # Linux/macOS
venv\Scripts\activate     # Windows
```

### 3. Zainstaluj pakiet

```bash
pip install -e .
```

## Uruchomienie po instalacji

Po zainstalowaniu, możesz uruchomić Ollama Server na kilka sposobów:

### Przy użyciu zainstalowanego skryptu

```bash
ollama-server run
```

### Przy użyciu modułu Python

```bash
python -m ollama_server.cli run
```

### Jako klient CLI

Pakiet instaluje narzędzie linii poleceń `ollama-server`, które udostępnia szereg przydatnych komend:

```bash
# Wyświetlenie pomocy
ollama-server --help

# Uruchomienie serwera
ollama-server run

# Wyświetlenie informacji o konfiguracji
ollama-server info

# Wyświetlenie dostępnych modeli
ollama-server models

# Konfiguracja modelu
ollama-server setup-model tinyllama

# Zadanie pytania do modelu
ollama-server ask "Co to jest Python?"
```

## Konfiguracja

### Plik .env

Ollama Server używa pliku `.env` do konfiguracji. Domyślny plik zostanie utworzony automatycznie przy pierwszym uruchomieniu. Możesz go edytować, aby dostosować ustawienia:

```ini
# Model Ollama
MODEL_NAME="tinyllama:latest"

# Konfiguracja serwera
OLLAMA_URL="http://localhost:11434"
SERVER_PORT=5001

# Parametry generowania
TEMPERATURE=0.7
MAX_TOKENS=1000
DEBUG=false
```

### Konfiguracja przez CLI

Możesz również skonfigurować ustawienia przez interfejs wiersza poleceń:

```bash
ollama-server config --model llama3 --port 8080 --temp 0.8 --tokens 2000
```

## Instalacja z PyPI

Gdy pakiet zostanie opublikowany na PyPI, będzie go można zainstalować bezpośrednio za pomocą pip:

```bash
pip install ollama-server
```

## Uruchamianie w trybie deweloperskim

Podczas rozwoju pakietu, przydatne może być uruchomienie serwera w trybie deweloperskim:

```bash
ollama-server run --debug
```

## Rozwiązywanie problemów

### Problem: Nie można połączyć z serwerem Ollama

**Rozwiązanie**: Upewnij się, że Ollama jest uruchomiona:

```bash
ollama serve
```

### Problem: Brak dostępu do portu

**Rozwiązanie**: Zmień port serwera w pliku `.env` lub użyj parametru `--port`:

```bash
ollama-server run --port 8080
```

### Problem: Model nie jest dostępny

**Rozwiązanie**: Pobierz model za pomocą komendy:

```bash
ollama pull tinyllama
```

Lub przy użyciu naszego CLI:

```bash
ollama-server setup-model tinyllama
```