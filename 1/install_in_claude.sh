#!/bin/bash

# Skrypt do instalacji serwera MCP w Claude Desktop z integracją Ollama Tiny model
# Ten skrypt tworzy i instaluje serwer w Claude Desktop

# Aktywacja środowiska wirtualnego
source mcp_env/bin/activate

# Sprawdzenie czy httpx jest zainstalowany (wymagany dla Ollama)
if ! pip show httpx &>/dev/null; then
  echo "Instalacja wymaganych zależności (httpx)..."
  pip install httpx
fi

# Tworzenie katalogu jeśli nie istnieje
mkdir -p mcp_server

# Tworzenie konfiguracji dla Ollamy
echo "Tworzenie konfiguracji dla modelu Ollama Tiny..."
cat > mcp_server/ollama_config.py << 'EOL'
# Konfiguracja Ollama Tiny model

OLLAMA_CONFIG = {
    "base_url": "http://localhost:11434",
    "model": "tinyllama",  # Możesz zmienić na inny dostępny model Ollama
    "timeout": 30
}

# Parametry generowania tekstu
GENERATION_PARAMS = {
    "temperature": 0.7,
    "top_p": 0.9,
    "max_tokens": 1000
}
EOL

# Tworzenie pliku integracji z Ollama
echo "Tworzenie modułu integracji z Ollama..."
cat > mcp_server/ollama_integration.py << 'EOL'
import httpx
import json
import asyncio
from mcp.server.fastmcp import Context
from ollama_config import OLLAMA_CONFIG, GENERATION_PARAMS

async def query_ollama(prompt: str, ctx: Context = None) -> str:
    """
    Wysyła zapytanie do modelu Ollama i zwraca odpowiedź.

    Args:
        prompt: Tekst zapytania
        ctx: Opcjonalny kontekst MCP do logowania

    Returns:
        str: Odpowiedź od modelu Ollama
    """
    if ctx:
        await ctx.info(f"Wysyłanie zapytania do modelu Ollama ({OLLAMA_CONFIG['model']})...")

    # Przygotowanie danych zapytania
    data = {
        "model": OLLAMA_CONFIG["model"],
        "prompt": prompt,
        **GENERATION_PARAMS
    }

    try:
        # Wysłanie zapytania do API Ollama
        async with httpx.AsyncClient(timeout=OLLAMA_CONFIG["timeout"]) as client:
            response = await client.post(
                f"{OLLAMA_CONFIG['base_url']}/api/generate",
                json=data
            )

            if response.status_code != 200:
                error_msg = f"Błąd odpowiedzi Ollama: {response.status_code}"
                if ctx:
                    await ctx.error(error_msg)
                return error_msg

            # Parsowanie odpowiedzi JSON
            try:
                result = response.json()
                return result.get("response", "Brak odpowiedzi od modelu")
            except json.JSONDecodeError:
                error_msg = "Błąd parsowania odpowiedzi JSON z Ollama"
                if ctx:
                    await ctx.error(error_msg)
                return error_msg

    except httpx.RequestError as e:
        error_msg = f"Błąd połączenia z Ollama: {str(e)}"
        if ctx:
            await ctx.error(error_msg)
        return error_msg
    except Exception as e:
        error_msg = f"Nieoczekiwany błąd: {str(e)}"
        if ctx:
            await ctx.error(error_msg)
        return error_msg
EOL

# Tworzenie serwera MCP z integracją Ollama
echo "Tworzenie serwera MCP z integracją Ollama..."
cat > mcp_server/server.py << 'EOL'
import os
import sqlite3
import aiosqlite
import aiofiles
from mcp.server.fastmcp import FastMCP, Context
from ollama_integration import query_ollama

# Tworzenie serwera MCP
mcp = FastMCP("MCP Serwer z SQLite, System Plików i Ollama Tiny")

# Konfiguracja ścieżek
DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
DB_PATH = os.path.join(DATA_DIR, "database.db")

# Utworzenie katalogu danych, jeśli nie istnieje
os.makedirs(DATA_DIR, exist_ok=True)

# Inicjalizacja bazy danych, jeśli nie istnieje
if not os.path.exists(DB_PATH):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
    ''')

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

# Narzędzia SQLite
@mcp.tool()
async def sqlite_query(query: str, ctx: Context) -> str:
    """Wykonaj zapytanie SQLite (tylko SELECT)."""
    if not query.strip().upper().startswith("SELECT"):
        return "Błąd: Dozwolone są tylko zapytania SELECT dla bezpieczeństwa."

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

# Narzędzie Ollama
@mcp.tool()
async def ollama_ask(prompt: str, ctx: Context) -> str:
    """Generuj odpowiedź używając modelu Ollama Tiny."""
    await ctx.info(f"Wysyłanie zapytania do modelu Ollama: {prompt[:50]}...")
    response = await query_ollama(prompt, ctx)
    return response

# Uruchomienie serwera MCP
if __name__ == "__main__":
    print(f"Uruchamianie serwera MCP...")
    print(f"- Baza danych: {DB_PATH}")
    print(f"- Katalog danych: {DATA_DIR}")
    print(f"- Ollama Tiny model gotowy do użycia")
    mcp.run()
EOL

# Instalacja dodatkowych zależności
pip install aiosqlite aiofiles httpx

# Instalacja serwera w Claude Desktop
echo "Instalowanie serwera MCP w Claude Desktop..."
mcp install mcp_server/server.py --name "MCP z Ollama Tiny (Testowy)"

echo "==== Instalacja zakończona ===="
echo ""
echo "Serwer MCP z integracją Ollama Tiny został zainstalowany w Claude Desktop."
echo ""
echo "UWAGA: Aby korzystać z modelu Ollama Tiny, upewnij się że:"
echo "1. Ollama jest zainstalowana i uruchomiona (https://ollama.com/download)"
echo "2. Model tinyllama jest pobrany (komenda: ollama pull tinyllama)"
echo "3. Serwer Ollama działa na porcie 11434 (domyślny port)"