#!/bin/bash

# Poprawiony skrypt testowy dla MCP, używający FastMCP zamiast Server/Tool
# Ten skrypt jest kompatybilny z nowszymi wersjami SDK MCP

# Aktywacja środowiska wirtualnego
source mcp_env/bin/activate

echo "==== Bezpośredni test serwera MCP (poprawiona wersja) ===="

# Sprawdzenie czy wymagane pakiety są zainstalowane
required_packages=("mcp" "aiosqlite" "aiofiles")
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

# Sprawdzenie zainstalowanej wersji MCP
MCP_VERSION=$(pip show mcp | grep Version | cut -d' ' -f2)
echo "Zainstalowana wersja MCP: $MCP_VERSION"

# Tworzenie skryptu poprawionego serwera MCP z FastMCP
cat > mcp_server/simple_fastmcp_server.py << 'EOL'
from mcp.server.fastmcp import FastMCP

# Tworzenie serwera MCP
mcp = FastMCP("Prosty serwer testowy")

# Proste narzędzie echo
@mcp.tool()
def echo(message: str) -> str:
    """Zwraca otrzymaną wiadomość."""
    return f"Otrzymano: {message}"

# Proste narzędzie kalkulacyjne
@mcp.tool()
def calculate(operation: str, a: float, b: float) -> str:
    """Wykonuje podstawowe operacje matematyczne."""
    if operation == "add":
        result = a + b
    elif operation == "subtract":
        result = a - b
    elif operation == "multiply":
        result = a * b
    elif operation == "divide":
        if b == 0:
            return "Błąd: Dzielenie przez zero"
        result = a / b
    else:
        return f"Nieznana operacja: {operation}"

    return f"Wynik {a} {operation} {b} = {result}"

# Uruchomienie serwera
if __name__ == "__main__":
    print("Uruchamianie serwera MCP (FastMCP)...")
    mcp.run()
EOL

# Tworzenie skryptu testowego klienta
cat > mcp_server/test_client.py << 'EOL'
import asyncio
import sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def run_test():
    # Parametry dla połączenia stdio do lokalnego skryptu
    server_params = StdioServerParameters(
        command="python",
        args=["mcp_server/simple_fastmcp_server.py"]
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

                # Wywołanie narzędzia calculate
                if any(tool.name == "calculate" for tool in tools):
                    print("Wywołanie narzędzia 'calculate'...")
                    result = await session.call_tool("calculate", {"operation": "add", "a": 5, "b": 3})
                    print(f"Wynik dodawania: {result.text}")

                    result = await session.call_tool("calculate", {"operation": "multiply", "a": 4, "b": 7})
                    print(f"Wynik mnożenia: {result.text}")
                else:
                    print("Narzędzie 'calculate' nie jest dostępne")

                print("Test zakończony pomyślnie!")

    except Exception as e:
        print(f"Błąd podczas testu: {str(e)}")
        print(f"Typ wyjątku: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return False

    return True

if __name__ == "__main__":
    success = asyncio.run(run_test())
    # Ustawienie kodu wyjścia na podstawie wyniku testu
    sys.exit(0 if success else 1)
EOL

# Uruchomienie testu
echo "Uruchamianie testu klienta MCP..."
if python mcp_server/test_client.py; then
    echo "Test zakończony pomyślnie!"
else
    echo "Test nie powiódł się. Szczegóły powyżej."
fi

# Zapytanie czy użytkownik chce uruchomić serwer w trybie interaktywnym
echo ""
echo "Czy chcesz uruchomić serwer MCP w trybie interaktywnym? (t/n): "
read answer

if [[ "$answer" == "t" ]]; then
    echo "Uruchamianie serwera MCP..."
    python mcp_server/simple_fastmcp_server.py
else
    echo "Test zakończony."
fi