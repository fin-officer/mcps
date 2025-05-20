#!/bin/bash

# Skrypt do instalacji serwera MCP w Claude Desktop skonfigurowanego
# do testowania z modelem Ollama Tiny Model
set -e  # Zatrzymanie skryptu przy błędzie

echo "==== Instalacja serwera MCP z konfiguracją dla Ollama Tiny Model ===="

# Sprawdzenie czy środowisko wirtualne istnieje
if [ ! -d "mcp_env" ]; then
    echo "Błąd: Nie znaleziono środowiska wirtualnego mcp_env."
    echo "Uruchom najpierw ./install.sh aby skonfigurować projekt."
    exit 1
fi

# Aktywacja środowiska wirtualnego
source mcp_env/bin/activate

# Sprawdzenie czy Ollama jest zainstalowana
if ! command -v ollama &> /dev/null; then
    echo "Ostrzeżenie: Nie znaleziono Ollama w systemie."
    echo "Aby używać tego skryptu, musisz mieć zainstalowaną Ollama ze strony: https://ollama.com/download"

    read -p "Czy chcesz kontynuować mimo to? (t/n): " continue_choice
    if [[ "$continue_choice" != "t" ]]; then
        echo "Instalacja przerwana."
        exit 1
    fi
fi

# Tworzenie pliku konfiguracji dla integracji z Ollama
echo "Tworzenie konfiguracji Ollama..."
cat > mcp_server/ollama_config.py << 'EOL'
# Konfiguracja modelu Ollama

# Podstawowa konfiguracja
OLLAMA_CONFIG = {
    "base_url": "http://localhost:11434",  # Domyślny port Ollama
    "model": "tinyllama:latest",           # Model Tiny LLama (można zmienić na dowolny dostępny model)
    "timeout": 60,                         # Timeout w sekundach
}

# Parametry generacji
GENERATION_PARAMS = {
    "temperature": 0.7,
    "top_p": 0.9,
    "top_k": 40,
    "max_tokens": 2048,
    "presence_penalty": 1.0,
    "frequency_penalty": 1.0,
}
EOL

# Tworzenie narzędzia MCP do korzystania z Ollama
echo "Tworzenie narzędzia MCP dla Ollama..."
cat > mcp_server/ollama_tool.py << 'EOL'
import json
import httpx
from mcp.server.fastmcp import Context
from ollama_config import OLLAMA_CONFIG, GENERATION_PARAMS

async def generate_ollama_response(prompt: str, ctx: Context = None) -> str:
    """
    Funkcja do generowania odpowiedzi z modelu Ollama Tiny.

    Args:
        prompt: Tekst zapytania do modelu
        ctx: Kontekst MCP (opcjonalny)

    Returns:
        Odpowiedź z modelu Ollama
    """
    if ctx:
        await ctx.info(f"Wysyłanie zapytania do modelu Ollama {OLLAMA_CONFIG['model']}...")

    url = f"{OLLAMA_CONFIG['base_url']}/api/generate"

    # Przygotowanie danych zapytania
    data = {
        "model": OLLAMA_CONFIG["model"],
        "prompt": prompt,
        **GENERATION_PARAMS
    }

    try:
        # Wykonanie zapytania do API Ollama
        async with httpx.AsyncClient(timeout=OLLAMA_CONFIG["timeout"]) as client:
            response = await client.post(
                url,
                json=data,
                headers={"Content-Type": "application/json"}
            )

            # Sprawdzenie odpowiedzi
            if response.status_code != 200:
                error_message = f"Błąd komunikacji z Ollama: {response.status_code}"
                if ctx:
                    await ctx.error(error_message)
                return error_message

            # Przetwarzanie odpowiedzi
            try:
                result = response.json()
                return result.get("response", "Brak odpowiedzi od modelu.")
            except json.JSONDecodeError:
                error_message = "Błąd przetwarzania odpowiedzi z Ollama (nieprawidłowy JSON)"
                if ctx:
                    await ctx.error(error_message)
                return error_message

    except httpx.HTTPError as e:
        error_message = f"Błąd HTTP podczas komunikacji z Ollama: {str(e)}"
        if ctx:
            await ctx.error(error_message)
        return error_message
    except Exception as e:
        error_message = f"Nieoczekiwany błąd podczas komunikacji z Ollama: {str(e)}"
        if ctx:
            await ctx.error(error_message)
        return error_message
EOL

# Aktualizacja głównego pliku serwera MCP o narzędzie Ollama
echo "Aktualizacja serwera MCP o narzędzie Ollama..."
cat > mcp_server/server_ollama.py << 'EOL'
import os
import aiosqlite
import aiofiles
from mcp.server.fastmcp import FastMCP, Context
from ollama_tool import generate_ollama_response

# Tworzenie serwera MCP
mcp = FastMCP("MCP Server z SQLite, systemem plików i Ollama")

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

# Narzędzie Ollama
@mcp.tool()
async def ollama_ask(prompt: str, ctx: Context) -> str:
    """Zadaj pytanie do modelu Ollama Tiny."""
    await ctx.info(f"Przetwarzanie zapytania: {prompt}")
    return await generate_ollama_response(prompt, ctx)

# Uruchomienie serwera MCP
if __name__ == "__main__":
    print(f"Uruchamianie serwera MCP z obsługą Ollama...")
    print(f"- Baza danych: {DB_PATH}")
    print(f"- Katalog danych: {DATA_DIR}")
    mcp.run()
EOL

# Instalacja dodatkowych zależności dla Ollama
echo "Instalacja dodatkowych zależności..."
pip install httpx

# Tworzenie skryptu instalacyjnego dla Claude Desktop z serwera Ollama
cat > install_in_claude_ollama.sh << 'EOL'
#!/bin/bash

source mcp_env/bin/activate
echo "Instalowanie serwera MCP z obsługą Ollama w Claude Desktop..."
mcp install mcp_server/server_ollama.py --name "MCP Server z Ollama Tiny"
EOL

chmod +x install_in_claude_ollama.sh

# Tworzenie skryptu testowego dla serwera z Ollama
cat > test_ollama.sh << 'EOL'
#!/bin/bash

source mcp_env/bin/activate
echo "Uruchamianie inspektora MCP dla serwera z Ollama..."
mcp dev mcp_server/server_ollama.py
EOL

chmod +x test_ollama.sh

# Tworzenie skryptu uruchamiającego serwer Ollama
cat > run_ollama.sh << 'EOL'
#!/bin/bash

source mcp_env/bin/activate
echo "Uruchamianie serwera MCP z Ollama..."
python mcp_server/server_ollama.py
EOL

chmod +x run_ollama.sh

# Zakończenie
echo ""
echo "==== Instalacja zakończona ===="
echo ""
echo "Aby uruchomić serwer MCP z Ollama Tiny Model, wykonaj:"
echo "./run_ollama.sh"
echo ""
echo "Aby przetestować serwer MCP z Ollama w inspektorze, wykonaj:"
echo "./test_ollama.sh"
echo ""
echo "Aby zainstalować serwer z Ollama w Claude Desktop, wykonaj:"
echo "./install_in_claude_ollama.sh"
echo ""
echo "UWAGA: Upewnij się, że serwer Ollama jest uruchomiony na porcie 11434"
echo "i model tinyllama jest załadowany (jeśli nie, użyj komendy: ollama pull tinyllama)"