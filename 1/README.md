# Serwer MCP z obsługą SQLite, systemu plików i emaili

![MCP Logo](https://modelcontextprotocol.io/images/mcp_hero.svg)

Ten projekt implementuje serwer Model Context Protocol (MCP), który umożliwia modelom językowym (takim jak Claude) bezpieczny i ustandaryzowany dostęp do następujących funkcjonalności:
- Wykonywania zapytań do bazy danych SQLite
- Operacji na plikach lokalnych (odczyt, zapis, listowanie)
- Wysyłki i zarządzania emailami przez SMTP

## 📋 Spis treści

- [Wprowadzenie do MCP](#wprowadzenie-do-mcp)
- [Architektura systemu](#architektura-systemu)
- [Wymagania](#wymagania)
- [Instalacja](#instalacja)
- [Uruchamianie serwera](#uruchamianie-serwera)
- [Konfiguracja](#konfiguracja)
- [Dostępne narzędzia](#dostępne-narzędzia)
  - [SQLite](#sqlite)
  - [System plików](#system-plików)
  - [Email](#email)
- [Przykłady użycia](#przykłady-użycia)
- [Bezpieczeństwo](#bezpieczeństwo)
- [Rozwiązywanie problemów](#rozwiązywanie-problemów)
- [Rozszerzanie funkcjonalności](#rozszerzanie-funkcjonalności)
- [Licencja](#licencja)

## 📘 Wprowadzenie do MCP

Model Context Protocol (MCP) to otwarty standard, który umożliwia modelom językowym (LLM) ustandaryzowany dostęp do zewnętrznych danych i narzędzi. Działa podobnie jak API webowe, ale jest specjalnie zaprojektowane dla interakcji z LLM.

Główne koncepcje w MCP:
- **Resources**: podobne do endpointów GET - dostarczają dane do kontekstu LLM
- **Tools**: podobne do endpointów POST - wykonują akcje i wywołują efekty uboczne
- **Prompts**: szablony interakcji z LLM

Więcej informacji można znaleźć na [oficjalnej stronie MCP](https://modelcontextprotocol.io).

## 🏗️ Architektura systemu

```
┌───────────────────┐         ┌───────────────────┐
│                   │         │                   │
│  Claude Desktop   │◄────────►   MCP Serwer      │
│  lub inny klient  │         │                   │
│                   │         │                   │
└───────────────────┘         └─────────┬─────────┘
                                       ▲
                                       │
                                       ▼
                              ┌─────────────────┐
                              │                 │
                              │  SQLite DB      │
                              │                 │
                              └─────────────────┘
                                       ▲
                                       │
                                       ▼
                              ┌─────────────────┐
                              │                 │
                              │ System Plików   │
                              │                 │
                              └─────────────────┘
                                       ▲
                                       │
                                       ▼
                              ┌─────────────────┐
                              │                 │
                              │ Serwer SMTP     │
                              │                 │
                              └─────────────────┘
```

Serwer MCP udostępnia następujące komponenty:
- **Baza danych SQLite**: do przechowywania i zapytań o dane strukturalne
- **System plików**: do operacji na plikach w bezpiecznej, wydzielonej przestrzeni
- **Klient SMTP**: do wysyłania wiadomości email

## 🔧 Wymagania

- Python 3.8 lub nowszy
- pip (menedżer pakietów Python)
- Dostęp do serwera SMTP (dla funkcjonalności email)
- Claude Desktop lub inny klient MCP (opcjonalnie)

### Wymagane pakiety Python:
- mcp[cli] - oficjalne SDK Model Context Protocol
- aiosqlite - asynchroniczny interfejs do SQLite
- aiosmtplib - asynchroniczny klient SMTP
- aiofiles - asynchroniczne operacje na plikach

## 📥 Instalacja

### Automatyczna instalacja za pomocą skryptu

1. Nadaj uprawnienia do wykonania skryptu:
   ```bash
   chmod +x install.sh
   ```

2. Uruchom skrypt instalacyjny:
   ```bash
   ./install.sh
   ```

### Ręczna instalacja

1. Utwórz wirtualne środowisko Python:
   ```bash
   python3 -m venv mcp_env
   source mcp_env/bin/activate
   ```

2. Zainstaluj wymagane pakiety:
   ```bash
   pip install --upgrade pip
   pip install "mcp[cli]" aiosqlite aiosmtplib aiofiles
   ```

3. Utwórz strukturę katalogów:
   ```bash
   mkdir -p mcp_server/data
   ```

4. Skopiuj pliki źródłowe z repozytorium do katalogu `mcp_server/`.

## 🚀 Uruchamianie serwera

### Podstawowe uruchomienie

```bash
source mcp_env/bin/activate
python mcp_server/server.sh
```

Lub użyj skryptu:
```bash
./run.sh
```

### Testowanie z MCP Inspector

```bash
source mcp_env/bin/activate
mcp dev mcp_server/server.sh
```

Lub użyj skryptu:
```bash
./test.sh
```

### Instalacja w Claude Desktop

```bash
source mcp_env/bin/activate
mcp install mcp_server/server.sh
```

Lub użyj skryptu:
```bash
./install_in_claude.sh
```

### Parametry uruchomienia

Serwer można uruchomić z dodatkowymi parametrami:

```bash
# Uruchomienie z określoną nazwą serwera
mcp install mcp_server/server.sh --name "Mój serwer MCP"

# Uruchomienie z dodatkowymi zmiennymi środowiskowymi
mcp install mcp_server/server.sh -v API_KEY=abc123 -v DB_URL=sqlite:///path/to/db

# Uruchomienie z plikiem zmiennych środowiskowych
mcp install mcp_server/server.sh -f .env
```

## ⚙️ Konfiguracja

### Konfiguracja bazy danych SQLite

Baza danych SQLite znajduje się w pliku `mcp_server/data/database.db`. Możesz zmodyfikować schemat bazy danych, edytując skrypt `mcp_server/init_db.py`.

Domyślnie tworzona jest tabela `users` z przykładowymi danymi. Możesz dostosować schemat według własnych potrzeb.

### Konfiguracja systemu plików

System plików jest ograniczony do katalogu `mcp_server/data/`. Jest to katalog bazowy dla wszystkich operacji na plikach, co zapewnia izolację i bezpieczeństwo.

### Konfiguracja email

Konfiguracja serwera SMTP znajduje się w pliku `mcp_server/email_config.py`. Przed użyciem funkcjonalności email, należy zaktualizować ten plik własnymi danymi:

```python
# Konfiguracja serwera SMTP
SMTP_CONFIG = {
    "host": "smtp.example.com",  # Zmień na swój serwer SMTP
    "port": 587,
    "username": "user@example.com",  # Zmień na swój login
    "password": "password",  # Zmień na swoje hasło
    "use_tls": True
}

# Konfiguracja domyślnych ustawień email
DEFAULT_EMAIL = {
    "from_addr": "user@example.com",  # Zmień na swój adres email
    "reply_to": "user@example.com"  # Zmień na swój adres email
}
```

## 🛠️ Dostępne narzędzia

### SQLite

#### Narzędzia (Tools)

- **sqlite_query(query: str) -> str** 
  - Wykonuje zapytanie SELECT do bazy danych SQLite
  - Parametry:
    - `query`: Zapytanie SQL (tylko instrukcje SELECT)
  - Zwraca:
    - Wyniki zapytania w formacie tekstowej tabeli lub komunikat o błędzie

#### Zasoby (Resources)

- **schema://tables**
  - Udostępnia schemat wszystkich tabel w bazie danych
  - Zwraca:
    - Tekstowa reprezentacja schematu tabel z ich definicjami SQL

#### Przykładowe użycie

```
sqlite_query("SELECT * FROM users LIMIT 3")
```

### System plików

#### Narzędzia (Tools)

- **fs_list_files(directory: str = "") -> str**
  - Listuje pliki w określonym katalogu (względem katalogu `data`)
  - Parametry:
    - `directory`: Ścieżka do katalogu (opcjonalna, domyślnie katalog główny `data`)
  - Zwraca:
    - Lista plików i katalogów w formacie tekstowym

- **fs_read_file(filepath: str) -> str**
  - Odczytuje zawartość pliku (względem katalogu `data`)
  - Parametry:
    - `filepath`: Ścieżka do pliku
  - Zwraca:
    - Zawartość pliku lub komunikat o błędzie

- **fs_write_file(filepath: str, content: str) -> str**
  - Zapisuje zawartość do pliku (względem katalogu `data`)
  - Parametry:
    - `filepath`: Ścieżka do pliku
    - `content`: Zawartość do zapisania
  - Zwraca:
    - Komunikat o sukcesie lub błędzie

#### Przykładowe użycie

```
fs_list_files()
fs_read_file("config.json")
fs_write_file("notes/note1.txt", "To jest przykładowa notatka")
```

### Email

#### Narzędzia (Tools)

- **email_send(to: str, subject: str, body: str) -> str**
  - Wysyła email do określonego odbiorcy
  - Parametry:
    - `to`: Adres email odbiorcy
    - `subject`: Temat wiadomości
    - `body`: Treść wiadomości
  - Zwraca:
    - Komunikat o sukcesie lub błędzie

#### Przykładowe użycie

```
email_send("odbiorca@example.com", "Ważna informacja", "Treść wiadomości email")
```

## 📝 Przykłady użycia

### Przykład 1: Integracja z bazą danych i systemem plików

```
# Wykonanie zapytania do bazy danych
wynik = sqlite_query("SELECT name, email FROM users WHERE id = 1")

# Zapisanie wyniku do pliku
fs_write_file("wynik_zapytania.txt", wynik)

# Listowanie plików w katalogu
pliki = fs_list_files()
```

### Przykład 2: Wysyłanie raportu email

```
# Pobranie danych z bazy
dane = sqlite_query("SELECT name, email FROM users")

# Utworzenie treści raportu
raport = "Raport użytkowników:\n\n" + dane

# Wysłanie raportu mailem
email_send("szef@firma.com", "Raport dzienny", raport)
```

### Przykład 3: Tworzenie i aktualizacja pliku konfiguracyjnego

```
# Sprawdzenie, czy plik istnieje
try:
    konfiguracja = fs_read_file("config.json")
    print("Odczytano istniejącą konfigurację")
except:
    # Utworzenie nowego pliku konfiguracyjnego
    nowa_konfiguracja = '{"opcja1": "wartość1", "opcja2": true}'
    fs_write_file("config.json", nowa_konfiguracja)
    print("Utworzono nową konfigurację")
```

## 🔒 Bezpieczeństwo

### Zabezpieczenia SQLite

- Serwer pozwala tylko na wykonywanie zapytań SELECT, co zapobiega modyfikacji bazy danych
- Wszystkie zapytania są wykonywane asynchronicznie, co zmniejsza ryzyko blokowania serwera

### Zabezpieczenia systemu plików

- Dostęp do plików jest ograniczony tylko do katalogu `data`
- Wszystkie ścieżki są weryfikowane, aby zapobiec atakom typu path traversal
- Operacje na plikach są wykonywane asynchronicznie

### Zabezpieczenia email

- Używanie TLS do szyfrowania połączenia z serwerem SMTP
- Konfiguracja przechowywana jest oddzielnie od kodu serwera
- Operacje SMTP są wykonywane asynchronicznie

## ❓ Rozwiązywanie problemów

### Problem: Serwer nie uruchamia się

**Rozwiązanie:**
- Sprawdź, czy środowisko wirtualne jest aktywowane
- Sprawdź, czy wszystkie zależności są zainstalowane
- Sprawdź logi błędów w terminalu

### Problem: Błędy przy operacjach na plikach

**Rozwiązanie:**
- Sprawdź, czy katalog `mcp_server/data` istnieje i ma odpowiednie uprawnienia
- Upewnij się, że ścieżki są podawane względem katalogu `data`

### Problem: Błędy przy wysyłaniu emaili

**Rozwiązanie:**
- Sprawdź poprawność konfiguracji SMTP w pliku `email_config.py`
- Upewnij się, że serwer SMTP jest dostępny i akceptuje połączenia
- Sprawdź, czy poświadczenia logowania są poprawne

## 🔌 Rozszerzanie funkcjonalności

### Dodawanie nowych narzędzi SQLite

Aby dodać nowe narzędzie SQLite, dodaj nową funkcję z dekoratorem `@mcp.tool()` w pliku `server.py`:

```python
@mcp.tool()
async def sqlite_count_records(table_name: str, ctx: Context) -> str:
    """Zlicza ilość rekordów w tabeli."""
    query = f"SELECT COUNT(*) as count FROM {table_name}"
    try:
        async with aiosqlite.connect(DB_PATH) as db:
            async with db.execute(query) as cursor:
                result = await cursor.fetchone()
                return f"Liczba rekordów w tabeli {table_name}: {result[0]}"
    except Exception as e:
        return f"Błąd: {str(e)}"
```

### Dodawanie nowych funkcjonalności systemu plików

Przykład dodania nowego narzędzia do kopiowania plików:

```python
@mcp.tool()
async def fs_copy_file(source: str, destination: str, ctx: Context) -> str:
    """Kopiuje plik z jednej lokalizacji do drugiej."""
    source_path = os.path.normpath(os.path.join(DATA_DIR, source))
    dest_path = os.path.normpath(os.path.join(DATA_DIR, destination))
    
    # Sprawdzenie bezpieczeństwa ścieżek
    if not source_path.startswith(DATA_DIR) or not dest_path.startswith(DATA_DIR):
        return "Błąd: Niedozwolona ścieżka."
    
    try:
        # Odczyt źródłowego pliku
        async with aiofiles.open(source_path, 'rb') as src_file:
            content = await src_file.read()
        
        # Zapis do docelowego pliku
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        async with aiofiles.open(dest_path, 'wb') as dest_file:
            await dest_file.write(content)
        
        return f"Plik został skopiowany z {source} do {destination}"
    except Exception as e:
        return f"Błąd podczas kopiowania pliku: {str(e)}"
```

### Integracja z innymi usługami

Można rozszerzyć serwer MCP o integrację z innymi usługami, takimi jak API REST, bazy NoSQL, itp. Poniżej przykład integracji z API pogodowym:

```python
import httpx

@mcp.tool()
async def get_weather(city: str, ctx: Context) -> str:
    """Pobiera dane pogodowe dla określonego miasta."""
    API_KEY = "your_api_key"  # Zastąp swoim kluczem API
    
    try:
        await ctx.info(f"Pobieranie danych pogodowych dla {city}...")
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"https://api.weatherapi.com/v1/current.json?key={API_KEY}&q={city}"
            )
            
            if response.status_code != 200:
                return f"Błąd: Nie udało się pobrać danych pogodowych. Kod: {response.status_code}"
            
            data = response.json()
            temp_c = data["current"]["temp_c"]
            condition = data["current"]["condition"]["text"]
            
            return f"Pogoda w {city}: {condition}, {temp_c}°C"
    except Exception as e:
        return f"Błąd podczas pobierania danych pogodowych: {str(e)}"
```

## 📄 Licencja

Ten projekt jest dostępny na licencji Apache . Zobacz plik LICENSE dla szczegółów.

---

## 📞 Kontakt i wsparcie

Jeśli masz pytania lub potrzebujesz pomocy, utwórz issue w repozytorium projektu lub skontaktuj się z autorem.

---

**Projekt wykorzystuje Model Context Protocol (MCP)**, otwarty standard rozwijany przez Anthropic.
Więcej informacji: [modelcontextprotocol.io](https://modelcontextprotocol.io)