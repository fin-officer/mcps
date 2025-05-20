#!/bin/bash

# Bezpośredni skrypt testowy, który uruchamia serwer MCP bez użycia uv
# i bez wymagania Claude Desktop

# Aktywacja środowiska wirtualnego
source mcp_env/bin/activate

echo "==== Bezpośredni test serwera MCP ===="

# Sprawdzenie czy wymagane pakiety są zainstalowane
required_packages=("mcp" "aiosqlite" "aiofiles" "httpx")
missing_packages=()

for package in "${required_packages[@]}"; do
    if ! pip show $package &>/dev/null; then
        missing_packages+=("$package")
    fi
done

if [ ${#missing_packages[@]} -gt 0 ]; then
    echo "Instalacja brakujących pakietów: ${missing_packages[*]}"
    pip install ${missing_packages[*]}
fi

# Tworzenie testowego środowiska
mkdir -p mcp_server/data

# Tworzenie skryptu serwera MCP
cat > mcp_server/simple_server.py << 'EOL'
import os
import sqlite3
import asyncio
from mcp.server import Server, Tool

# Definicja prostego narzędzia
class SimpleTool(Tool):
    """Proste narzędzie testowe."""

    async def call(self, arguments):
        # Metoda wywoływana, gdy narzędzie jest używane
        message = arguments.get("message", "brak wiadomości")
        return f"Otrzymano wiadomość: {message}"

# Inicjalizacja serwera MCP
server = Server()

# Rejestracja narzędzia
server.register_tool(SimpleTool(name="echo", description="Proste narzędzie echo"))

# Główna funkcja uruchamiająca serwer
async def run_server():
    from mcp.server.stdio import stdio_server

    print("Uruchamianie serwera MCP w trybie stdio...")

    # Uruchomienie serwera w trybie stdio
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options(
                server_name="Simple MCP Server",
                server_version="1.0.0"
            )
        )

# Uruchomienie serwera
if __name__ == "__main__":
    asyncio.run(run_server())
EOL

# Tworzenie skryptu testowego klienta
cat > mcp_server/test_client.py << 'EOL'
import asyncio
import json
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def run_test():
    # Parametry dla połączenia stdio do lokalnego skryptu
    server_params = StdioServerParameters(
        command="python",
        args=["mcp_server/simple_server.py"]
    )

    try:
        print("Łączenie z serwerem MCP...")
        # Nawiązanie połączenia z serwerem
        async with stdio_client(server_params) as (read, write):
            async with ClientSession(read, write) as session:
                # Inicjalizacja połączenia
                await session.initialize()

                # Listowanie dostępnych narzędzi
                tools = await session.list_tools()
                print(f"Dostępne narzędzia: {[tool.name for tool in tools]}")

                # Wywołanie narzędzia echo
                if any(tool.name == "echo" for tool in tools):
                    print("Wywołanie narzędzia 'echo'...")
                    result = await session.call_tool("echo", {"message": "Testowa wiadomość"})
                    print(f"Otrzymana odpowiedź: {result.text}")
                else:
                    print("Narzędzie 'echo' nie jest dostępne")

                print("Test zakończony pomyślnie!")
    except Exception as e:
        print(f"Błąd podczas testu: {str(e)}")

if __name__ == "__main__":
    asyncio.run(run_test())
EOL

# Uruchomienie testu
echo "Uruchamianie testu klienta MCP..."
python mcp_server/test_client.py

# Zapytanie czy użytkownik chce uruchomić serwer w trybie interaktywnym
echo ""
echo "Czy chcesz uruchomić serwer MCP w trybie interaktywnym? (t/n): "
read answer

if [[ "$answer" == "t" ]]; then
    echo "Uruchamianie serwera MCP..."
    python mcp_server/simple_server.py
else
    echo "Test zakończony."
fi