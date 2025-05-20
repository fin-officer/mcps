#!/bin/bash

# Skrypt do bezpośredniego uruchomienia MCP Inspector
# bez korzystania z polecenia uv

# Aktywacja środowiska wirtualnego
source mcp_env/bin/activate

echo "==== Bezpośredni test MCP Inspector ===="

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

# Tworzenie prostego serwera MCP dla testów
mkdir -p mcp_server

# Jeśli nie istnieje prosty serwer, utwórz go
if [ ! -f "mcp_server/basic_server.py" ]; then
    echo "Tworzenie testowego serwera MCP..."
    cat > mcp_server/basic_server.py << 'EOL'
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
    mcp.run()
EOL
fi

# Uruchomienie serwera MCP bezpośrednio z Pythonem
echo "Uruchamianie serwera MCP w osobnym terminalu..."
gnome-terminal -- bash -c "source mcp_env/bin/activate && python mcp_server/basic_server.py; read -p 'Naciśnij Enter, aby zamknąć...' dummy" || \
xterm -e "source mcp_env/bin/activate && python mcp_server/basic_server.py; read -p 'Naciśnij Enter, aby zamknąć...' dummy" || \
konsole --new-tab -e "source mcp_env/bin/activate && python mcp_server/basic_server.py; read -p 'Naciśnij Enter, aby zamknąć...' dummy" || \
(
    echo "Nie udało się otworzyć nowego terminala."
    echo "Uruchamianie serwera w tle..."
    source mcp_env/bin/activate
    python mcp_server/basic_server.py &
    SERVER_PID=$!
    echo "Serwer MCP uruchomiony w tle (PID: $SERVER_PID)"
    echo "Aby zakończyć, naciśnij Ctrl+C lub zamknij terminal"

    # Zapisanie PID do pliku
    echo $SERVER_PID > mcp_server.pid
)

echo "Teraz możesz połączyć się z serwerem MCP za pomocą klienta."
echo "Aby przetestować, uruchom w nowym terminalu:"
echo "source mcp_env/bin/activate && python -c \"
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def test():
    params = StdioServerParameters(command='python', args=['mcp_server/basic_server.py'])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            print(f'Dostępne narzędzia: {[tool.name for tool in tools]}')
            result = await session.call_tool('echo', {'message': 'Test działa!'})
            print(f'Wynik: {result.text}')

asyncio.run(test())
\""

echo "Naciśnij Ctrl+C, aby zakończyć serwer"
wait