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
