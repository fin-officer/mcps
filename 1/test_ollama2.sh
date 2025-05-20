#!/bin/bash

# Skrypt do testowania podstawowej integracji z Ollama
# Ten skrypt tworzy minimalny serwer MCP z integracją Ollama i testuje go

# Aktywacja środowiska wirtualnego
source mcp_env/bin/activate

echo "==== Test integracji MCP z Ollama ===="

# Sprawdzenie czy wymagane pakiety są zainstalowane
required_packages=("mcp" "httpx")
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

# Tworzenie konfiguracji dla Ollama
cat > mcp_server/ollama_config.py << 'EOL'
# Konfiguracja Ollama

OLLAMA_CONFIG = {
    "base_url": "http://localhost:11434",
    "model": "tinyllama",  # Można zmienić na inny model
    "timeout": 30
}

# Parametry generacji
GENERATION_PARAMS = {
    "temperature": 0.7,
    "top_p": 0.9,
    "max_tokens": 1000
}
EOL

# Tworzenie modułu komunikacji z Ollama
cat > mcp_server/ollama_client.py << 'EOL'
import httpx
import json
import asyncio
from ollama_config import OLLAMA_CONFIG, GENERATION_PARAMS

async def query_ollama(prompt: str):
    """
    Wysyła zapytanie do Ollama API i zwraca odpowiedź.

    Args:
        prompt: Zapytanie do modelu

    Returns:
        str: Odpowiedź od modelu Ollama lub komunikat błędu
    """
    print(f"Wysyłanie zapytania do Ollama ({OLLAMA_CONFIG['model']}): {prompt[:50]}...")

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
                return f"Błąd odpowiedzi z Ollama: {response.status_code}"

            # Przetwarzanie odpowiedzi
            try:
                result = response.json()
                return result.get("response", "Brak odpowiedzi od modelu")
            except json.JSONDecodeError:
                return "Błąd przetwarzania odpowiedzi JSON z Ollama"

    except httpx.RequestError as e:
        return f"Błąd połączenia z Ollama: {str(e)}"
    except Exception as e:
        return f"Nieoczekiwany błąd: {str(e)}"

# Prosty test do uruchomienia bezpośrednio
if __name__ == "__main__":
    async def test():
        response = await query_ollama("Powiedz mi coś o Polsce w jednym zdaniu.")
        print(f"Odpowiedź: {response}")

    asyncio.run(test())
EOL

# Tworzenie prostego serwera MCP z narzędziem Ollama
cat > mcp_server/ollama_server.py << 'EOL'
from mcp.server.fastmcp import FastMCP, Context
from ollama_client import query_ollama

# Tworzenie serwera MCP
mcp = FastMCP("Prosty serwer MCP z integracją Ollama")

# Narzędzie Ollama
@mcp.tool()
async def ollama_ask(prompt: str, ctx: Context) -> str:
    """Zadaj pytanie do modelu Ollama."""
    await ctx.info(f"Przetwarzanie zapytania: {prompt[:50]}...")
    response = await query_ollama(prompt)
    return response

# Proste narzędzie echo dla testów
@mcp.tool()
def echo(message: str) -> str:
    """Zwraca otrzymaną wiadomość."""
    return f"Otrzymano: {message}"

# Uruchomienie serwera
if __name__ == "__main__":
    print("Uruchamianie serwera MCP z integracją Ollama...")
    mcp.run()
EOL

# Tworzenie skryptu testowego klienta dla Ollama
cat > mcp_server/test_ollama_client.py << 'EOL'
import asyncio
import sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def run_test():
    # Parametry dla połączenia stdio do lokalnego skryptu
    server_params = StdioServerParameters(
        command="python",
        args=["mcp_server/ollama_server.py"]
    )

    try:
        print("Łączenie z serwerem MCP z Ollama...")
        # Nawiązanie połączenia z serwerem
        async with stdio_client(server_params) as (read, write):
            async with ClientSession(read, write) as session:
                # Inicjalizacja połączenia
                await session.initialize()

                # Listowanie dostępnych narzędzi
                tools = await session.list_tools()
                print(f"Dostępne narzędzia: {[tool.name for tool in tools]}")

                # Wywołanie narzędzia echo dla testu podstawowej funkcjonalności
                if any(tool.name == "echo" for tool in tools):
                    print("Wywołanie narzędzia 'echo'...")
                    result = await session.call_tool("echo", {"message": "Test działania serwera"})
                    print(f"Otrzymana odpowiedź: {result.text}")
                else:
                    print("Narzędzie 'echo' nie jest dostępne")

                # Wywołanie narzędzia Ollama jeśli jest dostępne
                if any(tool.name == "ollama_ask" for tool in tools):
                    print("Wywołanie narzędzia 'ollama_ask'...")
                    result = await session.call_tool("ollama_ask", {"prompt": "Wymień 3 największe miasta w Polsce."})
                    print(f"Odpowiedź Ollama: {result.text}")
                else:
                    print("Narzędzie 'ollama_ask' nie jest dostępne")

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

# Utworzenie skryptu do bezpośredniego testu Ollama (bez MCP)
cat > test_ollama_direct.py << 'EOL'
import asyncio
import httpx
import json

async def test_ollama_api():
    """Bezpośredni test API Ollama bez MCP."""
    print("Wykonywanie bezpośredniego testu API Ollama...")

    api_url = "http://localhost:11434/api/generate"

    data = {
        "model": "tinyllama",
        "prompt": "Napisz jedno zdanie o Polsce.",
        "temperature": 0.7,
        "max_tokens": 100
    }

    try:
        # Sprawdzenie czy serwer Ollama jest dostępny
        async with httpx.AsyncClient(timeout=5) as client:
            try:
                models_response = await client.get("http://localhost:11434/api/tags")
                if models_response.status_code == 200:
                    models = models_response.json().get("models", [])
                    print(f"Dostępne modele Ollama: {[model['name'] for model in models]}")

                    # Sprawdzenie czy model tinyllama jest dostępny
                    if not any(model["name"] == "tinyllama" for model in models):
                        print("UWAGA: Model 'tinyllama' nie jest zainstalowany!")
                        print("Zainstaluj go komendą: ollama pull tinyllama")
                else:
                    print(f"Błąd przy pobieraniu listy modeli: {models_response.status_code}")
            except Exception as e:
                print(f"Nie można pobrać listy modeli: {str(e)}")

        # Wysłanie zapytania do API
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(api_url, json=data)

            if response.status_code == 200:
                result = response.json()
                print(f"Odpowiedź Ollama: {result.get('response', 'Brak odpowiedzi')}")
                return True
            else:
                print(f"Błąd odpowiedzi: {response.status_code}")
                print(f"Treść odpowiedzi: {response.text}")
                return False

    except httpx.ConnectError:
        print("Błąd połączenia z serwerem Ollama. Czy serwer Ollama jest uruchomiony?")
        print("Aby uruchomić serwer Ollama, wpisz w terminalu: ollama serve")
        return False
    except Exception as e:
        print(f"Nieoczekiwany błąd: {str(e)}")
        return False

if __name__ == "__main__":
    asyncio.run(test_ollama_api())
EOL

# Sprawdzenie czy Ollama jest zainstalowana i uruchomiona
echo "Sprawdzanie czy Ollama jest zainstalowana i dostępna..."
if ! command -v ollama &> /dev/null; then
    echo "UWAGA: Ollama nie znaleziona w systemie."
    echo "Można ją zainstalować ze strony https://ollama.com/download"

    read -p "Czy chcesz kontynuować mimo braku Ollama? (t/n): " continue_answer
    if [[ "$continue_answer" != "t" ]]; then
        echo "Test przerwany."
        exit 1
    fi
else
    echo "Ollama znaleziona w systemie."

    # Sprawdzenie czy serwer Ollama jest uruchomiony
    if curl -s --head --connect-timeout 2 http://localhost:11434 > /dev/null; then
        echo "Serwer Ollama jest uruchomiony."
    else
        echo "UWAGA: Serwer Ollama nie jest uruchomiony."
        echo "Aby uruchomić serwer, otwórz nowy terminal i wpisz: ollama serve"

        read -p "Czy uruchomić serwer Ollama teraz? (t/n): " start_ollama
        if [[ "$start_ollama" == "t" ]]; then
            echo "Uruchamianie serwera Ollama w nowym terminalu..."
            gnome-terminal -- bash -c "ollama serve; read -p 'Naciśnij Enter, aby zakończyć...'" || \
            xterm -e "ollama serve; read -p 'Naciśnij Enter, aby zakończyć...'" || \
            konsole --new-tab -e "ollama serve; read -p 'Naciśnij Enter, aby zakończyć...'" || \
            (
                echo "Nie udało się otworzyć nowego terminala dla Ollama."
                echo "Proszę uruchomić serwer Ollama ręcznie w nowym terminalu komendą: ollama serve"
                read -p "Naciśnij Enter po uruchomieniu serwera Ollama..." dummy
            )
        fi
    fi

    # Sprawdzenie czy model tinyllama jest pobrany
    if ollama list 2>/dev/null | grep -q tinyllama; then
        echo "Model tinyllama jest dostępny."
    else
        echo "UWAGA: Model tinyllama nie jest pobrany."

        read -p "Czy pobrać model tinyllama teraz? (t/n): " pull_model
        if [[ "$pull_model" == "t" ]]; then
            echo "Pobieranie modelu tinyllama..."
            ollama pull tinyllama
        else
            echo "Model tinyllama nie zostanie pobrany. Test może się nie powieść."
        fi
    fi
fi

# Bezpośredni test API Ollama
echo ""
echo "Wykonywanie bezpośredniego testu API Ollama..."
python test_ollama_direct.py

# Zapytanie o uruchomienie pełnego testu
echo ""
read -p "Czy chcesz uruchomić test integracji MCP z Ollama? (t/n): " run_test
if [[ "$run_test" == "t" ]]; then
    echo "Uruchamianie testu integracji MCP z Ollama..."
    python mcp_server/test_ollama_client.py
fi

# Zapytanie o uruchomienie serwera
echo ""
read -p "Czy chcesz uruchomić serwer MCP z integracją Ollama? (t/n): " run_server
if [[ "$run_server" == "t" ]]; then
    echo "Uruchamianie serwera MCP z Ollama..."
    python mcp_server/ollama_server.py
else
    echo "Test zakończony."
fi