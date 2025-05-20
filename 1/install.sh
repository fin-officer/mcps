#!/bin/bash

# Skrypt instalacyjny dla serwera MCP z obsługą SQLite, systemu plików i emaili
set -e  # Zatrzymanie skryptu przy błędzie

echo "==== Instalacja serwera MCP z obsługą SQLite, systemu plików i emaili ===="

# Sprawdzenie wymaganych narzędzi
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "Błąd: Wymagane narzędzie '$1' nie jest zainstalowane."
        exit 1
    fi
}

check_command python3
check_command pip

# Konfiguracja środowiska
echo "Tworzenie wirtualnego środowiska Python..."
VENV_DIR="mcp_env"
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

# Instalacja zależności
echo "Instalacja zależności..."
pip install --upgrade pip
pip install "mcp[cli]"  # Główne SDK MCP
pip install sqlite3 aiosqlite aiosmtplib aiofiles  # Zależności dla narzędzi

# Tworzenie struktury katalogów
echo "Tworzenie struktury katalogów..."
mkdir -p mcp_server/data

# Tworzenie przykładowej bazy SQLite
echo "Tworzenie przykładowej bazy SQLite..."
cat > mcp_server/init_db.py << 'EOL'
import sqlite3

conn = sqlite3.connect('mcp_server/data/database.db')
cursor = conn.cursor()

# Tworzenie przykładowej tabeli
cursor.execute('''
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
)
''')

# Dodanie przykładowych danych
sample_users = [
    (1, "Jan Kowalski", "jan@example.com"),
    (2, "Anna Nowak", "anna@example.com"),
    (3, "Piotr Wiśniewski", "piotr@example.com")
]

cursor.executemany(
    "INSERT OR REPLACE INTO users (id, name, email) VALUES (?, ?, ?)",
    sample_users
)

conn.commit()
conn.close()

print("Baza danych została zainicjalizowana.")
EOL

python mcp_server/init_db.py

# Tworzenie pliku konfiguracji email
echo "Tworzenie konfiguracji email..."
cat > mcp_server/email_config.py << 'EOL'
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
EOL

# Tworzenie pliku serwera MCP
echo "Tworzenie serwera MCP..."
cat > mcp_server/server.py << 'EOL'
import os
import aiosqlite
import aiofiles
import aiosmtplib
from email.message import EmailMessage
from mcp.server.fastmcp import FastMCP, Context
from email_config import SMTP_CONFIG, DEFAULT_EMAIL

# Tworzenie serwera MCP
mcp = FastMCP("MCP Server z SQLite, systemem plików i emailami")

# Konfiguracja ścieżek
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
DB_PATH = os.path.join(DATA_DIR, "database.db")

# Narzędzia SQLite
@mcp.tool()
async def sqlite_query(query: str, ctx: Context) -> str:
    """Wykonaj zapytanie SQLite (tylko SELECT)."""
    if not query.strip().upper().startswith("SELECT"):
        return "Błąd: Dozwolone są tylko zapytania SELECT."

    try:
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            await ctx.info(f"Wykonywanie zapytania: {query}")

            async with db.execute(query) as cursor:
                rows = await cursor.fetchall()

                if not rows:
                    return "Zapytanie nie zwróciło żadnych wyników."

                # Pobranie nazw kolumn
                columns = [description[0] for description in cursor.description]

                # Formatowanie wyników jako tabela tekstowa
                result = [", ".join(columns)]
                for row in rows:
                    result.append(", ".join(str(row[col]) for col in columns))

                return "\n".join(result)
    except Exception as e:
        return f"Błąd zapytania SQLite: {str(e)}"

@mcp.resource("schema://tables")
async def get_schema() -> str:
    """Pobierz schemat tabel w bazie danych."""
    query = "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"

    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute(query) as cursor:
            tables = await cursor.fetchall()

            result = []
            for table_name, table_sql in tables:
                result.append(f"### Tabela: {table_name}\n")
                result.append(f"```sql\n{table_sql}\n```\n")

            return "\n".join(result) if result else "Brak tabel w bazie danych."

# Narzędzia systemu plików
@mcp.tool()
async def fs_list_files(directory: str = "") -> str:
    """Wylistuj pliki w katalogu (względnie do katalogu data)."""
    target_dir = os.path.normpath(os.path.join(DATA_DIR, directory))

    # Sprawdzenie czy ścieżka jest w obrębie DATA_DIR (zabezpieczenie)
    if not target_dir.startswith(DATA_DIR):
        return f"Błąd: Niedozwolona ścieżka. Dostęp możliwy tylko do katalogu {DATA_DIR}."

    try:
        entries = os.listdir(target_dir)
        result = []
        for entry in entries:
            full_path = os.path.join(target_dir, entry)
            entry_type = "katalog" if os.path.isdir(full_path) else "plik"
            size = os.path.getsize(full_path) if os.path.isfile(full_path) else "-"
            result.append(f"{entry} ({entry_type}, {size} bajtów)")

        return "\n".join(result) if result else "Katalog jest pusty."
    except Exception as e:
        return f"Błąd podczas listowania plików: {str(e)}"

@mcp.tool()
async def fs_read_file(filepath: str) -> str:
    """Odczytaj zawartość pliku (względnie do katalogu data)."""
    target_path = os.path.normpath(os.path.join(DATA_DIR, filepath))

    # Sprawdzenie czy ścieżka jest w obrębie DATA_DIR (zabezpieczenie)
    if not target_path.startswith(DATA_DIR):
        return f"Błąd: Niedozwolona ścieżka. Dostęp możliwy tylko do katalogu {DATA_DIR}."

    try:
        if not os.path.isfile(target_path):
            return f"Błąd: Plik nie istnieje lub nie jest zwykłym plikiem."

        async with aiofiles.open(target_path, 'r') as file:
            content = await file.read()
            return content
    except Exception as e:
        return f"Błąd podczas odczytu pliku: {str(e)}"

@mcp.tool()
async def fs_write_file(filepath: str, content: str, ctx: Context) -> str:
    """Zapisz zawartość do pliku (względnie do katalogu data)."""
    target_path = os.path.normpath(os.path.join(DATA_DIR, filepath))

    # Sprawdzenie czy ścieżka jest w obrębie DATA_DIR (zabezpieczenie)
    if not target_path.startswith(DATA_DIR):
        return f"Błąd: Niedozwolona ścieżka. Dostęp możliwy tylko do katalogu {DATA_DIR}."

    try:
        # Utworzenie katalogu nadrzędnego, jeśli nie istnieje
        os.makedirs(os.path.dirname(target_path), exist_ok=True)

        await ctx.info(f"Zapisywanie do pliku: {filepath}")
        async with aiofiles.open(target_path, 'w') as file:
            await file.write(content)
            return f"Plik został pomyślnie zapisany: {filepath}"
    except Exception as e:
        return f"Błąd podczas zapisu pliku: {str(e)}"

# Narzędzia email
@mcp.tool()
async def email_send(to: str, subject: str, body: str, ctx: Context) -> str:
    """Wyślij email do określonego odbiorcy."""
    try:
        await ctx.info(f"Wysyłanie emaila do: {to}")

        # Tworzenie wiadomości email
        message = EmailMessage()
        message["From"] = DEFAULT_EMAIL["from_addr"]
        message["To"] = to
        message["Subject"] = subject
        message["Reply-To"] = DEFAULT_EMAIL["reply_to"]
        message.set_content(body)

        # Konfiguracja serwera SMTP i wysyłka
        smtp = aiosmtplib.SMTP(
            hostname=SMTP_CONFIG["host"],
            port=SMTP_CONFIG["port"],
            use_tls=SMTP_CONFIG["use_tls"]
        )

        await ctx.info("Łączenie z serwerem SMTP...")
        await smtp.connect()

        await ctx.info("Logowanie do serwera SMTP...")
        await smtp.login(SMTP_CONFIG["username"], SMTP_CONFIG["password"])

        await ctx.info("Wysyłanie wiadomości...")
        await smtp.send_message(message)

        await ctx.info("Rozłączanie z serwerem SMTP...")
        await smtp.quit()

        return f"Email został pomyślnie wysłany do {to}"
    except Exception as e:
        return f"Błąd podczas wysyłania emaila: {str(e)}"

# Uruchomienie serwera MCP
if __name__ == "__main__":
    print(f"Uruchamianie serwera MCP...")
    print(f"- Baza danych: {DB_PATH}")
    print(f"- Katalog danych: {DATA_DIR}")
    mcp.run()
EOL

# Tworzenie pliku README
echo "Tworzenie pliku README..."
cat > README.md << 'EOL'
# Serwer MCP z obsługą SQLite, systemu plików i emaili

Ten projekt implementuje serwer MCP (Model Context Protocol), który udostępnia narzędzia do:
- wykonywania zapytań do bazy SQLite
- operacji na plikach lokalnych (odczyt, zapis, listowanie)
- wysyłki emaili przez SMTP

## Wymagania

- Python 3.8+
- pip

## Instalacja

Uruchom skrypt instalacyjny:

```bash
./install.sh
```

## Uruchamianie serwera

```bash
source mcp_env/bin/activate
python mcp_server/server.py
```

## Testowanie serwera

```bash
source mcp_env/bin/activate
mcp dev mcp_server/server.py
```

## Instalacja serwera w Claude Desktop

```bash
source mcp_env/bin/activate
mcp install mcp_server/server.py
```

## Konfiguracja

- Konfiguracja serwera SMTP znajduje się w pliku `mcp_server/email_config.py`
- Dane SQLite przechowywane są w `mcp_server/data/database.db`
- Pliki serwowane przez serwer przechowywane są w katalogu `mcp_server/data/`

## Dostępne narzędzia

### SQLite
- `sqlite_query` - wykonanie zapytania SELECT do bazy danych
- `schema://tables` - pobranie schematu tabel w bazie danych

### System plików
- `fs_list_files` - listowanie plików w katalogu
- `fs_read_file` - odczyt zawartości pliku
- `fs_write_file` - zapis zawartości do pliku

### Email
- `email_send` - wysyłka emaila do określonego odbiorcy
EOL

# Tworzenie skryptu uruchamiającego
echo "Tworzenie skryptu uruchamiającego..."
cat > run.sh << 'EOL'
#!/bin/bash

source mcp_env/bin/activate
python mcp_server/server.py
EOL

chmod +x run.sh

# Tworzenie skryptu testowego - zmienionego, by nie używać uv
echo "Tworzenie skryptu testowego..."
cat > test.sh << 'EOL'
#!/bin/bash

source mcp_env/bin/activate
mcp dev mcp_server/server.py
EOL

chmod +x test.sh

# Tworzenie skryptu instalacji w Claude Desktop
echo "Tworzenie skryptu instalacji w Claude Desktop..."
cat > install_in_claude.sh << 'EOL'
#!/bin/bash

source mcp_env/bin/activate
mcp install mcp_server/server.py
EOL

chmod +x install_in_claude.sh

# Nadanie uprawnień do wykonania
chmod +x install.sh

echo "==== Instalacja zakończona ===="
echo ""
echo "Aby uruchomić serwer MCP, wykonaj:"
echo "./run.sh"
echo ""
echo "Aby przetestować serwer MCP z inspektorem, wykonaj:"
echo "./test.sh"
echo ""
echo "Aby zainstalować serwer w Claude Desktop, wykonaj:"
echo "./install_in_claude.sh"
echo ""
echo "UWAGA: Przed użyciem emaili, pamiętaj o zaktualizowaniu konfiguracji SMTP w pliku mcp_server/email_config.py"