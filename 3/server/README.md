# Struktura Pakietu Python dla Ollama Server

Stworzyliśmy kompletną strukturę pakietu Python dla Ollama Server, używając nowoczesnego narzędzia do zarządzania zależnościami - Poetry. Poniżej przedstawiam podsumowanie struktury projektu i instrukcje, jak go używać.

## Pliki i struktura projektu

```
ollama-server/
│
├── ollama_server/                # Główny pakiet
│   ├── __init__.py              # Inicjalizacja pakietu
│   ├── api.py                   # API i endpointy REST
│   ├── cli.py                   # Interfejs wiersza poleceń
│   ├── config.py                # Konfiguracja i ładowanie ustawień
│   ├── models.py                # Operacje na modelach Ollama
│   ├── server.py                # Główny serwer Flask
│   ├── utils.py                 # Funkcje pomocnicze
│   └── web/                     # Pliki związane z interfejsem webowym
│       ├── __init__.py
│       ├── static/              # Statyczne pliki (CSS, JS)
│       │   ├── css/
│       │   │   └── style.css
│       │   └── js/
│       │       └── script.js
│       └── templates/           # Szablony HTML
│           ├── base.html
│           ├── index.html
│           └── error.html
│
├── tests/                       # Testy
│   ├── __init__.py
│   ├── test_api.py
│   ├── test_config.py
│   └── test_models.py
│
├── pyproject.toml              # Konfiguracja Poetry
├── .env.example                # Przykładowy plik konfiguracyjny
├── .gitignore                  # Pliki ignorowane przez Git
├── LICENSE                     # Licencja MIT
├── README.md                   # Główna dokumentacja
└── INSTALLATION.md             # Instrukcja instalacji
```

## Najważniejsze funkcje pakietu

1. **Modułowa architektura** - pakiet podzielony na logiczne moduły (API, modele, konfiguracja, itp.)
2. **Interfejs wiersza poleceń** - wykonywanie zadań bezpośrednio z terminala
3. **Interfejs webowy** - przeglądarkowy GUI dla łatwiejszej interakcji
4. **REST API** - dla integracji z innymi aplikacjami
5. **Obsługa różnych modeli Ollama** - z możliwością łatwego przełączania
6. **Konfiguracja przez .env** - proste zarządzanie ustawieniami
7. **Testy jednostkowe** - dla zapewnienia niezawodności

## Jak używać pakietu

### Instalacja

```bash
# Instalacja przy użyciu Poetry
git clone https://github.com/username/ollama-server.git
cd ollama-server
poetry install
poetry shell

# Lub instalacja przy użyciu pip
pip install -e .
```

### Uruchamianie serwera

```bash
# Przy użyciu skryptu CLI
ollama-server run

# Opcje konfiguracyjne
ollama-server run --host 0.0.0.0 --port 8080 --debug
```

### Korzystanie z CLI

```bash
# Wyświetlenie listy modeli
ollama-server models

# Konfiguracja modelu
ollama-server setup-model tinyllama

# Zadanie pytania do modelu
ollama-server ask "Co to jest Python?"

# Wyświetlenie informacji o konfiguracji
ollama-server info
```

### API REST

Serwer udostępnia następujące endpointy:

- `POST /api/ask` - zadanie pytania do modelu
- `GET /api/models` - lista dostępnych modeli
- `POST /api/switch_model` - zmiana aktywnego modelu
- `POST /api/echo` - testowanie serwera

### Interfejs webowy

Dostępny pod adresem: `http://localhost:5001`

## Dalszy rozwój

Pakiet można rozwijać w kilku kierunkach:

1. Dodanie obsługi strumieniowania odpowiedzi (streaming)
2. Implementacja historii konwersacji
3. Dodanie zaawansowanych funkcji UI (wcięcia kodu, podświetlanie składni, itp.)
4. Rozszerzenie o obsługę innych backendów LLM (np. LocalAI)
5. Dodanie wsparcia dla modeli multimodalnych (np. LLaVA)

## Publikacja pakietu

Aby opublikować pakiet na PyPI, należy wykonać:

```bash
poetry build
poetry publish
```


### Struktura pakietu

Przygotowałem modułową strukturę pakietu zgodną z najlepszymi praktykami Pythona:

1. **Plik konfiguracyjny Poetry (`pyproject.toml`)**:
   - Zawiera definicję pakietu, zależności i narzędzia budowania
   - Umożliwia publikację na PyPI

2. **Główne moduły aplikacji**:
   - `api.py` - implementacja REST API do komunikacji z modelami Ollama
   - `cli.py` - interfejs wiersza poleceń z różnymi funkcjami
   - `config.py` - zarządzanie konfiguracją i plikiem .env
   - `models.py` - operacje na modelach Ollama (z informacjami o 19 modelach)
   - `server.py` - główny serwer Flask
   - `utils.py` - funkcje pomocnicze do zarządzania procesami Ollama

3. **Interfejs webowy**:
   - Szablony HTML w `web/templates/`
   - Style CSS i skrypty JavaScript w `web/static/`
   - Responsywny design i współczesny wygląd

4. **Testy**:
   - Testy jednostkowe dla każdego kluczowego modułu
   - Konfiguracja pytest

5. **Dokumentacja**:
   - Instrukcja instalacji (`INSTALLATION.md`)
   - Licencja MIT (`LICENSE`)
   - Pliki konfiguracyjne (`.env.example`, `.gitignore`)

### Kluczowe funkcje

1. **Zarządzanie modelami**:
   - Informacje o 19 różnych modelach Ollama
   - Funkcje do pobierania i przełączania modeli
   - Automatyczne wykrywanie odpowiedniego modelu dla systemu

2. **Interfejs webowy**:
   - Zadawanie pytań do modelu w przeglądarce
   - Zmiana parametrów generowania (temperatura, liczba tokenów)
   - Przełączanie aktywnego modelu

3. **REST API**:
   - Endpointy do zadawania pytań (`/api/ask`)
   - Pobieranie listy modeli (`/api/models`)
   - Przełączanie modelu (`/api/switch_model`)
   - Endpoint testowy (`/api/echo`)

4. **Interfejs CLI**:
   - Uruchamianie serwera (`run`)
   - Wyświetlanie informacji (`info`)
   - Zarządzanie modelami (`models`, `setup-model`)
   - Zadawanie pytań z terminala (`ask`)

### Jak używać pakietu

Pakiet można zainstalować i używać na kilka sposobów:

1. **Instalacja z repozytorium**:
   ```bash
   git clone https://github.com/username/ollama-server.git
   cd ollama-server
   poetry install
   poetry shell
   ```

2. **Uruchamianie serwera**:
   ```bash
   ollama-server run
   ```

3. **Korzystanie z CLI**:
   ```bash
   ollama-server models
   ollama-server ask "Co to jest Python?"
   ```

4. **Korzystanie z interfejsu webowego**:
   Otwórz przeglądarkę pod adresem: `http://localhost:5001`

Pakiet jest gotowy do użycia i dalszego rozwoju. Może być również opublikowany na PyPI w przyszłości, aby umożliwić instalację za pomocą `pip install ollama-server`.


